// FilterDSLRealWorldTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

/// Tests for filter DSL patterns used in ua-conductor production workflows.
/// These tests verify the filter expressions used in bulk operations and automation.
@Suite("Filter DSL Real World")
struct FilterDSLRealWorldTests {
    @Suite("Tag-Based Filters")
    struct TagBasedFilters {
        @Test func filterByMeetingActionTag() throws {
            // ua-conductor pattern: tags CONTAINS 'meeting-action'
            let expr = try FilterParser.parse("tags CONTAINS 'meeting-action'")

            #expect(expr.matches(UATestData.meetingAction))
            #expect(!expr.matches(UATestData.jiraTask))
        }

        @Test func filterByMultipleTags() throws {
            // Find tasks with both jira and review tags
            let expr = try FilterParser.parse("tags CONTAINS 'jira' AND tags CONTAINS 'review'")

            #expect(expr.matches(UATestData.jiraTask))
            #expect(!expr.matches(UATestData.meetingAction))
        }

        @Test func filterByAnyOfTags() throws {
            // Find tasks with either tag
            let expr = try FilterParser.parse("tags CONTAINS 'jira' OR tags CONTAINS 'meeting-action'")

            #expect(expr.matches(UATestData.jiraTask))
            #expect(expr.matches(UATestData.meetingAction))
            #expect(!expr.matches(UATestData.personalTask))
        }
    }

    @Suite("Status Filters")
    struct StatusFilters {
        @Test func filterOpenTasks() throws {
            let expr = try FilterParser.parse("status = open")

            #expect(expr.matches(UATestData.meetingAction))
            #expect(expr.matches(UATestData.jiraTask))
            #expect(!expr.matches(UATestData.completedTask))
        }

        @Test func filterNotCompleted() throws {
            let expr = try FilterParser.parse("status != completed")

            #expect(expr.matches(UATestData.meetingAction))
            #expect(!expr.matches(UATestData.completedTask))
        }

        @Test func filterCompletedOrCanceled() throws {
            let expr = try FilterParser.parse("status = completed OR status = canceled")

            #expect(expr.matches(UATestData.completedTask))
        }
    }

    @Suite("Project Filters")
    struct ProjectFilters {
        @Test func filterByProjectName() throws {
            let expr = try FilterParser.parse("project = 'Mobile App'")

            #expect(expr.matches(UATestData.meetingAction))
            #expect(expr.matches(UATestData.jiraTask))
            #expect(!expr.matches(UATestData.personalTask))
        }

        @Test func filterNoProject() throws {
            let expr = try FilterParser.parse("project IS NULL")

            #expect(!expr.matches(UATestData.meetingAction))
            #expect(expr.matches(UATestData.personalTask))
        }

        @Test func filterHasProject() throws {
            let expr = try FilterParser.parse("project IS NOT NULL")

            #expect(expr.matches(UATestData.meetingAction))
        }
    }

    @Suite("Combined Filters")
    struct CombinedFilters {
        @Test func workAreaOpenTasks() throws {
            // Common ua-conductor pattern: all open tasks in work area
            let expr = try FilterParser.parse(
                "status = open AND area LIKE '%Under Armour%'"
            )

            #expect(expr.matches(UATestData.meetingAction))
            #expect(expr.matches(UATestData.jiraTask))
            #expect(!expr.matches(UATestData.completedTask))
            #expect(!expr.matches(UATestData.personalTask))
        }

        @Test func urgentWorkTasks() throws {
            let expr = try FilterParser.parse(
                "status = open AND area LIKE '%Under Armour%' AND tags CONTAINS 'urgent'"
            )

            #expect(expr.matches(UATestData.inlineTagsTask))
            #expect(!expr.matches(UATestData.meetingAction))
        }

        @Test func notInAreaOrCompleted() throws {
            let expr = try FilterParser.parse(
                "NOT (area LIKE '%Under Armour%') OR status = completed"
            )

            #expect(expr.matches(UATestData.personalTask))
            #expect(expr.matches(UATestData.completedTask))
        }
    }

    @Suite("IN Operator")
    struct INOperator {
        @Test func statusInList() throws {
            let expr = try FilterParser.parse("status IN ('open', 'canceled')")

            #expect(expr.matches(UATestData.meetingAction))
            #expect(!expr.matches(UATestData.completedTask))
        }
    }

    @Suite("LIKE Patterns")
    struct LIKEPatterns {
        @Test func nameStartsWith() throws {
            let expr = try FilterParser.parse("name LIKE 'Review%'")

            #expect(expr.matches(UATestData.jiraTask))
        }

        @Test func nameContains() throws {
            let expr = try FilterParser.parse("name LIKE '%API%'")

            #expect(expr.matches(UATestData.meetingAction))
        }

        @Test func nameEndsWith() throws {
            let expr = try FilterParser.parse("name LIKE '%implementation'")

            #expect(expr.matches(UATestData.jiraTask))
        }
    }

    @Suite("Date Comparisons")
    struct DateComparisons {
        @Test func dueDateExists() throws {
            let expr = try FilterParser.parse("due IS NOT NULL")

            #expect(expr.matches(UATestData.meetingAction))
            #expect(expr.matches(UATestData.jiraTask))
        }

        @Test func noDueDate() throws {
            let expr = try FilterParser.parse("due IS NULL")

            #expect(!expr.matches(UATestData.meetingAction))
            #expect(expr.matches(UATestData.completedTask))
        }
    }

    @Suite("Complex Production Queries")
    struct ComplexProductionQueries {
        @Test func dailyStandupQuery() throws {
            // Find open tasks for standup report
            let expr = try FilterParser.parse(
                "status = open AND area LIKE '%Under Armour%' AND due IS NOT NULL"
            )

            #expect(expr.matches(UATestData.meetingAction))
            #expect(expr.matches(UATestData.jiraTask))
        }

        @Test func meetingActionCleanup() throws {
            // Find completed meeting actions to archive
            let expr = try FilterParser.parse(
                "status = completed AND tags CONTAINS 'meeting-action'"
            )

            // None of our test data matches this exactly
            let completedMeetingAction = Todo(
                id: "completed-meeting",
                name: "Completed meeting action",
                status: .completed,
                tags: [UATestData.meetingActionTag]
            )

            #expect(expr.matches(completedMeetingAction))
        }

        @Test func jiraTasksNeedingReview() throws {
            let expr = try FilterParser.parse(
                "status = open AND tags CONTAINS 'jira' AND tags CONTAINS 'review'"
            )

            #expect(expr.matches(UATestData.jiraTask))
        }
    }
}
