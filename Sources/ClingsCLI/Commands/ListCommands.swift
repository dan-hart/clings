// ListCommands.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

// MARK: - Shared Options

struct OutputOptions: ParsableArguments {
    @Flag(name: .long, help: "Output as JSON")
    var json = false

    @Flag(name: .long, help: "Suppress color output")
    var noColor = false
}

// MARK: - Base List Command

protocol ListCommand: AsyncParsableCommand {
    var output: OutputOptions { get }
    var listView: ListView { get }
}

extension ListCommand {
    func run() async throws {
        let client = ThingsClient()
        let todos = try await client.fetchList(listView)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(todos: todos))
    }
}

// MARK: - Today Command

struct TodayCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "today",
        abstract: "Show today's todos",
        aliases: ["t"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView { .today }
}

// MARK: - Inbox Command

struct InboxCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "inbox",
        abstract: "Show inbox todos",
        aliases: ["i"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView { .inbox }
}

// MARK: - Upcoming Command

struct UpcomingCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "upcoming",
        abstract: "Show upcoming todos",
        aliases: ["u"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView { .upcoming }
}

// MARK: - Anytime Command

struct AnytimeCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "anytime",
        abstract: "Show anytime todos"
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView { .anytime }
}

// MARK: - Someday Command

struct SomedayCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "someday",
        abstract: "Show someday todos",
        aliases: ["s"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView { .someday }
}

// MARK: - Logbook Command

struct LogbookCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "logbook",
        abstract: "Show completed todos",
        aliases: ["l"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView { .logbook }
}

// MARK: - Projects Command

struct ProjectsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "projects",
        abstract: "List all projects"
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClient()
        let projects = try await client.fetchProjects()

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(projects: projects))
    }
}

// MARK: - Areas Command

struct AreasCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "areas",
        abstract: "List all areas"
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClient()
        let areas = try await client.fetchAreas()

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(areas: areas))
    }
}

// MARK: - Tags Command

struct TagsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tags",
        abstract: "List all tags"
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClient()
        let tags = try await client.fetchTags()

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(tags: tags))
    }
}
