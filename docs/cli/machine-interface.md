# A CLI you can build on

clings 0.4 introduces a versioned JSON interface. Human-readable output remains
the default. Put `--json` after the command, and check both the process exit
status and the response's `success` field.

## Response contract

JSON command responses use this envelope:

```json
{
  "schemaVersion": 1,
  "success": true,
  "data": {"items": []}
}
```

The shape of `data` depends on the command. List responses retain their `items`
array; a single todo remains an object inside `data`. Failures include
`error.code` and an actionable `error.message`. Partial operations retain their
per-item results in `data`, even when `success` is false. Do not treat a failed
batch as proof that nothing changed.

```bash
clings today --json | jq -r '.data.items[] | [.id, .name] | @tsv'
clings filter "tags CONTAINS 'docs'" --sort due --limit 5 --json \
  | jq '.data.items'
clings add "Draft release notes tomorrow #docs" --parse-only --json \
  | jq '.data'
```

Help, version output, and generated shell completion scripts keep their native
text formats. Interactive picking is not a JSON interface: use an exact ID
instead. Prompts and progress are not machine data.

### Exit statuses

| Status | Meaning | What a script should do |
|--------|---------|------------------------|
| `0` | Successful operation or explicit interactive cancellation | Inspect the result |
| `1` | Invalid input, ambiguous selection, or missing noninteractive confirmation | Correct input or provide explicit authorization |
| `2` | Runtime failure, partial mutation, or unhealthy required diagnostic capability | Inspect retained results before retrying |

When redirecting JSON, preserve the exit code:

```bash
if clings doctor --json > doctor.json; then
  jq '.data' doctor.json
else
  clings_status=$?
  jq '.error, .data' doctor.json
  exit "$clings_status"
fi
```

## Query deliberately

Search, filter, and saved-view execution share scope, sorting, and limits.
`--list` narrows the selection; `--include-logbook` includes historical items.
Available sort keys are `id`, `name`, `due`, `when`, `created`, and `modified`.
A leading minus reverses order; dates that are absent stay last. Equal values
use the ID as a stable tie-breaker. Limits must be positive.

```bash
clings search docs --list inbox --sort name --limit 20
clings filter "when IS NOT NULL" --include-logbook --sort=-modified --limit 10
clings views run docs-today --sort due --limit 3
```

`when` is the scheduled start, not the deadline. `due` is the deadline. Filter
operators retain their existing left-to-right behavior; use parentheses to make
mixed `AND` and `OR` grouping explicit. Unknown fields and trailing expressions
are rejected instead of silently matching.

## Preview, authorize, verify

Add and update previews resolve the complete mutation without applying it.
Invalid dates fail before writes. Explicit scalar flags override parsed/template
values; add merges tags while update replaces its tag set. Saved relative template expressions are resolved when
the template runs, not frozen when it is saved.

```bash
clings add "Draft guide tomorrow by friday #docs" --parse-only --json
clings update TASK_ID --name "Publish guide" --when tomorrow --parse-only --json
```

Deletion uses Things' supported cancellation API. It is not a move to Trash and
does not permanently erase a todo. Inspect the ID, then confirm interactively
or use `--force` intentionally. Undo is a local mutation journal, not a backup.
Scheduling, headings, and project moves cannot be promised full restoration;
previews and help expose these limits.

Project and tag management are not recorded for undo. A partially created
project reports its ID and completed assignments with exit 2. Inspect that ID
before retrying so a later property failure does not create a duplicate project.

A timeout is not a rollback. Inspect Things before retrying an uncertain
automation outcome; terminating the CLI's script cannot retract an operation
already received by the application.

## Freeze a batch selection

Save a dry-run plan to review the exact IDs and proposed changes. Executing the
saved plan does not rerun the selection query. The plan is a preview, not write
authorization; execution still requires confirmation or `--yes`.

```bash
umask 077 # Plans can contain private task data.
clings bulk complete --list inbox --where "tags CONTAINS 'done'" \
  --dry-run --json > completion-plan.json
clings bulk complete --execute-plan completion-plan.json --yes --json
```

Plans include expected snapshots and persistent per-item execution state.
Execution updates the saved plan in place. Redirect results to a different file;
redirecting stdout onto the plan being read would truncate it before execution.
Changed tasks are conflicts, not silently updated selections. Successful items
are not repeated on retry. Interrupted writes are reconciled against current
state before another write is attempted. Keep the plan file until execution is
resolved; it may contain task titles and notes, so treat it as private data.

Supported status/tag batches record grouped undo. Failed reversal members remain
available for retry. Journal or plan-storage failures are reported explicitly;
they must not be interpreted as proof that the underlying Things write failed.

## Diagnose without changing tasks

`doctor` separates local storage, readable Things data, automation runtime,
optional URL-scheme token, and automation authorization. Its optional automation
probe is read-only. An absent token does not make SQLite reads unhealthy.
Redacted support output must not expose the token, task data, or private paths.

Use `clings doctor --help` for probe and support-output options, and inspect its
JSON result and exit status before automating remediation.
