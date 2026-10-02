@testable import ClingsCLI
import ClingsCore
import Foundation
import Testing

struct BatchExecutionTests {
    @Test func acceptsEnvelopedPlanAndTagUndoPreservesUnrelatedLaterFields() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root, ids: ["a"])
            let saved = try BatchPlan(operation: .tag, todos: [await client.fetchTodo(id: "a")], tags: ["review"])
            let payload = try JSONSerialization.jsonObject(with: StateJSON.encoder().encode(saved))
            try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "success": true, "data": payload]).write(to: URL(fileURLWithPath: path))
            try await CommandTestSupport.withRuntime(client: client) {
                _ = try await CommandTestSupport.captureStandardOutput { try await BulkTagCommand.parse(["--execute-plan", path, "--yes"]).run() }
                client.todosByID["a"]?.name = "Later title"
                _ = try await CommandTestSupport.captureStandardOutput { try await UndoCommand.parse([]).run() }
                #expect(client.todosByID["a"]?.name == "Later title")
                #expect(client.todosByID["a"]?.tags.isEmpty == true)
            }
        }
    }

    @Test func refusesSelectionFlagsEvenWhenTheyEqualDefaults() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root, ids: ["a"])
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try BulkCompleteCommand.parse(["--execute-plan", path, "--list", "today", "--yes"])
                await #expect(throws: (any Error).self) { try await command.run() }
            }
            #expect(client.completedIDs.isEmpty)
        }
    }

    @Test func intentPersistenceFailurePreventsWrite() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root, ids: ["a"])
            let counter = SaveCounter()
            try await CommandTestSupport.withRuntime(client: client) {
                try await CommandRuntime.$persistPlan.withValue({ plan, path in
                    counter.count += 1
                    if counter.count == 2 {
                        throw ThingsError.operationFailed("disk full")
                    }
                    try plan.save(path: path)
                }) {
                    let command = try BulkCompleteCommand.parse(["--execute-plan", path, "--yes"])
                    await #expect(throws: (any Error).self) { try await command.run() }
                }
            }
            #expect(client.completedIDs.isEmpty)
            #expect(try BatchPlan.load(path: path).items[0].state == .pending)
        }
    }

    @Test func uncertainOriginalCanRetryButOtherStateConflicts() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root, ids: ["a"])
            var saved = try BatchPlan.load(path: path)
            saved.items[0].state = .uncertain
            try saved.save(path: path)
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try BulkCompleteCommand.parse(["--execute-plan", path, "--yes"])
                _ = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                #expect(client.completedIDs == ["a"])
                try saved.save(path: path)
                client.todosByID["a"]?.status = .canceled
                await #expect(throws: (any Error).self) { try await command.run() }
                #expect(try BatchPlan.load(path: path).items[0].state == .conflict)
                #expect(client.completedIDs == ["a"])
            }
        }
    }

    @Test func companionLockPreventsSecondExecutionAcrossConfigurations() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root, ids: ["a"])
            try await MutationLock.withPlanLock(path: path) {
                await #expect(throws: (any Error).self) {
                    try await MutationLock.withPlanLock(path: path) {}
                }
            }
        }
    }

    private func plan(client: RecordingThingsClient, root: URL, ids: [String] = ["a", "b"]) throws -> String {
        for id in ids {
            client.todosByID[id] = Todo(id: id, name: id, creationDate: Date(timeIntervalSinceReferenceDate: 1.123456789), modificationDate: Date(timeIntervalSinceReferenceDate: 2.987654321))
        }
        let plan = BatchPlan(operation: .complete, todos: ids.compactMap { client.todosByID[$0] })
        let path = root.appendingPathComponent("plan.json").path
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try plan.save(path: path)
        return path
    }

    @Test func partialBatchRetriesOnlyFailedAndGroupedUndoRetainsRemaining() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root)
            client.failedIDs = ["b"]
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try BulkCompleteCommand.parse(["--execute-plan", path, "--yes"])
                await #expect(throws: (any Error).self) { try await command.run() }
                let states = try BatchPlan.load(path: path).items.map(\.state)
                #expect(states == [.succeeded, .failed])
                client.failedIDs = []
                _ = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                #expect(client.completedIDs == ["a", "b"])
                client.failedIDs = ["b"]
                let undo = try UndoCommand.parse([])
                await #expect(throws: (any Error).self) { try await undo.run() }
                #expect(try UndoStore.latest()?.members?.map { $0.snapshot.id } == ["b"])
                #expect(client.todosByID["a"]?.status == .open)
            }
        }
    }

    @Test func rejectsDuplicateAndFieldStalePlansBeforeWrites() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root, ids: ["a"])
            var duplicate = try BatchPlan.load(path: path)
            duplicate.items.append(duplicate.items[0])
            try duplicate.save(path: path)
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try BulkCompleteCommand.parse(["--execute-plan", path, "--yes"])
                await #expect(throws: (any Error).self) { try await command.run() }
                duplicate.items.removeLast()
                try duplicate.save(path: path)
                client.todosByID["a"]?.name = "Changed but same ID"
                await #expect(throws: (any Error).self) { try await command.run() }
            }
            #expect(client.completedIDs.isEmpty)
        }
    }

    @Test func inProgressPersistenceFailureReconcilesWithoutRepeatingWrite() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root, ids: ["a"])
            let counter = SaveCounter()
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try BulkCompleteCommand.parse(["--execute-plan", path, "--yes"])
                try await CommandRuntime.$persistPlan.withValue({ plan, path in
                    counter.count += 1
                    if counter.count == 3 {
                        throw ThingsError.operationFailed("disk full")
                    }
                    try plan.save(path: path)
                }) {
                    await #expect(throws: (any Error).self) { try await command.run() }
                }
                #expect(try BatchPlan.load(path: path).items[0].state == .inProgress)
                _ = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                #expect(client.completedIDs == ["a"])
                #expect(try BatchPlan.load(path: path).items[0].state == .succeeded)
            }
        }
    }
}

private final class SaveCounter: @unchecked Sendable { var count = 0 }
