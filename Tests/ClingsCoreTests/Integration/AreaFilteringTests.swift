// AreaFilteringTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

/// Tests for area-based filtering in automation workflows.
/// Filters todos by area to separate work from personal tasks.
@Suite("Area Filtering")
struct AreaFilteringTests {
    @Suite("Exact Area Match")
    struct ExactAreaMatch {
        @Test func filterByAreaWithEmoji() throws {
            // Filter by area with emoji prefix: area = "🖥️ Work"
            let expr = try FilterParser.parse("area = '🖥️ Work'")

            #expect(expr.matches(WorkTestData.meetingAction), "Should match task with emoji area")
            #expect(expr.matches(WorkTestData.jiraTask), "Should match task with emoji area")
            #expect(!expr.matches(WorkTestData.personalTask), "Should not match different area")
        }

        @Test func filterByAreaExactMatchRequired() throws {
            // Partial match without emoji should not work
            let expr = try FilterParser.parse("area = 'Work'")

            #expect(!expr.matches(WorkTestData.meetingAction),
                    "Partial match without emoji should not match")
        }
    }

    @Suite("LIKE Pattern Matching")
    struct LIKEPatternMatching {
        @Test func filterByAreaLikePattern() throws {
            // Alternative: area LIKE '%Work%'
            let expr = try FilterParser.parse("area LIKE '%Work%'")

            #expect(expr.matches(WorkTestData.meetingAction), "LIKE pattern should match")
            #expect(expr.matches(WorkTestData.jiraTask), "LIKE pattern should match")
            #expect(!expr.matches(WorkTestData.personalTask), "Should not match different area")
        }

        @Test func filterByAreaStartsWithEmoji() throws {
            let expr = try FilterParser.parse("area LIKE '🖥️%'")

            #expect(expr.matches(WorkTestData.meetingAction), "Should match areas starting with emoji")
        }
    }

    @Suite("Area IS NULL")
    struct AreaIsNull {
        @Test func filterByMissingArea() throws {
            let todoNoArea = Todo(id: "no-area", name: "Test", area: nil)
            let expr = try FilterParser.parse("area IS NULL")

            #expect(expr.matches(todoNoArea), "Should match task without area")
            #expect(!expr.matches(WorkTestData.meetingAction), "Should not match task with area")
        }

        @Test func filterByPresentArea() throws {
            let todoNoArea = Todo(id: "no-area", name: "Test", area: nil)
            let expr = try FilterParser.parse("area IS NOT NULL")

            #expect(!expr.matches(todoNoArea), "Should not match task without area")
            #expect(expr.matches(WorkTestData.meetingAction), "Should match task with area")
        }
    }

    @Suite("Combined Area Filters")
    struct CombinedAreaFilters {
        @Test func filterByAreaAndStatus() throws {
            let expr = try FilterParser.parse("area LIKE '%Work%' AND status = open")

            #expect(expr.matches(WorkTestData.meetingAction), "Open task in Work area")
            #expect(expr.matches(WorkTestData.jiraTask), "Open task in Work area")
            #expect(!expr.matches(WorkTestData.completedTask), "Completed task should not match")
        }

        @Test func filterByAreaAndTags() throws {
            let expr = try FilterParser.parse("area LIKE '%Work%' AND tags CONTAINS 'meeting-action'")

            #expect(expr.matches(WorkTestData.meetingAction), "Has meeting-action tag in Work area")
            #expect(!expr.matches(WorkTestData.jiraTask), "Does not have meeting-action tag")
        }

        @Test func filterByMultipleAreas() throws {
            // Either work or personal
            let expr = try FilterParser.parse("area LIKE '%Work%' OR area LIKE '%Personal%'")

            #expect(expr.matches(WorkTestData.meetingAction), "Work area matches")
            #expect(expr.matches(WorkTestData.personalTask), "Personal area matches")
        }
    }

    @Suite("Case Sensitivity")
    struct CaseSensitivity {
        @Test func areaMatchIsCaseInsensitive() throws {
            // LIKE should be case-insensitive
            let expr = try FilterParser.parse("area LIKE '%WORK%'")

            #expect(expr.matches(WorkTestData.meetingAction),
                    "LIKE pattern matching should be case-insensitive")
        }
    }
}
