// AreaFilteringTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

/// Tests for area-based filtering as used in ua-conductor workflows.
/// ua-conductor filters todos by area to separate work from personal tasks.
@Suite("Area Filtering")
struct AreaFilteringTests {
    @Suite("Exact Area Match")
    struct ExactAreaMatch {
        @Test func filterByAreaWithEmoji() throws {
            // ua-conductor uses: area = "🖥️ Under Armour"
            let expr = try FilterParser.parse("area = '🖥️ Under Armour'")

            #expect(expr.matches(UATestData.meetingAction), "Should match task with emoji area")
            #expect(expr.matches(UATestData.jiraTask), "Should match task with emoji area")
            #expect(!expr.matches(UATestData.personalTask), "Should not match different area")
        }

        @Test func filterByAreaExactMatchRequired() throws {
            // Partial match without emoji should not work
            let expr = try FilterParser.parse("area = 'Under Armour'")

            #expect(!expr.matches(UATestData.meetingAction),
                    "Partial match without emoji should not match")
        }
    }

    @Suite("LIKE Pattern Matching")
    struct LIKEPatternMatching {
        @Test func filterByAreaLikePattern() throws {
            // ua-conductor alternative: area LIKE '%Under Armour%'
            let expr = try FilterParser.parse("area LIKE '%Under Armour%'")

            #expect(expr.matches(UATestData.meetingAction), "LIKE pattern should match")
            #expect(expr.matches(UATestData.jiraTask), "LIKE pattern should match")
            #expect(!expr.matches(UATestData.personalTask), "Should not match different area")
        }

        @Test func filterByAreaStartsWithEmoji() throws {
            let expr = try FilterParser.parse("area LIKE '🖥️%'")

            #expect(expr.matches(UATestData.meetingAction), "Should match areas starting with emoji")
        }
    }

    @Suite("Area IS NULL")
    struct AreaIsNull {
        @Test func filterByMissingArea() throws {
            let todoNoArea = Todo(id: "no-area", name: "Test", area: nil)
            let expr = try FilterParser.parse("area IS NULL")

            #expect(expr.matches(todoNoArea), "Should match task without area")
            #expect(!expr.matches(UATestData.meetingAction), "Should not match task with area")
        }

        @Test func filterByPresentArea() throws {
            let todoNoArea = Todo(id: "no-area", name: "Test", area: nil)
            let expr = try FilterParser.parse("area IS NOT NULL")

            #expect(!expr.matches(todoNoArea), "Should not match task without area")
            #expect(expr.matches(UATestData.meetingAction), "Should match task with area")
        }
    }

    @Suite("Combined Area Filters")
    struct CombinedAreaFilters {
        @Test func filterByAreaAndStatus() throws {
            let expr = try FilterParser.parse("area LIKE '%Under Armour%' AND status = open")

            #expect(expr.matches(UATestData.meetingAction), "Open task in UA area")
            #expect(expr.matches(UATestData.jiraTask), "Open task in UA area")
            #expect(!expr.matches(UATestData.completedTask), "Completed task should not match")
        }

        @Test func filterByAreaAndTags() throws {
            let expr = try FilterParser.parse("area LIKE '%Under Armour%' AND tags CONTAINS 'meeting-action'")

            #expect(expr.matches(UATestData.meetingAction), "Has meeting-action tag in UA area")
            #expect(!expr.matches(UATestData.jiraTask), "Does not have meeting-action tag")
        }

        @Test func filterByMultipleAreas() throws {
            // Either work or personal
            let expr = try FilterParser.parse("area LIKE '%Under Armour%' OR area LIKE '%Personal%'")

            #expect(expr.matches(UATestData.meetingAction), "UA area matches")
            #expect(expr.matches(UATestData.personalTask), "Personal area matches")
        }
    }

    @Suite("Case Sensitivity")
    struct CaseSensitivity {
        @Test func areaMatchIsCaseInsensitive() throws {
            // LIKE should be case-insensitive
            let expr = try FilterParser.parse("area LIKE '%UNDER ARMOUR%'")

            #expect(expr.matches(UATestData.meetingAction),
                    "LIKE pattern matching should be case-insensitive")
        }
    }
}
