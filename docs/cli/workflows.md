# Workflow cookbook

[README](../../README.md) · [Getting started](getting-started.md) · [Scripting](filtering-and-scripting.md)

These recipes describe current source behavior. Commands that create, complete, cancel, update, tag, or move items write to Things. Parsing and bulk previews do not write to Things. Names such as `Documentation` are example projects; substitute existing names, or create the project deliberately first.

## 1. Capture, inspect, create

```bash
clings add "Draft release notes tomorrow #docs // include migration steps" --parse-only --json
clings add "Draft release notes tomorrow #docs // include migration steps"
```

Use quotes so tags and spaces reach the parser. Preview checks interpretation, not whether projects/tags are available or automation is authorized.

For predictable names and dates, use explicit options:

```bash
clings add "Draft release notes" --project "Documentation" \
  --when tomorrow --deadline friday --tags docs release --parse-only
```

## 2. Separate starts from deadlines

```bash
clings add "Publish guide" --when tomorrow --deadline friday --parse-only
clings upcoming
clings filter "due >= today AND due < tomorrow"
```

Upcoming is a scheduled-work list; the filter is a deadline query over open tasks. They answer different questions. `add` can create both dates through AppleScript without a Things URL token. Changing the schedule of an existing task uses `update --when` and does require a token.

## 3. Make a morning queue

```bash
clings today
clings focus --limit 5
clings focus --limit 5 --format "{name} [{project}] {due}"
```

Focus ranks deadlines, urgent/priority/high tags, and unassigned work. It does not schedule tasks, hide other tasks, or mutate Things. The plain report includes reasons; the custom-line output does not.

## 4. Save a context view

```bash
clings views save docs-ready "tags CONTAINS 'docs' AND NOT tags CONTAINS 'waiting'" \
  --note "Documentation ready for action"
clings views run docs-ready --format "{name} [{project}]"
clings views list --json
```

Saving the same name replaces its definition. Deleting the view only deletes local configuration. Relative dates in expressions are evaluated each time the view runs.

## 5. Reuse release preparation

```bash
clings template save release-prep "Prepare release" \
  --when tomorrow --deadline friday --tags release docs \
  --notes "Check installation before announcing" \
  --checklist "Run tests" "Review changelog" "Verify installation"

clings add "Prepare next release" --template release-prep --parse-only --json
clings template run release-prep
```

The template retains date expressions, not a fixed creation-time date. Explicit template options store scheduling; a date found only in the title is not retained as a template scheduling default. `add --template` lets you override the title and other defaults. Tags combine; supplied checklist items replace the template checklist.

## 6. Triage an inbox in batches

```bash
clings inbox --json | jq -r '.items[] | [.id, .name] | @tsv'
clings bulk move --list inbox --where "tags CONTAINS 'docs'" \
  --to "Documentation" --dry-run
```

After inspecting the preview:

```bash
clings bulk move --list inbox --where "tags CONTAINS 'docs'" --to "Documentation"
```

The command prompts before writing. It cannot roll back a partial batch and does not record bulk undo history. Use a small selection first. The filter never expands selection beyond the chosen list.

## 7. Find the right task without copying an ID

```bash
clings pick show release
clings pick complete release
```

Enter a displayed number or exact ID. The completion action only offers open tasks. `pick show` can include historical work. These are interactive workflows; do not expect `--json` to remove the prompt.

For scripts, use a known exact ID:

```bash
clings show EXAMPLE_ID --json
clings complete EXAMPLE_ID
```

`EXAMPLE_ID` is a placeholder; replace it with an ID from your data. Do not select the first search result automatically when several titles match.

## 8. Prepare a weekly review

```bash
clings review start --no-color
clings project audit
clings someday --format "{name} [{project}] {due}"
clings stats --days 7
```

Review generates guidance and stores local session progress; it does not process your inbox or update tasks automatically. Audit highlights open-project issues. `review status` reads saved progress; `review clear` resets only the review session. Review output is text, even when `--json` is passed.

## 9. Export completed work

```bash
clings logbook --json | jq -r '
  ["Task", "Project", "Status"],
  (.items[] | select(.status == "completed") |
    [.name, (.project // ""), .status]) | @csv'
```

Redirect to a new report file if desired; ordinary shell redirection overwrites an existing file. Canceled records are excluded explicitly. This export is a report, not a complete Things backup or a restorable import format.

## 10. Inspect an undo before using it

```bash
clings undo --show
clings undo
```

Undo supports recorded single-todo creation, update, completion, cancellation, and deletion. Undoing creation cancels the todo; undoing completion/cancellation/deletion reopens it. Update undo restores the recorded name, notes, deadline, and tags, not the schedule or heading. It does not cover bulk actions, project/tag management, or changes made directly in Things. A failed reversal consumes the entry, so inspect errors and the Things task itself.
