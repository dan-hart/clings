@testable import ClingsCLI
import ClingsCore
import Foundation
import Testing

struct BatchExecutionTests {
    @Test(arguments: [1, 20])
    func savedPlanUndoFollowsExecutionAndSurvivesNewerHistory(interveningCount: Int) async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root, ids: ["a"])
            var saved = try BatchPlan.load(path: path)
            saved.createdAt = Date(timeIntervalSinceReferenceDate: 1)
            try saved.save(path: path)
            try await CommandTestSupport.withRuntime(client: client) {
                for index in 0..<interveningCount {
                    let id = "intervening-\(index)"
                    client.todosByID[id] = Todo(id: id, name: id)
                    _ = try await CommandTestSupport.captureStandardOutput {
                        try await CompleteCommand.parse([id]).run()
                    }
                }
                _ = try await CommandTestSupport.captureStandardOutput {
                    try await BulkCompleteCommand.parse(["--execute-plan", path, "--yes"]).run()
                }
                #expect(try UndoStore.latest()?.todoID == saved.id)
                #expect(try UndoStore.list().count == min(interveningCount + 1, 20))
                #expect(try BatchPlan.load(path: path).items[0].undoRecorded)
                _ = try await CommandTestSupport.captureStandardOutput { try await UndoCommand.parse([]).run() }
                #expect(client.reopenedIDs == ["a"])
                #expect(client.todosByID["a"]?.status == .open)
                #expect(client.todosByID["intervening-\(interveningCount - 1)"]?.status == .completed)
            }
        }
    }

    @Test func resumedBatchUndoFollowsItsNewWritesWithoutReorderingNoOpRetries() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root)
            client.failedIDs = ["b"]
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try BulkCompleteCommand.parse(["--execute-plan", path, "--yes"])
                await #expect(throws: (any Error).self) { try await command.run() }
                let originalGroup = try #require(try UndoStore.latest())
                client.todosByID["intervening"] = Todo(id: "intervening", name: "Intervening")
                _ = try await CommandTestSupport.captureStandardOutput { try await CompleteCommand.parse(["intervening"]).run() }
                client.failedIDs = []
                _ = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                let resumedGroup = try #require(try UndoStore.latest())
                #expect(resumedGroup.id == originalGroup.id)
                #expect(resumedGroup.members?.map { $0.snapshot.id } == ["a", "b"])
                #expect(resumedGroup.createdAt > originalGroup.createdAt)
                _ = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                #expect(try UndoStore.latest()?.createdAt == resumedGroup.createdAt)
                #expect(client.completedIDs == ["a", "intervening", "b"])
                _ = try await CommandTestSupport.captureStandardOutput { try await UndoCommand.parse([]).run() }
                #expect(client.reopenedIDs == ["a", "b"])
                #expect(client.todosByID["intervening"]?.status == .completed)
            }
        }
    }

    @Test func journalFailureResumeRecordsUndoWithoutRepeatingSucceededWrite() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { root in
            let client = RecordingThingsClient()
            let path = try plan(client: client, root: root, ids: ["a"])
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try BulkCompleteCommand.parse(["--execute-plan", path, "--yes"])
                try await UndoStore.$beforeSave.withValue({ throw ThingsError.operationFailed("disk full") }) {
                    await #expect(throws: (any Error).self) { try await command.run() }
                    let saved = try BatchPlan.load(path: path)
                    #expect(saved.items[0].state == .succeeded)
                    #expect(saved.items[0].undoRecorded == false)
                    await #expect(throws: (any Error).self) { try await command.run() }
                }
                _ = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                #expect(client.completedIDs == ["a"])
                #expect(try BatchPlan.load(path: path).items[0].undoRecorded == true)
                #expect(try UndoStore.latest()?.members?.map { $0.snapshot.id } == ["a"])
                _ = try await CommandTestSupport.captureStandardOutput { try await UndoCommand.parse([]).run() }
                #expect(client.todosByID["a"]?.status == .open)
            }
        }
    }

    @Test(arguments: [BatchOperation.complete, .cancel, .tag, .move])
    func confirmationShowsExactFrozenChangesBeforePrompt(operation: BatchOperation) async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let client = RecordingThingsClient()
            client.projects = [Project(id: "destination-id", name: "Archive")]
            client.todosForList[.today] = [Todo(id: "exact-id", name: "Exact title", tags: [Tag(id: "old-tag", name: "old")], project: Project(id: "original-id", name: "Original"))]
            try await CommandTestSupport.withRuntime(client: client, inputs: ["no"]) {
                let (_, stderr) = try await CommandTestSupport.captureStandardError {
                    switch operation {
                    case .complete: try await BulkCompleteCommand.parse([]).run()
                    case .cancel: try await BulkCancelCommand.parse([]).run()
                    case .tag: try await BulkTagCommand.parse(["new"]).run()
                    case .move: try await BulkMoveCommand.parse(["--to", "Archive"]).run()
                    }
                }
                let prompt = try #require(stderr.range(of: "[y/N]"))
                let beforePrompt = String(stderr[..<prompt.lowerBound])
                #expect(beforePrompt.contains("exact-id"))
                #expect(beforePrompt.contains("Exact title"))
                switch operation {
                case .complete: #expect(beforePrompt.contains("open -> completed"))
                case .cancel: #expect(beforePrompt.contains("open -> canceled"))
                case .tag: #expect(beforePrompt.contains("[old] -> [new, old]"))
                case .move:
                    #expect(beforePrompt.contains("original-id -> destination-id"))
                    #expect(beforePrompt.contains("undo cannot restore project move"))
                }
            }
            #expect(client.completedIDs.isEmpty)
            #expect(client.updatedTodos.isEmpty)
            #expect(client.movedTodos.isEmpty)
        }
    }

    @Test func textDryRunShowsFinalTagsAndExactDestination() async throws {
        let client = RecordingThingsClient()
        client.projects = [Project(id: "destination-id", name: "Archive")]
        client.todosForList[.today] = [Todo(id: "exact-id", name: "Exact title", tags: [Tag(id: "old-tag", name: "old")])]
        try await CommandTestSupport.withRuntime(client: client) {
            let (_, tags) = try await CommandTestSupport.captureStandardOutput { try await BulkTagCommand.parse(["new", "--dry-run"]).run() }
            #expect(tags.contains("[old] -> [new, old]"))
            let (_, move) = try await CommandTestSupport.captureStandardOutput { try await BulkMoveCommand.parse(["--to", "Archive", "--dry-run"]).run() }
            #expect(move.contains("none -> destination-id"))
            #expect(move.contains("undo cannot restore project move"))
        }
    }

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
