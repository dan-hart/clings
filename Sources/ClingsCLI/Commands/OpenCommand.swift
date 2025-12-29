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
        This command is currently disabled because URL schemes are not allowed.

        LISTS:
          today, inbox, upcoming, anytime, someday, logbook

        EXAMPLES:
          clings open today             Open Today list in Things
          clings open inbox             Open Inbox in Things
          clings open ABC123            Open a specific todo by ID

        NOTE:
          URL schemes are disabled, so this command is a no-op.
          Open Things 3 manually instead.

        SEE ALSO:
          show, today, inbox
        """
    )

    @Argument(help: "The ID of the todo to open, or a list name (today, inbox, etc.)")
    var target: String

    func run() async throws {
        _ = target
        throw ThingsError.invalidState("Open command is disabled: URL schemes are not allowed.")
    }
}
