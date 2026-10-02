#!/usr/bin/env bash
# Require green CI on the exact commit being released, not a branch's old result.
set -euo pipefail
[[ $# == 1 && "$1" =~ ^[0-9a-f]{40}$ ]] || { echo 'Usage: release-ci-check.sh COMMIT_SHA' >&2; exit 1; }
RELEASE_SHA="$1"
gh api "repos/dan-hart/clings/commits/$RELEASE_SHA/check-runs?per_page=100" |
  ruby -rjson -e '
    checks = JSON.parse(STDIN.read).fetch("check_runs")
    ci = checks.select { |check| check["name"] == "Build, Test, Release Build" }
    abort "No CI check on this exact release commit" if ci.empty?
    latest = ci.max_by { |check| check.fetch("id") }
    abort "Release CI is not green" unless latest["status"] == "completed" && latest["conclusion"] == "success"
    # The tag workflow creates its own running checks on the same commit. They
    # depend on this gate, so only earlier CI/review checks belong in the gate.
    prior_checks = checks.reject { |check| ["Release arm64", "Release x86_64", "Publish verified release"].include?(check["name"]) }
    latest_by_name = prior_checks.group_by { |check| check["name"] }.values.map { |group| group.max_by { |check| check.fetch("id") } }
    abort "Another release-commit check is pending or failed" unless latest_by_name.all? { |check| check["status"] == "completed" && ["success", "neutral", "skipped"].include?(check["conclusion"]) }
    puts "Exact-commit CI verified"
  '
