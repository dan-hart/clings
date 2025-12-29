# Changelog

All notable changes to clings will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.10] - 2025-12-29

### Fixed

- **Todo creation via AppleScript**: Avoids JXA "Can't make class" failures and schedules `when` dates using the Things `schedule` command.
- **Tag automation reliability**: Corrected tag existence checks so tag add/update/delete/rename and multi-tag updates work again.

## [0.2.9] - 2025-12-29

### Fixed

- **Multi-tag updates via AppleScript**: Set tag names using a comma-separated string to avoid AppleScript type errors when applying multiple tags.

## [0.2.8] - 2025-12-29

### Fixed

- **JXA crash on null modificationDate**: JXA list/search/fetch now safely handles missing modification dates (falls back to creationDate), fixing crashes in `clings filter` and list commands.

### Changed

- **No URL scheme usage**: Removed all Things URL scheme usage across add/update/open/project flows. Tag updates now use AppleScript, and creation uses JXA + AppleScript.
- **Open command disabled**: `clings open` now reports a clear error when invoked because URL schemes are disabled.
- **Bulk tag add**: Bulk tag operations now apply tags via update instead of printing a URL scheme warning.

## [0.2.7] - 2025-12-16

### Added

- **Project creation**: Create projects via `clings project add`:
  - `clings project add "Project Name"` - Create a new project
  - `clings project add "Sprint" --area "Work" --deadline 2025-01-31` - With options
  - Supports `--notes`, `--area`, `--when`, `--deadline`, and `--tags` flags
  - `clings project list` (or just `clings project`) - List all projects

- **Complete by title search**: Complete todos by searching their title:
  - `clings complete --title "buy milk"` - Search and complete by title
  - `clings complete -t "groceries"` - Short form
  - Shows disambiguation list when multiple todos match
  - Original ID-based completion still works: `clings complete ABC123`

## [0.2.6] - 2025-12-16

### Added

- **Tag CRUD commands**: Full tag management via `clings tags` subcommands:
  - `clings tags add "TagName"` - Create a new tag
  - `clings tags delete "TagName"` - Delete a tag (with confirmation unless `--force`)
  - `clings tags rename "OldName" "NewName"` - Rename a tag
  - `clings tags list` - List all tags (also the default when running just `clings tags`)

### Changed

- `clings tags` command now supports subcommands instead of only listing tags.
- Tag CRUD operations use AppleScript (not JXA) for reliable execution.

## [0.2.5] - 2025-12-16

### Fixed

- **`update --tags` silent failure**: Fixed critical bug where `clings update <id> --tags` would report success but never actually apply tags. Root cause was JXA's `todo.tags.push()` silently failing. Now uses Things URL scheme (`things:///update?id=X&tags=Y`) for reliable tag updates.

### Changed

- Tag operations in `updateTodo()` now use URL scheme instead of JXA for reliability.
- Added documentation comments explaining JXA tag limitations.

## [0.1.6] - 2025-12-08

### Fixed

- **`add --area` AppleScript error (-1700)**: Area assignment now correctly sets `todo.area` after `Things.make()` instead of attempting to set it in `withProperties`, which caused a JXA type conversion error.

- **`add --project` silent failure**: Added fallback to `Things.projects.whose()` when `Things.lists.byName()` fails to find a project, fixing cases where todos would silently land in Inbox instead of the specified project.

- **Emoji in title causes error**: Updated string escaping to use JSON encoding, which properly handles all Unicode characters including emoji (e.g., `⚠️`, `🖥️`).

- **Area ignored when project specified**: Removed the conditional that prevented area assignment when a project was also specified. Area and project can now be used together.

### Added

- **`--area` flag for `todo update`**: You can now move existing todos to a different area using `clings todo update <ID> --area "Area Name"`.

## [0.1.5] - 2025-12-05

### Fixed

- Fixed `add` command bugs with area, when/deadline, and project handling.

### Added

- Code quality audit: fixed 98% of clippy warnings, improved documentation.
- Homebrew installation support via `brew install dan-hart/tap/clings`.

## [0.1.4] and earlier

Initial development releases with core functionality:
- List views (today, inbox, upcoming, anytime, someday, logbook)
- Todo management (add, complete, cancel, update)
- Project management
- Search with filters
- Natural language parsing for quick add
- Shell completions (bash, zsh, fish)
- JSON output for scripting
- Terminal UI (tui)
- Statistics and review features
