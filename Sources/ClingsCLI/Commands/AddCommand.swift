// AddCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation

struct AddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new todo with natural language support",
        discussion: """
        Supports natural language patterns for capture, scheduling, tags, notes,
        and checklist items.

        Quote the full task so your shell preserves #tags and spaces. --when
        sets the planned start; --deadline sets the due date. Explicit options
        override parsed values, while tags are combined and deduplicated.
        Template defaults are applied before parsing the title and options.

        PREVIEW FIRST:
          clings add "Draft release notes tomorrow #docs" --parse-only --json
          clings add "Draft release notes" --when tomorrow --deadline friday

        --parse-only never creates a todo. Invalid date options are rejected
        before any write, including impossible dates and invalid times.
        Priority markers are parsed but are not applied as a Things priority.

        EXAMPLES:
          clings add "Draft changelog entry tomorrow #docs"
          clings add "Replace air filter by friday !!"
          clings add "Review chapter outline for Writing Project"
          clings add "Task // notes go here"
          clings add "Task - checklist item 1 - checklist item 2"
        """
    )

    @Argument(help: "The todo title (supports natural language)")
    var title: String

    @Option(name: .long, help: "Start from a saved task template")
    var template: String?

    @Option(name: .long, help: "Add notes to the todo")
    var notes: String?

    @Option(name: .long, help: "Planned start date, e.g. 'tomorrow' or '2027-01-15'; preview with --parse-only")
    var when: String?

    @Option(name: .long, help: "Due date, distinct from the planned start; e.g. 'friday' or '2027-01-15'")
    var deadline: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Space-separated tag names, combined with parsed/template tags")
    var tags: [String] = []

    @Option(name: .long, help: "Add to a project")
    var project: String?

    @Option(name: .long, help: "Add to an area")
    var area: String?

    @Flag(name: .long, help: "Show parsed result without creating todo")
    var parseOnly = false

    @OptionGroup var output: OutputOptions

    func run() async throws {
        if parseOnly {
            try await perform(); return
        }
        try await MutationLock.withLock { try await perform() }
    }

    private func perform() async throws {
        let parser = TaskParser()
        var parsed = ParsedTask(title: "")

        if let template {
            guard let savedTemplate = try TemplateStore.load(name: template) else {
                throw ValidationError("Template not found: \(template)")
            }

            parsed = try ParsedTask(
                title: savedTemplate.title,
                notes: savedTemplate.notes,
                tags: savedTemplate.tags,
                project: savedTemplate.project,
                area: savedTemplate.area,
                dueDate: resolveDate(savedTemplate.deadlineExpression),
                whenDate: resolveDate(savedTemplate.whenExpression),
                checklistItems: savedTemplate.checklistItems
            )
        }

        let titleParsed = parser.parse(title)
        for expression in titleParsed.invalidDateExpressions {
            _ = try resolveDate(expression)
        }
        if !titleParsed.title.isEmpty {
            parsed.title = titleParsed.title
        }
        if let parsedNotes = titleParsed.notes, !parsedNotes.isEmpty {
            parsed.notes = parsedNotes
        }
        if !titleParsed.tags.isEmpty {
            parsed.tags.append(contentsOf: titleParsed.tags)
        }
        if let parsedProject = titleParsed.project {
            parsed.project = parsedProject
        }
        if let parsedArea = titleParsed.area {
            parsed.area = parsedArea
        }
        if let parsedWhen = titleParsed.whenDate {
            parsed.whenDate = parsedWhen
        }
        if let parsedDue = titleParsed.dueDate {
            parsed.dueDate = parsedDue
        }
        if !titleParsed.checklistItems.isEmpty {
            parsed.checklistItems = titleParsed.checklistItems
        }

        // Command line options override parsed values
        if let notes = notes {
            parsed.notes = notes
        }
        if !tags.isEmpty {
            parsed.tags.append(contentsOf: tags)
        }
        if let project = project {
            parsed.project = project
        }
        if let area = area {
            parsed.area = area
        }
        if let when = when {
            parsed.whenDate = try resolveDate(when)
        }
        if let deadline = deadline {
            parsed.dueDate = try resolveDate(deadline)
        }

        parsed.tags = Array(NSOrderedSet(array: parsed.tags)) as? [String] ?? parsed.tags

        // Handle parse-only mode
        if parseOnly {
            let preview = TaskPreview(
                title: parsed.title, notes: parsed.notes, tags: parsed.tags,
                project: parsed.project, area: parsed.area, when: parsed.whenDate,
                deadline: parsed.dueDate,
                undo: "Cancels the newly created todo; does not permanently delete it.",
                checklistItems: parsed.checklistItems
            )
            try print(preview.render(json: output.json))
            return
        }

        let client = CommandRuntime.makeClient()
        let id: String
        do { id = try await client.createTodo(
            name: parsed.title,
            notes: parsed.notes,
            when: parsed.whenDate,
            deadline: parsed.dueDate,
            tags: parsed.tags,
            project: parsed.project,
            area: parsed.area,
            checklistItems: parsed.checklistItems
        ) } catch let error as AppliedMutationError {
            try reportPartial(error, entry: UndoEntry(operation: .create, todoID: error.id, snapshot: nil))
        }
        try printOutcome(recordApplied(UndoEntry(operation: .create, todoID: id, snapshot: nil), message: "Created: \(parsed.title)"), output: output)
    }
}
