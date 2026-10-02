// Clings.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

/// The main clings command.
@main
struct Clings: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clings",
        abstract: "A powerful CLI for Things 3",
        discussion: """
        clings provides fast, scriptable access to Things 3 from the command line.

        Run clings with no arguments to show Today. Reads use the local Things
        database; writes use Things automation. Things 3 for Mac is required.

        USAGE:
          clings <subcommand> [options]

        EXAMPLES:
          clings today              Show today's todos
          clings inbox              Show inbox
          clings add "Draft changelog entry tomorrow #docs"
          clings views run docs-today
          clings doctor --verbose
          clings filter "due < today" --json
          clings bulk complete --list inbox --where "tags CONTAINS 'done'" --dry-run

        OUTPUT FORMATS:
          --json                    Machine-readable JSON for scripting
          (default)                 Human-readable colored output

        For more information on a specific command, run:
          clings <command> --help
          clings <command> <subcommand> --help

        GUIDES:
          https://github.com/dan-hart/clings#readme
          https://github.com/dan-hart/clings/tree/main/docs/cli

        Put output options after the command. --json takes precedence over
        --format and emits schema 1 envelopes with payloads under data.
        Failed commands return nonzero exits and structured JSON errors.
        Interactive pick rejects --json; help/version/completions remain text.
        """,
        version: "0.4.0",
        subcommands: [
            // List views
            TodayCommand.self,
            InboxCommand.self,
            UpcomingCommand.self,
            AnytimeCommand.self,
            SomedayCommand.self,
            LogbookCommand.self,

            // List meta
            ProjectsCommand.self,
            ProjectCommand.self,
            AreasCommand.self,
            TagsCommand.self,

            // Todo operations
            ShowCommand.self,
            AddCommand.self,
            CompleteCommand.self,
            CancelCommand.self,
            DeleteCommand.self,
            UpdateCommand.self,
            SearchCommand.self,
            ViewsCommand.self,
            TemplateCommand.self,
            UndoCommand.self,
            FocusCommand.self,
            PickCommand.self,
            DoctorCommand.self,

            // Bulk operations
            BulkCommand.self,

            // Filter
            FilterCommand.self,

            // Utilities
            OpenCommand.self,
            StatsCommand.self,
            ReviewCommand.self,
            CompletionsCommand.self,
            ConfigCommand.self,
        ],
        defaultSubcommand: TodayCommand.self
    )
}
