// FilterCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

/// Command to filter todos using a DSL expression.
struct FilterCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "filter",
        abstract: "Filter todos using a query expression",
        discussion: """
        Filter todos using a SQL-like query language.

        SYNTAX:
          field OPERATOR value [AND|OR condition...]

        OPERATORS:
          =, !=          Equality
          <, >, <=, >=   Comparison (for dates)
          LIKE           Pattern matching (% for wildcard)
          CONTAINS       Substring or tag match
          IS NULL        Check for null
          IS NOT NULL    Check for non-null
          IN             List membership

        FIELDS:
          status         open, completed, canceled
          due            Due date (YYYY-MM-DD or: today, tomorrow)
          tags           Tag list
          project        Project name
          area           Area name
          name           Task title
          notes          Task notes
          created        Creation date

        EXAMPLES:
          clings filter "status = open"
          clings filter "due < today AND status = open"
          clings filter "tags CONTAINS 'work'"
          clings filter "name LIKE '%report%'"
          clings filter "project IS NOT NULL"
        """
    )

    @Argument(help: "Filter expression")
    var expression: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let filter = try FilterParser.parse(expression)
        let client = ThingsClientFactory.create()

        // Fetch all open todos and filter
        var todos: [Todo] = []
        for list in [ListView.today, .inbox, .upcoming, .anytime, .someday] {
            let listTodos = try await client.fetchList(list)
            todos.append(contentsOf: listTodos)
        }

        // Remove duplicates (same todo might appear in multiple lists)
        let uniqueTodos = Array(Set(todos))

        // Apply filter
        let filtered = uniqueTodos.filter { filter.matches($0) }

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(todos: filtered))
    }
}
