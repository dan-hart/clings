#!/usr/bin/env bash
set -euo pipefail

STRICT=0
STAGED=0

for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --staged) STAGED=1 ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/asp-preflight.sh [--staged] [--strict]

Checks repository safety controls:
- Banned local-only paths are not tracked
- Staged files do not include obvious secret filenames
- Staged file content does not include private remote indicators
- Optional git-secrets scan if available
USAGE
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

fail() {
  echo "ASP preflight: FAIL - $1" >&2
  exit 1
}

echo "ASP preflight: starting"

tracked_banned="$(git ls-files | grep -E '^(research/|\.claude/|[Pp][Rr][Ii][Vv][Aa][Tt][Ee]/)' || true)"
if [[ -n "$tracked_banned" ]]; then
  echo "$tracked_banned" >&2
  fail "banned local-only paths are tracked"
fi

if [[ "$STAGED" -eq 1 ]]; then
  changed_files="$(git diff --cached --name-only --diff-filter=ACMR)"
else
  changed_files="$(git ls-files)"
fi

if [[ -z "$changed_files" ]]; then
  echo "ASP preflight: no files to scan"
  exit 0
fi

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  if [[ "$file" =~ (^|/)\.env(\.|$) ]] || [[ "$file" =~ \.(pem|key|p8|p12)$ ]]; then
    fail "potential secret file staged: $file"
  fi

  if [[ "$file" != "scripts/asp-preflight.sh" ]] && grep -E -n '(ssh://git@|100\.64\.|/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/)' "$file" >/dev/null 2>&1; then
    fail "private remote, internal network marker, or personal machine path found in $file"
  fi
done <<< "$changed_files"

if command -v git-secrets >/dev/null 2>&1; then
  if [[ "$STAGED" -eq 1 ]]; then
    git secrets --scan --cached || fail "git-secrets scan failed"
  else
    git secrets --scan || fail "git-secrets scan failed"
  fi
else
  if [[ "$STRICT" -eq 1 ]]; then
    fail "git-secrets is not installed (strict mode)"
  fi
  echo "ASP preflight: git-secrets not installed; skipping secret scan"
fi

echo "ASP preflight: OK"
