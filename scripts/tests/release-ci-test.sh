#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Isolate only the external GitHub API; exercise the real gate and JSON parser.
gh() { ruby -e 'puts File.read(ENV.fetch("CI_FIXTURE"))'; }
export -f gh
export CI_FIXTURE="$SCRIPT_DIR/fixtures/ci-release-running.json"
bash "$SOURCE_ROOT/scripts/release-ci-check.sh" 0000000000000000000000000000000000000000
for FIXTURE_NAME in ci-failed ci-missing; do
  export CI_FIXTURE="$SCRIPT_DIR/fixtures/$FIXTURE_NAME.json"
  if bash "$SOURCE_ROOT/scripts/release-ci-check.sh" 0000000000000000000000000000000000000000; then
    echo "Incorrectly accepted $FIXTURE_NAME" >&2
    exit 1
  fi
done
echo 'Release CI gate: 3 cases passed'
