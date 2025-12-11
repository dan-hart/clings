// TagTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

// Use typealias to avoid conflict with Testing.Tag
typealias ThingsTag = ClingsCore.Tag

@Suite("Tag Model")
struct TagTests {
    @Suite("Initialization")
    struct Initialization {
        @Test func initWithIdAndName() {
            let tag = ThingsTag(id: "t1", name: "work")

            #expect(tag.id == "t1")
            #expect(tag.name == "work")
        }

        @Test func convenienceInit() {
            let tag = ThingsTag(name: "urgent")

            #expect(!tag.id.isEmpty)
            #expect(tag.name == "urgent")
        }

        @Test func convenienceInitGeneratesUniqueIds() {
            let tag1 = ThingsTag(name: "tag1")
            let tag2 = ThingsTag(name: "tag2")

            #expect(tag1.id != tag2.id)
        }
    }

    @Suite("Codable")
    struct CodableTests {
        @Test func decodeFromJSON() throws {
            let json = TestData.tagJSON.data(using: .utf8)!
            let decoder = JSONDecoder()

            let tag = try decoder.decode(ThingsTag.self, from: json)

            #expect(tag.id == "json-tag")
            #expect(tag.name == "json-tag")
        }

        @Test func encodeAndDecode() throws {
            let original = ThingsTag(id: "test-id", name: "test-tag")
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ThingsTag.self, from: data)

            #expect(decoded.id == original.id)
            #expect(decoded.name == original.name)
        }
    }

    @Suite("Equatable and Hashable")
    struct EquatableHashable {
        @Test func equality() {
            let tag1 = ThingsTag(id: "t1", name: "work")
            let tag2 = ThingsTag(id: "t1", name: "work")
            let tag3 = ThingsTag(id: "t2", name: "work")

            #expect(tag1 == tag2)
            #expect(tag1 != tag3)
        }

        @Test func hashing() {
            let tag1 = ThingsTag(id: "t1", name: "work")
            let tag2 = ThingsTag(id: "t1", name: "work")

            var set = Set<ThingsTag>()
            set.insert(tag1)
            set.insert(tag2)

            #expect(set.count == 1)
        }
    }

    @Suite("Test Data Fixtures")
    struct Fixtures {
        @Test func workTagFixture() {
            let tag = TestData.workTag
            #expect(tag.name == "work")
        }

        @Test func urgentTagFixture() {
            let tag = TestData.urgentTag
            #expect(tag.name == "urgent")
        }

        @Test func homeTagFixture() {
            let tag = TestData.homeTag
            #expect(tag.name == "home")
        }

        @Test func errandsTagFixture() {
            let tag = TestData.errandsTag
            #expect(tag.name == "errands")
        }

        @Test func allTagsFixture() {
            #expect(TestData.allTags.count == 4)
        }
    }
}
