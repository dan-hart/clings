// UndoStoreTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("UndoStore", .serialized)
struct UndoStoreTests {
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
            #expect((try UndoStore.latest())?.operation == .update)

            let popped = try UndoStore.popLatest()
            #expect(popped?.todoID == TestData.todoOpen.id)
            #expect((try UndoStore.latest()) == nil)
        }
    }

    @Test func keepsOnlyMostRecentEntries() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { _ in
            for index in 0..<30 {
                try UndoStore.record(UndoEntry(operation: .complete, todoID: "todo-\(index)", snapshot: nil))
            }

            let entries = try UndoStore.list()
            #expect(entries.count == 20)
            #expect(entries.first?.todoID == "todo-29")
            #expect(entries.last?.todoID == "todo-10")
        }
    }
}
