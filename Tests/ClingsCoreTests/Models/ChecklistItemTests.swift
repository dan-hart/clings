// ChecklistItemTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("ChecklistItem Model")
struct ChecklistItemTests {
    @Suite("Initialization")
    struct Initialization {
        @Test func withAllParameters() {
            let item = ChecklistItem(id: "c1", name: "Step 1", completed: true)

            #expect(item.id == "c1")
            #expect(item.name == "Step 1")
            #expect(item.completed)
        }

        @Test func withDefaultCompleted() {
            let item = ChecklistItem(id: "c1", name: "Step 1")

            #expect(!item.completed)
        }

        @Test func convenienceInit() {
            let item = ChecklistItem(name: "My Step")

            #expect(!item.id.isEmpty)
            #expect(item.name == "My Step")
            #expect(!item.completed)
        }

        @Test func convenienceInitWithCompleted() {
            let item = ChecklistItem(name: "Done Step", completed: true)

            #expect(!item.id.isEmpty)
            #expect(item.name == "Done Step")
            #expect(item.completed)
        }

        @Test func convenienceInitGeneratesUniqueIds() {
            let item1 = ChecklistItem(name: "Step 1")
            let item2 = ChecklistItem(name: "Step 2")

            #expect(item1.id != item2.id)
        }
    }

    @Suite("Codable")
    struct CodableTests {
        @Test func decodeFromJSON() throws {
            let json = TestData.checklistItemJSON.data(using: .utf8)!
            let decoder = JSONDecoder()

            let item = try decoder.decode(ChecklistItem.self, from: json)

            #expect(item.name == "Checklist from JSON")
            #expect(item.completed)
        }

        @Test func decodeFromMinimalJSON() throws {
            let json = TestData.checklistItemJSONMinimal.data(using: .utf8)!
            let decoder = JSONDecoder()

            let item = try decoder.decode(ChecklistItem.self, from: json)

            #expect(item.name == "Minimal checklist")
            #expect(!item.completed) // Default
            #expect(!item.id.isEmpty) // Generated
        }

        @Test func decodeWithMissingId() throws {
            let json = """
            {
                "name": "No ID",
                "completed": false
            }
            """.data(using: .utf8)!
            let decoder = JSONDecoder()

            let item = try decoder.decode(ChecklistItem.self, from: json)

            #expect(!item.id.isEmpty)
            #expect(item.name == "No ID")
        }

        @Test func encodeAndDecode() throws {
            let original = ChecklistItem(id: "test-id", name: "Test Item", completed: true)
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ChecklistItem.self, from: data)

            #expect(decoded.id == original.id)
            #expect(decoded.name == original.name)
            #expect(decoded.completed == original.completed)
        }
    }

    @Suite("Equatable and Hashable")
    struct EquatableHashable {
        @Test func equality() {
            let item1 = ChecklistItem(id: "c1", name: "Step", completed: false)
            let item2 = ChecklistItem(id: "c1", name: "Step", completed: false)
            let item3 = ChecklistItem(id: "c2", name: "Step", completed: false)

            #expect(item1 == item2)
            #expect(item1 != item3)
        }

        @Test func hashing() {
            let item1 = ChecklistItem(id: "c1", name: "Step", completed: false)
            let item2 = ChecklistItem(id: "c1", name: "Step", completed: false)

            var set = Set<ChecklistItem>()
            set.insert(item1)
            set.insert(item2)

            #expect(set.count == 1)
        }
    }

    @Suite("Test Data Fixtures")
    struct Fixtures {
        @Test func fixtures() {
            #expect(TestData.checklistItem1.completed)
            #expect(!TestData.checklistItem2.completed)
            #expect(!TestData.checklistItem3.completed)
        }
    }
}
