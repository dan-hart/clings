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
        discussion: """
        Perform operations on multiple todos at once using filters.

        All bulk commands support:
        - --where EXPR    Filter expression to select todos
        - --dry-run       Preview changes without applying
        - -y/--yes        Skip confirmation prompt
        - --list LIST     List to operate on (default: today)

        EXAMPLES:
          clings bulk complete --where "tags CONTAINS 'done'"
          clings bulk cancel --list inbox --dry-run
          clings bulk move --to "Archive" --where "status = open"

        SEE ALSO:
          filter, complete, cancel
        """,
        subcommands: [
            BulkCompleteCommand.self,
            BulkCancelCommand.self,
            BulkTagCommand.self,
            BulkMoveCommand.self,
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
        abstract: "Mark multiple todos as completed",
        discussion: """
        Marks multiple todos as completed based on filter criteria.

        EXAMPLES:
          clings bulk complete --list today
          clings bulk complete --where "tags CONTAINS 'quick'"
          clings bulk complete --where "due < today" --dry-run

        SEE ALSO:
          complete, bulk cancel
        """
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
        abstract: "Cancel multiple todos",
        discussion: """
        Cancels multiple todos based on filter criteria.

        EXAMPLES:
          clings bulk cancel --list inbox
          clings bulk cancel --where "status = open AND project IS NULL"
          clings bulk cancel --dry-run

        SEE ALSO:
          cancel, bulk complete
        """
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
        abstract: "Add tags to multiple todos",
        discussion: """
        Adds tags to multiple todos based on filter criteria.

        NOTE: This operation has limited support due to Things 3 API
        constraints. Some tags may not be added via automation.

        EXAMPLES:
          clings bulk tag "urgent,review" --list today
          clings bulk tag "done" --where "status = completed"
          clings bulk tag "important" --dry-run

        SEE ALSO:
          tags, add --tags
        """
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

        for todo in todos {
            let existing = todo.tags.map { $0.name }
            var merged = existing
            for tag in tagList where !merged.contains(tag) {
                merged.append(tag)
            }
            try await client.updateTodo(id: todo.id, name: nil, notes: nil, dueDate: nil, tags: merged)
        }

        print(formatter.format(message: "Updated \(todos.count) todo(s)"))
    }
}

// MARK: - Bulk Move Command

struct BulkMoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "move",
        abstract: "Move multiple todos to a project",
        discussion: """
        Moves multiple todos to a project based on filter criteria.

        EXAMPLES:
          clings bulk move --to "Work Project" --list inbox
          clings bulk move --to "Archive" --where "tags CONTAINS 'done'"
          clings bulk move --to "Personal" --dry-run

        SEE ALSO:
          projects, add --project
        """
    )

    @Option(name: .long, help: "Target project name")
    var to: String

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

        print("Will move \(todos.count) todo(s) to project '\(to)':")
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

        var moved = 0
        var failed = 0
        for todo in todos {
            do {
                try await client.moveTodo(id: todo.id, toProject: to)
                moved += 1
            } catch {
                failed += 1
            }
        }

        print(formatter.format(message: "Moved: \(moved), Failed: \(failed)"))
    }
}

// MARK: - Filter Helper

/// Filter todos using the full DSL parser.
func filterTodos(_ todos: [Todo], with clause: String) throws -> [Todo] {
    let filter = try FilterParser.parse(clause)
    return todos.filter { filter.matches($0) }
}
