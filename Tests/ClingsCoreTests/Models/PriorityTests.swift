// PriorityTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("Priority Enum")
struct PriorityTests {
    @Suite("Raw Values")
    struct RawValues {
        @Test func rawValues() {
            #expect(Priority.none.rawValue == 0)
            #expect(Priority.low.rawValue == 1)
            #expect(Priority.medium.rawValue == 2)
            #expect(Priority.high.rawValue == 3)
        }
    }

    @Suite("Symbols")
    struct Symbols {
        @Test func symbols() {
            #expect(Priority.none.symbol == "")
            #expect(Priority.low.symbol == "!")
            #expect(Priority.medium.symbol == "!!")
            #expect(Priority.high.symbol == "!!!")
        }
    }

    @Suite("Names")
    struct Names {
        @Test func names() {
            #expect(Priority.none.name == "none")
            #expect(Priority.low.name == "low")
            #expect(Priority.medium.name == "medium")
            #expect(Priority.high.name == "high")
        }
    }

    @Suite("String Parsing")
    struct StringParsing {
        @Test func parseFromName() {
            #expect(Priority(string: "low") == .low)
            #expect(Priority(string: "medium") == .medium)
            #expect(Priority(string: "high") == .high)
        }

        @Test func parseFromNameCaseInsensitive() {
            #expect(Priority(string: "LOW") == .low)
            #expect(Priority(string: "Medium") == .medium)
            #expect(Priority(string: "HIGH") == .high)
        }

        @Test func parseFromSymbol() {
            #expect(Priority(string: "!") == .low)
            #expect(Priority(string: "!!") == .medium)
            #expect(Priority(string: "!!!") == .high)
        }

        @Test func parseFromPrefixedName() {
            #expect(Priority(string: "!low") == .low)
            #expect(Priority(string: "!medium") == .medium)
            #expect(Priority(string: "!high") == .high)
        }

        @Test func parseEmpty() {
            // Empty string and "none" both return .none
            #expect(Priority(string: "") == Priority.none)
            #expect(Priority(string: "none") == Priority.none)
        }

        @Test func parseUnknown() {
            #expect(Priority(string: "urgent") == nil)
            #expect(Priority(string: "critical") == nil)
            #expect(Priority(string: "!!!!") == nil)
        }
    }

    @Suite("Comparable")
    struct ComparableTests {
        @Test func comparison() {
            #expect(Priority.none < Priority.low)
            #expect(Priority.low < Priority.medium)
            #expect(Priority.medium < Priority.high)

            #expect(!(Priority.high < Priority.low))
            #expect(!(Priority.medium < Priority.none))
        }

        @Test func sorting() {
            let priorities: [Priority] = [.high, .none, .medium, .low]
            let sorted = priorities.sorted()

            #expect(sorted == [.none, .low, .medium, .high])
        }
    }

    @Suite("Things Values")
    struct ThingsValues {
        @Test func thingsValues() {
            #expect(Priority.none.thingsValue == nil)
            #expect(Priority.low.thingsValue == 1)
            #expect(Priority.medium.thingsValue == 2)
            #expect(Priority.high.thingsValue == 3)
        }
    }

    @Suite("CaseIterable")
    struct CaseIterableTests {
        @Test func allCases() {
            let allCases = Priority.allCases
            #expect(allCases.count == 4)
            #expect(allCases[0] == .none)
            #expect(allCases[1] == .low)
            #expect(allCases[2] == .medium)
            #expect(allCases[3] == .high)
        }
    }

    @Suite("Codable")
    struct CodableTests {
        @Test func encodeAndDecode() throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            for priority in Priority.allCases {
                let data = try encoder.encode(priority)
                let decoded = try decoder.decode(Priority.self, from: data)
                #expect(decoded == priority)
            }
        }

        @Test func decodeFromInt() throws {
            let decoder = JSONDecoder()

            #expect(try decoder.decode(Priority.self, from: "0".data(using: .utf8)!) == .none)
            #expect(try decoder.decode(Priority.self, from: "1".data(using: .utf8)!) == .low)
            #expect(try decoder.decode(Priority.self, from: "2".data(using: .utf8)!) == .medium)
            #expect(try decoder.decode(Priority.self, from: "3".data(using: .utf8)!) == .high)
        }
    }
}
