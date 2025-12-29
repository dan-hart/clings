// ProjectCommands.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

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
        Creates a new project in Things 3.

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

        let client = ThingsClientFactory.create()
        let parsedWhen = try when.map { try parseWhenDate($0) }
        let parsedDeadline = try deadline.map { try parseWhenDate($0) }
        let tagList = tags?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? []

        _ = try await client.createProject(
            name: trimmedTitle,
            notes: notes,
            when: parsedWhen,
            deadline: parsedDeadline,
            tags: tagList,
            area: area
        )

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Created project: \(trimmedTitle)"))
    }

    private func parseWhenDate(_ str: String) throws -> Date {
        let lower = str.lowercased()
        let calendar = Calendar.current
        let now = Date()

        if lower == "today" {
            return calendar.startOfDay(for: now)
        }
        if lower == "tomorrow" {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                return tomorrow
            }
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let date = formatter.date(from: str) {
            return date
        }
        throw ThingsError.invalidState("Invalid date format: \(str). Use YYYY-MM-DD, 'today', or 'tomorrow'.")
    }
}
