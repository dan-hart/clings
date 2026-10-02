@testable import ClingsCore
import Foundation
import Testing

struct MutationAutomationTests {
    @Test func projectScriptTracksAssignmentsThroughRealExecutor() async throws {
        let create = JXAScripts.createProject(name: "Documentation", when: Date(), deadline: Date())
        let script = """
        (() => {
            const Application = () => ({ make: () => ({
                id: () => 'project-id',
                name: () => 'Documentation',
                set activationDate(value) {},
                set dueDate(value) { throw new Error('deadline rejected'); }
            }) });
            return \(create);
        })()
        """
        let result = try await JXABridge(timeout: 3).executeJSON(script, as: MutationResult.self)
        #expect(result.success == false)
        #expect(result.id == "project-id")
        #expect(result.appliedFields == ["create", "schedule"])
        #expect(result.error?.contains("deadline rejected") == true)
    }

    @Test func projectCreationRetainsPartialIDAndCompletedFields() async throws {
        for hybrid in [false, true] {
            for tagFailure in [false, true] {
                let bridge = MockJXAExecutor()
                bridge.jsonResponses = [.success(tagFailure
                    ? #"{"success":true,"id":"project-id","appliedFields":["create"]}"#
                    : #"{"success":false,"id":"project-id","appliedFields":["create","schedule"],"error":"deadline rejected"}"#)]
                bridge.appleScriptResponses = [.failure(ThingsError.operationFailed("tags rejected"))]
                let client: any ThingsClientProtocol = hybrid ? HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: bridge) : ThingsClient(bridge: bridge)
                do {
                    _ = try await client.createProject(name: "Documentation", notes: nil, when: nil, deadline: nil, tags: tagFailure ? ["docs"] : [], area: nil)
                    Issue.record("Expected partial project creation")
                } catch let error as AppliedMutationError {
                    #expect(error.id == "project-id")
                    #expect(error.fields == (tagFailure ? ["create"] : ["create", "schedule"]))
                } catch {
                    Issue.record("Lost partial project outcome: \(error)")
                }
            }
        }
    }

    @Test func trackedClientsRejectMalformedFirstScriptOutput() async throws {
        for hybrid in [false, true] {
            let bridge = MockJXAExecutor()
            bridge.appleScriptResponses = [.success("unexpected raw ID"), .success("ok"), .success("ok")]
            let client: any ThingsClientProtocol = hybrid ? HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: bridge) : ThingsClient(bridge: bridge)
            await #expect(throws: (any Error).self) {
                _ = try await client.createTodo(name: "A", notes: nil, when: nil, deadline: nil, tags: [], project: nil, area: nil, checklistItems: [])
            }
            await #expect(throws: (any Error).self) {
                try await client.restoreTodo(TodoSnapshot(id: "task", name: "Original", status: .open))
            }
        }
    }

    @Test func trackedAppleScriptReportsPartialOutcomeThroughRealExecutor() async throws {
        let script = JXAScripts.trackedAppleScript(id: nil, body: """
        set mutationID to "created\\"id"
        set end of appliedFields to "create"
        error "later \\"assignment\\" failed"
        """)
        let output = try await JXABridge(timeout: 3).executeAppleScript(script)
        let result = try MutationResult.appleScript(output)
        #expect(result.success == false)
        #expect(result.id == "created\"id")
        #expect(result.appliedFields == ["create"])
        #expect(result.error?.contains("later \"assignment\" failed") == true)
    }

    @Test func updateScriptTracksAssignmentBeforeLaterSetterFailure() async throws {
        let update = JXAScripts.updateTodo(id: "task", name: "Changed", notes: "Rejected")
        let script = """
        (() => {
            const Application = () => ({ toDos: { byId: () => ({
                exists: () => true,
                set name(value) {},
                set notes(value) { throw new Error('notes rejected'); }
            }) } });
            return \(update);
        })()
        """
        let result = try await JXABridge(timeout: 3).executeJSON(script, as: MutationResult.self)
        #expect(result.success == false)
        #expect(result.id == "task")
        #expect(result.appliedFields == ["title"])
        #expect(result.error?.contains("notes rejected") == true)
    }

    @Test func firstScriptsExposeCreatedIDAndAppliedFieldsOnFailure() async throws {
        for hybrid in [false, true] {
            let bridge = MockJXAExecutor()
            bridge.appleScriptResponses = [
                .success("{\"success\":false,\"id\":\"created-id\",\"appliedFields\":[\"create\",\"schedule\"],\"error\":\"deadline rejected\"}"),
                .success("{\"success\":false,\"id\":\"task\",\"appliedFields\":[\"title\"],\"error\":\"notes rejected\"}"),
            ]
            bridge.jsonResponses = [.success("{\"success\":false,\"id\":\"task\",\"appliedFields\":[\"title\"],\"error\":\"notes rejected\"}")]
            let client: any ThingsClientProtocol = hybrid ? HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: bridge) : ThingsClient(bridge: bridge)
            do {
                _ = try await client.createTodo(name: "A", notes: nil, when: Date(), deadline: Date(), tags: [], project: nil, area: nil, checklistItems: [])
                Issue.record("Expected partial create from first script")
            } catch let error as AppliedMutationError {
                #expect(error.id == "created-id")
                #expect(error.fields == ["create", "schedule"])
            }
            do {
                try await client.updateTodo(id: "task", name: "Changed", notes: "Rejected", dueDate: nil, tags: nil)
                Issue.record("Expected partial update from first script")
            } catch let error as AppliedMutationError {
                #expect(error.id == "task")
                #expect(error.fields == ["title"])
            }
            do {
                try await client.restoreTodo(TodoSnapshot(id: "task", name: "Original", notes: "Rejected", status: .open))
                Issue.record("Expected partial restore from first script")
            } catch let error as AppliedMutationError {
                #expect(error.id == "task")
                #expect(error.fields == ["title"])
            }
            #expect(bridge.appleScriptScripts.count == 2)
        }
    }

    @Test func restoreTagFailureReportsFieldsAlreadyRestored() async throws {
        for hybrid in [false, true] {
            let bridge = MockJXAExecutor()
            bridge.appleScriptResponses = try [.success(mutationResultJSON(success: true, id: "task", appliedFields: ["title", "notes", "deadline", "status"])), .failure(ThingsError.operationFailed("tag failed"))]
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
            bridge.appleScriptResponses = try [.success(mutationResultJSON(success: true, id: "task", appliedFields: ["title", "notes", "deadline", "status"])), .success("ok"), .success("ok")]
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
            bridge.appleScriptResponses = try [.success(mutationResultJSON(success: true, id: "created-id", appliedFields: ["create"])), .failure(ThingsError.operationFailed("tag failed")), .failure(ThingsError.operationFailed("tag failed"))]
            bridge.jsonResponses = try [.success(mutationResultJSON(success: true))]
            let client: any ThingsClientProtocol = hybrid ? HybridThingsClient(database: MockThingsDatabaseReader(), jxaBridge: bridge) : ThingsClient(bridge: bridge)
            do { _ = try await client.createTodo(name: "A", notes: nil, when: nil, deadline: nil, tags: ["work"], project: nil, area: nil, checklistItems: []); Issue.record("Expected partial create") }
            catch let error as AppliedMutationError { #expect(error.id == "created-id"); #expect(error.fields == ["create"]) }
            do { try await client.updateTodo(id: "task", name: "Changed", notes: nil, dueDate: nil, tags: ["work"]); Issue.record("Expected partial update") }
            catch let error as AppliedMutationError { #expect(error.id == "task"); #expect(error.fields == ["title"]) }
        }
    }
}
