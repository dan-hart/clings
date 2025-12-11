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
        aliases: ["done"]
    )

    @Argument(help: "The ID of the todo to complete")
    var id: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClientFactory.create()
        try await client.completeTodo(id: id)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Completed todo: \(id)"))
    }
}

// MARK: - Cancel Command

struct CancelCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cancel",
        abstract: "Cancel a todo"
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
