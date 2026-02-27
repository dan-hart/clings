# clings - a feature-rich cli for Things 3 on macOS

> "clings" rhymes with "things"

> **Disclaimer:** This project is not affiliated with, endorsed by, or sponsored by [Cultured Code](https://culturedcode.com/). Things 3 is a registered trademark of Cultured Code GmbH & Co. KG. clings is an independent, open-source project that provides a command-line interface wrapper for the Things 3 application.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Built with Swift](https://img.shields.io/badge/built%20with-Swift-FA7343.svg)](https://swift.org/)
[![macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)

**clings** brings the power of [Things 3](https://culturedcode.com/things/) to your terminal. Manage tasks, projects, and workflows with natural language, bulk operations, and powerful search - all without leaving the command line.

## Features

### 1. View Commands

Access all your Things 3 lists directly:

```bash
clings today             # or: clings t (default command)
clings inbox             # or: clings i
clings upcoming          # or: clings u
clings anytime
clings someday           # or: clings s
clings logbook           # or: clings l

# Organization
clings projects          # List all projects
clings areas             # List all areas
clings tags list         # List all tags
clings show <ID>         # Show details of a specific todo
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

You can also use explicit flags:

```bash
clings add "Task title" \
  --when tomorrow \
  --deadline "2024-12-31" \
  --tags work urgent \
  --project "Sprint 1" \
  --area "Work" \
  --notes "Additional context"

# Preview without creating
clings add "Test task tomorrow #work" --parse-only
```

### 3. Search and Filter

Search todos by text, or use the powerful filter command for advanced queries:

```bash
# Text search (case-insensitive, searches title and notes)
clings search "meeting"
clings find "project report"     # alias for search
clings f "status"                # short alias

# Advanced filtering (SQL-like query language)
clings filter "status = open"
clings filter "due < today AND status = open"
clings filter "tags CONTAINS 'urgent'"
clings filter "name LIKE '%report%'"
clings filter "project IS NOT NULL"
```

**Filter operators:** `=`, `!=`, `<`, `>`, `<=`, `>=`, `LIKE`, `CONTAINS`, `IS NULL`, `IS NOT NULL`, `IN`
**Logic:** `AND`, `OR`
**Fields:** `status`, `due`, `tags`, `project`, `area`, `name`, `notes`, `created`

### 4. Todo Management

Manage individual todos:

```bash
# Show details
clings show <ID>

# Update properties
clings update <ID> --name "New title"
clings update <ID> --notes "Updated notes"
clings update <ID> --due 2024-12-25
clings update <ID> --tags work urgent

# Complete, cancel, or delete
clings complete <ID>             # or: clings done <ID>
clings complete --title "milk"   # complete by title search
clings cancel <ID>
clings delete <ID>               # or: clings rm <ID>
clings delete <ID> --force       # skip confirmation
```

### 5. Bulk Operations

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
- `--yes` - Skip confirmation prompts (use with caution)
- `--list` - Specify which list to operate on (default: today)

### 6. Statistics Dashboard

Track your productivity:

```bash
clings stats              # Show dashboard
clings stats trends       # Completion trends over time
clings stats heatmap      # Activity heatmap calendar
clings stats --days 7     # Limit to last 7 days
```

### 7. Weekly Review

Guide yourself through a GTD-style weekly review:

```bash
clings review             # Start a new review (default)
clings review start       # Same as above
clings review status      # Show last review session info
clings review clear       # Clear review session
```

### 8. Shell Completions

Generate shell completions:

```bash
clings completions bash > ~/.bash_completion.d/clings
clings completions zsh > ~/.zfunc/_clings
clings completions fish > ~/.config/fish/completions/clings.fish
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

To upgrade to the latest version:

```bash
brew update && brew upgrade clings
```

### From Source

```bash
# Clone the repository
git clone https://github.com/dan-hart/clings
cd clings

# Build release binary
swift build -c release

# Install to /usr/local/bin
cp .build/release/clings /usr/local/bin/
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

# Filter by status and date
clings filter "due < today AND status = open"

# Get productivity stats
clings stats

# Get help on any command
clings --help
clings add --help
```

## Command Reference

### Global Options

```
--json                   Output as JSON (for scripting)
--no-color               Suppress color output
-h, --help               Show help
--version                Show version
```

### Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `today` | `t` | Show today's todos (default) |
| `inbox` | `i` | Show inbox todos |
| `upcoming` | `u` | Show upcoming todos |
| `anytime` | - | Show anytime todos |
| `someday` | `s` | Show someday todos |
| `logbook` | `l` | Show completed todos |
| `projects` | - | List all projects |
| `areas` | - | List all areas |
| `tags` | - | Manage tags |
| `show` | - | Show details of a todo by ID |
| `add` | - | Add a new todo with natural language |
| `update` | - | Update a todo's properties |
| `complete` | `done` | Mark a todo as completed |
| `cancel` | - | Cancel a todo |
| `delete` | `rm` | Delete a todo (moves to trash) |
| `search` | `find`, `f` | Search todos by text |
| `filter` | - | Filter todos using SQL-like expressions |
| `open` | - | Open Things 3 to a view or item |
| `bulk` | - | Bulk operations on multiple todos |
| `stats` | - | View productivity statistics |
| `review` | - | GTD weekly review workflow (start, status, clear) |
| `config` | - | Configure clings settings |
| `completions` | - | Generate shell completions |

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
clings today --json | jq '.items[] | select(.tags | contains(["work"]))'
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
swift build              # Build
swift run clings today   # Run in debug mode
swift test               # Run tests
```

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make changes following code quality standards
4. Add tests for new functionality
5. Ensure all checks pass: `swift build && swift test`
6. Submit a pull request

## License

GNU General Public License v3.0 (GPLv3) - see [LICENSE](LICENSE)

## Links

- **Repository:** https://github.com/dan-hart/clings
- **Things 3:** https://culturedcode.com/things/
