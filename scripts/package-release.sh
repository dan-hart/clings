#!/usr/bin/env bash
set -euo pipefail
[[ $# == 3 ]] || { echo 'Usage: package-release.sh VERSION ARCH OUTPUT_DIRECTORY' >&2; exit 1; }
RELEASE_VERSION="$1"
RELEASE_ARCH="$2"
OUTPUT_DIRECTORY="$3"
[[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid version' >&2; exit 1; }
[[ "$RELEASE_ARCH" == arm64 || "$RELEASE_ARCH" == x86_64 ]] || { echo 'Unsupported architecture' >&2; exit 1; }
BIN_DIRECTORY="$(swift build -c release --show-bin-path)"
RELEASE_BINARY="$BIN_DIRECTORY/clings"
[[ -x "$RELEASE_BINARY" ]] || { echo 'Build the release binary before packaging' >&2; exit 1; }
[[ "$("$RELEASE_BINARY" --version)" == "$RELEASE_VERSION" ]] || { echo 'Binary version does not match release' >&2; exit 1; }
lipo -verify_arch "$RELEASE_ARCH" "$RELEASE_BINARY"
mkdir -p "$OUTPUT_DIRECTORY"
PACKAGE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/clings-package.XXXXXX")"
mkdir -p "$PACKAGE_DIRECTORY/bin" "$PACKAGE_DIRECTORY/completions"
cp "$RELEASE_BINARY" "$PACKAGE_DIRECTORY/bin/clings"
cp LICENSE "$PACKAGE_DIRECTORY/LICENSE"
for SHELL_NAME in bash zsh fish; do
  "$RELEASE_BINARY" completions "$SHELL_NAME" > "$PACKAGE_DIRECTORY/completions/clings.$SHELL_NAME"
done
COMMIT_SHA="$(git rev-parse HEAD)"
RELEASE_SWIFT_VERSION="$(swift --version)"
RELEASE_SDK_VERSION="$(xcrun --show-sdk-version)"
ruby -rjson -e 'puts JSON.pretty_generate({version: ARGV[0], architecture: ARGV[1], commit: ARGV[2], swiftVersion: ARGV[3], sdkVersion: ARGV[4]})' \
  "$RELEASE_VERSION" "$RELEASE_ARCH" "$COMMIT_SHA" "$RELEASE_SWIFT_VERSION" "$RELEASE_SDK_VERSION" > "$PACKAGE_DIRECTORY/build-info.json"
# Normalize timestamps/ownership and disable gzip timestamps for reproducible archives.
COMMIT_TIME="$(git log -1 --format=%ct)"
NORMALIZED_TIME="$(date -r "$COMMIT_TIME" '+%Y%m%d%H%M.%S')"
find "$PACKAGE_DIRECTORY" -exec touch -t "$NORMALIZED_TIME" {} +
COPYFILE_DISABLE=1 tar --format ustar --uid 0 --gid 0 --uname root --gname wheel \
  -cf - -C "$PACKAGE_DIRECTORY" . | gzip -n > "$OUTPUT_DIRECTORY/clings-v$RELEASE_VERSION-macos-$RELEASE_ARCH.tar.gz"
echo "Packaged $RELEASE_VERSION ($RELEASE_ARCH) at $COMMIT_SHA"
