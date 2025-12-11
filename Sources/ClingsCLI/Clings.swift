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

        QUICK START:
          clings today              Show today's todos
          clings inbox              Show inbox
          clings add "Buy milk"     Add a new todo

        OUTPUT FORMATS:
          --json                    Machine-readable JSON for scripting
          (default)                 Human-readable colored output

        For more information on a specific command, run:
          clings <command> --help
        """,
        version: "0.2.0",
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

            // Bulk operations
            BulkCommand.self,

            // Filter
            FilterCommand.self,

            // Utilities
            OpenCommand.self,
            StatsCommand.self,
            ReviewCommand.self,
            CompletionsCommand.self,
        ],
        defaultSubcommand: TodayCommand.self
    )
}
