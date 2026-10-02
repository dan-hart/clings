#!/usr/bin/env bash
# Run swift test --enable-code-coverage before this read-only coverage gate.
set -euo pipefail
SOURCE_DIRECTORY="$(pwd)/Sources/"
COVERAGE_PATH="$(swift test --show-codecov-path)"
ruby -rjson -e '
  files = JSON.parse(File.read(ARGV[0])).fetch("data").flat_map { |data| data.fetch("files") }
  source = files.select { |file| file.fetch("filename").start_with?(ARGV[1]) }
  abort "No source coverage found" if source.empty?
  total = source.sum { |file| file.fetch("summary").fetch("lines").fetch("count") }
  covered = source.sum { |file| file.fetch("summary").fetch("lines").fetch("covered") }
  abort "Source coverage has no executable lines" if total.zero?
  percentage = 100.0 * covered / total
  puts format("Source line coverage: %.2f%% (%d/%d)", percentage, covered, total)
  abort "Source line coverage is below the 80% project requirement" if percentage < 80
  %w[ClingsCore/ThingsClient/ThingsDatabase.swift ClingsCLI/Support/QueryOptions.swift].each do |path|
    critical = source.select { |file| file.fetch("filename").end_with?("/Sources/#{path}") }
    abort "Missing critical-path coverage: #{path}" if critical.empty?
    count = critical.sum { |file| file.fetch("summary").fetch("lines").fetch("count") }
    covered = critical.sum { |file| file.fetch("summary").fetch("lines").fetch("covered") }
    abort "Critical source has no executable lines: #{path}" if count.zero?
    percentage = 100.0 * covered / count
    puts format("Critical source coverage %s: %.2f%%", path, percentage)
    abort "Critical source coverage below 95%: #{path}" if percentage < 95
  end
' "$COVERAGE_PATH" "$SOURCE_DIRECTORY"
