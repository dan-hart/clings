# clings - a feature-rich cli for Things 3 on macOS

> "clings" rhymes with "things"

> **Disclaimer:** This project is not affiliated with, endorsed by, or sponsored by [Cultured Code](https://culturedcode.com/). Things 3 is a registered trademark of Cultured Code GmbH & Co. KG. clings is an independent, open-source project that provides a command-line interface wrapper for the Things 3 application.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Built with Rust](https://img.shields.io/badge/built%20with-Rust-orange.svg)](https://www.rust-lang.org/)
[![macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)

**clings** brings the power of [Things 3](https://culturedcode.com/things/) to your terminal. Manage tasks, projects, and workflows with natural language, bulk operations, and powerful search - all without leaving the command line.

## Features

### 1. List Commands

Access all your Things 3 lists with a single command:

```bash
clings list              # Show today's todos (default)
clings list inbox        # Show inbox
clings list upcoming     # Show upcoming todos
clings list areas        # List all areas
clings list tags         # List all tags
clings list projects     # List all projects

# Shortcuts for common views
clings today             # or: clings t
clings inbox             # or: clings i
clings upcoming          # or: clings u
clings someday           # or: clings s
clings logbook           # or: clings l
```

### 2. Natural Language Task Entry

Add tasks using natural language parsing:

```bash
clings add "buy milk tomorrow #errands"
clings add "call mom friday 3pm for Family !high"
clings add "finish report by dec 15 #work"
clings add "review PR // needs careful testing - check auth - verify tests"

# Supported patterns:
# - Dates: today, tomorrow, next monday, in 3 days, dec 15
# - Times: 3pm, 15:00, morning, evening
# - Tags: #tag1 #tag2
# - Projects: for ProjectName
# - Areas: in AreaName
# - Deadlines: by friday
# - Priority: !high, !!, !!!
# - Notes: // notes at the end
# - Checklist: - item1 - item2
```

### 3. Search with Filters

Search your todos with simple flags or advanced SQL-like expressions:

```bash
# Text search
clings search "meeting"

# Filter by tag, project, or due date
clings search --tag work
clings search --project "Sprint 1"
clings search --due today

# Advanced filter (SQL-like syntax)
clings search --filter "status = 'open' AND due < today"
clings search --filter "tags CONTAINS 'urgent' OR project = 'Important'"
```

**Filter operators:** `=`, `!=`, `<`, `>`, `LIKE`, `CONTAINS`, `IS NULL`, `IS NOT NULL`, `IN`
**Logic:** `AND`, `OR`, `NOT`, parentheses

### 4. Bulk Operations

Perform operations on multiple tasks using powerful filters.

> **Data Safety:** Bulk operations include built-in safety measures. Operations affecting more than 5 items require confirmation. Always use `--dry-run` first to preview changes.

```bash
# ALWAYS preview changes first with --dry-run
clings bulk complete --where "tags CONTAINS 'done'" --dry-run

# Complete matching tasks
clings bulk complete --where "tags CONTAINS 'done'"

# Cancel old project tasks
clings bulk cancel --where "project = 'Old Project'"

# Tag work tasks as urgent
clings bulk tag --where "project = 'Work'" urgent priority

# Move tasks to a project
clings bulk move --where "tags CONTAINS 'work'" --to "Work Project"
```

**Safety options:**
- `--dry-run` - Preview changes without applying them
- `--limit N` - Maximum items to process (default: 50)
- `--yes` - Skip confirmation prompts (use with caution)

### 5. Statistics Dashboard

Track your productivity:

```bash
clings stats              # Show dashboard
clings stats --trends     # Completion trends over time
clings stats --heatmap    # Activity heatmap calendar
```

### 6. Weekly Review

Guide yourself through a GTD-style weekly review:

```bash
clings review              # Start a new review
clings review --resume     # Resume paused review
clings review --status     # Check progress
```

### 7. Terminal UI

Launch the interactive terminal interface:

```bash
clings tui

# Keybindings:
# j/k or arrows  Navigate
# c              Complete todo
# x              Cancel todo
# Enter          Open in Things
# q/Esc          Quit
```

### 8. Shell Integration

Generate shell completions:

```bash
clings shell completions bash > ~/.bash_completion.d/clings
clings shell completions zsh > ~/.zsh/completions/_clings
clings shell completions fish > ~/.config/fish/completions/clings.fish

# Show installation instructions
clings shell completions zsh --install
```

## Requirements

- **macOS 10.15 (Catalina) or later**
- **Things 3 for Mac** - [Mac App Store](https://apps.apple.com/app/things-3/id904280696) or [Cultured Code](https://culturedcode.com/things/)
- **Automation Permission** - On first run, macOS will prompt you to grant automation permission

## Installation

### Homebrew (Recommended)

```bash
brew install dan-hart/tap/clings
```

### From Source

```bash
# Clone the repository
git clone https://github.com/dan-hart/clings
cd clings

# Build release binary
cargo build --release

# Install to /usr/local/bin
cp target/release/clings /usr/local/bin/

# Or install using cargo
cargo install --path .
```

## Quick Start

```bash
# View today's tasks
clings today

# Add a quick task
clings add "buy groceries tomorrow #errands"

# View your inbox
clings inbox

# Search for tasks
clings search "project"

# Get productivity stats
clings stats

# Get help on any command
clings --help
clings add --help
```

## Command Reference

### Global Options

```
-o, --output <FORMAT>    Output format [pretty|json] (default: pretty)
-h, --help               Show help
-V, --version            Show version
```

### Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `list [VIEW]` | - | List todos from a view (today, inbox, upcoming, etc.) |
| `today` | `t` | Show today's todos |
| `inbox` | `i` | Show inbox todos |
| `upcoming` | `u` | Show upcoming todos |
| `anytime` | - | Show anytime todos |
| `someday` | `s` | Show someday todos |
| `logbook` | `l` | Show completed todos |
| `add` | `a` | Quick add with natural language |
| `todo` | - | Manage todos (show, complete, cancel, delete) |
| `project` | - | Manage projects (list, show, add) |
| `search` | - | Search todos by text or filters |
| `open` | - | Open Things 3 to a view or item |
| `bulk` | `b` | Bulk operations on multiple todos |
| `stats` | - | View productivity statistics |
| `review` | `r` | Interactive weekly review workflow |
| `shell` | - | Shell integration (completions) |
| `tui` | - | Launch the terminal UI |

## Output Formats

### Pretty (default)

Human-readable colored output:

```
Today (3 items)
──────────────────────────────────────────────
[ ] Review PR #123        Development   Dec 15   #work
[ ] Buy groceries         -             -        #personal
[x] Call dentist          Health        Dec 10   -
```

### JSON

Machine-readable JSON for scripting:

```bash
clings today -o json | jq '.items[] | select(.tags | contains(["work"]))'
```

## Data Safety

- **Read operations:** Use direct SQLite access to the Things 3 database (read-only)
- **Write operations:** Use Apple's JavaScript for Automation (JXA) through the official Things 3 API
- **No direct database writes:** clings never writes directly to the Things 3 database

### Best Practices

1. **Always use `--dry-run` first** when running bulk operations
2. **Start with small filters** to verify your filter expression matches what you expect
3. **Keep Things 3 backups** - Things 3 syncs to iCloud automatically

## Troubleshooting

### Automation permission error

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
```

Then enable Things 3 under your terminal application.

### Things 3 not running

Things 3 must be running for clings to communicate with it via AppleScript/JXA.

## Development

```bash
cargo build           # Build
cargo run -- today    # Run in debug mode
cargo test            # Run tests
cargo clippy          # Run linter
cargo fmt             # Format code
```

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make changes following code quality standards
4. Add tests for new functionality
5. Ensure all checks pass: `cargo fmt && cargo clippy && cargo test`
6. Submit a pull request

## License

GNU General Public License v3.0 (GPLv3) - see [LICENSE](LICENSE)

## Links

- **Repository:** https://github.com/dan-hart/clings
- **Things 3:** https://culturedcode.com/things/
