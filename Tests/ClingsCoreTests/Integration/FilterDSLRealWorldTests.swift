// FilterDSLRealWorldTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

/// Tests for filter DSL patterns used in production workflows.
/// These tests verify the filter expressions used in bulk operations and automation.
@Suite("Filter DSL Real World")
struct FilterDSLRealWorldTests {
    @Suite("Tag-Based Filters")
    struct TagBasedFilters {
        @Test func filterByMeetingActionTag() throws {
            // Filter pattern: tags CONTAINS 'meeting-action'
            let expr = try FilterParser.parse("tags CONTAINS 'meeting-action'")

            #expect(expr.matches(WorkTestData.meetingAction))
            #expect(!expr.matches(WorkTestData.jiraTask))
        }

        @Test func filterByMultipleTags() throws {
            // Find tasks with both jira and review tags
            let expr = try FilterParser.parse("tags CONTAINS 'jira' AND tags CONTAINS 'review'")

            #expect(expr.matches(WorkTestData.jiraTask))
            #expect(!expr.matches(WorkTestData.meetingAction))
        }

        @Test func filterByAnyOfTags() throws {
            // Find tasks with either tag
            let expr = try FilterParser.parse("tags CONTAINS 'jira' OR tags CONTAINS 'meeting-action'")

            #expect(expr.matches(WorkTestData.jiraTask))
            #expect(expr.matches(WorkTestData.meetingAction))
            #expect(!expr.matches(WorkTestData.personalTask))
        }
    }

    @Suite("Status Filters")
    struct StatusFilters {
        @Test func filterOpenTasks() throws {
            let expr = try FilterParser.parse("status = open")

            #expect(expr.matches(WorkTestData.meetingAction))
            #expect(expr.matches(WorkTestData.jiraTask))
            #expect(!expr.matches(WorkTestData.completedTask))
        }

        @Test func filterNotCompleted() throws {
            let expr = try FilterParser.parse("status != completed")

            #expect(expr.matches(WorkTestData.meetingAction))
            #expect(!expr.matches(WorkTestData.completedTask))
        }

        @Test func filterCompletedOrCanceled() throws {
            let expr = try FilterParser.parse("status = completed OR status = canceled")

            #expect(expr.matches(WorkTestData.completedTask))
        }
    }

    @Suite("Project Filters")
    struct ProjectFilters {
        @Test func filterByProjectName() throws {
            let expr = try FilterParser.parse("project = 'Mobile App'")

            #expect(expr.matches(WorkTestData.meetingAction))
            #expect(expr.matches(WorkTestData.jiraTask))
            #expect(!expr.matches(WorkTestData.personalTask))
        }

        @Test func filterNoProject() throws {
            let expr = try FilterParser.parse("project IS NULL")

            #expect(!expr.matches(WorkTestData.meetingAction))
            #expect(expr.matches(WorkTestData.personalTask))
        }

        @Test func filterHasProject() throws {
            let expr = try FilterParser.parse("project IS NOT NULL")

            #expect(expr.matches(WorkTestData.meetingAction))
        }
    }

    @Suite("Combined Filters")
    struct CombinedFilters {
        @Test func workAreaOpenTasks() throws {
            // Common pattern: all open tasks in work area
            let expr = try FilterParser.parse(
                "status = open AND area LIKE '%Work%'"
            )

            #expect(expr.matches(WorkTestData.meetingAction))
            #expect(expr.matches(WorkTestData.jiraTask))
            #expect(!expr.matches(WorkTestData.completedTask))
            #expect(!expr.matches(WorkTestData.personalTask))
        }

        @Test func urgentWorkTasks() throws {
            let expr = try FilterParser.parse(
                "status = open AND area LIKE '%Work%' AND tags CONTAINS 'urgent'"
            )

            #expect(expr.matches(WorkTestData.inlineTagsTask))
            #expect(!expr.matches(WorkTestData.meetingAction))
        }

        @Test func notInAreaOrCompleted() throws {
            let expr = try FilterParser.parse(
                "NOT (area LIKE '%Work%') OR status = completed"
            )

            #expect(expr.matches(WorkTestData.personalTask))
            #expect(expr.matches(WorkTestData.completedTask))
        }
    }

    @Suite("IN Operator")
    struct INOperator {
        @Test func statusInList() throws {
            let expr = try FilterParser.parse("status IN ('open', 'canceled')")

            #expect(expr.matches(WorkTestData.meetingAction))
            #expect(!expr.matches(WorkTestData.completedTask))
        }
    }

    @Suite("LIKE Patterns")
    struct LIKEPatterns {
        @Test func nameStartsWith() throws {
            let expr = try FilterParser.parse("name LIKE 'Review%'")

            #expect(expr.matches(WorkTestData.jiraTask))
        }

        @Test func nameContains() throws {
            let expr = try FilterParser.parse("name LIKE '%API%'")

            #expect(expr.matches(WorkTestData.meetingAction))
        }

        @Test func nameEndsWith() throws {
            let expr = try FilterParser.parse("name LIKE '%implementation'")

            #expect(expr.matches(WorkTestData.jiraTask))
        }
    }

    @Suite("Date Comparisons")
    struct DateComparisons {
        @Test func dueDateExists() throws {
            let expr = try FilterParser.parse("due IS NOT NULL")

            #expect(expr.matches(WorkTestData.meetingAction))
            #expect(expr.matches(WorkTestData.jiraTask))
        }

        @Test func noDueDate() throws {
            let expr = try FilterParser.parse("due IS NULL")

            #expect(!expr.matches(WorkTestData.meetingAction))
            #expect(expr.matches(WorkTestData.completedTask))
        }
    }

    @Suite("Complex Production Queries")
    struct ComplexProductionQueries {
        @Test func dailyStandupQuery() throws {
            // Find open tasks for standup report
            let expr = try FilterParser.parse(
                "status = open AND area LIKE '%Work%' AND due IS NOT NULL"
            )

            #expect(expr.matches(WorkTestData.meetingAction))
            #expect(expr.matches(WorkTestData.jiraTask))
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
                tags: [WorkTestData.meetingActionTag]
            )

            #expect(expr.matches(completedMeetingAction))
        }

        @Test func jiraTasksNeedingReview() throws {
            let expr = try FilterParser.parse(
                "status = open AND tags CONTAINS 'jira' AND tags CONTAINS 'review'"
            )

            #expect(expr.matches(WorkTestData.jiraTask))
        }
    }
}
