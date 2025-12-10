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
        aliases: ["find", "f"]
    )

    @Argument(help: "The search query")
    var query: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClient()
        let todos = try await client.search(query: query)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(todos: todos))
    }
}
