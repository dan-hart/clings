<div align="center">

# ⚡ clings

### Your Things 3 workflow. Your terminal.

Capture in natural language · Query your tasks · Build repeatable workflows

[![CI](https://img.shields.io/github/actions/workflow/status/dan-hart/clings/ci.yml?branch=main&style=for-the-badge&label=build)](https://github.com/dan-hart/clings/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/dan-hart/clings?style=for-the-badge&color=FF4F00)](https://github.com/dan-hart/clings/releases)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-FA7343?style=for-the-badge&logo=swift&logoColor=white)](Package.swift)
[![macOS](https://img.shields.io/badge/macOS-14%2B-111111?style=for-the-badge&logo=apple&logoColor=white)](Package.swift)
[![License](https://img.shields.io/badge/license-GPLv3-blue?style=for-the-badge)](LICENSE)

[Get started](#get-started) · [Command reference](docs/cli/command-reference.md) · [Workflow cookbook](docs/cli/workflows.md) · [Scripting guide](docs/cli/filtering-and-scripting.md)

*“clings” rhymes with “things.”*

</div>

**clings** brings [Things 3](https://culturedcode.com/things/) to the command line. Read your lists from the local SQLite database, capture tasks with natural language, and write through Things’ automation APIs. Compose the output with your own shell tools.

```bash
# Capture an idea before it disappears
clings add "Draft release notes tomorrow #docs // include migration steps"

# Build a working queue
clings focus --limit 5

# Find open work with a deadline
clings filter "tags CONTAINS 'docs' AND due IS NOT NULL" --json \
  | jq -r '.items[] | [.name, (.dueDate // "—")] | @tsv'

# Preview a batch before changing anything
clings bulk move --list inbox --where "tags CONTAINS 'docs'" \
  --to "Documentation" --dry-run
```

## Why clings?

| Capability | What you can do |
| --- | --- |
| 📝 Natural-language capture | Parse dates, tags, project names, notes, and checklists; preview before creating |
| 🔎 Structured queries | Combine `AND`, `OR`, `NOT`, date comparisons, tag matches, and wildcards |
| 🧩 Reusable workflows | Save named filter views and task templates with relative date defaults |
| ⚙️ Shell composition | Use JSON and custom todo-line templates with `jq`, scripts, and reports |
| 🎯 Focus and review | Rank open work, audit projects, and generate weekly review reports |
| 📦 Bulk actions | Preview and confirm completion, cancellation, tagging, and project moves |
| ↩️ Limited undo | Reverse supported recent single-todo operations; inspect the history first |

## Get started

You need **macOS 14 or later** and **Things 3 for Mac**. Building from source requires a Swift 6 toolchain. Writes may require macOS Automation permission for the terminal you use.

### Install with Homebrew

```bash
brew install dan-hart/tap/clings
clings --version
clings --help
```

Upgrade with `brew update && brew upgrade clings`. Homebrew installs the published release; examples on `main` describe the current source and may include changes awaiting release.

### Build current source

```bash
git clone https://github.com/dan-hart/clings.git
cd clings
swift build -c release
.build/release/clings --help

# Optional: install somewhere on your PATH
mkdir -p "$HOME/.local/bin"
install .build/release/clings "$HOME/.local/bin/clings"
```

### Your first five commands

```bash
clings                         # Today is the default
clings inbox                   # See captured tasks
clings add "Draft outline tomorrow #writing" --parse-only
clings search "outline"        # Find existing tasks
clings doctor --verbose        # Inspect local setup
```

Remove `--parse-only` when the parsed result looks right. For installation, permissions, and shell completion setup, see [Getting started](docs/cli/getting-started.md).

## Powerful workflows

### Capture with a start date and a deadline

```bash
clings add "Publish documentation" \
  --when tomorrow \
  --deadline friday \
  --project "Documentation" \
  --tags docs release \
  --notes "Include examples and migration notes" \
  --parse-only --json
```

The **start date** is when you plan to work; the **deadline** is when it is due. Explicit options override parsed values; tags are combined. Preview unfamiliar dates: an unrecognized date can resolve to no date.

### Turn a query into a named view

```bash
clings views save docs-due "tags CONTAINS 'docs' AND due <= today" \
  --note "Documentation due by today"
clings views run docs-due
clings views run docs-due --format "{id} {name} [{project}] {due}"
```

Views evaluate relative dates when run. They search open lists, not Logbook, and live in local clings configuration.

### Reuse a checklist without freezing its dates

```bash
clings template save release-prep "Prepare release" \
  --when tomorrow --tags release docs \
  --checklist "Run tests" "Review changelog" "Verify installation"

clings add "Prepare next release" --template release-prep --parse-only --json
clings template run release-prep
```

Use template `--when`/`--deadline` options to store relative expressions. Dates embedded in the template title are not retained as schedule defaults.

### Export a report you can use elsewhere

```bash
# TSV for a spreadsheet or terminal report (requires jq)
clings today --json | jq -r '
  ["ID", "Task", "Project", "Deadline"],
  (.items[] | [.id, .name, (.project // ""), (.dueDate // "")]) | @tsv'

# Completed work only, excluding canceled Logbook entries
clings logbook --json \
  | jq -r '.items[] | select(.status == "completed") | .name'

# A compact text queue
clings focus --limit 5 --format "{name} [{project}] {tags}"
```

### Triage an inbox with a preview

```bash
clings bulk move --list inbox --where "tags CONTAINS 'docs'" \
  --to "Documentation" --dry-run

# After reviewing the selection, repeat without --dry-run
clings bulk move --list inbox --where "tags CONTAINS 'docs'" \
  --to "Documentation"
```

Bulk filters apply **only to the selected list** (default: Today). Without a filter, the entire list is selected. Every nonempty write prompts unless `--yes` is supplied. Bulk writes are sequential, may partially succeed, and are not covered by undo.

## Find the right command

| Command | Purpose |
| --- | --- |
| `today` | Today's working list; alias `t`; default command |
| `inbox` | Captured tasks; alias `i` |
| `upcoming` | Future scheduled work; alias `u` |
| `anytime` | Available unscheduled work |
| `someday` | Someday/maybe tasks; alias `s` |
| `logbook` | Completed/canceled history; alias `l` |
| `search` | Title/notes search; aliases `find`, `f` |
| `filter` | Structured queries over open lists |
| `show` | Inspect one exact todo ID |
| `add` | Natural-language capture, templates, parsing preview |
| `update` | Edit title, notes, deadline, schedule, heading, tags |
| `complete` | Complete by ID or unambiguous text; alias `done` |
| `cancel` | Mark a todo canceled |
| `delete` | Cancel via automation, not Trash movement; alias `rm` |
| `views` | Local saved queries: `list`, `save`, `run`, `delete` |
| `template` | Task blueprints: `list`, `save`, `run`, `delete` |
| `projects` | List visible projects |
| `project` | `list`, `add`, `audit` |
| `areas` | List areas of responsibility |
| `tags` | `list`, `add`, `delete`, `rename` |
| `bulk` | Preview/execute `complete`, `cancel`, `tag`, `move` |
| `focus` | Ranked working queue |
| `pick` | Interactive `show`, `complete`, `cancel`, `delete` |
| `undo` | Inspect/reverse supported recent single-todo mutations |
| `doctor` | Local setup diagnostics |
| `stats` | Dashboard, `trends`, `heatmap` |
| `review` | Weekly report: `start`, `status`, `clear` |
| `config` | `set-auth-token` for schedule/heading updates |
| `completions` | Generate bash/zsh/fish completion scripts |
| `open` | Currently disabled; returns an error |

```bash
clings --help
clings add --help
clings bulk move --help
clings template save --help
```

Most output commands accept `--json` and `--no-color`. Todo renderers also accept `--format` with `{id}`, `{name}`, `{status}`, `{due}`, `{project}`, `{area}`, and `{tags}`. JSON takes precedence over custom formatting. Put options after the command.

## Know the boundaries

- **Reads:** SQLite access is read-only. clings does not write directly to the Things database.
- **Writes:** Things’ AppleScript/JXA automation APIs perform writes. `update --when` and `update --heading` additionally use Things URLs and need an auth token; `add --when` does not.
- **Delete:** The automation implementation cancels a todo; it does not move it to Trash. It currently runs without confirmation even when `--force` is omitted. Use Things itself for permanent deletion.
- **Undo:** Covers supported single-todo changes, not bulk writes or project/tag management. Schedule and heading changes cannot be restored. Inspect `clings undo --show` first.
- **JSON:** Lists, search, filter, and saved-view results are suitable for pipelines. Interactive picking, bulk previews, and review reports may still emit text despite `--json`.
- **Priority:** Natural-language priority markers are parsed, but are not applied as a native Things priority. Use tags such as `urgent` with `focus`.

Keep independent backups; synchronization is not a substitute for recoverable backups. Details are in the [command reference](docs/cli/command-reference.md) and [troubleshooting guide](docs/cli/troubleshooting.md).

## Documentation

- [Getting started](docs/cli/getting-started.md): installation, permissions, local configuration, completions
- [Command reference](docs/cli/command-reference.md): every command family, defaults, options, and limitations
- [Workflow cookbook](docs/cli/workflows.md): capture, planning, templates, bulk triage, and reporting
- [Filtering and scripting](docs/cli/filtering-and-scripting.md): query syntax, JSON shapes, `jq`, and shell patterns
- [Troubleshooting](docs/cli/troubleshooting.md): diagnosis, dates, permissions, and unexpected results
- [Ten proposed improvements](docs/cli/improvement-roadmap.md): source-based ideas for the next iterations

## Development and contributions

```bash
swift build
swift test
swift build -c release
bash scripts/release-docs-check.sh
bash scripts/asp-preflight.sh --staged --strict
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [AGENTS.md](AGENTS.md), [testing and coverage](docs/development/testing-and-coverage.md), and the [release documentation checklist](docs/release/help-readme-docs-checklist.md). Contributions that preserve Things terminology, scriptability, and safe automation are welcome.

## License and support

GNU General Public License v3.0 — see [LICENSE](LICENSE).

[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-support-ffdd00?style=for-the-badge&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/codedbydan)

clings is an independent open-source project, not affiliated with or endorsed by Cultured Code. Things 3 is a registered trademark of Cultured Code GmbH & Co. KG.
