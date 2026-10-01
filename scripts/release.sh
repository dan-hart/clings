#!/usr/bin/env bash
# Run only from a clean checkout of main with the version bump already merged.
set -euo pipefail
[[ $# == 1 && "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Usage: release.sh vVERSION' >&2; exit 1; }
RELEASE_TAG="$1"
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIRECTORY/.."
git fetch origin main --tags
bash scripts/release-preflight.sh "$RELEASE_TAG"
RELEASE_SHA="$(git rev-parse HEAD)"
bash scripts/release-ci-check.sh "$RELEASE_SHA"
# Never replace an existing tag. The source gate verifies an existing local tag.
if ! git show-ref --verify --quiet "refs/tags/$RELEASE_TAG"; then
  git tag -a "$RELEASE_TAG" -m "Release $RELEASE_TAG"
fi
git push origin "refs/tags/$RELEASE_TAG"

RUN_ID=''
for ATTEMPT in $(seq 1 12); do
  RUN_ID="$(gh run list --repo dan-hart/clings --workflow release.yml --commit "$RELEASE_SHA" \
    --json databaseId,headBranch,event --jq ".[] | select(.headBranch == \"$RELEASE_TAG\" and .event == \"push\") | .databaseId" | head -1)"
  [[ -n "$RUN_ID" ]] && break
  sleep 10
done
[[ -n "$RUN_ID" ]] || { echo 'Release workflow was not found; inspect Actions before retrying' >&2; exit 1; }
gh run watch "$RUN_ID" --repo dan-hart/clings --exit-status --interval 15
gh release view "$RELEASE_TAG" --repo dan-hart/clings --json assets --jq '.assets[].name' |
  ruby -e 'a=STDIN.read.lines.map(&:strip); v=ARGV[0]; required=["clings-#{v}-macos-arm64.tar.gz", "clings-#{v}-macos-x86_64.tar.gz", "SHA256SUMS"]; abort "Release assets missing" unless (required-a).empty?' "$RELEASE_TAG"
bash scripts/update-homebrew.sh "$RELEASE_TAG"
brew update
if brew list --versions clings >/dev/null 2>&1; then
  brew upgrade clings
else
  brew install dan-hart/tap/clings
fi
brew test clings
bash scripts/install-smoke-test.sh "$(brew --prefix clings)/bin/clings" "${RELEASE_TAG#v}"
echo "Release verified: $RELEASE_TAG at $RELEASE_SHA"
