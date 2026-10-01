#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 && "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Usage: release-notes.sh vVERSION' >&2; exit 1; }
ruby -e '
  version = ARGV.fetch(0).delete_prefix("v")
  lines = File.readlines("CHANGELOG.md")
  start = lines.index { |line| line.start_with?("## [#{version}] - ") }
  abort "Missing release changelog" unless start
  rest = lines.drop(start + 1)
  finish = rest.index { |line| line.start_with?("## [") } || rest.length
  puts rest.take(finish).join.strip
' "$1"
