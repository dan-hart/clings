# clings - A fast, feature-rich command-line interface for Things 3 on macOS

> **Disclaimer:** This project is not affiliated with, endorsed by, or sponsored by [Cultured Code](https://culturedcode.com/). Things 3 is a registered trademark of Cultured Code GmbH & Co. KG. clings is an independent, open-source project that provides a command-line interface wrapper for the Things 3 application.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Built with Rust](https://img.shields.io/badge/built%20with-Rust-orange.svg)](https://www.rust-lang.org/)
[![macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)
[![Rust Version](https://img.shields.io/badge/rust-2021%20edition-blue.svg)](https://www.rust-lang.org/)
[![GitHub stars](https://img.shields.io/github/stars/dan-hart/clings.svg?style=social)](https://github.com/dan-hart/clings/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/dan-hart/clings.svg)](https://github.com/dan-hart/clings/issues)
[![GitHub last commit](https://img.shields.io/github/last-commit/dan-hart/clings.svg)](https://github.com/dan-hart/clings/commits/main)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/dan-hart/clings/graphs/commit-activity)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/dan-hart/clings/pulls)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow.svg)](https://buymeacoffee.com/codedbydan)

**clings** brings the power of [Things 3](https://culturedcode.com/things/) to your terminal. Manage tasks, projects, and workflows with natural language, bulk operations, focus tracking, and powerful automation - all without leaving the command line.

## Features

### 1. Core List Commands

Access all your Things 3 lists instantly:

```bash
clings inbox              # View inbox
clings today              # Today's tasks
clings upcoming           # Upcoming tasks
clings anytime            # Anytime tasks
clings someday            # Someday tasks
clings logbook            # Completed tasks

# Aliases for speed
clings i                  # inbox
clings t                  # today
clings u                  # upcoming
```

### 2. Natural Language Task Entry

Add tasks using natural language parsing - just type what you mean:

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

### 3. Interactive Fuzzy Finder

Use the interactive picker to search and select tasks with a beautiful fuzzy interface:

```bash
clings pick                         # Pick from all todos
clings pick today                   # Pick from today's todos
clings pick --action complete       # Complete selected todo
clings pick --multi                 # Select multiple todos
clings pick --query "urgent"        # Pre-filter with search
clings pick --preview               # Show task preview pane
```

### 4. Bulk Operations with Filters

Perform operations on multiple tasks using powerful SQL-like filters.

> **Data Safety:** Bulk operations include built-in safety measures to prevent accidental data loss. Operations affecting more than 5 items require confirmation, and a default limit of 50 items applies. Always use `--dry-run` first to preview changes.

```bash
# ALWAYS preview changes first with --dry-run
clings bulk complete --where "tags CONTAINS 'done'" --dry-run

# Complete tasks (will prompt for confirmation if >5 items match)
clings bulk complete --where "tags CONTAINS 'done'"

# Cancel old project tasks
clings bulk cancel --where "project = 'Old Project'"

# Tag work tasks as urgent
clings bulk tag --where "project = 'Work'" urgent priority

# Move tasks to a project
clings bulk move --where "tags CONTAINS 'work'" --to "Work Project"

# Set due dates
clings bulk set-due --where "project = 'Sprint'" --date tomorrow

# Clear overdue dates
clings bulk clear-due --where "due < today AND status = open"
```

**Safety Options:**

| Flag | Description |
|------|-------------|
| `--dry-run` | Preview changes without applying them (RECOMMENDED first step) |
| `--limit N` | Maximum items to process (default: 50) |
| `--bypass-bulk-data-check` | Skip confirmation prompts (use with caution) |

**Filter expressions** support:
- **Operators:** `=`, `!=`, `<`, `>`, `<=`, `>=`, `LIKE`, `CONTAINS`, `IS NULL`, `IS NOT NULL`, `IN`
- **Logic:** `AND`, `OR`, `NOT`, parentheses
- **Fields:** `status`, `due`, `tags`, `project`, `area`, `name`, `notes`, `created`

### 5. Project Templates

Create reusable project structures and apply them instantly:

```bash
# Create a template from an existing project
clings template create "Sprint" --from-project "Sprint 42"

# Apply a template to create a new project
clings template apply "Sprint" --name "Sprint 43" --area "Work"

# Apply with variable substitution
clings template apply "Sprint" --name "Sprint 43" --var "num=43,team=Backend"

# List all templates
clings template list

# Show template details
clings template show "Sprint"

# Preview before creating
clings template apply "Sprint" --name "Sprint 43" --dry-run

# Edit a template
clings template edit "Sprint"

# Delete a template
clings template delete "Sprint"
```

### 6. Shell & Editor Integration

Integrate clings into your workflow with shell completions, prompts, and editor plugins:

```bash
# Generate shell completions
clings shell completions bash > ~/.bash_completion.d/clings
clings shell completions zsh > ~/.zsh/completions/_clings
clings shell completions fish > ~/.config/fish/completions/clings.fish

# Show installation instructions
clings shell completions zsh --install

# Add task counts to your shell prompt
clings shell prompt --format emoji
clings shell prompt --format powerline
clings shell prompt --format labeled
clings shell prompt --custom "Inbox: {inbox} | Today: {today}"

# Example in .zshrc:
# PS1='$(clings shell prompt -f emoji) $ '

# Generate editor plugins
clings shell editor vim > ~/.vim/plugin/clings.vim
clings shell editor emacs > ~/.emacs.d/clings.el
clings shell editor vscode > ~/.config/Code/User/snippets/clings.json
```

### 7. Statistics Dashboard

Track your productivity with detailed insights and visualizations:

```bash
# Show comprehensive dashboard
clings stats

# Quick summary
clings stats summary

# Get actionable insights
clings stats insights

# Completion trends
clings stats trends --days 30

# Project breakdown
clings stats projects

# Tag statistics
clings stats tags

# Time pattern analysis (when you're most productive)
clings stats patterns

# Productivity heatmap
clings stats heatmap --weeks 8
```

### 8. Focus Mode

Track work sessions with Pomodoro timers and maintain productivity streaks:

```bash
# Start a 25-minute Pomodoro
clings focus start

# Focus on a specific task
clings focus start --task ABC123

# Custom duration
clings focus start --duration 50m

# Check current session
clings focus status

# Watch mode (continuously update)
clings focus status --watch

# Stop session
clings focus stop

# Pause and resume
clings focus pause
clings focus resume

# Take a break
clings focus break              # 5-minute short break
clings focus break long         # 15-minute long break

# View session history
clings focus history

# Weekly report
clings focus report --period week
```

### 9. Sync Queue

Queue operations when Things 3 is unavailable, then sync later:

```bash
# Check queue status
clings sync status

# Execute pending operations
clings sync run

# Preview what would run
clings sync run --dry-run

# List queued operations
clings sync list
clings sync list --status pending

# Add operation to queue
clings sync add --operation complete --id ABC123

# Retry failed operations
clings sync retry --all
clings sync retry 42

# Clear completed operations
clings sync clear
clings sync clear --all --force
```

### 10. Scriptable Automation

Create powerful automation rules with triggers, conditions, and actions:

```bash
# List all rules
clings automation list

# Run all matching rules
clings automation run

# Run a specific rule
clings automation run --rule "auto-tag-work"

# Preview what would run
clings automation run --dry-run

# Create a new rule
clings automation create "auto-tag" --trigger scheduled

# Show rule details
clings automation show "auto-tag-work"

# Edit a rule in your editor
clings automation edit "auto-tag-work"

# Enable/disable rules
clings automation toggle "auto-tag-work" --enable
clings automation toggle "auto-tag-work" --disable

# Import/export rules
clings automation import rules.yaml
clings automation export rules.yaml --rules "rule1,rule2"

# Delete a rule
clings automation delete "auto-tag-work"
```

## Requirements

- **macOS 10.15 (Catalina) or later**
- **Things 3 for Mac** - [Mac App Store](https://apps.apple.com/app/things-3/id904280696) or [Cultured Code](https://culturedcode.com/things/)
- **Automation Permission** - On first run, macOS will prompt you to grant automation permission to your terminal app to control Things 3

When you first run clings, macOS will display a permission dialog. Click "OK" to grant access. If you miss the dialog or deny permission, you can enable it manually:

1. Open **System Settings** > **Privacy & Security** > **Automation**
2. Find your terminal application (Terminal, iTerm2, etc.)
3. Enable the checkbox for **Things 3**
4. Run clings again

Alternatively, run this command to open the settings directly:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
```

## Installation

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

### Development Install

```bash
# Install for development
cargo install --path .

# Build and run directly
cargo run -- today
cargo run -- --help
```

### Shell Completions

Install shell completions for better command-line experience:

#### Zsh

```bash
# Generate and install completion file
clings shell completions zsh > ~/.zsh/completions/_clings

# Or using the system completion directory
sudo clings shell completions zsh > /usr/local/share/zsh/site-functions/_clings

# Reload your shell
exec zsh
```

#### Bash

```bash
# Generate and install completion file
clings shell completions bash > ~/.bash_completion.d/clings

# Add to .bashrc if needed:
# source ~/.bash_completion.d/clings

# Reload your shell
source ~/.bashrc
```

#### Fish

```bash
# Generate and install completion file
clings shell completions fish > ~/.config/fish/completions/clings.fish

# Reload your shell
exec fish
```

## Quick Start

```bash
# View today's tasks
clings today

# Add a quick task
clings add "buy groceries tomorrow #errands"

# Use the interactive picker
clings pick today --action complete

# View your inbox
clings inbox

# Search for tasks
clings search "project"

# Get productivity stats
clings stats summary

# Start a focus session
clings focus start

# Get help on any command
clings --help
clings add --help
clings bulk --help
```

## Command Reference

### Global Options

```bash
-o, --output <FORMAT>    Output format [pretty|json] (default: pretty)
-h, --help               Show help
-V, --version            Show version
```

### Core List Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `inbox` | `i` | List inbox todos |
| `today` | `t` | List todos due today |
| `upcoming` | `u` | List upcoming todos |
| `anytime` | - | List anytime todos |
| `someday` | `s` | List someday todos |
| `logbook` | `l` | List completed todos |

### Task Management

```bash
# Quick add with natural language
clings add "task description" [--parse-only] [--project NAME] [--area NAME]

# Full todo management
clings todo list                              # List all todos
clings todo show <ID>                         # Show todo details
clings todo add "title" [options]             # Add new todo
clings todo complete <ID>                     # Mark complete
clings todo cancel <ID>                       # Mark canceled
clings todo delete <ID>                       # Delete todo
```

### Project Management

```bash
clings project list                           # List all projects
clings project show <ID>                      # Show project details
clings project add "title" [options]          # Add new project
```

### Organization

```bash
clings areas                                  # List all areas
clings tags                                   # List all tags
clings search <query>                         # Search todos
clings filter <expression>                    # Filter with SQL-like syntax
```

### Advanced Features

```bash
# Bulk operations
clings bulk complete --where <filter> [--dry-run]
clings bulk cancel --where <filter> [--dry-run]
clings bulk tag --where <filter> <tags...> [--dry-run]
clings bulk move --where <filter> --to <project> [--dry-run]
clings bulk set-due --where <filter> --date <date> [--dry-run]
clings bulk clear-due --where <filter> [--dry-run]

# Interactive picker
clings pick [list] [--action ACTION] [--multi] [--query QUERY] [--preview]

# Weekly review
clings review [--resume] [--status] [--clear]

# Templates
clings template create <name> --from-project <project> [--description DESC]
clings template apply <template> --name <name> [options] [--dry-run]
clings template list
clings template show <name>
clings template edit <name>
clings template delete <name>

# Shell integration
clings shell completions <shell> [--install]
clings shell prompt [--format FORMAT] [--segment SEGMENT] [--custom FORMAT]
clings shell editor <editor>

# Pipe operations
clings pipe add [--project NAME] [--tags TAGS] [--dry-run]
clings pipe complete [--dry-run]
clings pipe list <list> [--with-id] [--delimiter DELIM]

# Git integration
clings git install-hooks [--hook NAME] [--force] [--repo PATH]
clings git uninstall-hooks [--hook NAME] [--repo PATH]
clings git process-message <message> [--project NAME] [--execute]

# Statistics
clings stats [summary|dashboard|insights|trends|projects|tags|patterns|heatmap]

# Focus mode
clings focus start [--task ID] [--duration DURATION] [--session-type TYPE]
clings focus stop [--abandon] [--notes NOTES]
clings focus status [--watch]
clings focus pause
clings focus resume
clings focus break [short|long|DURATION]
clings focus history [--limit N] [--task ID]
clings focus report [--period PERIOD]

# Sync queue
clings sync status
clings sync run [--stop-on-error] [--dry-run] [--limit N]
clings sync list [--status STATUS] [--limit N]
clings sync add --operation TYPE --id ID [--payload JSON]
clings sync retry [--all | ID]
clings sync clear [--all] [--older-than HOURS] [--force]

# Automation
clings automation list
clings automation show <name>
clings automation run [--rule NAME] [--event EVENT] [--dry-run]
clings automation create <name> [--description DESC] [--trigger TYPE]
clings automation edit <name>
clings automation delete <name> [--force]
clings automation toggle <name> [--enable|--disable]
clings automation import <file> [--overwrite]
clings automation export <file> [--rules NAMES]

# Other
clings open <target>                          # Open Things to a view or item
```

## Output Formats

### Pretty (default)

Human-readable colored output with icons and formatting:

```
Today (3 items)
──────────────────────────────────────────────
[ ] Review PR #123        Development   Dec 15   #work
[ ] Buy groceries         -             -        #personal
[x] Call dentist          Health        Dec 10   -
```

### JSON

Machine-readable JSON for scripting and automation:

```bash
clings today --output json

# Use with jq for filtering
clings today -o json | jq '.items[] | select(.tags | contains(["work"]))'

# Pipe to other tools
clings today -o json | jq -r '.items[].name' | wc -l
```

## Configuration

clings stores configuration and data in `~/.clings/`:

```
~/.clings/
├── config.yaml          # User configuration
├── clings.db            # SQLite database (stats, sessions, queue)
├── templates/           # Project templates (YAML files)
├── rules/               # Automation rules (YAML files)
├── sessions/            # Focus session logs
└── cache/               # Cached data (completions, etc.)
```

## Data Safety

clings is designed with data safety as a priority. Your Things 3 data is precious, and we take several measures to protect it.

### How clings Accesses Your Data

- **Read operations:** Use direct SQLite access to the Things 3 database (read-only)
- **Write operations:** Use Apple's JavaScript for Automation (JXA) through the official Things 3 API
- **No direct database writes:** clings never writes directly to the Things 3 database

### Built-in Safety Measures

| Feature | Description |
|---------|-------------|
| **Confirmation prompts** | Bulk operations affecting >5 items require explicit confirmation |
| **Batch size limits** | Default limit of 50 items per bulk operation |
| **Dry-run mode** | Preview any bulk operation before executing with `--dry-run` |
| **Explicit bypass** | Scripting requires `--bypass-bulk-data-check` flag |

### Best Practices

1. **Always use `--dry-run` first** when running bulk operations
2. **Start with small filters** to verify your filter expression matches what you expect
3. **Use the interactive picker** (`clings pick`) for one-off operations
4. **Keep Things 3 backups** - Things 3 syncs to iCloud automatically
5. **Test filters with `clings filter`** before using them in bulk operations

### Recovery Options

If you accidentally modify data:

1. **Things 3 Undo:** Use Cmd+Z in Things 3 immediately after the operation
2. **iCloud Sync:** Things 3 data syncs to iCloud and may have recent versions
3. **Time Machine:** Restore from a Time Machine backup if available

## Troubleshooting

### Things 3 not installed

**Error:**
```
Things 3 is not installed.
```

**Solution:**

Install Things 3 from:
- [Mac App Store](https://apps.apple.com/app/things-3/id904280696)
- [Cultured Code](https://culturedcode.com/things/)

### Automation permission error

**Error:**
```
Automation permission required.
```

**Solution:**

Grant automation permission to your terminal:

1. Open **System Settings** > **Privacy & Security** > **Automation**
2. Find your terminal application (Terminal, iTerm2, etc.)
3. Enable the checkbox for **Things 3**
4. Run clings again

Quick access to settings:
```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
```

### Things 3 not running error

**Error:**
```
Things 3 is not running. Please launch Things 3 and try again.
```

**Solution:**

Launch Things 3 before running clings commands. Things 3 must be running for clings to communicate with it via AppleScript/JXA.

### Command not found

**Error:**
```
zsh: command not found: clings
```

**Solution:**

Ensure the binary is in your PATH:

```bash
# Check if installed
which clings

# Install to /usr/local/bin
sudo cp target/release/clings /usr/local/bin/

# Or add cargo bin to PATH in your shell config
export PATH="$HOME/.cargo/bin:$PATH"
```

## Development

### Build & Test

```bash
# Build
cargo build

# Run in debug mode
cargo run -- today

# Run tests
cargo test

# Run linter
cargo clippy

# Format code
cargo fmt

# Build release binary
cargo build --release
```

### Project Structure

```
src/
├── main.rs              # Entry point - CLI parsing and orchestration
├── lib.rs               # Library exports - all business logic
├── error.rs             # Custom error types with thiserror
├── cli/
│   ├── mod.rs           # CLI module exports
│   ├── args.rs          # Clap argument definitions
│   └── commands/        # Command implementations
├── things/
│   ├── mod.rs           # Things module exports
│   ├── client.rs        # ThingsClient - JXA script execution
│   └── types.rs         # Data types (Todo, Project, Area, Tag, etc.)
├── output/
│   ├── mod.rs           # Output module exports
│   ├── pretty.rs        # Human-readable colored output
│   └── json.rs          # JSON output formatting
├── features/
│   ├── nlp/             # Natural language parsing
│   ├── bulk/            # Bulk operations
│   ├── interactive/     # Interactive fuzzy picker
│   ├── templates/       # Project templates
│   ├── shell/           # Shell integration
│   ├── stats/           # Statistics and insights
│   ├── focus/           # Focus mode
│   ├── sync/            # Sync queue
│   └── automation/      # Automation rules
├── core/
│   ├── traits.rs        # Core traits
│   ├── filter.rs        # Filter expression parser
│   └── datetime.rs      # Date/time utilities
├── config/
│   ├── mod.rs           # Configuration management
│   ├── settings.rs      # Settings types
│   └── paths.rs         # Path utilities
└── storage/
    ├── mod.rs           # Storage layer
    ├── database.rs      # SQLite database
    └── migrations.rs    # Database migrations
```

### Code Quality

This project follows strict quality standards:

- **No unsafe code**
- **No `.unwrap()` or `.expect()`** - all errors handled properly
- **Comprehensive tests** - unit, integration, and doc tests
- **Full documentation** - all public items documented
- **Linting** - clippy pedantic + nursery warnings

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes following the code quality standards
4. Add tests for new functionality
5. Ensure all checks pass:
   ```bash
   cargo fmt && cargo clippy && cargo test
   ```
6. Submit a pull request

Please read [CLAUDE.md](CLAUDE.md) for detailed guidelines on:
- Code structure and architecture
- Error handling patterns
- Testing requirements
- Documentation standards
- Performance requirements

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3).

See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Things 3](https://culturedcode.com/things/) by Cultured Code for creating an amazing task management app
- The Rust community for excellent tools and libraries
- All contributors to this project

## Support

If you find clings useful, consider supporting development:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow.svg)](https://buymeacoffee.com/codedbydan)

## Links

- **Repository:** https://github.com/dan-hart/clings
- **Things 3:** https://culturedcode.com/things/
- **Things 3 URL Scheme:** https://culturedcode.com/things/support/articles/2803573/
