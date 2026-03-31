# clings Command Reference

This guide mirrors the built-in help text and gives quick examples for the main `clings` command families.

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
clings project add "Writing Sprint" --area "Writing" --deadline 2025-06-01
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
clings open today
```

`open` is intentionally disabled in the current CLI build, so use it only if that behavior changes in a future release.
