# Clings Productivity Suite Design

**Goal:** Ship 10 practical CLI improvements for `clings` in one cohesive pass without changing its core hybrid read/write architecture.

**Approach:** Keep reads on SQLite and writes on JXA/AppleScript, but add a small state layer under `~/.config/clings` for reusable local features: saved views, templates, undo history, and richer review state. Prefer thin, composable commands over large interactive subsystems.

**Scope:**
- `doctor` command for setup diagnostics
- saved filter views via `views`
- interactive pick flows via `pick`
- `undo` for supported recent mutations
- smarter `review`
- project health auditing via `project audit`
- task templates via `template` and `add --template`
- stronger natural-language date capture
- custom line formatting for todo-list style commands
- new `focus` command for a daily working view

**Best-guess product decisions:**
- Persist local command state in JSON files under the existing config directory.
- Make undo explicitly limited to supported actions instead of pretending to be universal.
- Implement pick mode as a dedicated `pick` command to avoid invasive argument changes across many existing commands.
- Keep template scheduling expressions relative by storing raw strings like `tomorrow` instead of freezing parsed dates.
- Reuse shared analyzers for review, focus, and project audit so the heuristics stay consistent.
