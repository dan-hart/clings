// ListCommands.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

// MARK: - Shared Options

struct OutputOptions: ParsableArguments {
    @Flag(name: .long, help: "Output a schema 1 JSON response with payload under data; takes precedence over --format")
    var json = false

    @Flag(name: .long, help: "Suppress color output")
    var noColor = false

    @Option(name: .long, help: "Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers")
    var format: String?
}

// MARK: - Base List Command

protocol ListCommand: AsyncParsableCommand {
    var output: OutputOptions { get }
    var listView: ListView { get }
}

extension ListCommand {
    func run() async throws {
        let client = CommandRuntime.makeClient()
        let todos = try await client.fetchList(listView)
        print(renderTodos(todos, list: listView.displayName, output: output))
    }
}

// MARK: - Today Command

struct TodayCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "today",
        abstract: "Show today's todos",
        discussion: """
        Displays all todos scheduled for today, including those with today's
        deadline or "when" date set to today.

        This is the default command: clings and clings today are equivalent.
        Overdue deadlines and previously activated open work may also appear.
        Repeating templates and todos in trashed projects are excluded.

        EXAMPLES:
          clings today                  Show today's todos
          clings t                      Alias for 'today'
          clings today --json           Output as JSON
          clings today --no-color       Disable colored output
          clings today --format "{id} {name} {due}"
          clings today --json | jq -r '.data.items[] | [.id, .name] | @tsv'

        SEE ALSO:
          inbox, upcoming, anytime, someday
        """,
        aliases: ["t"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView {
        .today
    }
}

// MARK: - Inbox Command

struct InboxCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "inbox",
        abstract: "Show inbox todos",
        discussion: """
        Displays todos in the Inbox - items not yet organized into
        projects or scheduled for a specific date.

        The Inbox is the default capture location in Things. During
        weekly reviews, process these items by scheduling them or
        moving them to projects.

        This command only reads the list. To move selected items into a project,
        preview clings bulk move --list inbox --to "Documentation" --dry-run.

        EXAMPLES:
          clings inbox                  Show inbox items
          clings i                      Alias for 'inbox'
          clings inbox --json           Output as JSON

        SEE ALSO:
          today, review
        """,
        aliases: ["i"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView {
        .inbox
    }
}

// MARK: - Upcoming Command

struct UpcomingCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "upcoming",
        abstract: "Show upcoming todos",
        discussion: """
        Displays todos scheduled for future dates. These are items with
        a "when" date set to tomorrow or later.

        A deadline and a scheduled start are different concepts. For a deadline
        queue across open lists, use clings filter "due IS NOT NULL" instead.

        EXAMPLES:
          clings upcoming               Show upcoming todos
          clings u                      Alias for 'upcoming'
          clings upcoming --json        Output as JSON

        SEE ALSO:
          today, anytime, someday
        """,
        aliases: ["u"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView {
        .upcoming
    }
}

// MARK: - Anytime Command

struct AnytimeCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "anytime",
        abstract: "Show anytime todos",
        discussion: """
        Displays todos with no scheduled date - tasks you can do whenever
        you have time. These appear in the "Anytime" list in Things.

        Someday items are kept separate. Use --format "{name} [{project}] {tags}"
        to scan available work by project and context.

        EXAMPLES:
          clings anytime                Show anytime todos
          clings anytime --json         Output as JSON

        SEE ALSO:
          today, upcoming, someday
        """
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView {
        .anytime
    }
}

// MARK: - Someday Command

struct SomedayCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "someday",
        abstract: "Show someday todos",
        discussion: """
        Displays todos in the "Someday" list - ideas and tasks you might
        want to do eventually but aren't committed to yet.

        Review these periodically during your weekly review to decide
        if any should be moved to active lists.

        A Someday task may still have a deadline. --json preserves that deadline
        for reporting; --format "{name} {due}" shows it beside the title.

        EXAMPLES:
          clings someday                Show someday items
          clings s                      Alias for 'someday'
          clings someday --json         Output as JSON

        SEE ALSO:
          anytime, review
        """,
        aliases: ["s"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView {
        .someday
    }
}

// MARK: - Logbook Command

struct LogbookCommand: ListCommand {
    static let configuration = CommandConfiguration(
        commandName: "logbook",
        abstract: "Show completed todos",
        discussion: """
        Displays recently completed todos from the Logbook.

        The Logbook contains your completed tasks, providing a
        record of accomplishments. Useful for:
        - Weekly reviews
        - Time tracking
        - Generating reports

        The list can also include canceled work. Filter the JSON status when
        you need completed items only:
          clings logbook --json | jq '.data.items[] | select(.status == "completed")'

        EXAMPLES:
          clings logbook                Show completed todos
          clings l                      Alias for 'logbook'
          clings logbook --json         Output as JSON

        SEE ALSO:
          complete, stats
        """,
        aliases: ["l"]
    )

    @OptionGroup var output: OutputOptions

    var listView: ListView {
        .logbook
    }
}

// MARK: - Projects Command

struct ProjectsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "projects",
        abstract: "List all projects",
        discussion: """
        Displays visible projects from Things 3, excluding trashed projects
        and repeating project templates in the SQLite read path.

        Projects contain related todos working toward a specific goal.
        Use this to get an overview of all your active projects.

        EXAMPLES:
          clings projects               List all projects
          clings projects --json        Output as JSON

        SEE ALSO:
          areas, add --project
        """
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = CommandRuntime.makeClient()
        let projects = try await client.fetchProjects()

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(CLIResponse.render(formatter.format(projects: projects), output: output))
    }
}

// MARK: - Areas Command

struct AreasCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "areas",
        abstract: "List all areas",
        discussion: """
        Displays all areas from Things 3.

        Areas represent different spheres of responsibility in your life
        (e.g., "Work", "Personal", "Health"). Projects and todos can be
        assigned to areas for organization.

        Use area names with add --area or filter "area = 'Writing'".
        This command lists areas; it does not create or rename them.

        EXAMPLES:
          clings areas                  List all areas
          clings areas --json           Output as JSON

        SEE ALSO:
          projects, add --area
        """
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = CommandRuntime.makeClient()
        let areas = try await client.fetchAreas()

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(CLIResponse.render(formatter.format(areas: areas), output: output))
    }
}

// Note: TagsCommand moved to TagCommands.swift to support subcommands (add, delete, rename)
