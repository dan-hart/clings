// AreaTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("Area Model")
struct AreaTests {
    @Suite("Initialization")
    struct Initialization {
        @Test func withAllParameters() {
            let tag = Tag(name: "work")
            let area = Area(id: "a1", name: "Work Area", tags: [tag])

            #expect(area.id == "a1")
            #expect(area.name == "Work Area")
            #expect(area.tags.count == 1)
            #expect(area.tags.first?.name == "work")
        }

        @Test func withDefaults() {
            let area = Area(id: "a1", name: "Simple Area")

            #expect(area.id == "a1")
            #expect(area.name == "Simple Area")
            #expect(area.tags.isEmpty)
        }
    }

    @Suite("Codable")
    struct CodableTests {
        @Test func decodeFromJSON() throws {
            let json = TestData.areaJSON.data(using: .utf8)!
            let decoder = JSONDecoder()

            let area = try decoder.decode(Area.self, from: json)

            #expect(area.id == "json-area")
            #expect(area.name == "JSON Area")
            #expect(area.tags.isEmpty)
        }

        @Test func decodeWithTags() throws {
            let json = """
            {
                "id": "a1",
                "name": "Work",
                "tags": [{"id": "t1", "name": "priority"}]
            }
            """.data(using: .utf8)!
            let decoder = JSONDecoder()

            let area = try decoder.decode(Area.self, from: json)

            #expect(area.tags.count == 1)
            #expect(area.tags.first?.name == "priority")
        }

        @Test func decodeWithMissingTags() throws {
            let json = """
            {
                "id": "a1",
                "name": "No Tags"
            }
            """.data(using: .utf8)!
            let decoder = JSONDecoder()

            let area = try decoder.decode(Area.self, from: json)

            #expect(area.tags.isEmpty)
        }

        @Test func encodeAndDecode() throws {
            let original = Area(id: "test-id", name: "Test Area", tags: [Tag(name: "test")])
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(Area.self, from: data)

            #expect(decoded.id == original.id)
            #expect(decoded.name == original.name)
            #expect(decoded.tags.count == original.tags.count)
        }
    }

    @Suite("Equatable and Hashable")
    struct EquatableHashable {
        @Test func equality() {
            let area1 = Area(id: "a1", name: "Work")
            let area2 = Area(id: "a1", name: "Work")
            let area3 = Area(id: "a2", name: "Work")

            #expect(area1 == area2)
            #expect(area1 != area3)
        }

        @Test func hashing() {
            let area1 = Area(id: "a1", name: "Work")
            let area2 = Area(id: "a1", name: "Work")

            var set = Set<Area>()
            set.insert(area1)
            set.insert(area2)

            #expect(set.count == 1)
        }
    }

    @Suite("Test Data Fixtures")
    struct Fixtures {
        @Test func personalAreaFixture() {
            let area = TestData.personalArea
            #expect(area.name == "Personal")
            #expect(!area.tags.isEmpty)
        }

        @Test func workAreaFixture() {
            let area = TestData.workArea
            #expect(area.name == "Work")
            #expect(!area.tags.isEmpty)
        }

        @Test func allAreasFixture() {
            #expect(TestData.allAreas.count == 2)
        }
    }
}
