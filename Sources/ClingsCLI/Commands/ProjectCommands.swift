// ProjectCommands.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ArgumentParser
import ClingsCore
import Foundation

// MARK: - Project Command (Parent)

struct ProjectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "project",
        abstract: "Manage projects",
        discussion: """
        List and create projects in Things 3.

        Projects are containers for related todos working toward a specific goal.

        EXAMPLES:
          clings project                    List all projects (same as 'clings projects')
          clings project list               Same as above
          clings project add "Q1 Planning"  Create a new project
          clings project add "Sprint" --area "Work" --deadline 2025-01-31

        SEE ALSO:
          projects, add --project, areas
        """,
        subcommands: [
            ProjectListCommand.self,
            ProjectAddCommand.self,
        ],
        defaultSubcommand: ProjectListCommand.self
    )
}

// MARK: - Project List Command

struct ProjectListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all projects",
        aliases: ["ls"]
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClientFactory.create()
        let projects = try await client.fetchProjects()

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(projects: projects))
    }
}

// MARK: - Project Add Command

struct ProjectAddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Create a new project",
        discussion: """
        Creates a new project in Things 3 using the URL scheme.

        EXAMPLES:
          clings project add "Q1 Planning"
          clings project add "Feature X" --notes "Implementation of feature X"
          clings project add "Sprint 12" --area "Work" --when today
          clings project add "Vacation" --deadline 2025-06-01 --tags "personal,planning"
        """
    )

    @Argument(help: "Title of the project")
    var title: String

    @Option(name: .long, help: "Project notes/description")
    var notes: String?

    @Option(name: .long, help: "Area to assign project to")
    var area: String?

    @Option(name: .long, help: "When to start (today, tomorrow, YYYY-MM-DD)")
    var when: String?

    @Option(name: .long, help: "Deadline date (YYYY-MM-DD)")
    var deadline: String?

    @Option(name: .long, help: "Tags (comma-separated)")
    var tags: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw ThingsError.invalidState("Project title cannot be empty")
        }

        // Build URL scheme for project creation
        // things:///add-project?title=X&notes=Y&area=Z&when=W&deadline=D&tags=T
        var components = URLComponents()
        components.scheme = "things"
        components.host = ""
        components.path = "/add-project"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "title", value: trimmedTitle),
            URLQueryItem(name: "show-quick-entry", value: "false"),
        ]

        if let notes = notes {
            queryItems.append(URLQueryItem(name: "notes", value: notes))
        }
        if let area = area {
            queryItems.append(URLQueryItem(name: "area", value: area))
        }
        if let when = when {
            // Parse relative dates
            let whenValue = parseWhenDate(when)
            queryItems.append(URLQueryItem(name: "when", value: whenValue))
        }
        if let deadline = deadline {
            queryItems.append(URLQueryItem(name: "deadline", value: deadline))
        }
        if let tags = tags {
            queryItems.append(URLQueryItem(name: "tags", value: tags))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw ThingsError.operationFailed("Failed to build Things URL")
        }

        NSWorkspace.shared.open(url)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Created project: \(trimmedTitle)"))
    }

    private func parseWhenDate(_ str: String) -> String {
        let lower = str.lowercased()
        let calendar = Calendar.current
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        if lower == "today" {
            return formatter.string(from: calendar.startOfDay(for: now))
        }
        if lower == "tomorrow" {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                return formatter.string(from: tomorrow)
            }
        }
        // Return as-is (assume YYYY-MM-DD format)
        return str
    }
}
