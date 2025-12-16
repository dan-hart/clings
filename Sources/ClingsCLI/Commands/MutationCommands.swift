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

    @Option(name: .long, parsing: .upToNextOption, help: "New tags (replaces existing)")
    var tags: [String] = []

    @OptionGroup var output: OutputOptions

    func run() async throws {
        // Check if any update options provided
        guard name != nil || notes != nil || due != nil || !tags.isEmpty else {
            throw ThingsError.invalidState("No update options provided. Use --name, --notes, --due, or --tags.")
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

        // Update the todo
        try await client.updateTodo(
            id: id,
            name: name,
            notes: notes,
            dueDate: dueDate,
            tags: tags.isEmpty ? nil : tags
        )

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Updated todo: \(id)"))
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
}
