// ShowCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

struct ShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show details of a todo by ID",
        discussion: """
        Displays detailed information about a specific todo, including:
        - Title and notes
        - Status (open, completed, canceled)
        - Due date and scheduling
        - Project and area assignment
        - Tags
        - Checklist items

        To find a todo's ID, use --json output on any list command:
          clings today --json | jq '.items[].id'

        EXAMPLES:
          clings show ABC123            Show todo details
          clings show ABC123 --json     Output as JSON

        SEE ALSO:
          today, search, filter
        """
    )

    @Argument(help: "The ID of the todo to show")
    var id: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClientFactory.create()
        let todo = try await client.fetchTodo(id: id)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(todo: todo))
    }
}
