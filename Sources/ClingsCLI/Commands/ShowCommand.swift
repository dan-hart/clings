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
          clings today --json | jq -r '.data.items[].id'

        Schema 1 JSON data contains one todo object rather than count/items. --format renders a
        single custom line instead of the detailed view. Showing never modifies
        the todo; use pick show if you do not know its exact ID.

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
        let client = CommandRuntime.makeClient()
        let todo = try await client.fetchTodo(id: id)
        print(renderTodo(todo, output: output))
    }
}
