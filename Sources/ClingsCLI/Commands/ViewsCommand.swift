// ViewsCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation

struct ViewsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "views",
        abstract: "Manage saved filter views",
        discussion: """
        Save named filter expressions so you can reuse them without retyping DSL.

        EXAMPLES:
          clings views save docs "tags CONTAINS 'docs'" --note "Documentation queue"
          clings views list
          clings views run docs --json
          clings views delete docs
        """,
        subcommands: [
            ViewsListCommand.self,
            ViewsSaveCommand.self,
            ViewsRunCommand.self,
            ViewsDeleteCommand.self,
        ],
        defaultSubcommand: ViewsListCommand.self
    )
}

struct ViewsListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List saved views",
        discussion: """
        Show every saved view name, the filter expression it runs, and any note you
        stored alongside it.

        EXAMPLES:
          clings views list
          clings views ls --json
        """,
        aliases: ["ls"]
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        let views = try SavedViewStore.list()
        if output.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(views)
            print(String(data: data, encoding: .utf8) ?? "[]")
            return
        }

        if views.isEmpty {
            print("No saved views")
            return
        }

        for view in views {
            if let note = view.note, !note.isEmpty {
                print("\(view.name): \(view.expression)  # \(note)")
            } else {
                print("\(view.name): \(view.expression)")
            }
        }
    }
}

struct ViewsSaveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "save",
        abstract: "Save a named filter view",
        discussion: """
        Store a reusable filter expression under a short name.

        EXAMPLES:
          clings views save docs-today "tags CONTAINS 'docs' AND due <= today"
          clings views save docs "tags CONTAINS 'docs'" --note "Documentation queue"
        """
    )

    @Argument(help: "View name")
    var name: String

    @Argument(help: "Filter expression")
    var expression: String

    @Option(name: .long, help: "Optional description for this view")
    var note: String?

    func run() throws {
        try SavedViewStore.save(SavedView(name: name, expression: expression, note: note))
        print("Saved view: \(name)")
    }
}

struct ViewsRunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a saved filter view",
        discussion: """
        Load a saved view by name, evaluate its filter expression, and render the
        matching open todos.

        EXAMPLES:
          clings views run docs-today
          clings views run docs --json
          clings views run docs --format "{status} {name} [{project}]"
        """
    )

    @Argument(help: "View name")
    var name: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        guard let view = try SavedViewStore.load(name: name) else {
            throw ValidationError("Saved view not found: \(name)")
        }

        let filter = try FilterParser.parse(view.expression)
        let client = CommandRuntime.makeClient()
        let todos = try await fetchOpenTodos(client: client).filter { filter.matches($0) }
        print(renderTodos(todos, list: view.name, output: output))
    }
}

struct ViewsDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a saved view",
        discussion: """
        Remove a saved view you no longer need.

        EXAMPLES:
          clings views delete docs-today
          clings views rm docs
        """,
        aliases: ["rm"]
    )

    @Argument(help: "View name")
    var name: String

    func run() throws {
        guard try SavedViewStore.delete(name: name) else {
            throw ValidationError("Saved view not found: \(name)")
        }
        print("Deleted view: \(name)")
    }
}
