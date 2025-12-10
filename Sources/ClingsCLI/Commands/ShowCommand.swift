// ShowCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

struct ShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show details of a todo by ID"
    )

    @Argument(help: "The ID of the todo to show")
    var id: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClient()
        let todo = try await client.fetchTodo(id: id)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(todo: todo))
    }
}
