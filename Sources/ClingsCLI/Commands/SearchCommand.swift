// SearchCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search todos by text",
        discussion: """
        Searches todos by matching text in the title and notes.
        The search is case-insensitive.

        For more complex filtering (by status, tags, dates), use
        the 'filter' command instead.

        Search can include completed/canceled todos. Repeating templates and
        trashed-project descendants are excluded by SQLite reads. Use exact IDs
        from --json for follow-up actions; titles are not unique identifiers.

        EXAMPLES:
          clings search "meeting"       Find todos containing "meeting"
          clings find "project report"  Alias for 'search'
          clings f status               Short alias
          clings search urgent --json   Output results as JSON

        SEE ALSO:
          filter, today, show
        """,
        aliases: ["find", "f"]
    )

    @Argument(help: "The search query")
    var query: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = CommandRuntime.makeClient()
        let todos = try await client.search(query: query)
        print(renderTodos(todos, list: "Search", output: output))
    }
}
