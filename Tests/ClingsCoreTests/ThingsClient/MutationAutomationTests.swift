@testable import ClingsCore
import Foundation
import Testing

struct MutationAutomationTests {
    @Test func restoreTagFailureReportsFieldsAlreadyRestored() async throws {
        for hybrid in [false, true] {
            let bridge = MockJXAExecutor()
            bridge.appleScriptResponses = [.success("ok"), .failure(ThingsError.operationFailed("tag failed"))]
            let client: any ThingsClientProtocol = hybrid ? HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: bridge) : ThingsClient(bridge: bridge)
            do {
                try await client.restoreTodo(TodoSnapshot(id: "task", name: "Original", status: .completed))
                Issue.record("Expected partial restore")
            } catch let error as AppliedMutationError {
                #expect(error.id == "task")
                #expect(error.fields == ["title", "notes", "deadline", "status"])
            }
        }
    }

    @Test func realClientPathsClearNullFieldsAndMoveByExactID() async throws {
        for hybrid in [false, true] {
            let bridge = MockJXAExecutor()
            bridge.appleScriptResponses = [.success("ok"), .success("ok"), .success("ok")]
            let client: any ThingsClientProtocol = hybrid ? HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: bridge) : ThingsClient(bridge: bridge)
            try await client.restoreTodo(TodoSnapshot(id: "task", name: "Original", status: .canceled))
            try await client.moveTodo(id: "task", toProjectID: "exact-project")
            #expect(bridge.appleScriptScripts[0].contains("set notes of targetTodo to \"\""))
            #expect(bridge.appleScriptScripts[0].contains("set due date of targetTodo to missing value"))
            #expect(bridge.appleScriptScripts[0].contains("set status of targetTodo to canceled"))
            #expect(bridge.appleScriptScripts[2].contains("project id \"exact-project\""))
        }
    }

    @Test func realClientCreateAndUpdateExposePartialWrites() async throws {
        for hybrid in [false, true] {
            let bridge = MockJXAExecutor()
            bridge.appleScriptResponses = [.success("created-id"), .failure(ThingsError.operationFailed("tag failed")), .failure(ThingsError.operationFailed("tag failed"))]
            bridge.jsonResponses = try [.success(mutationResultJSON(success: true))]
            let client: any ThingsClientProtocol = hybrid ? HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: bridge) : ThingsClient(bridge: bridge)
            do { _ = try await client.createTodo(name: "A", notes: nil, when: nil, deadline: nil, tags: ["work"], project: nil, area: nil, checklistItems: []); Issue.record("Expected partial create") }
            catch let error as AppliedMutationError { #expect(error.id == "created-id"); #expect(error.fields == ["create"]) }
            do { try await client.updateTodo(id: "task", name: "Changed", notes: nil, dueDate: nil, tags: ["work"]); Issue.record("Expected partial update") }
            catch let error as AppliedMutationError { #expect(error.id == "task"); #expect(error.fields == ["title"]) }
        }
    }
}
