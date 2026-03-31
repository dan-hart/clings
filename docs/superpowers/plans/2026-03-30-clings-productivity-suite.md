# Clings Productivity Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 10 shippable CLI improvements to `clings` with shared local state, better analysis, and stronger task capture.

**Architecture:** Add a focused config/state layer in `ClingsCore`, then build command-facing analyzers and helpers on top of it. Keep command implementations thin by pushing persistence, formatting, focus scoring, review summaries, and project audit logic into reusable core types.

**Tech Stack:** Swift 6, ArgumentParser, GRDB, Foundation, Swift Testing

---

### Task 1: Add shared config/state storage

**Files:**
- Create: `Sources/ClingsCore/Config/ClingsConfig.swift`
- Create: `Sources/ClingsCore/Config/JSONFileStore.swift`
- Modify: `Sources/ClingsCore/Config/AuthTokenStore.swift`
- Test: `Tests/ClingsCoreTests/Config/JSONFileStoreTests.swift`

- [ ] Write failing tests for config directory resolution and JSON round-trips
- [ ] Run targeted tests and confirm failures
- [ ] Implement shared config helpers and migrate auth token path lookup
- [ ] Re-run targeted tests and confirm passes

### Task 2: Add reusable local feature stores

**Files:**
- Create: `Sources/ClingsCore/Config/SavedViewStore.swift`
- Create: `Sources/ClingsCore/Config/TemplateStore.swift`
- Create: `Sources/ClingsCore/Config/UndoStore.swift`
- Test: `Tests/ClingsCoreTests/Config/SavedViewStoreTests.swift`
- Test: `Tests/ClingsCoreTests/Config/TemplateStoreTests.swift`
- Test: `Tests/ClingsCoreTests/Config/UndoStoreTests.swift`

- [ ] Write failing storage tests for views, templates, and undo history
- [ ] Run targeted tests and confirm failures
- [ ] Implement codable stores and trimming/replace semantics
- [ ] Re-run targeted tests and confirm passes

### Task 3: Add analyzers for review, audit, and focus

**Files:**
- Create: `Sources/ClingsCore/Analysis/ProjectAudit.swift`
- Create: `Sources/ClingsCore/Analysis/FocusPlanner.swift`
- Create: `Sources/ClingsCore/Analysis/ReviewAssistant.swift`
- Test: `Tests/ClingsCoreTests/Analysis/ProjectAuditTests.swift`
- Test: `Tests/ClingsCoreTests/Analysis/FocusPlannerTests.swift`
- Test: `Tests/ClingsCoreTests/Analysis/ReviewAssistantTests.swift`

- [ ] Write failing tests for health findings, focus ranking, and review summary heuristics
- [ ] Run targeted tests and confirm failures
- [ ] Implement analyzers
- [ ] Re-run targeted tests and confirm passes

### Task 4: Strengthen natural-language parsing and todo formatting

**Files:**
- Create: `Sources/ClingsCore/NLP/NaturalLanguageDateParser.swift`
- Create: `Sources/ClingsCore/Output/TodoLineFormatter.swift`
- Modify: `Sources/ClingsCore/NLP/TaskParser.swift`
- Modify: `Sources/ClingsCore/Output/OutputFormatter.swift`
- Test: `Tests/ClingsCoreTests/NLP/NaturalLanguageDateParserTests.swift`
- Test: `Tests/ClingsCoreTests/NLP/TaskParserTests.swift`
- Test: `Tests/ClingsCoreTests/Output/TodoLineFormatterTests.swift`

- [ ] Write failing tests for new date phrases, quoted project/area parsing, and custom line formats
- [ ] Run targeted tests and confirm failures
- [ ] Implement parser and formatter support
- [ ] Re-run targeted tests and confirm passes

### Task 5: Expand command surface

**Files:**
- Create: `Sources/ClingsCLI/Commands/DoctorCommand.swift`
- Create: `Sources/ClingsCLI/Commands/ViewsCommand.swift`
- Create: `Sources/ClingsCLI/Commands/TemplateCommand.swift`
- Create: `Sources/ClingsCLI/Commands/UndoCommand.swift`
- Create: `Sources/ClingsCLI/Commands/FocusCommand.swift`
- Create: `Sources/ClingsCLI/Commands/PickCommand.swift`
- Create: `Sources/ClingsCLI/Support/CommandSupport.swift`
- Modify: `Sources/ClingsCLI/Clings.swift`
- Test: `Tests/ClingsCLITests/ArgumentParsingTests.swift`
- Test: `Tests/ClingsCLITests/CommandConfigurationTests.swift`

- [ ] Write failing argument/configuration tests for the new commands
- [ ] Run targeted tests and confirm failures
- [ ] Implement commands and shared CLI helpers
- [ ] Re-run targeted tests and confirm passes

### Task 6: Upgrade existing commands

**Files:**
- Modify: `Sources/ClingsCLI/Commands/AddCommand.swift`
- Modify: `Sources/ClingsCLI/Commands/ListCommands.swift`
- Modify: `Sources/ClingsCLI/Commands/SearchCommand.swift`
- Modify: `Sources/ClingsCLI/Commands/FilterCommand.swift`
- Modify: `Sources/ClingsCLI/Commands/MutationCommands.swift`
- Modify: `Sources/ClingsCLI/Commands/ProjectCommands.swift`
- Modify: `Sources/ClingsCLI/Commands/ReviewCommand.swift`
- Test: `Tests/ClingsCLITests/ArgumentParsingTests.swift`

- [ ] Write failing parsing/behavior-oriented tests for template use, custom formatting, undo recording support, audit routing, and improved review options
- [ ] Run targeted tests and confirm failures
- [ ] Implement command changes with minimal code paths
- [ ] Re-run targeted tests and confirm passes

### Task 7: Update docs and verify end-to-end

**Files:**
- Modify: `README.md`
- Verify: `swift test`
- Verify: `swift build`

- [ ] Update README command documentation for new features
- [ ] Run the full test suite
- [ ] Run a full build
- [ ] Fix any regressions and re-run verification
