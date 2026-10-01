#!/usr/bin/env bash
# Update the maintainer's public formula using the actual GitHub source archive.
set -euo pipefail
[[ $# == 1 && "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Usage: update-homebrew.sh vVERSION' >&2; exit 1; }
RELEASE_TAG="$1"
ARCHIVE_URL="https://github.com/dan-hart/clings/archive/refs/tags/$RELEASE_TAG.tar.gz"
UPDATE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/clings-tap-update.XXXXXX")"
curl --fail --location --retry 3 "$ARCHIVE_URL" --output "$UPDATE_DIRECTORY/source.tar.gz"
ARCHIVE_SHA="$(shasum -a 256 "$UPDATE_DIRECTORY/source.tar.gz" | awk '{print $1}')"
gh api repos/dan-hart/homebrew-tap/contents/Formula/clings.rb > "$UPDATE_DIRECTORY/formula.json"
FORMULA_SHA="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).fetch("sha")' "$UPDATE_DIRECTORY/formula.json")"
FORMULA_CONTENT="$(ruby -rjson -rbase64 -e '
  data = JSON.parse(File.read(ARGV[0]))
  formula = Base64.decode64(data.fetch("content"))
  abort "Unexpected formula class" unless formula.include?("class Clings < Formula")
  abort "Unexpected source URL" unless formula.match?(%r{url "https://github.com/dan-hart/clings/archive/refs/tags/v[0-9.]+\.tar\.gz"})
  formula.sub!(%r{url "https://github.com/dan-hart/clings/archive/refs/tags/v[0-9.]+\.tar\.gz"}, "url \"#{ARGV[1]}\"")
  abort "Missing formula checksum" unless formula.sub!(/sha256 "[0-9a-f]{64}"/, "sha256 \"#{ARGV[2]}\"")
  formula.sub!(/depends_on xcode: \["[0-9.]+", :build\]/, "depends_on xcode: [\"16.0\", :build]")
  formula.sub!("depends_on :macos", "depends_on macos: :sonoma")
  puts Base64.strict_encode64(formula)
' "$UPDATE_DIRECTORY/formula.json" "$ARCHIVE_URL" "$ARCHIVE_SHA")"
gh api repos/dan-hart/homebrew-tap/contents/Formula/clings.rb --method PUT \
  -f message="chore: update clings to $RELEASE_TAG" -f sha="$FORMULA_SHA" -f content="$FORMULA_CONTENT" \
  --jq '.commit.html_url'
echo "Homebrew source checksum: $ARCHIVE_SHA"
