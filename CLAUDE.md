# CLAUDE.md - clings Project Guidelines

> A Things 3 CLI for macOS

## Project Overview

**clings** is a fast, feature-rich command-line interface for [Things 3](https://culturedcode.com/things/) on macOS, written in Swift.

- **License:** GNU General Public License v3.0 (GPLv3)
- **Platform:** macOS only (requires Things 3 installed)
- **Technology:** Swift + SQLite (reads) + JavaScript for Automation (JXA) via `osascript` (writes)
- **Version:** 0.2.0

## Build & Run

```bash
# Build
swift build

# Run
swift run clings today
swift run clings --help

# Test
swift test

# Build release
swift build -c release
```

## Architecture

### Hybrid Read/Write Approach

clings uses a **hybrid architecture** for optimal performance and safety:

- **Reads:** Direct SQLite access to the Things 3 database (~30ms response time)
- **Writes:** JXA/AppleScript through the official Things 3 automation API

This approach provides:
- Near-instant reads without launching Things 3
- Safe writes through the official API
- Compatibility with Things 3 updates

### Module Structure

```
Sources/
├── clings/
│   └── main.swift           # Entry point
├── ClingsCore/
│   ├── CLI/
│   │   ├── Commands/        # Command implementations
│   │   └── CLIApp.swift     # ArgumentParser setup
│   ├── Database/
│   │   └── ThingsDatabase.swift  # SQLite access
│   ├── JXA/
│   │   └── ThingsJXA.swift  # JXA script execution
│   ├── Models/
│   │   └── Todo.swift       # Data types
│   ├── NLP/
│   │   └── TaskParser.swift # Natural language parsing
│   └── Output/
│       ├── PrettyPrinter.swift
│       └── JSONOutput.swift
```

### Design Principles

1. **Separation of Concerns:** CLI layer thin, business logic in ClingsCore
2. **Testability:** All business logic in library target
3. **Swift Best Practices:** Use Swift's type safety, optionals, and error handling
4. **Performance:** SQLite for reads, batch operations where possible

## Code Quality Standards

### Error Handling

```swift
// Use typed errors
enum ClingsError: LocalizedError {
    case thingsNotRunning
    case permissionDenied
    case notFound(String)
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .thingsNotRunning:
            return "Things 3 is not running"
        case .permissionDenied:
            return "Automation permission required.\n\nGrant access in System Settings > Privacy & Security > Automation"
        case .notFound(let item):
            return "Item not found: \(item)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}
```

**Rules:**
- Use Swift's `Error` protocol for custom error types
- Use `throws` and `try` for error propagation
- NEVER use force unwrapping (`!`) in production code
- All error messages must be user-friendly with actionable guidance
- Handle macOS automation permission errors gracefully

### Swift Concurrency

Use async/await for I/O operations:

```swift
func fetchTodos() async throws -> [Todo] {
    try await withCheckedThrowingContinuation { continuation in
        // Database or JXA operation
    }
}
```

### Formatting

Use SwiftFormat with project defaults. Import organization:

```swift
// 1. Foundation/Standard library
import Foundation

// 2. External packages
import ArgumentParser
import GRDB

// 3. Internal modules
import ClingsCore
```

## Testing Requirements

### Test Categories

**Unit Tests** - Test individual functions:
```swift
import XCTest
@testable import ClingsCore

final class TaskParserTests: XCTestCase {
    func testParseDateTodayReturnsCurrentDate() {
        let result = TaskParser.parseDate("today")
        XCTAssertEqual(result, Date().formatted(date: .numeric, time: .omitted))
    }
}
```

**Integration Tests** - Test CLI commands:
```swift
import XCTest

final class CLIIntegrationTests: XCTestCase {
    func testHelpFlagShowsUsage() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ".build/debug/clings")
        process.arguments = ["--help"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        XCTAssertTrue(output?.contains("Things 3") == true)
    }
}
```

### Coverage Requirements

- **Minimum:** 80% overall code coverage
- **Critical Paths:** 95%+ coverage for:
  - Error handling
  - Database access
  - CLI argument parsing

## Dependencies (Package.swift)

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/groue/GRDB.swift", from: "6.24.0"),
    .package(url: "https://github.com/malcommac/SwiftDate", from: "7.0.0"),
]
```

| Package | Purpose |
|---------|---------|
| swift-argument-parser | CLI argument parsing |
| GRDB.swift | SQLite database access |
| SwiftDate | Date/time parsing and formatting |

## CLI Design Guidelines

### Command Structure

```
clings [OPTIONS] <COMMAND>

Options:
  --json                 Output as JSON (for scripting)
  --no-color             Suppress color output
  -h, --help             Show help
  --version              Show version

Commands:
  today, t (default)     Show today's todos
  inbox, i               Show inbox todos
  upcoming, u            Show upcoming todos
  anytime                Show anytime todos
  someday, s             Show someday todos
  logbook, l             Show completed todos
  projects               List all projects
  areas                  List all areas
  tags                   List all tags
  show                   Show details of a todo by ID
  add                    Quick add with natural language
  complete, done         Mark a todo as completed
  cancel                 Cancel a todo
  delete, rm             Delete a todo
  update                 Update a todo's properties
  search, find, f        Search todos by text
  bulk                   Bulk operations on multiple todos
  filter                 Filter todos using a query
  open                   Open a todo or list in Things 3
  stats                  View productivity statistics
  review                 Interactive weekly review workflow
  completions            Generate shell completions
```

### Design Principles

1. **Intuitive:** Commands match Things 3 terminology
2. **Scriptable:** JSON output for piping and automation
3. **Informative:** Exit codes indicate success (0), user error (1), system error (2)
4. **Complete:** Shell completions for bash, zsh, fish
5. **Fast:** SQLite reads complete in ~30ms

## CI/CD Requirements

### GitHub Actions Workflow

Every PR must pass:
1. `swift build` - Build succeeds
2. `swift test` - All tests pass
3. `swift build -c release` - Release build succeeds

### Release Process

On tag push:
1. Build release binaries (macOS ARM64, macOS x86_64)
2. Generate shell completions
3. Create GitHub release with artifacts
4. Update Homebrew formula

### Updating Homebrew Formula

When releasing a new version:

1. **Get the SHA256 checksum** for the new release tarball:
   ```bash
   curl -sL https://github.com/dan-hart/clings/archive/refs/tags/v<VERSION>.tar.gz | shasum -a 256
   ```

2. **Update the formula** in the homebrew-tap repository:
   - Repository: https://github.com/dan-hart/homebrew-tap
   - File: `Formula/clings.rb`
   - Update the `url` to point to the new version tag
   - Update the `sha256` with the new checksum

3. **Commit and push** the formula changes

4. **Verify** the update works:
   ```bash
   brew update && brew upgrade clings
   ```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes following these guidelines
4. Add tests for new functionality
5. Ensure all checks pass: `swift build && swift test`
6. Submit a pull request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Claude Directives

- Never add Claude as a co-author on commits
- **Always update the Homebrew tap when releasing a new version:**
  1. Update version in code
  2. Commit, tag (e.g., `v0.2.1`), and push to all remotes
  3. Get SHA256: `curl -sL https://github.com/dan-hart/clings/archive/refs/tags/v<VERSION>.tar.gz | shasum -a 256`
  4. Update `~/Developer/homebrew-tap/Formula/clings.rb` with new version and SHA256
  5. Commit and push homebrew-tap
  6. Run `brew update && brew upgrade clings` to verify
