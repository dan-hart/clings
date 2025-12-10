// MutationCommands.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

// MARK: - Complete Command

struct CompleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Mark a todo as completed",
        aliases: ["done"]
    )

    @Argument(help: "The ID of the todo to complete")
    var id: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClient()
        try await client.completeTodo(id: id)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Completed todo: \(id)"))
    }
}

// MARK: - Cancel Command

struct CancelCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cancel",
        abstract: "Cancel a todo"
    )

    @Argument(help: "The ID of the todo to cancel")
    var id: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClient()
        try await client.cancelTodo(id: id)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Canceled todo: \(id)"))
    }
}

// MARK: - Delete Command

struct DeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a todo (moves to trash)",
        aliases: ["rm"]
    )

    @Argument(help: "The ID of the todo to delete")
    var id: String

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClient()
        try await client.deleteTodo(id: id)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Deleted todo: \(id)"))
    }
}
