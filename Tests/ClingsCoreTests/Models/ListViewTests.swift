// ListViewTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("ListView Enum")
struct ListViewTests {
    @Suite("Raw Values")
    struct RawValues {
        @Test func rawValues() {
            #expect(ListView.inbox.rawValue == "inbox")
            #expect(ListView.today.rawValue == "today")
            #expect(ListView.upcoming.rawValue == "upcoming")
            #expect(ListView.anytime.rawValue == "anytime")
            #expect(ListView.someday.rawValue == "someday")
            #expect(ListView.logbook.rawValue == "logbook")
            #expect(ListView.trash.rawValue == "trash")
        }
    }

    @Suite("Display Names")
    struct DisplayNames {
        @Test func displayNames() {
            #expect(ListView.inbox.displayName == "Inbox")
            #expect(ListView.today.displayName == "Today")
            #expect(ListView.upcoming.displayName == "Upcoming")
            #expect(ListView.anytime.displayName == "Anytime")
            #expect(ListView.someday.displayName == "Someday")
            #expect(ListView.logbook.displayName == "Logbook")
            #expect(ListView.trash.displayName == "Trash")
        }
    }

    @Suite("Things List Names")
    struct ThingsListNames {
        @Test func thingsListNames() {
            // thingsListName returns displayName for compatibility
            #expect(ListView.inbox.thingsListName == "Inbox")
            #expect(ListView.today.thingsListName == "Today")
            #expect(ListView.upcoming.thingsListName == "Upcoming")
            #expect(ListView.anytime.thingsListName == "Anytime")
            #expect(ListView.someday.thingsListName == "Someday")
            #expect(ListView.logbook.thingsListName == "Logbook")
            #expect(ListView.trash.thingsListName == "Trash")
        }
    }

    @Suite("JXA List Names")
    struct JXAListNames {
        @Test func jxaListNames() {
            #expect(ListView.inbox.jxaListName == "inbox")
            #expect(ListView.today.jxaListName == "today")
            #expect(ListView.upcoming.jxaListName == "upcoming")
            #expect(ListView.anytime.jxaListName == "anytime")
            #expect(ListView.someday.jxaListName == "someday")
            #expect(ListView.logbook.jxaListName == "logbook")
            #expect(ListView.trash.jxaListName == "trash")
        }
    }

    @Suite("CaseIterable")
    struct CaseIterableTests {
        @Test func allCases() {
            let allCases = ListView.allCases
            #expect(allCases.count == 7)
            #expect(allCases.contains(.inbox))
            #expect(allCases.contains(.today))
            #expect(allCases.contains(.upcoming))
            #expect(allCases.contains(.anytime))
            #expect(allCases.contains(.someday))
            #expect(allCases.contains(.logbook))
            #expect(allCases.contains(.trash))
        }
    }

    @Suite("Codable")
    struct CodableTests {
        @Test func encodeAndDecode() throws {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            for listView in ListView.allCases {
                let data = try encoder.encode(listView)
                let decoded = try decoder.decode(ListView.self, from: data)
                #expect(decoded == listView)
            }
        }

        @Test func decodeFromString() throws {
            let decoder = JSONDecoder()

            #expect(
                try decoder.decode(ListView.self, from: "\"inbox\"".data(using: .utf8)!) == .inbox
            )
            #expect(
                try decoder.decode(ListView.self, from: "\"today\"".data(using: .utf8)!) == .today
            )
            #expect(
                try decoder.decode(ListView.self, from: "\"logbook\"".data(using: .utf8)!) == .logbook
            )
        }
    }

    @Suite("Consistency")
    struct Consistency {
        @Test func jxaListNameMatchesRawValue() {
            for listView in ListView.allCases {
                #expect(listView.jxaListName == listView.rawValue)
            }
        }

        @Test func thingsListNameMatchesDisplayName() {
            for listView in ListView.allCases {
                #expect(listView.thingsListName == listView.displayName)
            }
        }
    }
}
