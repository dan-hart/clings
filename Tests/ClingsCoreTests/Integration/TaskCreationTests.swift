// TaskCreationTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

/// Tests for task creation parsing used in automation scripts.
/// Creates tasks with clings add using various flags and NLP.
@Suite("Task Creation")
struct TaskCreationTests {
    let parser = TaskParser()

    @Suite("Natural Language Tags")
    struct NaturalLanguageTags {
        let parser = TaskParser()

        @Test func parseInlineTags() {
            // clings add "Task #work #urgent"
            let result = parser.parse("Update documentation #work #urgent")

            #expect(result.title == "Update documentation")
            #expect(result.tags.contains("work"))
            #expect(result.tags.contains("urgent"))
        }

        @Test func parseMultipleTags() {
            // Pattern for meeting actions (using underscore since parser uses \w+)
            let result = parser.parse("Review API spec #meeting_action #jira")

            #expect(result.tags.count == 2)
            #expect(result.tags.contains("meeting_action"))
            #expect(result.tags.contains("jira"))
        }

        @Test func tagWithUnderscore() {
            // Note: TaskParser uses \w+ pattern which doesn't include hyphens
            // Use underscores for multi-word tags
            let result = parser.parse("Task #meeting_action")

            #expect(result.tags.contains("meeting_action"))
        }

        @Test func tagWithNumbers() {
            let result = parser.parse("Task #test123")

            #expect(result.tags.contains("test123"))
        }
    }

    @Suite("Escaped Hash in Title")
    struct EscapedHashInTitle {
        let parser = TaskParser()

        @Test func escapedHashNotParsedAsTag() {
            // clings add "Review PR \#267" - escaped hash should be literal
            let result = parser.parse("Review PR \\#267 changes")

            #expect(result.title == "Review PR #267 changes")
            #expect(!result.tags.contains("267"))
        }

        @Test func mixedEscapedAndRealTags() {
            let result = parser.parse("Fix issue \\#123 #urgent")

            #expect(result.title == "Fix issue #123")
            #expect(result.tags.contains("urgent"))
            #expect(!result.tags.contains("123"))
        }
    }

    @Suite("Notes Parsing")
    struct NotesParsing {
        let parser = TaskParser()

        @Test func notesAfterDoubleSlash() {
            // clings add "Task // Notes here"
            let result = parser.parse("Review PR // From meeting on 2025-12-10")

            #expect(result.title == "Review PR")
            #expect(result.notes == "From meeting on 2025-12-10")
        }
    }

    @Suite("Date Parsing")
    struct DateParsing {
        let parser = TaskParser()

        @Test func whenDateToday() {
            // clings add "Task" --when "today"
            let result = parser.parse("Call mom today")

            #expect(result.whenDate != nil)
            #expect(Calendar.current.isDateInToday(result.whenDate!))
        }

        @Test func whenDateTomorrow() {
            let result = parser.parse("Review PR tomorrow")

            #expect(result.whenDate != nil)
            #expect(Calendar.current.isDateInTomorrow(result.whenDate!))
        }

        @Test func dueDateByDay() {
            let result = parser.parse("Submit report by friday")

            #expect(result.dueDate != nil)
        }
    }

    @Suite("Project Parsing")
    struct ProjectParsing {
        let parser = TaskParser()

        @Test func projectAfterFor() {
            let result = parser.parse("Update tests for MobileApp")

            #expect(result.project == "MobileApp")
            #expect(result.title == "Update tests")
        }

        @Test func projectWithSpaces() {
            let result = parser.parse("Task for Project Alpha")

            #expect(result.project == "Project Alpha")
        }
    }

    @Suite("Combined Parsing")
    struct CombinedParsing {
        let parser = TaskParser()

        @Test func automationStyleTask() {
            // Full automation style task creation
            let result = parser.parse(
                "Review PROJ-1234 API changes #jira #review by friday // Check auth flow"
            )

            #expect(result.title.contains("Review") || result.title.contains("PROJ-1234"))
            #expect(result.tags.contains("jira"))
            #expect(result.tags.contains("review"))
            #expect(result.dueDate != nil)
            #expect(result.notes == "Check auth flow")
        }

        @Test func meetingActionStyle() {
            // Note: Using underscore since TaskParser uses \w+ for tags
            let result = parser.parse(
                "Follow up on API discussion #meeting_action today // From standup"
            )

            #expect(result.tags.contains("meeting_action"))
            #expect(result.whenDate != nil)
            #expect(result.notes == "From standup")
        }
    }

    @Suite("Priority Parsing")
    struct PriorityParsing {
        let parser = TaskParser()

        @Test func priorityHighExclamations() {
            let result = parser.parse("Critical bug fix !!!")

            #expect(result.priority == .high)
        }

        @Test func priorityHighWord() {
            let result = parser.parse("Deploy fix !high")

            #expect(result.priority == .high)
        }
    }

    @Suite("Checklist Items")
    struct ChecklistItems {
        let parser = TaskParser()

        @Test func checklistWithDashes() {
            let result = parser.parse("Deploy update - Build app - Run tests - Push to prod")

            #expect(result.checklistItems.count == 3)
            #expect(result.checklistItems.contains("Build app"))
            #expect(result.checklistItems.contains("Run tests"))
            #expect(result.checklistItems.contains("Push to prod"))
        }
    }
}
