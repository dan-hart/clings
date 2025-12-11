// OpenCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

struct OpenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open a todo or list in Things 3",
        discussion: """
        Opens Things 3 and navigates to a specific todo or list.
        Useful for quickly jumping to items from the command line.

        LISTS:
          today, inbox, upcoming, anytime, someday, logbook

        EXAMPLES:
          clings open today             Open Today list in Things
          clings open inbox             Open Inbox in Things
          clings open ABC123            Open a specific todo by ID

        NOTE:
          Things 3 must be installed. This command uses the Things
          URL scheme to navigate.

        SEE ALSO:
          show, today, inbox
        """
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
