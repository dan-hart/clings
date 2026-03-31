// CommandSupport.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ClingsCore
import Foundation

func makeFormatter(output: OutputOptions) -> OutputFormatter {
    output.json
        ? JSONOutputFormatter()
        : TextOutputFormatter(useColors: !output.noColor)
}

func renderTodos(_ todos: [Todo], list: String? = nil, output: OutputOptions) -> String {
    if output.json {
        let formatter = JSONOutputFormatter()
        return list.map { formatter.format(todos: todos, list: $0) } ?? formatter.format(todos: todos)
    }

    if let template = output.format {
        guard !todos.isEmpty else {
            return TextOutputFormatter(useColors: !output.noColor).format(todos: [])
        }
        let formatter = TodoLineFormatter(template: template)
        return todos.map { formatter.format(todo: $0) }.joined(separator: "\n")
    }

    let formatter = TextOutputFormatter(useColors: !output.noColor)
    return list.map { formatter.format(todos: todos, list: $0) } ?? formatter.format(todos: todos)
}

func renderTodo(_ todo: Todo, output: OutputOptions) -> String {
    if output.json {
        return JSONOutputFormatter().format(todo: todo)
    }
    if let template = output.format {
        return TodoLineFormatter(template: template).format(todo: todo)
    }
    return TextOutputFormatter(useColors: !output.noColor).format(todo: todo)
}

func renderMessage(_ message: String, output: OutputOptions) -> String {
    makeFormatter(output: output).format(message: message)
}

func fetchOpenTodos(client: any ThingsClientProtocol) async throws -> [Todo] {
    let lists: [ListView] = [.today, .inbox, .upcoming, .anytime, .someday]
    var todos: [Todo] = []
    for list in lists {
        todos.append(contentsOf: try await client.fetchList(list))
    }
    return uniqueTodos(todos)
}

func fetchVisibleTodos(client: any ThingsClientProtocol, includeLogbook: Bool = false) async throws -> [Todo] {
    var todos = try await fetchOpenTodos(client: client)
    if includeLogbook {
        todos.append(contentsOf: try await client.fetchList(.logbook))
    }
    return uniqueTodos(todos)
}

func uniqueTodos(_ todos: [Todo]) -> [Todo] {
    var seen: Set<String> = []
    var unique: [Todo] = []
    for todo in todos where !seen.contains(todo.id) {
        seen.insert(todo.id)
        unique.append(todo)
    }
    return unique
}

func parseFlexibleDate(_ expression: String?) -> Date? {
    guard let expression else { return nil }
    return NaturalLanguageDateParser().parse(expression)
}

func promptForTodoSelection(
    todos: [Todo],
    prompt: String,
    inputReader: () -> String? = { CommandRuntime.inputReader() }
) -> Todo? {
    guard !todos.isEmpty else {
        return nil
    }

    print(prompt)
    for (index, todo) in todos.enumerated() {
        let due = todo.dueDate.map {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: $0)
        } ?? "no due date"
        print("  \(index + 1). \(todo.name) [\(todo.id)] (\(due))")
    }
    print("Enter a number or todo ID:", terminator: " ")

    guard let rawSelection = inputReader()?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawSelection.isEmpty else {
        return nil
    }

    if let index = Int(rawSelection), todos.indices.contains(index - 1) {
        return todos[index - 1]
    }

    return todos.first { $0.id == rawSelection }
}
