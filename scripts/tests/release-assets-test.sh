#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/clings-asset-tests.XXXXXX")"
ASSET_DIRECTORY="$TEST_DIRECTORY/assets"
PACKAGE_DIRECTORY="$TEST_DIRECTORY/package"
mkdir -p "$ASSET_DIRECTORY" "$PACKAGE_DIRECTORY/bin" "$PACKAGE_DIRECTORY/completions"
cp "$SCRIPT_DIRECTORY/fixtures/release-agents.md.txt" "$PACKAGE_DIRECTORY/LICENSE"
cp "$SCRIPT_DIRECTORY/fixtures/release-agents.md.txt" "$PACKAGE_DIRECTORY/bin/clings"
for SHELL_NAME in bash zsh fish; do
  cp "$SCRIPT_DIRECTORY/fixtures/release-agents.md.txt" "$PACKAGE_DIRECTORY/completions/clings.$SHELL_NAME"
done
TEST_SHA=1111111111111111111111111111111111111111
package() {
  ruby -rjson -e 'puts JSON.generate(version: "0.4.0", architecture: ARGV[0], commit: ARGV[1])' "$1" "$2" > "$PACKAGE_DIRECTORY/build-info.json"
  tar -czf "$ASSET_DIRECTORY/clings-v0.4.0-macos-$1.tar.gz" -C "$PACKAGE_DIRECTORY" .
}
checksums() { (cd "$ASSET_DIRECTORY" && shasum -a 256 *.tar.gz > SHA256SUMS); }
verify() { bash "$SCRIPT_DIRECTORY/../verify-release-assets.sh" "$ASSET_DIRECTORY" v0.4.0 "$TEST_SHA"; }
reject() { if verify > "$TEST_DIRECTORY/output" 2>&1; then echo "Expected rejection: $1" >&2; exit 1; fi; }
package arm64 "$TEST_SHA"
package x86_64 "$TEST_SHA"
checksums
verify
package arm64 2222222222222222222222222222222222222222
checksums
reject 'wrong commit with valid checksum'
package arm64 "$TEST_SHA"
checksums
printf 'corruption' >> "$ASSET_DIRECTORY/clings-v0.4.0-macos-arm64.tar.gz"
reject 'corrupt archive'
package arm64 "$TEST_SHA"
checksums
cp "$ASSET_DIRECTORY/clings-v0.4.0-macos-arm64.tar.gz" "$ASSET_DIRECTORY/clings-v0.4.0-macos-x86_64.tar.gz"
checksums
reject 'wrong architecture'
package x86_64 "$TEST_SHA"
checksums
printf '%064d  ../outside.tar.gz\n' 0 >> "$ASSET_DIRECTORY/SHA256SUMS"
reject 'unexpected checksum path'
echo 'Release asset gate: 5 cases passed'
