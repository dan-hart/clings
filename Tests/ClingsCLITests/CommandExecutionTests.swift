// CommandExecutionTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation
import Testing
@testable import ClingsCLI

@Suite("Command Execution", .serialized)
struct CommandExecutionTests {
    @Test func commandSupportHelpersRenderDeduplicateAndSelect() async throws {
        let todo = CommandFixtures.todo(
            id: "todo-1",
            name: "Draft release notes",
            tags: [CommandFixtures.docsTag, CommandFixtures.urgentTag]
        )
        let other = CommandFixtures.todo(id: "todo-2", name: "Plan review", project: nil, area: nil)
        let client = RecordingThingsClient()
        client.todosForList = [
            .today: [todo],
            .inbox: [todo, other],
            .upcoming: [],
            .anytime: [],
            .someday: [],
            .logbook: [CommandFixtures.todo(id: "done-1", name: "Finished", status: .completed)],
        ]

        let formattedOutput = try OutputOptions.parse(["--format", "{name} [{project}]"])
        let rendered = renderTodos([todo], list: "Today", output: formattedOutput)
        #expect(rendered == "Draft release notes [Release]")

        let openTodos = try await fetchOpenTodos(client: client)
        #expect(openTodos.count == 2)

        let visibleTodos = try await fetchVisibleTodos(client: client, includeLogbook: true)
        #expect(visibleTodos.count == 3)

        let promptSelection = promptForTodoSelection(
            todos: [todo, other],
            prompt: "Choose one",
            inputReader: { "2" }
        )
        #expect(promptSelection?.id == "todo-2")

        let idSelection = promptForTodoSelection(
            todos: [todo, other],
            prompt: "Choose by id",
            inputReader: { "todo-1" }
        )
        #expect(idSelection?.id == "todo-1")
        #expect(parseFlexibleDate("tomorrow 3pm") != nil)
    }

    @Test func listSearchFilterAndShowCommandsUseRuntimeClient() async throws {
        let todayTodo = CommandFixtures.todo(
            id: "today-1",
            name: "Today work",
            tags: [CommandFixtures.docsTag],
            notes: "Important task"
        )
        let inboxTodo = CommandFixtures.todo(id: "inbox-1", name: "Inbox work", project: nil)
        let client = RecordingThingsClient()
        client.todosForList = [
            .today: [todayTodo],
            .inbox: [inboxTodo],
            .upcoming: [],
            .anytime: [],
            .someday: [],
        ]
        client.projects = [CommandFixtures.releaseProject]
        client.areas = [CommandFixtures.workArea, CommandFixtures.personalArea]
        client.todosByID[todayTodo.id] = todayTodo
        client.searchResults = [todayTodo]

        let todayOutput = try await runAsync(
            try TodayCommand.parse(["--format", "{name}"]),
            client: client
        )
        #expect(todayOutput.contains("Today work"))

        let projectsOutput = try await runAsync(
            try ProjectsCommand.parse(["--json"]),
            client: client
        )
        #expect(projectsOutput.contains("\"name\" : \"Release\""))

        let areasOutput = try await runAsync(
            try AreasCommand.parse([]),
            client: client
        )
        #expect(areasOutput.contains("Work"))

        let searchOutput = try await runAsync(
            try SearchCommand.parse(["release"]),
            client: client
        )
        #expect(searchOutput.contains("Today work"))
        #expect(client.searchQueries == ["release"])

        let filterOutput = try await runAsync(
            try FilterCommand.parse(["tags CONTAINS 'docs'"]),
            client: client
        )
        #expect(filterOutput.contains("Today work"))
        #expect(!filterOutput.contains("Inbox work"))

        let showOutput = try await runAsync(
            try ShowCommand.parse([todayTodo.id, "--json"]),
            client: client
        )
        #expect(showOutput.contains("\"id\" : \"today-1\""))
    }

    @Test func addTemplateAndViewsCommandsPersistThroughConfig() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let client = RecordingThingsClient()
            client.createTodoID = "created-from-template"

            let addParseOnlyOutput = try await runAsync(
                try AddCommand.parse(["Ship docs tomorrow #docs", "--parse-only", "--json"]),
                client: client
            )
            #expect(addParseOnlyOutput.contains("\"title\" : \"Ship docs\""))
            #expect(addParseOnlyOutput.contains("\"tags\""))

            let templateSaveOutput = try await runSync(
                try TemplateSaveCommand.parse(["daily", "Daily review #review", "--checklist", "Inbox", "Calendar"])
            )
            #expect(templateSaveOutput.contains("Saved template: daily"))

            let templateListOutput = try await runSync(
                try TemplateListCommand.parse([])
            )
            #expect(templateListOutput.contains("daily: Daily review"))

            let templateRunOutput = try await runAsync(
                try TemplateRunCommand.parse(["daily"]),
                client: client
            )
            #expect(templateRunOutput.contains("Created from template: Daily review"))
            #expect(client.createdTodos.count == 1)

            let templateDeleteOutput = try await runSync(
                try TemplateDeleteCommand.parse(["daily"])
            )
            #expect(templateDeleteOutput.contains("Deleted template: daily"))

            let viewsSaveOutput = try await runSync(
                try ViewsSaveCommand.parse(["docs", "tags CONTAINS 'docs'", "--note", "Documentation work"])
            )
            #expect(viewsSaveOutput.contains("Saved view: docs"))

            client.todosForList = [
                .today: [CommandFixtures.todo(id: "doc-1", name: "Doc task", tags: [CommandFixtures.docsTag])],
                .inbox: [CommandFixtures.todo(id: "other-1", name: "Other task", tags: [CommandFixtures.reviewTag])],
                .upcoming: [],
                .anytime: [],
                .someday: [],
            ]

            let viewsRunOutput = try await runAsync(
                try ViewsRunCommand.parse(["docs"]),
                client: client
            )
            #expect(viewsRunOutput.contains("Doc task"))
            #expect(!viewsRunOutput.contains("Other task"))

            let viewsListOutput = try await runSync(
                try ViewsListCommand.parse([])
            )
            #expect(viewsListOutput.contains("# Documentation work"))

            let viewsDeleteOutput = try await runSync(
                try ViewsDeleteCommand.parse(["docs"])
            )
            #expect(viewsDeleteOutput.contains("Deleted view: docs"))
        }
    }

    @Test func completionsOutputIncludesCurrentCommandFamilies() async throws {
        let zshOutput = try await runSync(
            try CompletionsCommand.parse(["zsh"])
        )
        #expect(zshOutput.contains("'views:Manage saved filter views'"))
        #expect(zshOutput.contains("'template:Manage reusable task templates'"))
        #expect(zshOutput.contains("'undo:Undo the most recent supported mutation'"))
        #expect(zshOutput.contains("'focus:Show a focused queue of high-attention tasks'"))
        #expect(zshOutput.contains("'pick:Interactively pick a todo for a follow-up action'"))
        #expect(zshOutput.contains("'doctor:Check clings setup and local environment'"))
        #expect(zshOutput.contains("'audit:Audit project health and missing next actions'"))
    }

    @Test func mutationCommandsUpdateAndUndoRoundTrip() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let baseTodo = CommandFixtures.todo(id: "todo-1", name: "Current title", tags: [CommandFixtures.docsTag], notes: "Old")
            let alternateTodo = CommandFixtures.todo(id: "todo-2", name: "Matching title")
            let client = RecordingThingsClient()
            client.todosByID[baseTodo.id] = baseTodo
            client.todosByID[alternateTodo.id] = alternateTodo
            client.searchResults = [alternateTodo]

            let completeByTitleOutput = try await runAsync(
                try CompleteCommand.parse(["--title", "Matching"]),
                client: client
            )
            #expect(completeByTitleOutput.contains("Completed: Matching title"))
            #expect(client.completedIDs == ["todo-2"])

            client.searchResults = [
                CommandFixtures.todo(id: "multi-1", name: "Matching alpha"),
                CommandFixtures.todo(id: "multi-2", name: "Matching beta"),
            ]
            let multipleMatchesOutput = try await runAsync(
                try CompleteCommand.parse(["--title", "Matching"]),
                client: client
            )
            #expect(multipleMatchesOutput.contains("Multiple todos match"))
            #expect(multipleMatchesOutput.contains("clings complete multi-1"))

            let cancelOutput = try await runAsync(
                try CancelCommand.parse([baseTodo.id]),
                client: client
            )
            #expect(cancelOutput.contains("Canceled todo: todo-1"))
            #expect(client.canceledIDs == ["todo-1"])

            let deleteOutput = try await runAsync(
                try DeleteCommand.parse([baseTodo.id]),
                client: client
            )
            #expect(deleteOutput.contains("Deleted todo: todo-1"))
            #expect(client.deletedIDs == ["todo-1"])

            try AuthTokenStore.saveToken("secret-token")
            let recorder = URLRecorder()
            let updateOutput = try await runAsync(
                try UpdateCommand.parse([
                    baseTodo.id,
                    "--name", "Updated title",
                    "--notes", "Updated notes",
                    "--due", "tomorrow",
                    "--when", "today",
                    "--heading", "Waiting",
                    "--tags", "docs", "urgent",
                ]),
                client: client,
                openedURLs: recorder
            )
            #expect(updateOutput.contains("Updated todo: todo-1"))
            #expect(client.updatedTodos.count == 1)
            #expect(recorder.urls.count == 1)
            #expect(recorder.urls[0].contains("things:///update"))
            #expect(recorder.urls[0].contains("auth-token=secret-token"))
            #expect(recorder.urls[0].contains("heading=Waiting"))

            let undoShowOutput = try await runAsync(
                try UndoCommand.parse(["--show"]),
                client: client
            )
            #expect(undoShowOutput.contains("Latest undo: update todo-1"))

            let undoUpdateOutput = try await runAsync(
                try UndoCommand.parse([]),
                client: client
            )
            #expect(undoUpdateOutput.contains("Undid update for todo-1"))

            try UndoStore.record(UndoEntry(operation: .create, todoID: "created-id", snapshot: nil))
            let undoCreateOutput = try await runAsync(
                try UndoCommand.parse([]),
                client: client
            )
            #expect(undoCreateOutput.contains("Undid create for created-id"))
            #expect(client.deletedIDs.contains("created-id"))

            try UndoStore.record(UndoEntry(operation: .complete, todoID: "todo-2", snapshot: TodoSnapshot(todo: alternateTodo)))
            let undoCompleteOutput = try await runAsync(
                try UndoCommand.parse([]),
                client: client
            )
            #expect(undoCompleteOutput.contains("Undid complete for todo-2"))
            #expect(client.reopenedIDs.contains("todo-2"))
        }
    }

    @Test func focusPickAndProjectCommandsUseRuntimeData() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let overdue = CommandFixtures.todo(
                id: "focus-1",
                name: "Overdue task",
                dueDate: Date(timeIntervalSinceNow: -3600),
                tags: [CommandFixtures.urgentTag]
            )
            let today = CommandFixtures.todo(id: "focus-2", name: "Today task", dueDate: Date())
            let completed = CommandFixtures.todo(id: "done-1", name: "Completed task", status: .completed)
            let client = RecordingThingsClient()
            client.todosForList = [
                .today: [today],
                .inbox: [overdue],
                .upcoming: [],
                .anytime: [],
                .someday: [],
                .logbook: [completed],
            ]
            client.searchResults = [overdue]
            client.todosByID[overdue.id] = overdue

            let focusOutput = try await runAsync(
                try FocusCommand.parse([]),
                client: client
            )
            #expect(focusOutput.contains("Overdue task"))
            #expect(focusOutput.contains("Overdue"))

            let focusFormatOutput = try await runAsync(
                try FocusCommand.parse(["--format", "{name}"]),
                client: client
            )
            #expect(focusFormatOutput.contains("Overdue task"))

            let pickShowOutput = try await runAsync(
                try PickShowCommand.parse(["Overdue"]),
                client: client,
                inputs: ["1"]
            )
            #expect(pickShowOutput.contains("Overdue task"))

            let pickCompleteOutput = try await runAsync(
                try PickCompleteCommand.parse([]),
                client: client,
                inputs: ["1"]
            )
            #expect(pickCompleteOutput.contains("Completed: Today task") || pickCompleteOutput.contains("Completed: Overdue task"))
            #expect(!client.completedIDs.isEmpty)

            let pickCancelOutput = try await runAsync(
                try PickCancelCommand.parse([]),
                client: client,
                inputs: ["1"]
            )
            #expect(pickCancelOutput.contains("Canceled:"))

            let pickDeleteOutput = try await runAsync(
                try PickDeleteCommand.parse([]),
                client: client,
                inputs: ["1"]
            )
            #expect(pickDeleteOutput.contains("Deleted:"))

            client.projects = [CommandFixtures.releaseProject]
            let projectListOutput = try await runAsync(
                try ProjectListCommand.parse(["--json"]),
                client: client
            )
            #expect(projectListOutput.contains("\"name\" : \"Release\""))

            let projectAddOutput = try await runAsync(
                try ProjectAddCommand.parse([
                    "Release Readiness",
                    "--notes", "Prepare the launch",
                    "--area", "Work",
                    "--when", "today",
                    "--deadline", "2030-01-01",
                    "--tags", "planning,research",
                ]),
                client: client
            )
            #expect(projectAddOutput.contains("Created project: Release Readiness"))
            #expect(client.createdProjects.count == 1)

            client.todosForList[.today] = [today]
            let projectAuditOutput = try await runAsync(
                try ProjectAuditCommand.parse(["--json"]),
                client: client
            )
            #expect(projectAuditOutput.contains("\"items\""))
        }
    }

    @Test func tagsAndBulkCommandsMutateThroughRuntimeClient() async throws {
        let first = CommandFixtures.todo(id: "bulk-1", name: "First", tags: [CommandFixtures.docsTag], project: nil)
        let second = CommandFixtures.todo(id: "bulk-2", name: "Second", tags: [], project: nil)
        let client = RecordingThingsClient()
        client.tags = [CommandFixtures.docsTag, CommandFixtures.reviewTag]
        client.todosForList = [
            .today: [first, second],
            .inbox: [first, second],
        ]

        let tagsListOutput = try await runAsync(
            try TagsListCommand.parse([]),
            client: client
        )
        #expect(tagsListOutput.contains("docs"))

        let tagsAddOutput = try await runAsync(
            try TagsAddCommand.parse(["urgent"]),
            client: client
        )
        #expect(tagsAddOutput.contains("Created tag: urgent"))
        #expect(client.createdTags == ["urgent"])

        let tagsDeleteOutput = try await runAsync(
            try TagsDeleteCommand.parse(["review"]),
            client: client,
            inputs: ["yes"]
        )
        #expect(tagsDeleteOutput.contains("Deleted tag: review"))
        #expect(client.deletedTags == ["review"])

        let tagsRenameOutput = try await runAsync(
            try TagsRenameCommand.parse(["docs", "documentation"]),
            client: client
        )
        #expect(tagsRenameOutput.contains("Renamed tag: docs -> documentation"))
        #expect(client.renamedTags.count == 1)

        let bulkCompleteOutput = try await runAsync(
            try BulkCompleteCommand.parse(["--list", "today", "--yes"]),
            client: client
        )
        #expect(bulkCompleteOutput.contains("Completed: 2, Failed: 0"))

        let bulkCancelOutput = try await runAsync(
            try BulkCancelCommand.parse(["--list", "today", "--dry-run"]),
            client: client
        )
        #expect(bulkCancelOutput.contains("[DRY RUN]"))

        let bulkTagOutput = try await runAsync(
            try BulkTagCommand.parse(["review", "--list", "today", "--yes"]),
            client: client
        )
        #expect(bulkTagOutput.contains("Updated 2 todo(s)"))
        #expect(client.updatedTodos.count >= 2)

        let bulkMoveOutput = try await runAsync(
            try BulkMoveCommand.parse(["--to", "Archive", "--list", "today", "--yes"]),
            client: client
        )
        #expect(bulkMoveOutput.contains("Moved: 2, Failed: 0"))
        #expect(client.movedTodos.count == 2)
    }

    @Test func doctorReviewStatsAndCompletionsCommandsReportExpectedOutput() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try AuthTokenStore.saveToken("doctor-token")

            let overdue = CommandFixtures.todo(
                id: "stats-1",
                name: "Overdue docs",
                dueDate: Date(timeIntervalSinceNow: -7200),
                tags: [CommandFixtures.docsTag],
                notes: "Needs attention"
            )
            let upcoming = CommandFixtures.todo(
                id: "stats-2",
                name: "Upcoming review",
                dueDate: Date(timeIntervalSinceNow: 2 * 24 * 3600),
                tags: [CommandFixtures.reviewTag]
            )
            let completed = CommandFixtures.todo(
                id: "stats-3",
                name: "Finished docs",
                status: .completed,
                tags: [CommandFixtures.docsTag]
            )

            let database = MockThingsDatabase(
                lists: [
                    .inbox: [overdue],
                    .today: [upcoming],
                    .upcoming: [upcoming],
                    .anytime: [overdue],
                    .someday: [],
                    .logbook: [completed],
                ],
                projects: [CommandFixtures.releaseProject],
                areas: [CommandFixtures.workArea],
                tags: [CommandFixtures.docsTag, CommandFixtures.reviewTag],
                todosByID: [:],
                searchResults: []
            )

            let doctorOutput = try await runSync(
                try DoctorCommand.parse(["--json"]),
                database: database
            )
            #expect(doctorOutput.contains("\"overallStatus\""))
            #expect(doctorOutput.contains("Auth token"))

            let reviewStartOutput = try await runAsync(
                try ReviewStartCommand.parse([]),
                database: database
            )
            #expect(reviewStartOutput.contains("Weekly Review"))
            #expect(ReviewSession.load() != nil)

            let reviewStatusOutput = try await runAsync(
                try ReviewStatusCommand.parse([]),
                database: database
            )
            #expect(reviewStatusOutput.contains("Review Session Status"))

            let reviewClearOutput = try await runAsync(
                try ReviewClearCommand.parse([]),
                database: database
            )
            #expect(reviewClearOutput.contains("Review session cleared."))
            #expect(ReviewSession.load() == nil)

            let statsOutput = try await runAsync(
                try StatsCommand.parse([]),
                database: database
            )
            #expect(statsOutput.contains("Things 3 Statistics"))
            #expect(statsOutput.contains("Overdue"))

            let trendsOutput = try await runAsync(
                try StatsTrendsCommand.parse(["--json"]),
                database: database
            )
            #expect(trendsOutput.contains("\"completed\""))

            let heatmapOutput = try await runAsync(
                try StatsHeatmapCommand.parse(["--no-color"]),
                database: database
            )
            #expect(heatmapOutput.contains("Completion Heatmap"))

            let bashCompletions = try await runSync(try CompletionsCommand.parse(["bash"]))
            #expect(bashCompletions.contains("_clings()"))

            let zshCompletions = try await runSync(try CompletionsCommand.parse(["zsh"]))
            #expect(zshCompletions.contains("#compdef clings"))

            let fishCompletions = try await runSync(try CompletionsCommand.parse(["fish"]))
            #expect(fishCompletions.contains("complete -c clings"))
        }
    }

    private func runSync<T: ParsableCommand>(
        _ command: T,
        client: RecordingThingsClient? = nil,
        database: MockThingsDatabase? = nil,
        inputs: [String] = [],
        openedURLs: URLRecorder? = nil
    ) async throws -> String {
        try await CommandTestSupport.withRuntime(
            client: client,
            database: database,
            inputs: inputs,
            openedURLs: openedURLs
        ) {
            var command = command
            let (_, output) = try CommandTestSupport.captureStandardOutput {
                try command.run()
            }
            return output
        }
    }

    private func runAsync<T: AsyncParsableCommand>(
        _ command: T,
        client: RecordingThingsClient? = nil,
        database: MockThingsDatabase? = nil,
        inputs: [String] = [],
        openedURLs: URLRecorder? = nil
    ) async throws -> String {
        try await CommandTestSupport.withRuntime(
            client: client,
            database: database,
            inputs: inputs,
            openedURLs: openedURLs
        ) {
            var command = command
            let (_, output) = try await CommandTestSupport.captureStandardOutput {
                try await command.run()
            }
            return output
        }
    }
}
