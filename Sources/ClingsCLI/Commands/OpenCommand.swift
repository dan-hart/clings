// OpenCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

struct OpenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open a todo or list in Things 3"
    )

    @Argument(help: "The ID of the todo to open, or a list name (today, inbox, etc.)")
    var target: String

    func run() async throws {
        let client = ThingsClient()

        // Check if it's a list name
        if let listView = ListView(rawValue: target.lowercased()) {
            try client.openInThings(list: listView)
        } else {
            // Assume it's a todo ID
            try client.openInThings(id: target)
        }
    }
}
