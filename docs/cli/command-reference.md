# clings Command Reference

Complete command guide for current source. Published binaries may lag `main`;
their built-in help is the authoritative list of accepted options.

[Getting started](getting-started.md) · [Workflows](workflows.md) · [Filtering and scripting](filtering-and-scripting.md) · [Troubleshooting](troubleshooting.md)

For the latest option-level details, run:

```bash
clings --help
clings <command> --help
clings <command> <subcommand> --help
```

## Root Usage

```bash
clings <subcommand> [options]
```

Quick examples:

```bash
clings today
clings add "Draft changelog entry tomorrow #docs"
clings views run docs-today
clings doctor --verbose
```

## Help Usage

Built-in help is organized around the same command families documented here:

```bash
clings --help
clings <command> --help
clings <command> <subcommand> --help
```

## Core Lists

| Command | Purpose | Example |
| --- | --- | --- |
| `clings today` | Show tasks scheduled for today | `clings today --format "{status} {name}"` |
| `clings inbox` | Show inbox items | `clings inbox --json` |
| `clings upcoming` | Show future scheduled work | `clings upcoming` |
| `clings anytime` | Show unscheduled anytime work | `clings anytime --json` |
| `clings someday` | Show someday/maybe items | `clings someday` |
| `clings logbook` | Show completed tasks | `clings logbook --json` |
| `clings projects` | List projects | `clings projects --json` |
| `clings areas` | List areas | `clings areas` |
| `clings tags list` | List tags | `clings tags ls --json` |
| `clings show <id>` | Show one todo in detail | `clings show abc123 --json` |

Aliases: `today` → `t`, `inbox` → `i`, `upcoming` → `u`, `someday` → `s`,
`logbook` → `l`. Running `clings` without arguments selects Today. Logbook can
include canceled tasks as well as completed work. Project lists exclude trashed
projects and repeating project templates in the SQLite read path.

All of these commands read Things data without modifying it. `--format` applies
to todo renderers, not project/area/tag tables. List JSON uses `{count, items}`
with an optional `list` label. `show --json` returns one object.

## Capture, Search, and Reuse

Use `add` when you want fast capture, `search` when you want free-text lookup, and `filter` when you want structured querying.

```bash
clings add "Draft changelog entry tomorrow #docs"
clings add "Weekly review prep" --template weekly-review
clings add "Test task tomorrow #docs" --parse-only --json

clings search "release"
clings filter "tags CONTAINS 'docs' AND due <= today"
clings today --format "{status} {name} [{project}]"
```

Saved views help you keep favorite filters close at hand:

```bash
clings views save docs "tags CONTAINS 'docs'" --note "Documentation queue"
clings views list
clings views run docs
clings views delete docs
```

Templates help you reuse repeated task shapes:

```bash
clings template save weekly-review "Weekly review" --when "tomorrow morning"
clings template list
clings template run weekly-review
clings template delete weekly-review
```

## Mutations and Interactive Picking

Use direct mutation commands when you already know the ID or title target:

```bash
clings complete abc123
clings complete --title "Review release checklist"
clings cancel abc123
clings delete abc123 --force
clings update abc123 --name "Updated title" --tags docs urgent
clings undo
clings undo --show
```

Use `pick` when you want an interactive chooser instead of copying IDs:

```bash
clings pick show release
clings pick complete docs
clings pick cancel follow-up
clings pick delete cleanup
```

## Project and Tag Management

```bash
clings project list
clings project add "Writing Sprint" --area "Writing" --deadline 2027-06-01
clings project audit
clings project audit --json

clings tags add "docs"
clings tags rename "docs" "guides"
clings tags delete "guides" --force
```

## Bulk Workflows

Preview first with `--dry-run`, then repeat the same command without it when the selection looks right.

```bash
clings bulk complete --where "tags CONTAINS 'done'" --dry-run
clings bulk complete --where "tags CONTAINS 'done'"
clings bulk cancel --where "project = 'Archive Prep'"
clings bulk tag "urgent,priority" --where "tags CONTAINS 'docs'"
clings bulk move --where "tags CONTAINS 'docs'" --to "Documentation"
```

## Review, Focus, and Reporting

```bash
clings focus
clings focus --limit 5
clings focus --format "{status} {name} [{project}]"

clings review
clings review status
clings review clear

clings stats
clings stats --days 7
clings stats trends
clings stats heatmap
```

## Environment and Utilities

```bash
clings doctor
clings doctor --verbose
clings config set-auth-token <token>
clings completions zsh > ~/.zfunc/_clings
clings open --help
```

`open` is intentionally disabled and returns an error. Use `show` in the
terminal or navigate Things manually.

## Options and exact behavior

### Shared output options

| Option | Behavior |
| --- | --- |
| `--json` | Schema 1 JSON envelope; takes precedence over `--format` |
| `--no-color` | Suppress ANSI colors in output paths that use them |
| `--format TEMPLATE` | Custom todo line: `{id}`, `{name}`, `{status}`, `{due}`, `{project}`, `{area}`, `{tags}` |

Put options after the command, such as `clings inbox --json`. Although many
commands accept the shared option group, not all renderers honor every option.
JSON payloads live under `.data`; errors include `.error` and nonzero exits.
Review and bulk support structured reports; `pick --json` is rejected before
reads/writes. Help/version/completions remain text. There are no root-level
global output options shared across all commands.

### add TITLE

| Option | Meaning |
| --- | --- |
| `--template NAME` | Load local task defaults before parsing TITLE |
| `--notes TEXT` | Override parsed/template notes |
| `--when DATE` | Planned start, resolved by the natural-language date parser |
| `--deadline DATE` | Due date, independently resolved |
| `--tags TAG...` | Separate values; append to parsed/template tags and deduplicate |
| `--project NAME`, `--area NAME` | Set assignments by name |
| `--parse-only` | Preview parsed fields without creating a todo |

TITLE is one shell argument. Dates, `#tags`, `for Project`, `in Area`, `// notes`,
and `- checklist item` patterns may be extracted. Preview whenever literal title
text overlaps parser syntax. Explicit scalar options override parsed values;
tags combine. Priority markers are parsed but are not sent as a Things priority.
Unrecognized or impossible dates are rejected before writes, including invalid
times embedded in task text. Use `--parse-only` to inspect the complete mutation.
`add --when/--deadline` does not require a URL auth token. Creation records undo.

### update ID

Accepts `--name TEXT`, `--notes TEXT`, `--due DATE`, `--when DATE`,
`--heading NAME`, `--tags TAG...`, and `--parse-only`. At least one property is required.
Tags replace the existing set; `--tags docs urgent` is two tags, while
`--tags docs,urgent` is one tag value.

`--when` recognizes `today`, `tomorrow`, `evening`, `anytime`, `someday`, or a
parseable date. `--when`/`--heading` require a Things URL token, validated before
mutations begin. Name/notes/deadline/tags updates use automation. Update records
a snapshot for undo, but scheduling/headings are not restored by undo.
`--parse-only` shows the complete proposed fields and undo limitations without
requiring a URL token or performing writes.

### complete [ID], cancel ID, delete ID

- `complete` (alias `done`) accepts `--title`/`-t` instead of an ID. It searches
  text and completes only when one open todo matches. Multiple matches print
  candidates without a write and exit 1; `--title` takes precedence over a supplied ID.
- `cancel` marks the todo canceled immediately, without confirmation.
- `delete` (alias `rm`) also cancels through the current automation API. It
  does not move to Trash. Confirmation is required unless `--force`/`-f` is
  supplied. Noninteractive invocation without authorization fails.

All three record supported undo entries. Use exact IDs from a list or `show`,
not an assumed unique title. These commands accept shared output options, but
`--format` does not apply to success messages.

### search QUERY and filter EXPRESSION

`search` aliases are `find` and `f`. It searches title/notes case-insensitively
and can return completed/canceled todos. SQLite search excludes repeating
templates and descendants of trashed projects.

`filter` defaults to open lists, deduplicates todos, then evaluates its DSL.
Search, filter, and `views run` share `--list`, `--include-logbook`, `--sort`,
and positive `--limit`. Sort keys are `id`, `name`, `due`, `when`, `created`,
and `modified`; a leading minus reverses order. Absent dates stay last and ties
use stable IDs. `when`/`start` is the scheduled start, distinct from `due`.
Unknown filter fields and trailing syntax are rejected.
Supported fields/operators and date boundaries are documented in
[Filtering and scripting](filtering-and-scripting.md). No arbitrary SQL runs.

### views

| Subcommand | Arguments/options | Effect |
| --- | --- | --- |
| `list` (`ls`, default) | Shared output options | List definitions; JSON payload `.data` is an array |
| `save` | `NAME EXPRESSION [--note TEXT]` | Save/replace local definition; does not validate the full DSL until run |
| `run` | `NAME` plus output options | Query open tasks; relative dates resolve now |
| `delete` (`rm`) | `NAME` | Delete only the local definition |

Views are stored in `saved-views.json` under the clings config directory.
They do not create smart lists inside Things.

### template

| Subcommand | Arguments/options | Effect |
| --- | --- | --- |
| `list` (`ls`, default) | Shared output options | List definitions; JSON payload `.data` is an array |
| `save` | `NAME TITLE` plus defaults below | Save/replace a local task blueprint |
| `run` | `NAME` plus output options | Create a Things todo and record creation undo |
| `delete` (`rm`) | `NAME` | Remove definition; existing todos remain |

Save defaults: `--notes`, `--when`, `--deadline`, `--project`, `--area`,
`--tags TAG...`, `--checklist ITEM...`. Quote each multiword checklist item.
Relative dates embedded in TITLE are retained as defaults; explicit date options
override them. Their relative expressions resolve when run. With template save,
explicit tags replace parsed tags; with add --template, tags combine.

### bulk

Actions: `complete`, `cancel`, `tag TAGS`, and `move --to PROJECT`.
Shared options: `--list LIST` (default `today`), `--where EXPRESSION`,
`--dry-run`, `--execute-plan PATH`, `--yes`/`-y`, and output options. List values are `today`, `inbox`,
`upcoming`, `anytime`, `someday`, and `logbook` (not their CLI aliases).

`--where` narrows the selected list; omitting it selects the whole list. Every
nonempty write prompts unless `--yes` is supplied. `--dry-run` previews and exits
before the prompt or writes. `tag` takes one comma-separated argument and merges
existing tags. A JSON dry-run produces a reusable exact-ID plan. Execution checks
snapshots and persists per-item results; retries skip successes and reconcile
interrupted writes. There is no atomic rollback. Status/tag batches support
grouped undo; project moves do not. Partial failures return exit 2. Keep plan
files private, and never redirect stdout onto an executing plan file.

### project, projects, areas, tags

`projects` and `project list` (`ls`, default) provide the same list behavior.
`project add TITLE` accepts `--notes`, `--area`, `--when`, `--deadline`,
`--tags "docs,release"`, and output options. Dates accept `today`, `tomorrow`,
or `YYYY-MM-DD`. `project audit` reports open-project health without writes.
`areas` lists areas but does not create or rename them.

`tags list` (`ls`, default) lists definitions. `tags add NAME`
creates one; `tags rename OLD NEW` (`mv`) renames it; `tags delete NAME` (`rm`) removes
it from tagged todos and prompts unless `--force`/`-f` is passed. Tag deletion
does not delete todos. Project/tag management is not covered by undo.

### focus, pick, undo

- `focus --limit N` defaults to 10. It ranks open tasks using deadlines, urgency
  tags, and unassigned work. Use a positive limit. JSON returns ranking items
  with `todo`, `score`, and `reasons`; custom formatting shows todo lines.
- `pick show|complete|cancel|delete [QUERY]` prompts for a displayed number or
  exact ID. Show includes historical work; writes restrict candidates to open
  tasks. An empty or invalid choice stops the command. `pick delete` cancels,
  matching direct delete and requiring confirmation. `--json` is rejected before
  selection or writes; use exact-ID commands for scripting.
- `undo --show` inspects the latest entry; `undo` attempts its reversal. History
  holds up to 20 entries. Supported operations: creation, update, completion,
  cancellation, deletion, and grouped status/tag changes. Creation undo cancels; status undo restores the original status; update
  undo restores name/notes/deadline/tags. It does not restore schedule/headings,
  or project moves, nor cover project/tag management. Entries remain until
  reversal succeeds; partially reversed groups retain unfinished members.

### stats and review

`stats --days N` defaults to 30. `stats trends --weeks N` defaults to 4;
`stats heatmap --weeks N` defaults to 12. All read the local database and accept
JSON report output. `--days` belongs to the dashboard, not its subcommands.

`review start` (default) generates a weekly report and saves local session
progress; it does not mutate Things todos. `review status` reads progress and
`review clear` clears that session only. Review reports/status support `--json`.
Progress is stored as `review-session.json` in the config
directory, with a legacy fallback path under `~/.clings`.

### doctor, config, completions, open

`doctor [--verbose] [--json]` checks config readiness without creating it, actual
database readability, `osascript`, optional token presence, and capabilities.
Required failures return exit 2; optional token warnings do not. Opt into a
read-only Things version query with `--probe-automation`. JSON is redacted even
with `--verbose`; `--support-bundle NEW_FILE` creates a private redacted report
without overwriting existing files.

`config set-auth-token TOKEN` stores the secret with mode 0600 for update
scheduling/headings. See [Getting started](getting-started.md) for token handling
and `CLINGS_CONFIG_DIR`. `completions bash|zsh|fish` prints a parser-generated script
with local saved view/template name completion;
installation and shell initialization are separate steps. `open TARGET` is
currently disabled and always raises an error.
