// HybridThingsClientTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("HybridThingsClient")
struct HybridThingsClientTests {
    @Test func readMethodsUseDatabaseLayer() async throws {
        let database = MockThingsDatabaseReader()
        database.lists = [.today: [TestData.todoOpen]]
        database.projects = [TestData.projectAlpha]
        database.areas = [TestData.workArea]
        database.tags = [TestData.workTag]
        database.todosByID = [TestData.todoOpen.id: TestData.todoOpen]
        database.searchResults = [TestData.todoNoProject]

        let client = HybridThingsClient(database: database, jxaBridge: MockJXAExecutor())

        let list = try await client.fetchList(.today)
        let projects = try await client.fetchProjects()
        let areas = try await client.fetchAreas()
        let tags = try await client.fetchTags()
        let todo = try await client.fetchTodo(id: TestData.todoOpen.id)
        let searchResults = try await client.search(query: "home")

        #expect(list == [TestData.todoOpen])
        #expect(projects == [TestData.projectAlpha])
        #expect(areas == [TestData.workArea])
        #expect(tags == [TestData.workTag])
        #expect(todo == TestData.todoOpen)
        #expect(searchResults == [TestData.todoNoProject])
        #expect(database.fetchedLists == [.today])
        #expect(database.fetchedTodoIDs == [TestData.todoOpen.id])
        #expect(database.searchQueries == ["home"])
    }

    @Test func writeMethodsUseBridgeAndApplyTagScripts() async throws {
        let bridge = MockJXAExecutor()
        bridge.appleScriptResponses = [
            .success("todo-id"),
            .success("ok"),
            .success("ok"),
            .success("ok"),
            .success("tag-id"),
            .success(""),
            .success(""),
        ]
        bridge.jsonResponses = [
            .success(try creationResultJSON(success: true, id: "project-id", name: "Ops")),
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
        ]

        let client = HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: bridge)

        let todoID = try await client.createTodo(
            name: "Ship docs",
            notes: "Publish help",
            when: Date(timeIntervalSinceReferenceDate: 10),
            deadline: Date(timeIntervalSinceReferenceDate: 20),
            tags: ["docs"],
            project: "Project Alpha",
            area: "Work",
            checklistItems: ["Draft"]
        )
        let projectID = try await client.createProject(
            name: "Ops",
            notes: "Runbook",
            when: Date(timeIntervalSinceReferenceDate: 30),
            deadline: Date(timeIntervalSinceReferenceDate: 40),
            tags: ["ops"],
            area: "Work"
        )
        try await client.completeTodo(id: "todo-id")
        try await client.reopenTodo(id: "todo-id")
        try await client.cancelTodo(id: "todo-id")
        try await client.deleteTodo(id: "todo-id")
        try await client.moveTodo(id: "todo-id", toProject: "Ops")
        try await client.updateTodo(
            id: "todo-id",
            name: "Renamed",
            notes: "Updated",
            dueDate: Date(timeIntervalSinceReferenceDate: 50),
            tags: ["docs"]
        )
        let tag = try await client.createTag(name: "docs")
        try await client.deleteTag(name: "docs")
        try await client.renameTag(oldName: "docs", newName: "guides")

        #expect(todoID == "todo-id")
        #expect(projectID == "project-id")
        #expect(tag == Tag(id: "tag-id", name: "docs"))
        #expect(bridge.executeJSONScripts.count == 7)
        #expect(bridge.appleScriptScripts.count == 7)
        #expect(bridge.appleScriptScripts[1].contains("docs"))
        #expect(bridge.executeJSONScripts[6].contains("Renamed"))
    }

    @Test func writeMethodsPropagateFailures() async throws {
        let missingIDBridge = MockJXAExecutor()
        missingIDBridge.appleScriptResponses = [.success("")]

        let missingIDClient = HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: missingIDBridge)
        do {
            _ = try await missingIDClient.createTodo(
                name: "Broken",
                notes: nil,
                when: nil,
                deadline: nil,
                tags: [],
                project: nil,
                area: nil,
                checklistItems: []
            )
            Issue.record("Expected missing todo ID error")
        } catch let error as ThingsError {
            switch error {
            case .operationFailed(let message):
                #expect(message.contains("Missing created todo ID"))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let failedMutationBridge = MockJXAExecutor()
        failedMutationBridge.jsonResponses = [.success(try mutationResultJSON(success: false, error: "nope"))]
        let failedMutationClient = HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: failedMutationBridge)
        do {
            try await failedMutationClient.completeTodo(id: "todo-id")
            Issue.record("Expected mutation failure")
        } catch let error as ThingsError {
            switch error {
            case .operationFailed(let message):
                #expect(message == "nope")
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let tagFailureBridge = MockJXAExecutor()
        tagFailureBridge.appleScriptResponses = [.failure(JXAError.scriptError("tag failure"))]
        let tagFailureClient = HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: tagFailureBridge)
        do {
            try await tagFailureClient.deleteTag(name: "docs")
            Issue.record("Expected deleteTag failure")
        } catch let error as ThingsError {
            switch error {
            case .jxaError(let jxaError):
                #expect(jxaError.localizedDescription.contains("tag failure"))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func openCommandsAreDisabled() {
        let client = HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: MockJXAExecutor())

        do {
            try client.openInThings(id: "todo-id")
            Issue.record("Expected openInThings(id:) to throw")
        } catch let error as ThingsError {
            switch error {
            case .invalidState(let message):
                #expect(message.contains("Open command is disabled"))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        do {
            try client.openInThings(list: .today)
            Issue.record("Expected openInThings(list:) to throw")
        } catch let error as ThingsError {
            switch error {
            case .invalidState(let message):
                #expect(message.contains("Open command is disabled"))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
