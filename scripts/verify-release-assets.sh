#!/usr/bin/env bash
# Verify downloaded release assets without extracting or executing their contents.
set -euo pipefail
[[ $# == 3 ]] || { echo 'Usage: verify-release-assets.sh DIRECTORY TAG COMMIT_SHA' >&2; exit 1; }
ASSET_DIRECTORY="$1"
RELEASE_TAG="$2"
RELEASE_SHA="$3"
[[ "$RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ && "$RELEASE_SHA" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid release identity' >&2; exit 1; }
cd "$ASSET_DIRECTORY"
# Only the two expected archive filenames may be referenced by the checksum file.
ruby -e '
  names = %w[arm64 x86_64].map { |arch| "clings-#{ARGV[0]}-macos-#{arch}.tar.gz" }
  lines = File.readlines("SHA256SUMS", chomp: true)
  actual = lines.map { |line| m = line.match(/\A[0-9a-f]{64}  (.+)\z/); abort "Invalid checksum entry" unless m; m[1] }
  abort "Unexpected or duplicate checksum filenames" unless actual.sort == names.sort
' "$RELEASE_TAG"
shasum -a 256 -c SHA256SUMS
for RELEASE_ARCH in arm64 x86_64; do
  ARCHIVE="clings-$RELEASE_TAG-macos-$RELEASE_ARCH.tar.gz"
  tar -tzf "$ARCHIVE" | ruby -e '
    entries = STDIN.read.lines.map(&:strip)
    abort "Unsafe archive path" if entries.any? { |p| p.start_with?("/") || p.split("/").include?("..") }
    required = ["./bin/clings", "./LICENSE", "./build-info.json"] + %w[bash zsh fish].map { |s| "./completions/clings.#{s}" }
    abort "Missing archive contents" unless (required - entries).empty?
  '
  tar -xOzf "$ARCHIVE" ./build-info.json | ruby -rjson -e '
    info = JSON.parse(STDIN.read)
    expected = {"version" => ARGV[0], "architecture" => ARGV[1], "commit" => ARGV[2]}
    abort "Release archive metadata mismatch" unless expected.all? { |k, v| info[k] == v }
  ' "${RELEASE_TAG#v}" "$RELEASE_ARCH" "$RELEASE_SHA"
done
echo "Release assets verified: $RELEASE_TAG at $RELEASE_SHA"
