// TemplateCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation

struct TemplateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "template",
        abstract: "Manage reusable task templates",
        discussion: """
        Save reusable task blueprints with notes, tags, checklist items, and relative
        schedule expressions.

        With no subcommand, lists templates. Saving and deleting definitions
        changes local clings state; run creates a real Things todo.

        EXAMPLES:
          clings template save weekly-review "Weekly review" --when "tomorrow morning"
          clings template list
          clings template run weekly-review
          clings template delete weekly-review
        """,
        subcommands: [
            TemplateListCommand.self,
            TemplateSaveCommand.self,
            TemplateRunCommand.self,
            TemplateDeleteCommand.self,
        ],
        defaultSubcommand: TemplateListCommand.self
    )
}

struct TemplateListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List saved templates",
        discussion: """
        Show all saved templates and the task title each template creates.

        --json returns a bare array including stored defaults and date expressions.

        EXAMPLES:
          clings template list
          clings template ls --json
        """,
        aliases: ["ls"]
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        let templates = try TemplateStore.list()
        if output.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(templates)
            print(String(data: data, encoding: .utf8) ?? "[]")
            return
        }

        if templates.isEmpty {
            print("No saved templates")
            return
        }

        for template in templates {
            print("\(template.name): \(template.title)")
        }
    }
}

struct TemplateSaveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "save",
        abstract: "Save a task template",
        discussion: """
        Capture a reusable task skeleton for repeatable work.

        Saving an existing name replaces it. Use --when and --deadline to store
        date expressions; dates embedded in the title are retained when explicit
        options are absent. Relative expressions are resolved when the task is made.
        --tags and --checklist accept space-separated values; quote each multiword
        checklist item. Saving does not create a Things todo.

        EXAMPLES:
          clings template save weekly-review "Weekly review" --when "tomorrow morning"
          clings template save release-checklist "Prepare release notes #docs" --checklist "Draft" "Review"
        """
    )

    @Argument(help: "Template name")
    var name: String

    @Argument(help: "Template title or natural-language task")
    var title: String

    @Option(name: .long, help: "Notes to store with the template")
    var notes: String?

    @Option(name: .long, help: "Store a relative when expression, e.g. 'tomorrow morning'")
    var when: String?

    @Option(name: .long, help: "Store a relative deadline expression, e.g. 'next friday'")
    var deadline: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Store tags")
    var tags: [String] = []

    @Option(name: .long, help: "Default project")
    var project: String?

    @Option(name: .long, help: "Default area")
    var area: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Checklist items")
    var checklist: [String] = []

    func run() throws {
        let parsed = TaskParser().parse(title)
        for expression in parsed.invalidDateExpressions {
            _ = try resolveDate(expression)
        }
        _ = try resolveDate(when)
        _ = try resolveDate(deadline)
        let template = TaskTemplate(
            name: name,
            title: parsed.title,
            notes: notes ?? parsed.notes,
            tags: Array(NSOrderedSet(array: parsed.tags + tags)) as? [String] ?? parsed.tags + tags,
            project: project ?? parsed.project,
            area: area ?? parsed.area,
            whenExpression: when ?? parsed.whenExpression,
            deadlineExpression: deadline ?? parsed.deadlineExpression,
            checklistItems: checklist.isEmpty ? parsed.checklistItems : checklist
        )
        try TemplateStore.save(template)
        print("Saved template: \(name)")
    }
}

struct TemplateRunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Create a task from a template",
        discussion: """
        Instantiate a saved template as a new todo in Things.

        Relative dates are resolved now. To preview or override defaults, use
        clings add "Task title" --template NAME --parse-only before creating.
        Creation is recorded for undo; undo cancels the new todo via automation.

        EXAMPLES:
          clings template run weekly-review
          clings template run release-checklist --json
        """
    )

    @Argument(help: "Template name")
    var name: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        guard let template = try TemplateStore.load(name: name) else {
            throw ValidationError("Template not found: \(name)")
        }

        let resolvedWhen = try resolveDate(template.whenExpression)
        let resolvedDeadline = try resolveDate(template.deadlineExpression)
        let client = CommandRuntime.makeClient()
        let id = try await client.createTodo(
            name: template.title,
            notes: template.notes,
            when: resolvedWhen,
            deadline: resolvedDeadline,
            tags: template.tags,
            project: template.project,
            area: template.area,
            checklistItems: template.checklistItems
        )
        try UndoStore.record(UndoEntry(operation: .create, todoID: id, snapshot: nil))
        print(renderMessage("Created from template: \(template.title)", output: output))
    }
}

struct TemplateDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a template",
        discussion: """
        Remove a saved template from local clings state.

        Existing Things todos created from the template are unaffected.

        EXAMPLES:
          clings template delete weekly-review
          clings template rm release-checklist
        """,
        aliases: ["rm"]
    )

    @Argument(help: "Template name")
    var name: String

    func run() throws {
        guard try TemplateStore.delete(name: name) else {
            throw ValidationError("Template not found: \(name)")
        }
        print("Deleted template: \(name)")
    }
}
