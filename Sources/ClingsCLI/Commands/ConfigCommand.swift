// ConfigCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Configure clings settings",
        discussion: """
        Manage local clings configuration values.

        EXAMPLES:
          clings config set-auth-token <token>

        SEE ALSO:
          update --when, update --heading
        """,
        subcommands: [SetAuthToken.self]
    )
}

struct SetAuthToken: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-auth-token",
        abstract: "Set the Things 3 auth token for URL scheme operations (e.g., --heading)",
        discussion: """
        Save the Things URL auth token locally so URL-scheme features can run
        without prompting for the token each time.

        EXAMPLES:
          clings config set-auth-token <token>
          clings doctor --verbose
        """
    )

    @Argument(help: "The auth token from Things 3 (Settings > General > Enable Things URLs)")
    var token: String

    func run() throws {
        try AuthTokenStore.saveToken(token)
        print("Auth token saved to ~/.config/clings/auth-token")
    }
}
