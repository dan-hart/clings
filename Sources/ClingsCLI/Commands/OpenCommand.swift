// OpenCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

struct OpenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Explain the disabled Things navigation command",
        discussion: """
        This command is currently disabled and exits with an error because
        URL-based navigation is not enabled. It does not launch or navigate Things.

        LISTS:
          today, inbox, upcoming, anytime, someday, logbook

        EXAMPLES:
          clings open --help            Explain the current limitation
          clings show ABC123            Inspect a todo in the terminal instead

        NOTE:
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
