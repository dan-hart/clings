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

        Local state defaults to ~/.config/clings. Set CLINGS_CONFIG_DIR to an
        alternate directory for separate templates, views, tokens, and undo history.

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

        Get it from Things > Settings > General > Enable Things URLs.
        Required for update --when/--heading, not add --when/--deadline.
        Stored as auth-token in the config directory with mode 0600. Treat it
        as a secret; typing a literal token may save it in your shell history.

        EXAMPLES:
          clings config set-auth-token <token>
          clings doctor --verbose
        """
    )

    @Argument(help: "The auth token from Things 3 (Settings > General > Enable Things URLs)")
    var token: String

    @OptionGroup var output: OutputOptions

    func run() throws {
        try AuthTokenStore.saveToken(token)
        print(renderMessage("Auth token saved securely in the config directory", output: output))
    }
}
