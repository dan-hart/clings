// UndoStoreTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import ClingsCore
import Darwin
import Foundation
import Testing

@Suite("UndoStore", .serialized)
struct UndoStoreTests {
    @Test func releasedMutationLockIsNotRetainedByInheritedDescriptor() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { root in
            var inherited: Int32 = -1
            defer {
                if inherited >= 0 {
                    close(inherited)
                }
            }
            try MutationLock.withLock {
                let lockPath = root.appendingPathComponent("mutation.lock").resolvingSymlinksInPath().path
                var lockInfo = stat()
                #expect(stat(lockPath, &lockInfo) == 0)
                for descriptor: Int32 in 0 ..< 1024 {
                    var descriptorInfo = stat()
                    if fstat(descriptor, &descriptorInfo) == 0, descriptorInfo.st_ino == lockInfo.st_ino, descriptorInfo.st_dev == lockInfo.st_dev {
                        inherited = dup(descriptor); break
                    }
                }
                #expect(inherited >= 0)
            }
            // dup shares the open-file description exactly as fork inheritance does.
            try MutationLock.withLock {}
        }
    }

    @Test func legacyHistoryIDsAreStableAndPrecisionRoundTrips() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { root in
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let legacy = #"[{"operation":"cancel","todoID":"a","snapshot":null,"createdAt":"2026-10-01T12:00:00Z"}]"#
            try Data(legacy.utf8).write(to: root.appendingPathComponent("undo-history.json"))
            let first = try #require(try UndoStore.latest())
            #expect(try UndoStore.latest()?.id == first.id)
            let date = Date(timeIntervalSinceReferenceDate: 123_456_789.123456)
            let todo = Todo(id: "b", name: "B", creationDate: date, modificationDate: date)
            let plan = BatchPlan(operation: .complete, todos: [todo])
            let decoded = try StateJSON.decoder().decode(BatchPlan.self, from: StateJSON.encoder().encode(plan))
            #expect(decoded.items[0].snapshot.matches(todo))
            #expect(decoded.items[0].snapshot.modificationDate?.timeIntervalSinceReferenceDate == date.timeIntervalSinceReferenceDate)
        }
    }

    @Test func recordsAndPopsMostRecentEntry() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { _ in
            let snapshot = TodoSnapshot(
                id: TestData.todoOpen.id,
                name: TestData.todoOpen.name,
                notes: TestData.todoOpen.notes,
                dueDate: TestData.todoOpen.dueDate,
                tags: TestData.todoOpen.tags.map(\.name),
                status: TestData.todoOpen.status,
                projectName: TestData.todoOpen.project?.name,
                areaName: TestData.todoOpen.area?.name
            )
            let entry = UndoEntry(
                operation: .update,
                todoID: TestData.todoOpen.id,
                snapshot: snapshot
            )

            try UndoStore.record(entry)
            #expect(try (UndoStore.latest())?.operation == .update)

            let popped = try UndoStore.popLatest()
            #expect(popped?.todoID == TestData.todoOpen.id)
            #expect(try (UndoStore.latest()) == nil)
        }
    }

    @Test func keepsOnlyMostRecentEntries() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { _ in
            for index in 0 ..< 30 {
                try UndoStore.record(UndoEntry(operation: .complete, todoID: "todo-\(index)", snapshot: nil))
            }

            let entries = try UndoStore.list()
            #expect(entries.count == 20)
            #expect(entries.first?.todoID == "todo-29")
            #expect(entries.last?.todoID == "todo-10")
        }
    }
}
