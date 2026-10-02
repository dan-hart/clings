# Filtering and scripting

[README](../../README.md) · [Command reference](command-reference.md) · [Workflow cookbook](workflows.md)

## Choose your search scope

| Command | Input scope |
| --- | --- |
| `search TEXT` | Visible todos matching title/notes, potentially including completed/canceled work |
| `filter EXPR` | Open tasks across Today, Inbox, Upcoming, Anytime, and Someday; duplicates removed |
| `views run NAME` | Same open-list scope as `filter` |
| `bulk ACTION --list LIST --where EXPR` | Only the selected Things list; defaults to Today |
| `logbook --json` | Existing completed-history view; query `--list logbook`/`--include-logbook` also includes canceled records |

A query such as `status = completed` needs `--include-logbook` or `--list logbook`.
Search, filter, and view execution share `--list`, `--include-logbook`, `--sort`,
and positive `--limit` controls. Sort by `id`, `name`, `due`, `when`, `created`,
or `modified`; prefix with `-` for descending (for example `--sort=-modified`).
Absent dates stay last in either direction; equal values use a stable ID tie-break.
Filters are evaluated against loaded tasks; this is not a SQL execution interface.

## Quote expressions

Wrap the whole expression in double quotes, with single quotes around string values. This protects spaces, operators, and wildcards from your shell:

```bash
clings filter "project = 'Documentation' AND tags CONTAINS 'docs'"
clings filter "name LIKE '%release%'"
clings filter "due IS NOT NULL"
```

Expressions support `AND`, `OR`, `NOT`, and parentheses. `AND` and `OR` are evaluated left to right at the same precedence; this differs from SQL. Use parentheses to make mixed conditions explicit.

```bash
clings filter "(tags CONTAINS 'docs' OR tags CONTAINS 'release') AND due IS NOT NULL"
clings filter "NOT tags CONTAINS 'waiting'"
clings filter "project IN ('Documentation', 'Reference')"
```

## Fields

| Field | Meaning |
| --- | --- |
| `id` | Exact todo identifier |
| `name`, `title` | Task title |
| `notes` | Notes text |
| `status` | `open`, `completed`, or `canceled` |
| `due`, `dueDate` | Optional deadline, not the scheduled start |
| `when`, `start`, `scheduledDate` | Optional scheduled start, distinct from the deadline |
| `tags` | Tag names |
| `project`, `area` | Optional names, not IDs |
| `created`, `creationDate` | Creation timestamp |
| `modified`, `modificationDate` | Modification timestamp |

Unknown fields and trailing expressions are rejected. Use `when IS NOT NULL`
to query scheduled tasks, without confusing their start dates with deadlines.

## Operators and dates

| Operator | Example |
| --- | --- |
| `=`, `!=` | `status = open` |
| `<`, `<=`, `>`, `>=` | `due < today` |
| `LIKE` | `name LIKE '%release%'` (`%` matches many characters; `_` matches one) |
| `CONTAINS` | `tags CONTAINS 'docs'` |
| `IS NULL`, `IS NOT NULL` | `project IS NULL` |
| `IN` | `project IN ('Documentation', 'Reference')` |

Unquoted date values include `today`, `tomorrow`, `yesterday`, weekday names, `in 3 days`, and `YYYY-MM-DD`. Quoted values are parsed as strings, so use `due < today`, not `due < 'today'`.

Date comparisons use timestamps. `today` represents local midnight; `due <= today` does not mean the entire day for deadlines with a time component. To include all deadlines before tomorrow, use `due < tomorrow`. Date parsing for filters is separate from the `add` natural-language parser.

```bash
clings filter "due < today"                      # Before today's midnight
clings filter "due < tomorrow"                   # Before tomorrow's midnight
clings filter "due >= today AND due < tomorrow"  # Today only
clings filter "due IS NULL AND project IS NULL"  # No deadline or project
```

## JSON shapes

Every JSON response uses schema 1: `{schemaVersion, success, data}`. Failures add
`error: {code, message}` and retain useful partial results in `data`. The payload
inside `.data` varies by command. See [the migration guide](machine-interface.md).

| Command | Shape | Access pattern |
| --- | --- | --- |
| Lists, search, filter, views run | `{count, items, list?}` | `.data.items[]` |
| Projects, areas, tags list | `{count, items}` | `.data.items[]` |
| Show | One todo object | `.data.id`, `.data.name` |
| Views list, template list | Arrays | `.data[]` |
| Add --parse-only | Final task preview | `.data.title`, `.data.when`, `.data.deadline` |
| Focus | `{items: [{todo, score, reasons}]}` | `.data.items[].todo` |
| Doctor | `{overallStatus, checks}` | `.data.checks[]` |
| Undo --show | Latest entry object, or a message object when empty | Inspect before assuming fields |
| Stats, trends, heatmap, project audit | Command-specific report objects | Inspect their fields first |

List/show todo objects contain `id`, `name`, `notes`, `status`, `dueDate`, `scheduledDate`, `tags`, `project`, `area`, `checklistItems`, `creationDate`, and `modificationDate`. `tags` is an array of names; `project`/`area` are names or `null`; dates are ISO 8601 strings or `null`. Missing notes become an empty string. Focus embeds model objects and does not use this flattened todo representation. Batch snapshots/journals preserve exact timestamp precision for safe comparisons rather than using the display date representation.

Illustrative list envelope (not captured task data):

```json
{
  "schemaVersion": 1,
  "success": true,
  "data": {
    "count": 1,
    "list": "Today",
    "items": [{"id": "EXAMPLE_ID", "name": "Draft release notes", "tags": ["docs"], "project": "Documentation", "dueDate": null, "scheduledDate": null}]
  }
}
```

## Useful jq pipelines

```bash
# IDs and names, without assuming a bare array
clings today --json | jq -r '.data.items[] | [.id, .name] | @tsv'

# Exact tag membership
clings today --json | jq '.data.items[] | select(.tags | index("docs"))'

# Completed work, omitting canceled tasks
clings logbook --json | jq -r '.data.items[] | select(.status == "completed") | .name'

# Definitions are arrays inside the envelope
clings views list --json | jq -r '.data[] | [.name, .expression] | @tsv'

# Ranking explanations use a different embedded todo shape
clings focus --json | jq -r '.data.items[] | [.todo.name, (.score | tostring), (.reasons | join(", "))] | @tsv'

# Check diagnostics by payload, not just exit status
clings doctor --json | jq -e '.success and .data.overallStatus == "ok"'
```

## Custom text output

```bash
clings today --format "{id} | {name} | {due} | {project} | {tags}"
clings show EXAMPLE_ID --format "{name} [{area}]"
```

Supported placeholders are `{id}`, `{name}`, `{status}`, `{due}`, `{project}`, `{area}`, and `{tags}`. Empty optional values render as empty strings; tags render with `#`; `{due}` uses `YYYY-MM-DD`. Unknown placeholders remain literal. Empty task lists still use the standard empty-list message. This is a display template, not CSV escaping; use `jq @csv`/`@tsv` for structured exports. `--json` takes precedence over `--format`.

## Script discipline

For Bash pipelines, enable `set -o pipefail` so an upstream CLI error is not hidden by a successful `jq`. Check exact IDs before writing. Keep `--dry-run` previews separate from bulk writes and inspect per-item results. Exit 1 means invalid/ambiguous/refused input; exit 2 means runtime, partial failure, or unhealthy required capability.

`pick --json` is rejected without writes. Review reports and bulk plans support JSON. Ambiguous `complete --title --json` returns a structured failure and exit 1 without writing. Prefer exact validated IDs rather than automatically selecting the first search result.
