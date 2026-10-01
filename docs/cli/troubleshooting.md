# Troubleshooting

[README](../../README.md) · [Getting started](getting-started.md) · [Command reference](command-reference.md)

## Start with evidence

```bash
clings --version
clings doctor --verbose
clings COMMAND --help
```

Replace `COMMAND` with the failing command. Record the version, exact command, error message, macOS version, and whether it fails on a read or write. Redact auth tokens, task notes, and personal paths before sharing diagnostics.

`doctor` checks local config/database/runtime availability. It does not prove automation permission or successful communication with Things. It may create the config directory. Missing auth tokens produce warnings even if you only use commands that do not need them.

## Reads work, writes fail

These use different interfaces: reads open SQLite; writes invoke Things automation. Inspect **System Settings > Privacy & Security > Automation** for the application running clings. Open Things manually if needed and retry from the same terminal/application. A token is not a substitute for macOS automation permission.

## Database not found or unreadable

Make sure Things 3 for Mac is installed and has initialized its local data by opening it. Check the precise error from `doctor --verbose`; database paths or formats may change with Things updates. Do not edit the Things database to work around a CLI error. Report the Things and clings versions and use the Things UI while the issue is investigated.

## A command or option is missing

```bash
command -v clings
clings --version
clings --help
```

You may be running an older Homebrew release or a different binary on `PATH`. Repository docs describe current source. Inspect `clings COMMAND --help`, and build source if you need an unreleased feature. Regenerate shell completions after upgrading.

## Dates are missing or surprising

```bash
clings add "Draft outline" --when tomorrow --deadline friday --parse-only --json
```

Inspect `when` and `deadline` separately. The planned start and deadline are different fields. Use explicit options or ISO dates when free-text interpretation is unclear. Invalid dates and impossible times are rejected before writes. Both `add --parse-only` and `update --parse-only` show the final fields without applying changes.

Templates retain relative expressions from title phrases or explicit
`template save --when ... --deadline ...` options. Explicit options override the
embedded expressions; relative dates are evaluated when a task is created.

The current source builds creation dates from Gregorian components to avoid locale-sensitive English AppleScript date parsing and includes runtime tests for midnight and half-hour DST transitions. Older installed releases may not contain this fix. Filter date parsing is separate and `today` means midnight; use `due < tomorrow` for deadlines anywhere today.

## Today looks too large

Today includes relevant previously activated open work and due/overdue deadlines, not just tasks whose start date is exactly today. Repeating templates and trashed-project descendants are excluded by the SQLite filters. Compare the task IDs against Things before reporting an overcount. Historical details are in [Issue #5 notes](../issues/issue-5-today-list-overcount.md).

## Filters return no completed work

`filter` and saved views read open lists only. `status = completed` cannot expand their scope. Use:

```bash
clings logbook --json | jq '.items[] | select(.status == "completed")'
```

Check field spelling, expression quotes, date boundaries, and the distinction between a project name and an ID. Bulk `--where` only filters its selected `--list`.

## jq reports invalid JSON

First inspect the command output directly. `pick` menus, bulk previews/prompts, review reports, and ambiguous `complete --title` output may contain plain text despite `--json`. Use list/search/filter JSON for pipelines. List results use `.items[]`; `show` is a single object; views/template definitions use bare arrays.

## Delete did not put a task in Trash

The current automation implementation sets status to canceled. Both `delete` and `pick delete` use that behavior. Single-task delete has no implemented confirmation prompt; `--force` is a compatibility flag. Use Things itself for trash/permanent deletion. `undo` can reopen a recorded cancellation, but does not recover arbitrary deleted data.

## A bulk command only partly worked

Bulk writes are sequential and do not roll back earlier successes. Complete/cancel/move report success/failure counts; tagging can stop at the first failure. Inspect the actual remaining tasks before retrying so you do not repeat unintended actions. A successful process exit alone is not proof that every item succeeded. Bulk operations are not recorded in undo history.

## Undo did not restore everything

`undo --show` displays the latest supported entry. Bulk writes, project/tag management, and changes outside clings are not recorded. Update snapshots do not restore scheduling or headings. Entries are removed before reversal, so failures consume them. Use your Things backups for recovery beyond these limits.

## open returns an error

`clings open` is currently disabled. It does not navigate Things or silently succeed. Use `clings show ID` in the terminal or open Things manually.

## Source tests cannot import Testing

The package uses Swift Testing and declares Swift tools version 6.0. Inspect `swift --version` and `xcode-select -p` to confirm the selected toolchain. A Command Line Tools installation may differ from the Xcode toolchain used by CI. Use a toolchain that supplies Swift Testing, then run `swift build`, `swift test`, and `swift build -c release`. Include the toolchain details when reporting failures.
