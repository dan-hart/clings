import ArgumentParser
@testable import ClingsCLI
import ClingsCore
import Foundation
import Testing

struct MutationSafetyTests {
    @Test func rootBoundaryRetainsRealClientPartialResultsIncludingProjects() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            for operation in ["create", "update", "restore", "project"] {
                try UndoStore.clear()
                let id = operation == "project" ? "created-project" : "task"
                let fields = operation == "update" || operation == "restore" ? ["title"] : ["create"]
                let outcome = try JSONSerialization.data(withJSONObject: ["success": false, "id": id, "appliedFields": fields, "error": "later assignment failed"])
                let todo = Todo(id: "task", name: "Original")
                let client = ThingsClient(bridge: FirstScriptPartialExecutor(outcome: String(decoding: outcome, as: UTF8.self), todo: todo))
                if operation == "restore" { try UndoStore.record(UndoEntry(operation: .update, todoID: id, snapshot: TodoSnapshot(todo: todo))) }
                let arguments: [String]
                switch operation {
                case "create": arguments = ["add", "Draft"]
                case "update": arguments = ["update", "task", "--name", "Changed"]
                case "project": arguments = ["project", "add", "Draft"]
                default: arguments = ["undo"]
                }
                try await CommandTestSupport.withRuntime(client: client) {
                    let (status, text) = try await CommandTestSupport.captureStandardOutput { await CommandBoundary.execute(arguments + ["--json"]) }
                    #expect(status == 2)
                    let response = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
                    #expect(response["schemaVersion"] as? Int == 1)
                    #expect(response["success"] as? Bool == false)
                    let data = try #require(response["data"] as? [String: Any])
                    #expect(data["id"] as? String == id)
                    #expect(data["applied"] as? Bool == true)
                    #expect(data["appliedFields"] as? [String] == fields)
                    if operation == "project" {
                        #expect(data["undoRecorded"] as? Bool == false)
                        #expect(try UndoStore.latest() == nil)
                        #expect(!(data["unsupportedUndo"] as? [String] ?? []).isEmpty)
                    }
                }
            }
        }
    }

    @Test func firstScriptPartialWritesCarryResultsAndPreserveUndoThroughRealClient() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            for operation in ["create", "update", "restore"] {
                try UndoStore.clear()
                let id = operation == "create" ? "created-id" : "task"
                let fields = operation == "create" ? ["create"] : ["title"]
                let outcome = try JSONSerialization.data(withJSONObject: [
                    "success": false, "id": id, "appliedFields": fields, "error": "later assignment rejected",
                ])
                let todo = Todo(id: "task", name: "Original", notes: "Original notes")
                let client = ThingsClient(bridge: FirstScriptPartialExecutor(outcome: String(decoding: outcome, as: UTF8.self), todo: todo))
                if operation == "restore" {
                    try UndoStore.record(UndoEntry(operation: .update, todoID: id, snapshot: TodoSnapshot(todo: todo)))
                }
                try await CommandTestSupport.withRuntime(client: client) {
                    do {
                        switch operation {
                        case "create": try await AddCommand.parse(["A", "--json"]).run()
                        case "update": try await UpdateCommand.parse([id, "--name", "Changed", "--notes", "Rejected", "--json"]).run()
                        default: try await UndoCommand.parse(["--json"]).run()
                        }
                        Issue.record("Expected first-script partial failure")
                    } catch let failure as CommandFailure {
                        #expect(failure.exitStatus == 2)
                        let data = try #require(failure.dataJSON)
                        let object = try #require(JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any])
                        #expect(object["id"] as? String == id)
                        #expect(object["applied"] as? Bool == true)
                        #expect(object["appliedFields"] as? [String] == fields)
                    }
                }
                #expect(try UndoStore.latest()?.todoID == id)
                #expect(try UndoStore.latest()?.operation == (operation == "create" ? .create : .update))
            }
        }
    }

    @Test func updateWithoutChangesDoesNotClaimApplied() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let client = RecordingThingsClient()
            client.todosByID["a"] = Todo(id: "a", name: "A")
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try UpdateCommand.parse(["a", "--json"])
                await #expect(throws: (any Error).self) { try await command.run() }
            }
            #expect(client.updatedTodos.isEmpty)
        }
    }

    @Test func confirmationAndForcedDeleteRestoreOriginalCompletedStatus() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let client = RecordingThingsClient()
            client.todosByID["a"] = Todo(id: "a", name: "A", status: .completed)
            try await CommandTestSupport.withRuntime(client: client, inputs: ["no"]) {
                _ = try await CommandTestSupport.captureStandardOutput { try await DeleteCommand.parse(["a"]).run() }
            }
            #expect(client.deletedIDs.isEmpty)
            try await CommandTestSupport.withRuntime(client: client) {
                _ = try await CommandTestSupport.captureStandardOutput { try await DeleteCommand.parse(["a", "--force"]).run() }
                _ = try await CommandTestSupport.captureStandardOutput { try await UndoCommand.parse([]).run() }
            }
            #expect(client.completedIDs == ["a"])
            #expect(client.reopenedIDs.isEmpty)
        }
    }

    @Test func supportedUndoRestoresNullFieldsAndPriorClosedStatus() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let prior = Todo(id: "a", name: "Original", status: .canceled, tags: [], creationDate: Date(timeIntervalSinceReferenceDate: 123_456_789.123456), modificationDate: Date(timeIntervalSinceReferenceDate: 987_654_321.987654))
            let client = RecordingThingsClient()
            client.todosByID["a"] = Todo(id: "a", name: "Changed", notes: "Added", status: .completed, dueDate: Date())
            try UndoStore.record(UndoEntry(operation: .update, todoID: "a", snapshot: TodoSnapshot(todo: prior)))
            try await CommandTestSupport.withRuntime(client: client) {
                let undo = try UndoCommand.parse([])
                _ = try await CommandTestSupport.captureStandardOutput { try await undo.run() }
            }
            #expect(client.todosByID["a"]?.name == "Original")
            #expect(client.todosByID["a"]?.notes == nil)
            #expect(client.todosByID["a"]?.dueDate == nil)
            #expect(client.todosByID["a"]?.status == .canceled)
            #expect(client.todosByID["a"]?.tags.isEmpty == true)
        }
    }

    @Test func journalFailureReportsAppliedInsteadOfFalseSuccess() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let client = RecordingThingsClient()
            client.todosByID["a"] = Todo(id: "a", name: "A")
            try await CommandTestSupport.withRuntime(client: client) {
                try await UndoStore.$beforeSave.withValue({ throw ThingsError.operationFailed("disk full") }) {
                    do { try await CompleteCommand.parse(["a", "--json"]).run(); Issue.record("Expected storage failure") }
                    catch let failure as CommandFailure {
                        #expect(failure.exitStatus == 2)
                        let object = try JSONSerialization.jsonObject(with: Data((failure.dataJSON ?? "").utf8)) as? [String: Any]
                        #expect(object?["applied"] as? Bool == true)
                        #expect(object?["undoRecorded"] as? Bool == false)
                    }
                }
            }
            #expect(client.completedIDs == ["a"])
        }
    }

    @Test func batchDryRunEmitsReusableExactIDPlan() async throws {
        let client = RecordingThingsClient()
        client.todosForList[.today] = [Todo(id: "a", name: "A")]
        try await CommandTestSupport.withRuntime(client: client) {
            let command = try BulkCompleteCommand.parse(["--dry-run", "--json"])
            let (_, output) = try await CommandTestSupport.captureStandardOutput { try await command.run() }
            let data = Data(output.utf8)
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(object?["schemaVersion"] as? Int == 1)
            #expect((object?["data"] as? [String: Any])?["operation"] as? String == "complete")
        }
        #expect(client.completedIDs.isEmpty)
    }

    @Test func deleteRefusesUnconfirmedNoninteractiveWrite() async throws {
        let client = RecordingThingsClient()
        client.todosByID["a"] = Todo(id: "a", name: "A")
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try DeleteCommand.parse(["a"])
                await #expect(throws: (any Error).self) { try await command.run() }
            }
        }
        #expect(client.deletedIDs.isEmpty)
    }

    @Test func failedUndoKeepsJournalEntry() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try UndoStore.record(UndoEntry(operation: .create, todoID: "a", snapshot: nil))
            let client = RecordingThingsClient()
            client.error = ThingsError.operationFailed("unavailable")
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try UndoCommand.parse([])
                await #expect(throws: (any Error).self) { try await command.run() }
            }
            #expect(try UndoStore.latest()?.todoID == "a")
        }
    }

    @Test func pickJSONRejectsBeforeAnyReadOrWrite() async throws {
        let client = RecordingThingsClient()
        try await CommandTestSupport.withRuntime(client: client, inputs: ["1"]) {
            let command = try PickCompleteCommand.parse(["x", "--json"])
            await #expect(throws: (any Error).self) { try await command.run() }
        }
        #expect(client.searchQueries.isEmpty)
        #expect(client.completedIDs.isEmpty)
    }
}

private struct FirstScriptPartialExecutor: JXAExecuting {
    let outcome: String
    let todo: Todo
    func execute(_: String) async throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try String(decoding: encoder.encode(todo), as: UTF8.self)
    }

    func executeJSON<T: Decodable & Sendable>(_: String, as type: T.Type) async throws -> T {
        try JSONDecoder().decode(type, from: Data(outcome.utf8))
    }

    func executeAppleScript(_: String) async throws -> String {
        outcome
    }

    func isThingsRunning() async -> Bool {
        true
    }
}
