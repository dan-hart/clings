// PickCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

struct PickCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pick",
        abstract: "Interactively pick a todo for a follow-up action",
        discussion: """
        Search visible todos, choose one interactively, and then run a follow-up
        action without manually copying IDs.

        EXAMPLES:
          clings pick show release
          clings pick complete docs
          clings pick cancel follow-up
          clings pick delete cleanup
        """,
        subcommands: [
            PickShowCommand.self,
            PickCompleteCommand.self,
            PickCancelCommand.self,
            PickDeleteCommand.self,
        ]
    )
}

struct PickShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Pick a todo and show its details",
        discussion: """
        Present matching todos, let you choose one, and render the selected todo.

        EXAMPLES:
          clings pick show
          clings pick show release
          clings pick show docs --json
        """
    )

    @Argument(help: "Optional search query")
    var query: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = CommandRuntime.makeClient()
        let candidates = try await pickCandidates(client: client, query: query, includeLogbook: true, onlyOpen: false)
        guard let todo = promptForTodoSelection(todos: candidates, prompt: "Show which todo?") else {
            throw ValidationError("No todo selected")
        }
        print(renderTodo(todo, output: output))
    }
}

struct PickCompleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Pick a todo and complete it",
        discussion: """
        Choose an open todo interactively, then mark it complete.

        EXAMPLES:
          clings pick complete
          clings pick complete release
        """
    )

    @Argument(help: "Optional search query")
    var query: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = CommandRuntime.makeClient()
        let candidates = try await pickCandidates(client: client, query: query, includeLogbook: false, onlyOpen: true)
        guard let todo = promptForTodoSelection(todos: candidates, prompt: "Complete which todo?") else {
            throw ValidationError("No todo selected")
        }
        try await client.completeTodo(id: todo.id)
        try UndoStore.record(UndoEntry(operation: .complete, todoID: todo.id, snapshot: TodoSnapshot(todo: todo)))
        print(renderMessage("Completed: \(todo.name)", output: output))
    }
}

struct PickCancelCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cancel",
        abstract: "Pick a todo and cancel it",
        discussion: """
        Choose an open todo interactively, then cancel it.

        EXAMPLES:
          clings pick cancel
          clings pick cancel follow-up
        """
    )

    @Argument(help: "Optional search query")
    var query: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = CommandRuntime.makeClient()
        let candidates = try await pickCandidates(client: client, query: query, includeLogbook: false, onlyOpen: true)
        guard let todo = promptForTodoSelection(todos: candidates, prompt: "Cancel which todo?") else {
            throw ValidationError("No todo selected")
        }
        try await client.cancelTodo(id: todo.id)
        try UndoStore.record(UndoEntry(operation: .cancel, todoID: todo.id, snapshot: TodoSnapshot(todo: todo)))
        print(renderMessage("Canceled: \(todo.name)", output: output))
    }
}

struct PickDeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Pick a todo and delete it",
        discussion: """
        Choose an open todo interactively, then move it to the trash.

        EXAMPLES:
          clings pick delete
          clings pick delete cleanup
        """
    )

    @Argument(help: "Optional search query")
    var query: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = CommandRuntime.makeClient()
        let candidates = try await pickCandidates(client: client, query: query, includeLogbook: false, onlyOpen: true)
        guard let todo = promptForTodoSelection(todos: candidates, prompt: "Delete which todo?") else {
            throw ValidationError("No todo selected")
        }
        try await client.deleteTodo(id: todo.id)
        try UndoStore.record(UndoEntry(operation: .delete, todoID: todo.id, snapshot: TodoSnapshot(todo: todo)))
        print(renderMessage("Deleted: \(todo.name)", output: output))
    }
}

private func pickCandidates(
    client: any ThingsClientProtocol,
    query: String?,
    includeLogbook: Bool,
    onlyOpen: Bool
) async throws -> [Todo] {
    let todos: [Todo]
    if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        todos = try await client.search(query: query)
    } else {
        todos = try await fetchVisibleTodos(client: client, includeLogbook: includeLogbook)
    }

    let filtered = onlyOpen ? todos.filter(\.isOpen) : todos
    guard !filtered.isEmpty else {
        throw ValidationError("No todos available for selection")
    }
    return filtered
}
