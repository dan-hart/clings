// MutationCommands.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

// MARK: - Complete Command

struct CompleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Mark a todo as completed",
        discussion: """
        Marks a todo as completed by its ID or title search. The todo will
        be moved to the Logbook in Things 3.

        You can complete by ID (exact) or by a title/notes text search:
          clings complete ABC123           By exact ID
          clings complete --title "milk"   By title search

        To find a todo's ID, use the show command or --json output:
          clings today --json | jq -r '.items[].id'

        --title completes only when exactly one open todo matches. Multiple
        matches are listed without completing anything; choose an exact ID or
        use clings pick complete. --title takes precedence if an ID is also given.

        EXAMPLES:
          clings complete ABC123             Complete by ID
          clings done ABC123                 Alias for 'complete'
          clings complete -t "buy groceries" Complete by title search
          clings complete --title "milk"     Same as above
          clings complete ABC123 --json      Output result as JSON

        SEE ALSO:
          cancel, bulk complete, show, search
        """,
        aliases: ["done"]
    )

    @Argument(help: "The ID of the todo to complete (optional if using --title)")
    var id: String?

    @Option(name: [.short, .long], help: "Complete todo by searching its title")
    var title: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        try await MutationLock.withLock { try await perform() }
    }

    private func perform() async throws {
        let client = CommandRuntime.makeClient()

        // Determine which mode to use
        if let searchTitle = title {
            // Search for todo by title
            let results = try await client.search(query: searchTitle)
            let openTodos = results.filter { $0.status == .open }

            switch openTodos.count {
            case 0:
                throw ThingsError.notFound("No open todos matching '\(searchTitle)'")

            case 1:
                // Exactly one match - complete it
                let todo = openTodos[0]
                let snapshot = try await client.fetchTodo(id: todo.id)
                try await client.completeTodo(id: todo.id)
                try printOutcome(recordApplied(UndoEntry(operation: .complete, todoID: todo.id, snapshot: TodoSnapshot(todo: snapshot)), message: "Completed: \(todo.name)"), output: output)

            default:
                // Multiple matches - show list with IDs
                print("Multiple todos match '\(searchTitle)':")
                for (index, todo) in openTodos.prefix(10).enumerated() {
                    print("  \(index + 1). \(todo.name)")
                }
                print("\nUse the exact ID to complete:")
                for todo in openTodos.prefix(5) {
                    print("  clings complete \(todo.id)")
                }
            }
        } else if let todoId = id {
            // Original ID-based completion
            let snapshot = try await client.fetchTodo(id: todoId)
            try await client.completeTodo(id: todoId)
            try printOutcome(recordApplied(UndoEntry(operation: .complete, todoID: todoId, snapshot: TodoSnapshot(todo: snapshot)), message: "Completed todo: \(todoId)"), output: output)
        } else {
            throw ValidationError("Provide either a todo ID or --title flag")
        }
    }
}

// MARK: - Cancel Command

struct CancelCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cancel",
        abstract: "Cancel a todo",
        discussion: """
        Cancels a todo by its ID. Canceled todos are not deleted but
        marked as canceled and moved to the Logbook.

        Use cancel for tasks that are no longer relevant, as opposed
        to complete which is for finished tasks.

        This writes immediately, without a confirmation prompt. Use show to
        inspect the ID first; clings undo can reopen the recorded todo.

        EXAMPLES:
          clings cancel ABC123          Cancel a specific todo
          clings cancel ABC123 --json   Output result as JSON

        SEE ALSO:
          complete, delete, bulk cancel
        """
    )

    @Argument(help: "The ID of the todo to cancel")
    var id: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        try await MutationLock.withLock { try await perform() }
    }

    private func perform() async throws {
        let client = CommandRuntime.makeClient()
        let snapshot = try await client.fetchTodo(id: id)
        try await client.cancelTodo(id: id)
        try printOutcome(recordApplied(UndoEntry(operation: .cancel, todoID: id, snapshot: TodoSnapshot(todo: snapshot)), message: "Canceled todo: \(id)"), output: output)
    }
}

// MARK: - Delete Command

struct DeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Cancel a todo through the automation API",
        discussion: """
        Deletes a todo by its ID. In Things 3, this is equivalent to
        canceling the todo (there is no true "delete" in the API).

        For permanent deletion, use the Things app directly.

        CURRENT BEHAVIOR:
          Requires confirmation unless --force is supplied. Noninteractive
          use requires --force. This cancels the todo, never moves it to Trash.
          Undo restores the previous status, including completed or canceled.

        EXAMPLES:
          clings delete ABC123          Delete a specific todo
          clings rm ABC123              Alias for 'delete'
          clings delete ABC123 -f       Compatibility flag (same behavior)

        SEE ALSO:
          cancel, complete
        """,
        aliases: ["rm"]
    )

    @Argument(help: "The ID of the todo to delete")
    var id: String

    @Flag(name: .shortAndLong, help: "Authorize cancellation without prompting (never moves to Trash)")
    var force = false

    @OptionGroup var output: OutputOptions

    func run() async throws {
        try await MutationLock.withLock { try await perform() }
    }

    private func perform() async throws {
        let client = CommandRuntime.makeClient()
        let snapshot = try await client.fetchTodo(id: id)
        guard try confirmMutation("Cancel '\(snapshot.name)' [\(id)]? This does not move it to Trash.", authorized: force) else {
            try printOutcome(MutationOutcome(applied: false, undoRecorded: false, message: "Canceled request; no change applied"), output: output)
            return
        }
        try await client.deleteTodo(id: id)
        try printOutcome(recordApplied(UndoEntry(operation: .delete, todoID: id, snapshot: TodoSnapshot(todo: snapshot)), message: "Canceled todo: \(id) (not moved to Trash)"), output: output)
    }
}

// MARK: - Update Command

struct UpdateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update a todo's properties",
        discussion: """
        Update one or more properties of a todo by ID.
        Only specified options will be updated.

        --tags replaces the existing tag set; pass separate names, not a comma
        list. --when and --heading require a configured Things URL auth token.
        Undo restores name, notes, deadline, and tags, but not scheduling/headings.

        EXAMPLES:
          clings update ABC123 --name "New title"
          clings update ABC123 --notes "Updated notes"
          clings update ABC123 --due 2027-01-15
          clings update ABC123 --when tomorrow
          clings update ABC123 --heading "Waiting on them"
          clings update ABC123 --tags docs urgent
        """
    )

    @Argument(help: "The ID of the todo to update")
    var id: String

    @Option(name: .long, help: "New title/name for the todo")
    var name: String?

    @Option(name: .long, help: "New notes for the todo")
    var notes: String?

    @Option(name: .long, help: "New due date (YYYY-MM-DD or 'today', 'tomorrow')")
    var due: String?

    @Option(name: .long, help: "Schedule for a date ('today', 'tomorrow', 'evening', 'anytime', 'someday', or YYYY-MM-DD). Requires auth token.")
    var when: String?

    @Option(name: .long, help: "Move to a heading within the task's project. Requires auth token.")
    var heading: String?

    @Option(name: .long, parsing: .upToNextOption, help: "New tags (replaces existing)")
    var tags: [String] = []

    @OptionGroup var output: OutputOptions
    @Flag(name: .long, help: "Preview final fields and undo capabilities without writing or requiring an auth token")
    var parseOnly = false

    func run() async throws {
        if parseOnly {
            try await perform(); return
        }
        try await MutationLock.withLock { try await perform() }
    }

    private func perform() async throws {
        // Check if any update options provided
        guard name != nil || notes != nil || due != nil || when != nil || heading != nil || !tags.isEmpty else {
            throw ThingsError.invalidState("No update options provided. Use --name, --notes, --due, --when, --heading, or --tags.")
        }

        let dueDate = try resolveDate(due)
        var resolvedWhen = when
        var scheduledDate: Date?
        // Validate --when value if provided
        if let when = when {
            let validKeywords = Set(["today", "tomorrow", "evening", "anytime", "someday"])
            let isKeyword = validKeywords.contains(when.lowercased())
            scheduledDate = isKeyword ? (try? resolveDate(when)) : try resolveDate(when)
            let isDate = scheduledDate != nil
            if !isKeyword, let scheduledDate {
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd@HH:mm"
                resolvedWhen = formatter.string(from: scheduledDate)
            }
            guard isKeyword || isDate else {
                throw ThingsError.invalidState(
                    "Invalid --when value: '\(when)'. Use 'today', 'tomorrow', 'evening', 'anytime', 'someday', or YYYY-MM-DD."
                )
            }
        }

        // Validate and trim --heading
        let resolvedHeading: String?
        if let heading = heading {
            let trimmed = heading.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ThingsError.invalidState("--heading value cannot be empty")
            }
            guard !trimmed.contains(where: { $0.isNewline }) else {
                throw ThingsError.invalidState("--heading value cannot contain newlines")
            }
            resolvedHeading = trimmed
        } else {
            resolvedHeading = nil
        }

        let client = CommandRuntime.makeClient()
        if parseOnly {
            let previous = try await client.fetchTodo(id: id)
            let preview = TaskPreview(
                id: id, title: name ?? previous.name, notes: notes ?? previous.notes,
                tags: tags.isEmpty ? previous.tags.map(\.name) : tags,
                project: previous.project?.name, area: previous.area?.name,
                when: when == nil ? previous.scheduledDate : scheduledDate,
                deadline: dueDate ?? previous.dueDate, scheduleExpression: resolvedWhen,
                heading: resolvedHeading,
                undo: "Restores title, notes, deadline and tags; scheduling and heading are not restored.",
                unsupportedUndo: [when != nil ? "schedule" : nil, heading != nil ? "heading" : nil].compactMap { $0 }
            )
            try print(preview.render(json: output.json))
            return
        }
        // Pre-validate auth token before any mutations to avoid partial updates
        warnUnsupported([when != nil ? "schedule" : nil, resolvedHeading != nil ? "heading" : nil].compactMap { $0 })
        let needsURLScheme = when != nil || resolvedHeading != nil
        var prevalidatedToken: String? = nil
        if needsURLScheme {
            do {
                prevalidatedToken = try AuthTokenStore.loadToken()
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                throw ThingsError.invalidState(
                    "Things auth token required for --when/--heading. Set with: clings config set-auth-token <token>"
                )
            } catch let error as ThingsError {
                throw error
            } catch {
                throw ThingsError.operationFailed(
                    "Failed to read auth token: \(error.localizedDescription). Try re-setting with: clings config set-auth-token <token>"
                )
            }
        }

        let previousSnapshot = try await client.fetchTodo(id: id)

        // Update via JXA (name, notes, dueDate, tags)
        let hasJXAUpdates = name != nil || notes != nil || dueDate != nil || !tags.isEmpty
        if hasJXAUpdates {
            do { try await client.updateTodo(
                id: id,
                name: name,
                notes: notes,
                dueDate: dueDate,
                tags: tags.isEmpty ? nil : tags
            ) } catch let error as AppliedMutationError {
                try reportPartial(error, entry: UndoEntry(operation: .update, todoID: id, snapshot: TodoSnapshot(todo: previousSnapshot)))
            }
        }

        // Handle when and heading via Things URL scheme (activationDate is read-only in JXA)
        if needsURLScheme, let token = prevalidatedToken {
            do {
                try updateViaURLScheme(id: id, when: resolvedWhen, heading: resolvedHeading, token: token)
            } catch {
                if hasJXAUpdates {
                    let jxaFields = [name != nil ? "name" : nil, notes != nil ? "notes" : nil,
                                     dueDate != nil ? "due date" : nil, !tags.isEmpty ? "tags" : nil]
                        .compactMap { $0 }.joined(separator: ", ")
                    let result = try recordApplied(UndoEntry(operation: .update, todoID: id, snapshot: TodoSnapshot(todo: previousSnapshot)), message: "Partial update: \(jxaFields) updated, but URL update failed", unsupported: ["schedule", "heading"])
                    throw try CommandFailure(exitStatus: 2, code: "mutation_partial", message: "Partial update: \(jxaFields) applied, but --when/--heading failed: \(error.localizedDescription)", dataJSON: payloadJSON(result))
                }
                throw error
            }
        }

        let urlSchemeNote = needsURLScheme ? " (--when/--heading sent via URL scheme; verify in Things)" : ""
        if !hasJXAUpdates {
            try printOutcome(MutationOutcome(applied: true, undoRecorded: false, unsupportedUndo: [when != nil ? "schedule" : nil, heading != nil ? "heading" : nil].compactMap { $0 }, message: "Updated todo: \(id)\(urlSchemeNote)"), output: output)
            return
        }
        try printOutcome(recordApplied(UndoEntry(operation: .update, todoID: id, snapshot: TodoSnapshot(todo: previousSnapshot)), message: "Updated todo: \(id)\(urlSchemeNote)", unsupported: [when != nil ? "schedule" : nil, heading != nil ? "heading" : nil].compactMap { $0 }), output: output)
    }

    private func updateViaURLScheme(id: String, when: String?, heading: String?, token: String) throws {
        var queryItems = [
            URLQueryItem(name: "auth-token", value: token),
            URLQueryItem(name: "id", value: id),
        ]
        if let when = when {
            queryItems.append(URLQueryItem(name: "when", value: when.lowercased()))
        }
        if let heading = heading {
            queryItems.append(URLQueryItem(name: "heading", value: heading))
        }

        guard var components = URLComponents(string: "things:///update") else {
            throw ThingsError.operationFailed("Internal error: failed to parse Things URL base")
        }
        components.queryItems = queryItems
        guard let url = components.url?.absoluteString else {
            throw ThingsError.operationFailed("Failed to construct Things URL")
        }

        try CommandRuntime.openURLScheme(url)
    }
}
