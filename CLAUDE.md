# CLAUDE.md - clings Project Guidelines

> A Things 3 CLI for macOS

## Project Overview

**clings** is a fast, feature-rich command-line interface for [Things 3](https://culturedcode.com/things/) on macOS, written in Rust.

- **License:** GNU General Public License v3.0 (GPLv3)
- **Platform:** macOS only (requires Things 3 installed)
- **Technology:** Rust + JavaScript for Automation (JXA) via `osascript`

## Build & Run

```bash
# Build
cargo build

# Run
cargo run -- today
cargo run -- --help

# Test
cargo test

# Lint
cargo clippy

# Format
cargo fmt
```

## Architecture

### Module Structure

```
src/
├── main.rs           # Entry point - CLI parsing and orchestration only
├── lib.rs            # Library exports - all business logic lives here
├── error.rs          # Custom error types with thiserror
├── cli/
│   ├── mod.rs        # CLI module exports
│   ├── args.rs       # Clap argument definitions
│   └── commands/     # Command implementations
│       └── mod.rs
├── things/
│   ├── mod.rs        # Things module exports
│   ├── client.rs     # ThingsClient - JXA script execution
│   └── types.rs      # Data types (Todo, Project, Area, Tag, etc.)
└── output/
    ├── mod.rs        # Output module exports
    ├── pretty.rs     # Human-readable colored output
    └── json.rs       # JSON output formatting
```

### Design Principles

1. **Separation of Concerns:** Keep `main.rs` thin - it should only parse CLI args and call into library code
2. **Testability:** All business logic in `lib.rs` crate, enabling unit tests
3. **Abstraction:** `ThingsClient` abstracts JXA interaction; output formatters abstract presentation
4. **Error Propagation:** Use `?` operator throughout; handle errors at boundaries

## Code Quality Standards

### Error Handling

```rust
// Use thiserror for library error types
#[derive(Error, Debug)]
pub enum ClingsError {
    #[error("Things 3 is not running")]
    ThingsNotRunning,

    #[error("Automation permission required.\n\n\
             Grant access in System Settings > Privacy & Security > Automation")]
    PermissionDenied,

    #[error("Item not found: {0}")]
    NotFound(String),
}
```

**Rules:**
- Use `thiserror` for custom error types
- Use `anyhow::Context` for adding context to errors in application code
- NEVER use `.unwrap()` or `.expect()` in production code
- All error messages must be user-friendly with actionable guidance
- Detect and handle macOS automation permission errors gracefully

### Strict Linting

Add to `lib.rs` and `main.rs`:

```rust
#![deny(unsafe_code)]
#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]
#![warn(clippy::pedantic)]
#![warn(clippy::nursery)]
#![allow(clippy::module_name_repetitions)]
```

**Rationale:**
- `unsafe_code`: No unsafe code in this project
- `unwrap_used`/`expect_used`: All fallible operations must use proper error handling
- `pedantic`/`nursery`: Catch subtle issues and follow best practices

### Formatting

Use `rustfmt` with project defaults. Import organization:

```rust
// 1. Standard library
use std::process::Command;

// 2. External crates
use clap::Parser;
use serde::{Deserialize, Serialize};

// 3. Internal modules
use crate::error::ClingsError;
use crate::things::ThingsClient;
```

## Testing Requirements

### Test Categories

**Unit Tests** - Same file as implementation:
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_date_today_returns_current_date() {
        // Test implementation
    }
}
```

**Integration Tests** - `tests/` directory:
```rust
use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn test_help_flag_shows_usage() {
    let mut cmd = Command::cargo_bin("clings").unwrap();
    cmd.arg("--help")
       .assert()
       .success()
       .stdout(predicate::str::contains("Things 3 CLI"));
}
```

**Doc Tests** - In documentation:
```rust
/// Parses a date string into a formatted date.
///
/// # Examples
///
/// ```
/// use clings::cli::args::parse_date;
/// assert_eq!(parse_date("today"), chrono::Local::now().format("%Y-%m-%d").to_string());
/// ```
pub fn parse_date(input: &str) -> String {
    // Implementation
}
```

### Testing Tools

- `assert_cmd` - Execute and test CLI binary
- `predicates` - Flexible assertions (contains, regex, etc.)
- `proptest` - Property-based testing for edge cases
- `mockall` - Mocking for unit tests (if needed)

### Coverage Requirements

- **Minimum:** 80% overall code coverage
- **Critical Paths:** 95%+ coverage for:
  - Error handling (`src/error.rs`)
  - Things client (`src/things/client.rs`)
  - CLI argument parsing (`src/cli/args.rs`)

Run coverage with:
```bash
cargo install cargo-tarpaulin
cargo tarpaulin --out Html
```

## Documentation Standards

### Code Documentation

Every public item requires documentation:

```rust
//! Things 3 client module.
//!
//! This module provides the `ThingsClient` struct for interacting with
//! Things 3 via JavaScript for Automation (JXA).

/// A client for interacting with Things 3 via JXA scripts.
///
/// # Examples
///
/// ```no_run
/// use clings::things::ThingsClient;
///
/// let client = ThingsClient::new();
/// let todos = client.get_list(ListView::Today)?;
/// ```
pub struct ThingsClient;

impl ThingsClient {
    /// Retrieves todos from the specified list view.
    ///
    /// # Arguments
    ///
    /// * `view` - The Things 3 list view to query
    ///
    /// # Errors
    ///
    /// Returns `ClingsError::ThingsNotRunning` if Things 3 is not open.
    /// Returns `ClingsError::PermissionDenied` if automation permission is denied.
    pub fn get_list(&self, view: ListView) -> Result<Vec<Todo>, ClingsError> {
        // Implementation
    }
}
```

### README Requirements

The README.md must include:
- Project description and features
- Installation instructions (cargo install, homebrew if available)
- Quick start guide with examples
- Full command reference
- Configuration options
- Contributing guidelines
- License information

## CLI Design Guidelines

### Command Structure

```
clings [OPTIONS] <COMMAND>

Options:
  -o, --output <FORMAT>    Output format [pretty|json] (default: pretty)
  -h, --help               Show help
  -V, --version            Show version

Commands:
  list        List todos from a view (today, inbox, upcoming, etc.)
  today       Show today's todos (alias for 'list today')
  inbox       Show inbox todos (alias for 'list inbox')
  upcoming    Show upcoming todos (alias for 'list upcoming')
  anytime     Show anytime todos (alias for 'list anytime')
  someday     Show someday todos (alias for 'list someday')
  logbook     Show completed todos (alias for 'list logbook')
  add         Quick add with natural language
  todo        Manage todos (show, complete, cancel, delete)
  project     Manage projects (list, show, add)
  search      Search todos by text or filters
  open        Open Things to a specific view or item
  bulk        Bulk operations on multiple todos
  stats       View productivity statistics
  review      Interactive weekly review workflow
  shell       Shell integration (completions)
  tui         Launch the terminal UI
```

### Design Principles

1. **Intuitive:** Commands match Things 3 terminology
2. **Scriptable:** JSON output for piping and automation
3. **Informative:** Exit codes indicate success (0), user error (1), system error (2)
4. **Complete:** Shell completions for bash, zsh, fish
5. **POSIX-compliant:** Follow standard argument conventions

### Output Examples

**Pretty (default):**
```
Today (3 items)
──────────────────────────────────────────────
[ ] Review PR #123        Development   Dec 15   #work
[ ] Buy groceries         -             -        #personal
[x] Call dentist          Health        Dec 10   -
```

**JSON:**
```json
{
  "list": "today",
  "count": 3,
  "items": [...]
}
```

## Performance Requirements

- **Startup time:** < 100ms
- **Command execution:** Minimize JXA calls; batch where possible
- **Memory:** No unnecessary allocations; efficient JSON parsing
- **Binary size:** Use `lto = true` and `strip = true` for release builds

## Dependencies Policy

Every dependency must be:
1. **Necessary:** No redundant functionality
2. **Well-maintained:** Active development, responsive maintainers
3. **Secure:** Regular `cargo audit` checks
4. **Documented:** Purpose noted in Cargo.toml comments

### Current Dependencies

```toml
[dependencies]
clap = { version = "4", features = ["derive", "env"] }  # CLI argument parsing
serde = { version = "1", features = ["derive"] }         # Serialization
serde_json = "1"                                          # JSON handling
chrono = { version = "0.4", features = ["serde"] }       # Date/time handling
colored = "2"                                             # Terminal colors
thiserror = "2"                                           # Error types
anyhow = "1"                                              # Error context

[dev-dependencies]
assert_cmd = "2"      # CLI testing
predicates = "3"      # Test assertions
proptest = "1"        # Property-based testing
```

## CI/CD Requirements

### GitHub Actions Workflow

Every PR must pass:
1. `cargo fmt --check` - Code formatting
2. `cargo clippy -- -D warnings` - Linting
3. `cargo test` - All tests
4. `cargo build --release` - Release build

### Release Process

On tag push:
1. Build release binaries (macOS ARM64, macOS x86_64)
2. Generate shell completions
3. Create GitHub release with artifacts
4. Update Homebrew formula (see below)

### Updating Homebrew Formula

When releasing a new version, the Homebrew formula must be updated:

1. **Get the SHA256 checksum** for the new release tarball:
   ```bash
   curl -sL https://github.com/dan-hart/clings/archive/refs/tags/v<VERSION>.tar.gz | shasum -a 256
   ```

2. **Update the formula** in the homebrew-tap repository:
   - Repository: https://github.com/dan-hart/homebrew-tap
   - File: `Formula/clings.rb`
   - Update the `url` to point to the new version tag
   - Update the `sha256` with the new checksum

3. **Commit and push** the formula changes:
   ```bash
   cd /path/to/homebrew-tap
   git add Formula/clings.rb
   git commit -m "Update clings to v<VERSION>"
   git push
   ```

4. **Verify** the update works:
   ```bash
   brew update
   brew upgrade clings
   # or for fresh install:
   brew install dan-hart/tap/clings
   ```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes following these guidelines
4. Add tests for new functionality
5. Ensure all checks pass: `cargo fmt && cargo clippy && cargo test`
6. Submit a pull request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
- never add claude as a co author on commits