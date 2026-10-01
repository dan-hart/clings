#!/usr/bin/env bash
# Read-only source integrity gate. Caller must fetch origin/main before running.
set -euo pipefail

fail() { echo "Release preflight: $*" >&2; exit 1; }
[[ $# -ge 1 && $# -le 2 ]] || fail 'Usage: release-preflight.sh vMAJOR.MINOR.PATCH [--tag-checkout]'
RELEASE_TAG="$1"
[[ "$RELEASE_TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail 'Tag must use semantic version vMAJOR.MINOR.PATCH'
MODE="${2:-}"
[[ -z "$MODE" || "$MODE" == '--tag-checkout' ]] || fail 'Unknown preflight option'
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail 'Not inside a Git checkout'
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || fail 'Release source must be clean, including untracked files'

HEAD_SHA="$(git rev-parse HEAD)"
MAIN_SHA="$(git rev-parse refs/remotes/origin/main 2>/dev/null)" || fail 'Fetch origin/main before release'
[[ "$HEAD_SHA" == "$MAIN_SHA" ]] || fail 'HEAD must exactly match fetched origin/main'
if [[ "$MODE" == '--tag-checkout' ]]; then
  TAG_SHA="$(git rev-parse "$RELEASE_TAG^{commit}" 2>/dev/null)" || fail 'Release tag is missing'
  [[ "$TAG_SHA" == "$HEAD_SHA" ]] || fail 'Release tag does not match current main'
else
  [[ "$(git symbolic-ref --quiet --short HEAD || true)" == 'main' ]] || fail 'Release must be prepared on main'
fi

RELEASE_VERSION="${RELEASE_TAG#v}"
SOURCE_VERSION="$(ruby -e 's=File.read("Sources/ClingsCLI/Clings.swift"); m=s.match(/version:\s*"([0-9]+\.[0-9]+\.[0-9]+)"/); abort "Missing source version" unless m; puts m[1]')"
[[ "$SOURCE_VERSION" == "$RELEASE_VERSION" ]] || fail "Source version $SOURCE_VERSION does not match $RELEASE_TAG"
rg -q "\*\*Version:\*\* $RELEASE_VERSION$" AGENTS.md || fail 'AGENTS version does not match release'
rg -q "^## \[$RELEASE_VERSION\] - " CHANGELOG.md || fail 'Changelog version entry is missing'

# These reviewed fixes must never be lost by publishing from an old checkout.
for REQUIRED_COMMIT in \
  1fe04b495ca99cef9ae086979236bc4416964982 \
  456d9e7b02bd694a883750e1edd8c9f40242573a; do
  git merge-base --is-ancestor "$REQUIRED_COMMIT" HEAD || fail "Release is missing required reviewed commit $REQUIRED_COMMIT"
done

if git show-ref --verify --quiet "refs/tags/$RELEASE_TAG"; then
  [[ "$(git rev-parse "$RELEASE_TAG^{commit}")" == "$HEAD_SHA" ]] || fail 'Existing tag points to a different commit; never move a published tag'
  [[ "$(git cat-file -t "$RELEASE_TAG")" == 'tag' ]] || fail 'Release tags must be annotated'
fi
echo "Release source verified: $RELEASE_TAG at $HEAD_SHA (CI/artifact checks are separate gates)"
