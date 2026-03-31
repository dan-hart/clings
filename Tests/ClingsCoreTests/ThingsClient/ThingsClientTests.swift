// ThingsClientTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("ThingsClient")
struct ThingsClientTests {
    @Test func fetchCollectionMethodsDecodeJSONResponses() async throws {
        let bridge = MockJXAExecutor()
        bridge.jsonResponses = [
            .success(try encodeJSON([TestData.todoOpen])),
            .success(try encodeJSON([TestData.projectAlpha])),
            .success(try encodeJSON([TestData.workArea])),
            .success(try encodeJSON([TestData.workTag])),
            .success(try encodeJSON([TestData.todoNoProject])),
        ]

        let client = ThingsClient(bridge: bridge)

        let today = try await client.fetchList(.today)
        let projects = try await client.fetchProjects()
        let areas = try await client.fetchAreas()
        let tags = try await client.fetchTags()
        let searchResults = try await client.search(query: "home")

        #expect(today == [TestData.todoOpen])
        #expect(projects.count == 1)
        #expect(projects[0].id == TestData.projectAlpha.id)
        #expect(projects[0].name == TestData.projectAlpha.name)
        #expect(areas == [TestData.workArea])
        #expect(tags == [TestData.workTag])
        #expect(searchResults == [TestData.todoNoProject])
        #expect(bridge.executeJSONScripts.count == 5)
        #expect(bridge.executeJSONScripts[0].contains("toDos"))
        #expect(bridge.executeJSONScripts[4].contains("home"))
    }

    @Test func fetchCollectionMethodsWrapBridgeErrors() async {
        let bridge = MockJXAExecutor()
        bridge.jsonResponses = [
            .failure(JXAError.thingsNotRunning),
            .failure(JXAError.scriptError("projects")),
            .failure(JXAError.scriptError("areas")),
            .failure(JXAError.scriptError("tags")),
            .failure(JXAError.scriptError("search")),
        ]

        let client = ThingsClient(bridge: bridge)

        await expectJXAError(from: { _ = try await client.fetchList(.today) }, contains: "Things 3 is not running")
        await expectJXAError(from: { _ = try await client.fetchProjects() }, contains: "projects")
        await expectJXAError(from: { _ = try await client.fetchAreas() }, contains: "areas")
        await expectJXAError(from: { _ = try await client.fetchTags() }, contains: "tags")
        await expectJXAError(from: { _ = try await client.search(query: "q") }, contains: "search")
    }

    @Test func fetchTodoHandlesSuccessNotFoundAndDecodeFailures() async throws {
        let validBridge = MockJXAExecutor()
        validBridge.executeResponses = [.success(try encodeJSON(TestData.todoOpen))]

        let validClient = ThingsClient(bridge: validBridge)
        let todo = try await validClient.fetchTodo(id: TestData.todoOpen.id)
        #expect(todo == TestData.todoOpen)

        let notFoundBridge = MockJXAExecutor()
        notFoundBridge.executeResponses = [.success(try errorResponseJSON(error: "missing", id: TestData.todoOpen.id))]

        let notFoundClient = ThingsClient(bridge: notFoundBridge)
        do {
            _ = try await notFoundClient.fetchTodo(id: TestData.todoOpen.id)
            Issue.record("Expected notFound error")
        } catch let error as ThingsError {
            switch error {
            case .notFound(let id):
                #expect(id == TestData.todoOpen.id)
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let invalidBridge = MockJXAExecutor()
        invalidBridge.executeResponses = [.success("{\"id\":\"broken\"}")]

        let invalidClient = ThingsClient(bridge: invalidBridge)
        do {
            _ = try await invalidClient.fetchTodo(id: "broken")
            Issue.record("Expected decode failure")
        } catch let error as ThingsError {
            switch error {
            case .operationFailed(let message):
                #expect(message.contains("Failed to decode todo"))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func createTodoUsesAppleScriptAppliesTagsAndRequiresCreatedID() async throws {
        let bridge = MockJXAExecutor()
        bridge.appleScriptResponses = [
            .success("todo-created-id"),
            .success("ok"),
        ]

        let client = ThingsClient(bridge: bridge)
        let createdID = try await client.createTodo(
            name: "Ship docs",
            notes: "Publish examples",
            when: Date(timeIntervalSinceReferenceDate: 10),
            deadline: Date(timeIntervalSinceReferenceDate: 20),
            tags: ["docs", "release"],
            project: "Project Alpha",
            area: "Work",
            checklistItems: ["Draft", "Review"]
        )

        #expect(createdID == "todo-created-id")
        #expect(bridge.appleScriptScripts.count == 2)
        #expect(bridge.appleScriptScripts[0].contains("Ship docs"))
        #expect(bridge.appleScriptScripts[0].contains("Draft"))
        #expect(bridge.appleScriptScripts[1].contains("release"))

        let missingIDBridge = MockJXAExecutor()
        missingIDBridge.appleScriptResponses = [.success("")]
        let missingIDClient = ThingsClient(bridge: missingIDBridge)

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
            Issue.record("Expected missing ID error")
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

        let tagFailureBridge = MockJXAExecutor()
        tagFailureBridge.appleScriptResponses = [
            .success("todo-created-id"),
            .failure(JXAError.scriptError("tag failure")),
        ]
        let tagFailureClient = ThingsClient(bridge: tagFailureBridge)
        await expectJXAError(
            from: {
                _ = try await tagFailureClient.createTodo(
                    name: "Needs tags",
                    notes: nil,
                    when: nil,
                    deadline: nil,
                    tags: ["docs"],
                    project: nil,
                    area: nil,
                    checklistItems: []
                )
            },
            contains: "tag failure"
        )
    }

    @Test func createProjectHandlesJSONResponsesAndTagUpdates() async throws {
        let bridge = MockJXAExecutor()
        bridge.jsonResponses = [.success(try creationResultJSON(success: true, id: "project-id", name: "Ops"))]
        bridge.appleScriptResponses = [.success("ok")]

        let client = ThingsClient(bridge: bridge)
        let createdID = try await client.createProject(
            name: "Ops",
            notes: "Runbook",
            when: Date(timeIntervalSinceReferenceDate: 30),
            deadline: Date(timeIntervalSinceReferenceDate: 40),
            tags: ["ops"],
            area: "Work"
        )

        #expect(createdID == "project-id")
        #expect(bridge.executeJSONScripts.count == 1)
        #expect(bridge.appleScriptScripts.count == 1)
        #expect(bridge.appleScriptScripts[0].contains("ops"))

        let failingBridge = MockJXAExecutor()
        failingBridge.jsonResponses = [.success(try creationResultJSON(success: false, error: "project failed"))]
        let failingClient = ThingsClient(bridge: failingBridge)
        do {
            _ = try await failingClient.createProject(
                name: "Broken",
                notes: nil,
                when: nil,
                deadline: nil,
                tags: [],
                area: nil
            )
            Issue.record("Expected createProject failure")
        } catch let error as ThingsError {
            switch error {
            case .operationFailed(let message):
                #expect(message == "project failed")
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func mutationMethodsAndUpdateTodoHandleSuccessAndFailurePaths() async throws {
        let bridge = MockJXAExecutor()
        bridge.jsonResponses = [
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
            .success(try mutationResultJSON(success: true)),
        ]
        bridge.appleScriptResponses = [
            .success("ok"),
            .success("ok"),
        ]

        let client = ThingsClient(bridge: bridge)
        try await client.completeTodo(id: "todo-1")
        try await client.reopenTodo(id: "todo-1")
        try await client.cancelTodo(id: "todo-1")
        try await client.deleteTodo(id: "todo-1")
        try await client.moveTodo(id: "todo-1", toProject: "Ops")
        try await client.updateTodo(
            id: "todo-1",
            name: "Renamed",
            notes: "Updated",
            dueDate: Date(timeIntervalSinceReferenceDate: 50),
            tags: ["ops"]
        )
        try await client.updateTodo(
            id: "todo-1",
            name: nil,
            notes: nil,
            dueDate: nil,
            tags: ["solo-tag"]
        )

        #expect(bridge.executeJSONScripts.count == 6)
        #expect(bridge.appleScriptScripts.count == 2)
        #expect(bridge.executeJSONScripts[4].contains("Ops"))
        #expect(bridge.executeJSONScripts[5].contains("Renamed"))
        #expect(bridge.appleScriptScripts[1].contains("solo-tag"))

        let failureBridge = MockJXAExecutor()
        failureBridge.jsonResponses = [.success(try mutationResultJSON(success: false, error: "mutation failed"))]
        let failureClient = ThingsClient(bridge: failureBridge)

        do {
            try await failureClient.completeTodo(id: "todo-2")
            Issue.record("Expected mutation failure")
        } catch let error as ThingsError {
            switch error {
            case .operationFailed(let message):
                #expect(message == "mutation failed")
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func tagManagementMethodsWrapJXAErrors() async throws {
        let bridge = MockJXAExecutor()
        bridge.appleScriptResponses = [
            .success("tag-id"),
            .success(""),
            .success(""),
        ]

        let client = ThingsClient(bridge: bridge)
        let tag = try await client.createTag(name: "docs")
        try await client.deleteTag(name: "docs")
        try await client.renameTag(oldName: "docs", newName: "guides")

        #expect(tag == Tag(id: "tag-id", name: "docs"))
        #expect(bridge.appleScriptScripts.count == 3)

        let failingBridge = MockJXAExecutor()
        failingBridge.appleScriptResponses = [.failure(JXAError.scriptError("delete failed"))]
        let failingClient = ThingsClient(bridge: failingBridge)
        await expectJXAError(from: { try await failingClient.deleteTag(name: "docs") }, contains: "delete failed")
    }

    @Test func openCommandsAreDisabled() {
        let client = ThingsClient(bridge: MockJXAExecutor())

        do {
            try client.openInThings(id: "todo-1")
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

    private func expectJXAError(
        from operation: () async throws -> Void,
        contains fragment: String
    ) async {
        do {
            try await operation()
            Issue.record("Expected JXA-backed ThingsError")
        } catch let error as ThingsError {
            switch error {
            case .jxaError(let jxaError):
                #expect(jxaError.localizedDescription.contains(fragment))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
