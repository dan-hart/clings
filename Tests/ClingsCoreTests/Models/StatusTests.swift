// StatusTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("Status Enum")
struct StatusTests {
    @Suite("Raw Values")
    struct RawValues {
        @Test func rawValues() {
            #expect(Status.open.rawValue == "open")
            #expect(Status.completed.rawValue == "completed")
            #expect(Status.canceled.rawValue == "canceled")
        }
    }

    @Suite("Display Names")
    struct DisplayNames {
        @Test func displayNames() {
            #expect(Status.open.displayName == "Open")
            #expect(Status.completed.displayName == "Completed")
            #expect(Status.canceled.displayName == "Canceled")
        }
    }

    @Suite("Things Status Parsing")
    struct ThingsStatusParsing {
        @Test func thingsStatusOpen() {
            #expect(Status(thingsStatus: "open") == .open)
            #expect(Status(thingsStatus: "Open") == .open)
            #expect(Status(thingsStatus: "OPEN") == .open)
            #expect(Status(thingsStatus: "") == .open)
        }

        @Test func thingsStatusCompleted() {
            #expect(Status(thingsStatus: "completed") == .completed)
            #expect(Status(thingsStatus: "Completed") == .completed)
            #expect(Status(thingsStatus: "COMPLETED") == .completed)
        }

        @Test func thingsStatusCanceled() {
            #expect(Status(thingsStatus: "canceled") == .canceled)
            #expect(Status(thingsStatus: "Canceled") == .canceled)
            #expect(Status(thingsStatus: "cancelled") == .canceled)
            #expect(Status(thingsStatus: "Cancelled") == .canceled)
        }

        @Test func thingsStatusUnknown() {
            #expect(Status(thingsStatus: "unknown") == nil)
            #expect(Status(thingsStatus: "pending") == nil)
            #expect(Status(thingsStatus: "active") == nil)
        }
    }

    @Suite("CaseIterable")
    struct CaseIterableTests {
        @Test func allCases() {
            let allCases = Status.allCases
            #expect(allCases.count == 3)
            #expect(allCases.contains(.open))
            #expect(allCases.contains(.completed))
            #expect(allCases.contains(.canceled))
        }
    }

    @Suite("Codable")
    struct CodableTests {
        @Test func encodeAndDecode() throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            for status in Status.allCases {
                let data = try encoder.encode(status)
                let decoded = try decoder.decode(Status.self, from: data)
                #expect(decoded == status)
            }
        }

        @Test func decodeFromString() throws {
            let decoder = JSONDecoder()

            let openData = "\"open\"".data(using: .utf8)!
            #expect(try decoder.decode(Status.self, from: openData) == .open)

            let completedData = "\"completed\"".data(using: .utf8)!
            #expect(try decoder.decode(Status.self, from: completedData) == .completed)

            let canceledData = "\"canceled\"".data(using: .utf8)!
            #expect(try decoder.decode(Status.self, from: canceledData) == .canceled)
        }
    }
}
