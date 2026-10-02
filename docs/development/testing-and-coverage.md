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
bash scripts/coverage-check.sh
```

For an independent scratch build, pass its exported JSON path to the gate:
`bash scripts/coverage-check.sh "$(swift test --scratch-path /private/tmp/clings-coverage --show-codecov-path)"`.
Generate that scratch build's instrumented report first; the gate does not run tests.

The project measures coverage against files in `Sources/`, not bundled dependencies. This command reports the source-only total:

```bash
clings_coverage_report="$(swift test --show-codecov-path)"
jq --arg sourcesPrefix "$(pwd)/Sources/" \
     '[.data[0].files[] | select(.filename | startswith($sourcesPrefix))] |
      {files: length,
       lines_total: (map(.summary.lines.count) | add),
       lines_covered: (map(.summary.lines.covered) | add),
       line_percent: ((map(.summary.lines.covered) | add) / (map(.summary.lines.count) | add) * 100)}' "$clings_coverage_report"
```

## File-Level Drilldown

Use this report to spot low-coverage files inside `Sources/`:

```bash
clings_coverage_report="$(swift test --show-codecov-path)"
jq -r --arg sourcesPrefix "$(pwd)/Sources/" '.data[0].files[] |
         select(.filename | startswith($sourcesPrefix)) |
         [.summary.lines.percent, .summary.lines.count, .summary.lines.covered, .filename] |
         @tsv' "$clings_coverage_report" |
  sort -n
```

## Suggested Release Preflight

Before cutting a release:

```bash
swift test
swift test --enable-code-coverage
bash scripts/coverage-check.sh
swift build
swift build -c release
bash scripts/release-docs-check.sh
```

## Notes

- Prefer source-only coverage when discussing the project target. Dependency coverage from `swift-argument-parser`, GRDB, and SwiftDate will otherwise dilute the total.
- Keep command help and `docs/` aligned. If you add a new command family, update the command reference and rerun the docs check script.
- `coverage-check.sh` reads SwiftPM's exported report and rejects source-only line coverage below 80%, or database/shared query-validation coverage below 95%. Run an instrumented test suite first so the report is current. Error paths also need explicit failure/partial-result tests; aggregate line coverage is not proof of safety.
