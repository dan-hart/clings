#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

fail() {
  echo "release-docs-check: FAIL - $1" >&2
  exit 1
}

echo "release-docs-check: checking CLI help, README coverage, completions, and docs..."

for required in README.md CHANGELOG.md CONTRIBUTING.md SECURITY.md AGENTS.md; do
  [[ -f "$required" ]] || fail "missing required documentation file: $required"
done

HELP_OUTPUT="$(swift run clings --help)"

COMMANDS_RAW="$(
  printf '%s\n' "$HELP_OUTPUT" |
    awk '/^SUBCOMMANDS:/{flag=1;next} flag && /^$/ {exit} flag {print}' |
    sed -En 's/^[[:space:]]*([a-z0-9-]+).*/\1/p'
)"

[[ -n "$COMMANDS_RAW" ]] || fail "could not parse subcommands from 'clings --help'"

missing_in_readme=()
while IFS= read -r cmd; do
  [[ -z "$cmd" ]] && continue
  if ! rg -q "\\| \`$cmd\` \\|" README.md; then
    missing_in_readme+=("$cmd")
  fi
done <<EOF
$COMMANDS_RAW
EOF

if [[ "${#missing_in_readme[@]}" -gt 0 ]]; then
  fail "README command table missing: ${missing_in_readme[*]}"
fi

ZSH_COMPLETIONS="$(swift run clings completions zsh)"
missing_in_completions=()
while IFS= read -r cmd; do
  [[ -z "$cmd" ]] && continue
  if ! printf '%s\n' "$ZSH_COMPLETIONS" | rg -q "'$cmd:"; then
    missing_in_completions+=("$cmd")
  fi
done <<EOF
$COMMANDS_RAW
EOF

if [[ "${#missing_in_completions[@]}" -gt 0 ]]; then
  fail "zsh completions missing commands: ${missing_in_completions[*]}"
fi

PUBLIC_DOC_FILES=(
  README.md
  Sources/ClingsCLI/Clings.swift
  Sources/ClingsCLI/Commands
  docs
)

PERSONAL_PATTERN='(Call mom|Buy milk|ProjectName|Q1 Planning|Sprint 12|Family|expense report|Migration Project|Operations Project)'
if rg -n "$PERSONAL_PATTERN" "${PUBLIC_DOC_FILES[@]}" -S >/dev/null; then
  fail "found personal, work-specific, or placeholder examples in help/docs (update examples to neutral text)"
fi

if rg -n '/Users/' "${PUBLIC_DOC_FILES[@]}" -S >/dev/null; then
  fail "found absolute local filesystem paths in public docs/help"
fi

echo "release-docs-check: OK"
