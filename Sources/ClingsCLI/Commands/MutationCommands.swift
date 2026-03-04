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

        You can complete by ID (exact) or by title search (fuzzy):
          clings complete ABC123           By exact ID
          clings complete --title "milk"   By title search

        To find a todo's ID, use the show command or --json output:
          clings today --json | jq '.[].id'

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
        let client = ThingsClientFactory.create()

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

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
                try await client.completeTodo(id: todo.id)
                print(formatter.format(message: "Completed: \(todo.name)"))

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
            try await client.completeTodo(id: todoId)
            print(formatter.format(message: "Completed todo: \(todoId)"))
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
        let client = ThingsClientFactory.create()
        try await client.cancelTodo(id: id)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Canceled todo: \(id)"))
    }
}

// MARK: - Delete Command

struct DeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a todo (moves to trash)",
        discussion: """
        Deletes a todo by its ID. In Things 3, this is equivalent to
        canceling the todo (there is no true "delete" in the API).

        For permanent deletion, use the Things app directly.

        EXAMPLES:
          clings delete ABC123          Delete a specific todo
          clings rm ABC123              Alias for 'delete'
          clings delete ABC123 -f       Skip confirmation

        SEE ALSO:
          cancel, complete
        """,
        aliases: ["rm"]
    )

    @Argument(help: "The ID of the todo to delete")
    var id: String

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClientFactory.create()
        try await client.deleteTodo(id: id)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Deleted todo: \(id)"))
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

        Examples:
          clings update ABC123 --name "New title"
          clings update ABC123 --notes "Updated notes"
          clings update ABC123 --due 2024-12-25
          clings update ABC123 --when tomorrow
          clings update ABC123 --heading "Waiting on them"
          clings update ABC123 --tags work,urgent
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

    func run() async throws {
        // Check if any update options provided
        guard name != nil || notes != nil || due != nil || when != nil || heading != nil || !tags.isEmpty else {
            throw ThingsError.invalidState("No update options provided. Use --name, --notes, --due, --when, --heading, or --tags.")
        }

        // Validate --when value if provided
        if let when = when {
            let validKeywords = Set(["today", "tomorrow", "evening", "anytime", "someday"])
            let isKeyword = validKeywords.contains(when.lowercased())
            let isDate = parseDate(when) != nil
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

        // Pre-validate auth token before any mutations to avoid partial updates
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

        let client = ThingsClientFactory.create()

        // Parse due date if provided
        var dueDate: Date? = nil
        if let dueStr = due {
            dueDate = parseDate(dueStr)
            if dueDate == nil {
                throw ThingsError.invalidState("Invalid date format: \(dueStr). Use YYYY-MM-DD, 'today', or 'tomorrow'.")
            }
        }

        // Update via JXA (name, notes, dueDate, tags)
        let hasJXAUpdates = name != nil || notes != nil || dueDate != nil || !tags.isEmpty
        if hasJXAUpdates {
            try await client.updateTodo(
                id: id,
                name: name,
                notes: notes,
                dueDate: dueDate,
                tags: tags.isEmpty ? nil : tags
            )
        }

        // Handle when and heading via Things URL scheme (activationDate is read-only in JXA)
        if needsURLScheme, let token = prevalidatedToken {
            do {
                try updateViaURLScheme(id: id, when: when, heading: resolvedHeading, token: token)
            } catch {
                if hasJXAUpdates {
                    let jxaFields = [name != nil ? "name" : nil, notes != nil ? "notes" : nil,
                                   dueDate != nil ? "due date" : nil, !tags.isEmpty ? "tags" : nil]
                        .compactMap { $0 }.joined(separator: ", ")
                    throw ThingsError.operationFailed(
                        "Partial update: \(jxaFields) updated, but --when/--heading failed: \(error.localizedDescription)"
                    )
                }
                throw error
            }
        }

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        let urlSchemeNote = needsURLScheme ? " (--when/--heading sent via URL scheme; verify in Things)" : ""
        print(formatter.format(message: "Updated todo: \(id)\(urlSchemeNote)"))
    }

    private func parseDate(_ str: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let lower = str.lowercased()

        if lower == "today" {
            return calendar.startOfDay(for: now)
        }
        if lower == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        }

        // Try ISO date format (YYYY-MM-DD)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        do {
            try process.run()
        } catch {
            throw ThingsError.operationFailed("Failed to launch Things URL scheme handler: \(error.localizedDescription)")
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ThingsError.operationFailed("Failed to update via Things URL scheme (exit code \(process.terminationStatus))")
        }
    }
}
