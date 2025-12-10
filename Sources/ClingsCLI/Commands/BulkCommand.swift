// BulkCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

struct BulkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bulk",
        abstract: "Bulk operations on multiple todos",
        subcommands: [
            BulkCompleteCommand.self,
            BulkCancelCommand.self,
            BulkTagCommand.self,
        ]
    )
}

// MARK: - Shared Bulk Options

struct BulkOptions: ParsableArguments {
    @Option(name: .long, help: "Filter expression (e.g., \"tags CONTAINS 'work'\")")
    var `where`: String?

    @Flag(name: .long, help: "Show what would be changed without making changes")
    var dryRun = false

    @Flag(name: [.customShort("y"), .long], help: "Skip confirmation prompt")
    var yes = false

    @OptionGroup var output: OutputOptions
}

// MARK: - Bulk Complete Command

struct BulkCompleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Mark multiple todos as completed"
    )

    @OptionGroup var bulkOptions: BulkOptions

    @Option(name: .long, help: "List to operate on (today, inbox, etc.)")
    var list: String = "today"

    func run() async throws {
        let client = ThingsClientFactory.create()

        // Get list view
        guard let listView = ListView(rawValue: list.lowercased()) else {
            throw ThingsError.invalidState("Unknown list: \(list)")
        }

        // Fetch todos
        var todos = try await client.fetchList(listView)

        // Apply filter if provided
        if let whereClause = bulkOptions.where {
            todos = try filterTodos(todos, with: whereClause)
        }

        let formatter: OutputFormatter = bulkOptions.output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !bulkOptions.output.noColor)

        if todos.isEmpty {
            print(formatter.format(message: "No todos match the criteria"))
            return
        }

        // Show what will be affected
        print("Will complete \(todos.count) todo(s):")
        for todo in todos {
            print("  - \(todo.name)")
        }

        if bulkOptions.dryRun {
            print(formatter.format(message: "[DRY RUN] No changes made"))
            return
        }

        // Confirm unless --yes
        if !bulkOptions.yes {
            print("\nProceed? (y/N): ", terminator: "")
            guard let response = readLine(), response.lowercased() == "y" else {
                print(formatter.format(message: "Aborted"))
                return
            }
        }

        // Execute
        var completed = 0
        var failed = 0
        for todo in todos {
            do {
                try await client.completeTodo(id: todo.id)
                completed += 1
            } catch {
                failed += 1
            }
        }

        print(formatter.format(message: "Completed: \(completed), Failed: \(failed)"))
    }
}

// MARK: - Bulk Cancel Command

struct BulkCancelCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cancel",
        abstract: "Cancel multiple todos"
    )

    @OptionGroup var bulkOptions: BulkOptions

    @Option(name: .long, help: "List to operate on (today, inbox, etc.)")
    var list: String = "today"

    func run() async throws {
        let client = ThingsClientFactory.create()

        guard let listView = ListView(rawValue: list.lowercased()) else {
            throw ThingsError.invalidState("Unknown list: \(list)")
        }

        var todos = try await client.fetchList(listView)

        if let whereClause = bulkOptions.where {
            todos = try filterTodos(todos, with: whereClause)
        }

        let formatter: OutputFormatter = bulkOptions.output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !bulkOptions.output.noColor)

        if todos.isEmpty {
            print(formatter.format(message: "No todos match the criteria"))
            return
        }

        print("Will cancel \(todos.count) todo(s):")
        for todo in todos {
            print("  - \(todo.name)")
        }

        if bulkOptions.dryRun {
            print(formatter.format(message: "[DRY RUN] No changes made"))
            return
        }

        if !bulkOptions.yes {
            print("\nProceed? (y/N): ", terminator: "")
            guard let response = readLine(), response.lowercased() == "y" else {
                print(formatter.format(message: "Aborted"))
                return
            }
        }

        var canceled = 0
        var failed = 0
        for todo in todos {
            do {
                try await client.cancelTodo(id: todo.id)
                canceled += 1
            } catch {
                failed += 1
            }
        }

        print(formatter.format(message: "Canceled: \(canceled), Failed: \(failed)"))
    }
}

// MARK: - Bulk Tag Command

struct BulkTagCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tag",
        abstract: "Add tags to multiple todos"
    )

    @Argument(help: "Tags to add (comma-separated)")
    var tags: String

    @OptionGroup var bulkOptions: BulkOptions

    @Option(name: .long, help: "List to operate on (today, inbox, etc.)")
    var list: String = "today"

    func run() async throws {
        let client = ThingsClientFactory.create()

        guard let listView = ListView(rawValue: list.lowercased()) else {
            throw ThingsError.invalidState("Unknown list: \(list)")
        }

        var todos = try await client.fetchList(listView)

        if let whereClause = bulkOptions.where {
            todos = try filterTodos(todos, with: whereClause)
        }

        let formatter: OutputFormatter = bulkOptions.output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !bulkOptions.output.noColor)

        if todos.isEmpty {
            print(formatter.format(message: "No todos match the criteria"))
            return
        }

        let tagList = tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        print("Will add tags [\(tagList.joined(separator: ", "))] to \(todos.count) todo(s):")
        for todo in todos {
            print("  - \(todo.name)")
        }

        if bulkOptions.dryRun {
            print(formatter.format(message: "[DRY RUN] No changes made"))
            return
        }

        if !bulkOptions.yes {
            print("\nProceed? (y/N): ", terminator: "")
            guard let response = readLine(), response.lowercased() == "y" else {
                print(formatter.format(message: "Aborted"))
                return
            }
        }

        // Note: Things 3 JXA doesn't easily support adding tags
        // For now, we'll use URL scheme which is limited
        print(formatter.format(message: "Bulk tag operations require Things URL scheme (limited support)"))
    }
}

// MARK: - Filter Helper

/// Simple filter evaluator for --where clauses.
func filterTodos(_ todos: [Todo], with clause: String) throws -> [Todo] {
    // Parse simple expressions like:
    // - "tags CONTAINS 'work'"
    // - "name LIKE '%report%'"
    // - "status = 'open'"

    let clause = clause.trimmingCharacters(in: .whitespaces)

    // Handle "tags CONTAINS 'value'"
    if let match = clause.range(of: #"tags\s+CONTAINS\s+'([^']+)'"#, options: .regularExpression) {
        let tagName = String(clause[match]).replacingOccurrences(of: #"tags\s+CONTAINS\s+'"#, with: "", options: .regularExpression).dropLast()
        return todos.filter { todo in
            todo.tags.contains { $0.name.lowercased() == tagName.lowercased() }
        }
    }

    // Handle "name LIKE '%value%'"
    if let match = clause.range(of: #"name\s+LIKE\s+'%([^%]+)%'"#, options: .regularExpression) {
        let pattern = String(clause[match])
            .replacingOccurrences(of: #"name\s+LIKE\s+'%"#, with: "", options: .regularExpression)
            .dropLast(2)
        return todos.filter { $0.name.lowercased().contains(pattern.lowercased()) }
    }

    // Handle "project = 'value'" or "project IS NOT NULL"
    if clause.lowercased().contains("project is not null") {
        return todos.filter { $0.project != nil }
    }
    if clause.lowercased().contains("project is null") {
        return todos.filter { $0.project == nil }
    }

    // Handle "due < today" or "due IS NOT NULL"
    if clause.lowercased().contains("due is not null") || clause.lowercased().contains("deadline is not null") {
        return todos.filter { $0.dueDate != nil }
    }
    if clause.lowercased().contains("due < today") || clause.lowercased().contains("deadline < today") {
        let today = Calendar.current.startOfDay(for: Date())
        return todos.filter { todo in
            guard let due = todo.dueDate else { return false }
            return due < today
        }
    }

    throw ThingsError.invalidState("Unsupported filter: \(clause)")
}
