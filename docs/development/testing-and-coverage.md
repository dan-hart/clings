# Testing and Coverage

`clings` uses Swift Testing for the package test suite, and the project target is at least 80% source coverage.

## Everyday Verification

Run the regular test suite:

```bash
swift test
```

Build the CLI:

```bash
swift build
swift build -c release
```

## Coverage Workflow

Generate coverage artifacts:

```bash
swift test --enable-code-coverage
```

The project measures coverage against files in `Sources/`, not bundled dependencies. This command reports the source-only total:

```bash
xcrun llvm-cov export -summary-only \
  .build/arm64-apple-macosx/debug/clingsPackageTests.xctest/Contents/MacOS/clingsPackageTests \
  -instr-profile=.build/arm64-apple-macosx/debug/codecov/default.profdata |
  jq --arg sourcesPrefix "$(pwd)/Sources/" \
     '[.data[0].files[] | select(.filename | startswith($sourcesPrefix))] |
      {files: length,
       lines_total: (map(.summary.lines.count) | add),
       lines_covered: (map(.summary.lines.covered) | add),
       line_percent: ((map(.summary.lines.covered) | add) / (map(.summary.lines.count) | add) * 100)}'
```

## File-Level Drilldown

Use this report to spot low-coverage files inside `Sources/`:

```bash
xcrun llvm-cov export -summary-only \
  .build/arm64-apple-macosx/debug/clingsPackageTests.xctest/Contents/MacOS/clingsPackageTests \
  -instr-profile=.build/arm64-apple-macosx/debug/codecov/default.profdata |
  jq -r --arg sourcesPrefix "$(pwd)/Sources/" '.data[0].files[] |
         select(.filename | startswith($sourcesPrefix)) |
         [.summary.lines.percent, .summary.lines.count, .summary.lines.covered, .filename] |
         @tsv' |
  sort -n
```

## Suggested Release Preflight

Before cutting a release:

```bash
swift test
swift test --enable-code-coverage
swift build
swift build -c release
bash scripts/release-docs-check.sh
```

## Notes

- Prefer source-only coverage when discussing the project target. Dependency coverage from `swift-argument-parser`, GRDB, and SwiftDate will otherwise dilute the total.
- Keep command help and `docs/` aligned. If you add a new command family, update the command reference and rerun the docs check script.
