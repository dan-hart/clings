// FocusCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation

struct FocusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus",
        abstract: "Show a focused queue of high-attention tasks",
        discussion: """
        Build a short, opinionated working queue from open todos, prioritizing
        overdue work and urgent items first.

        EXAMPLES:
          clings focus
          clings focus --limit 5
          clings focus --format "{status} {name} [{project}]"
          clings focus --json
        """
    )

    @Option(name: .long, help: "Maximum number of tasks to show")
    var limit: Int = 10

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = CommandRuntime.makeClient()
        let plan = FocusPlanner().build(todos: try await fetchOpenTodos(client: client), limit: limit)

        if output.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(plan)
            print(String(data: data, encoding: .utf8) ?? "{}")
            return
        }

        if let _ = output.format {
            print(renderTodos(plan.items.map(\.todo), list: "Focus", output: output))
            return
        }

        if plan.items.isEmpty {
            print("No focus items right now")
            return
        }

        for item in plan.items {
            let reasons = item.reasons.isEmpty ? "" : " [\(item.reasons.joined(separator: ", "))]"
            print("- \(item.todo.name)\(reasons)")
        }
    }
}
