#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 ]] || { echo 'Usage: install-smoke-test.sh BINARY VERSION' >&2; exit 1; }
SMOKE_BINARY="$1"
SMOKE_VERSION="$2"
[[ -x "$SMOKE_BINARY" ]] || { echo 'Installed binary is missing' >&2; exit 1; }
[[ "$("$SMOKE_BINARY" --version)" == "$SMOKE_VERSION" ]] || { echo 'Installed version mismatch' >&2; exit 1; }
"$SMOKE_BINARY" bulk complete --help | rg -q 'execute-plan'
"$SMOKE_BINARY" filter --help | rg -q 'include-logbook'
"$SMOKE_BINARY" add 'Release smoke test' --when tomorrow --parse-only --json |
  ruby -rjson -e 'j=JSON.parse(STDIN.read); abort "Wrong JSON schema" unless j["schemaVersion"] == 1 && j["success"] == true && j.fetch("data")["when"]'
if "$SMOKE_BINARY" add 'Release smoke test' --when invalid-date --parse-only --json > /dev/null 2>&1; then
  echo 'Invalid date was accepted by installed binary' >&2
  exit 1
fi
echo "Installed CLI smoke checks passed: $SMOKE_VERSION (no Things writes)"
