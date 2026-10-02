#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PREFLIGHT="$SOURCE_ROOT/scripts/release-preflight.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/clings-release-tests.XXXXXX")"
# Keep fixtures on failure for investigation. Never remove a broad directory.
echo "Release test fixtures: $TEST_ROOT"
git clone --quiet --shared --no-tags --config core.hooksPath=/dev/null "$SOURCE_ROOT" "$TEST_ROOT/repo"
cd "$TEST_ROOT/repo"
git switch --quiet -C main 97d28c125726f365a392554a2ef921b222828029
git config user.name 'Release Tests'
git config user.email 'release-tests@example.invalid'
git config commit.gpgsign false
git config tag.gpgsign false
cp "$SCRIPT_DIR/fixtures/release-version.swift.txt" Sources/ClingsCLI/Clings.swift
cp "$SCRIPT_DIR/fixtures/release-agents.md.txt" AGENTS.md
cp "$SCRIPT_DIR/fixtures/release-changelog.md.txt" CHANGELOG.md
git add Sources/ClingsCLI/Clings.swift AGENTS.md CHANGELOG.md
git commit --quiet -m 'Release fixture'
git update-ref refs/remotes/origin/main HEAD

pass=0
expect_success() {
  if ! bash "$PREFLIGHT" "$@" > "$TEST_ROOT/output.log" 2>&1; then
    echo "Expected success: $*" >&2
    tail -15 "$TEST_ROOT/output.log" >&2
    exit 1
  fi
  pass=$((pass + 1))
}
expect_failure() {
  local expected="$1"
  shift
  if bash "$PREFLIGHT" "$@" > "$TEST_ROOT/output.log" 2>&1; then
    echo "Expected failure: $expected" >&2
    exit 1
  fi
  if ! grep -qE "$expected" "$TEST_ROOT/output.log"; then
    echo "Wrong failure, expected $expected" >&2
    tail -15 "$TEST_ROOT/output.log" >&2
    exit 1
  fi
  pass=$((pass + 1))
}

expect_success v0.4.0
cp "$SCRIPT_DIR/fixtures/release-agents-invalid.md.txt" AGENTS.md
git add AGENTS.md
git commit --quiet -m 'Malformed AGENTS version fixture'
git update-ref refs/remotes/origin/main HEAD
expect_failure 'AGENTS version' v0.4.0
cp "$SCRIPT_DIR/fixtures/release-agents.md.txt" AGENTS.md
cp "$SCRIPT_DIR/fixtures/release-changelog-invalid.md.txt" CHANGELOG.md
git add AGENTS.md CHANGELOG.md
git commit --quiet -m 'Malformed changelog version fixture'
git update-ref refs/remotes/origin/main HEAD
expect_failure 'Changelog version' v0.4.0
cp "$SCRIPT_DIR/fixtures/release-changelog.md.txt" CHANGELOG.md
git add CHANGELOG.md
git commit --quiet -m 'Restore valid version fixture'
git update-ref refs/remotes/origin/main HEAD
expect_failure 'version' v0.4.1
expect_failure 'semantic' v0.4
git switch --quiet -c task/fixture
expect_failure 'main' v0.4.0
git switch --quiet main
git update-ref refs/remotes/origin/main HEAD~1
expect_failure 'origin/main' v0.4.0
git update-ref refs/remotes/origin/main HEAD
touch untracked-fixture
expect_failure 'clean' v0.4.0
git add untracked-fixture
git commit --quiet -m 'Fixture dirty-state cleanup'
git update-ref refs/remotes/origin/main HEAD
expect_success v0.4.0
git tag -a v0.4.0 -m 'fixture tag'
expect_success v0.4.0
git tag -a v9.9.9 HEAD~1 -m 'stale fixture'
expect_failure 'version' v9.9.9
git switch --quiet --detach v0.4.0
expect_failure 'main' v0.4.0
expect_success v0.4.0 --tag-checkout
git switch --quiet main
# A same-tree orphan commit must not pass just because versions match.
MISSING_HISTORY_SHA="$(git commit-tree "$(git rev-parse 'HEAD^{tree}')" -m 'Missing reviewed history fixture')"
git update-ref refs/heads/main "$MISSING_HISTORY_SHA"
git update-ref refs/remotes/origin/main "$MISSING_HISTORY_SHA"
expect_failure 'missing required reviewed commit' v0.4.0
echo "Release preflight: $pass cases passed"
