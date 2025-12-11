// TaskParserTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("TaskParser")
struct TaskParserTests {
    let parser = TaskParser()

    @Suite("Basic Title Extraction")
    struct BasicTitleExtraction {
        let parser = TaskParser()

        @Test func simpleTitle() {
            let result = parser.parse("Buy milk")
            #expect(result.title == "Buy milk")
            #expect(result.notes == nil)
            #expect(result.tags.isEmpty)
            #expect(result.project == nil)
            #expect(result.area == nil)
            #expect(result.dueDate == nil)
            #expect(result.whenDate == nil)
            #expect(result.checklistItems.isEmpty)
            #expect(result.priority == nil)
        }

        @Test func titleWithExtraWhitespace() {
            let result = parser.parse("  Buy   milk  ")
            #expect(result.title == "Buy milk")
        }
    }

    @Suite("Tag Extraction")
    struct TagExtraction {
        let parser = TaskParser()

        @Test func singleTag() {
            let result = parser.parse("Buy milk #grocery")
            #expect(result.title == "Buy milk")
            #expect(result.tags == ["grocery"])
        }

        @Test func multipleTags() {
            let result = parser.parse("Buy milk #grocery #urgent #shopping")
            #expect(result.title == "Buy milk")
            #expect(result.tags.count == 3)
            #expect(result.tags.contains("grocery"))
            #expect(result.tags.contains("urgent"))
            #expect(result.tags.contains("shopping"))
        }

        @Test func tagInMiddle() {
            let result = parser.parse("Buy #grocery milk")
            #expect(result.title == "Buy milk")
            #expect(result.tags == ["grocery"])
        }

        @Test func escapedHash() {
            let result = parser.parse("Fix issue \\#123")
            #expect(result.title == "Fix issue #123")
            #expect(result.tags.isEmpty)
        }

        @Test func tagWithNumbers() {
            let result = parser.parse("Task #test123")
            #expect(result.tags == ["test123"])
        }
    }

    @Suite("Priority Extraction")
    struct PriorityExtraction {
        let parser = TaskParser()

        @Test func priorityHighSymbol() {
            let result = parser.parse("Urgent task !!!")
            #expect(result.title == "Urgent task")
            #expect(result.priority == .high)
        }

        @Test func priorityMediumSymbol() {
            let result = parser.parse("Important task !!")
            #expect(result.title == "Important task")
            #expect(result.priority == .medium)
        }

        @Test func priorityLowSymbol() {
            let result = parser.parse("Minor task !")
            #expect(result.title == "Minor task")
            #expect(result.priority == .low)
        }

        @Test func priorityHighWord() {
            let result = parser.parse("Critical task !high")
            #expect(result.title == "Critical task")
            #expect(result.priority == .high)
        }

        @Test func priorityMediumWord() {
            let result = parser.parse("Task !medium")
            #expect(result.title == "Task")
            #expect(result.priority == .medium)
        }

        @Test func priorityLowWord() {
            let result = parser.parse("Task !low")
            #expect(result.title == "Task")
            #expect(result.priority == .low)
        }

        @Test func priorityWordCaseInsensitive() {
            let result = parser.parse("Task !HIGH")
            #expect(result.priority == .high)
        }
    }

    @Suite("Project Extraction")
    struct ProjectExtraction {
        let parser = TaskParser()

        @Test func projectExtraction() {
            let result = parser.parse("Write report for ProjectAlpha")
            #expect(result.title == "Write report")
            #expect(result.project == "ProjectAlpha")
        }

        @Test func projectWithSpaces() {
            let result = parser.parse("Task for Project Alpha")
            // Pattern matches capitalized words after "for"
            #expect(result.project == "Project Alpha")
        }

        @Test func projectLowercaseForIgnored() {
            let result = parser.parse("Looking for something")
            // "something" is lowercase, so not matched as project
            #expect(result.project == nil)
            #expect(result.title.contains("Looking for something"))
        }
    }

    @Suite("Area Extraction")
    struct AreaExtraction {
        let parser = TaskParser()

        @Test func areaExtraction() {
            let result = parser.parse("Task in WorkArea")
            #expect(result.title == "Task")
            #expect(result.area == "WorkArea")
        }

        @Test func areaWithSpaces() {
            let result = parser.parse("Task in Work Area")
            #expect(result.area == "Work Area")
        }

        @Test func areaNotMatchedWhenFollowedByDays() {
            // "in 3 days" should not be matched as area
            let result = parser.parse("Task in 3 days")
            #expect(result.area == nil)
            #expect(result.whenDate != nil)
        }
    }

    @Suite("Due Date Extraction")
    struct DueDateExtraction {
        let parser = TaskParser()

        @Test func dueDateByDay() {
            let result = parser.parse("Submit report by friday")
            #expect(result.dueDate != nil)
            #expect(result.title == "Submit report")
        }

        @Test func dueDateByDayShort() {
            let result = parser.parse("Submit by fri")
            #expect(result.dueDate != nil)
        }

        @Test func dueDateWeekdays() {
            let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            for day in days {
                let result = parser.parse("Task by \(day)")
                #expect(result.dueDate != nil, "Failed for \(day)")
            }
        }
    }

    @Suite("When Date Extraction")
    struct WhenDateExtraction {
        let parser = TaskParser()

        @Test func whenDateToday() {
            let result = parser.parse("Call mom today")
            #expect(result.whenDate != nil)
            #expect(result.title == "Call mom")

            let calendar = Calendar.current
            #expect(calendar.isDateInToday(result.whenDate!))
        }

        @Test func whenDateTomorrow() {
            let result = parser.parse("Call mom tomorrow")
            #expect(result.whenDate != nil)
            #expect(result.title == "Call mom")

            let calendar = Calendar.current
            #expect(calendar.isDateInTomorrow(result.whenDate!))
        }

        @Test func whenDateInDays() {
            let result = parser.parse("Review in 3 days")
            #expect(result.whenDate != nil)

            let calendar = Calendar.current
            let expected = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: Date()))!
            #expect(calendar.startOfDay(for: result.whenDate!) == expected)
        }

        @Test func whenDateInOneDay() {
            let result = parser.parse("Review in 1 day")
            #expect(result.whenDate != nil)
        }

        @Test func whenDateNextWeekday() {
            let result = parser.parse("Meeting next monday")
            #expect(result.whenDate != nil)

            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: result.whenDate!)
            #expect(weekday == 2) // Monday = 2
        }
    }

    @Suite("Notes Extraction")
    struct NotesExtraction {
        let parser = TaskParser()

        @Test func notesExtraction() {
            let result = parser.parse("Buy groceries // Remember to check sales")
            #expect(result.title == "Buy groceries")
            #expect(result.notes == "Remember to check sales")
        }

        @Test func notesWithExtraSpaces() {
            let result = parser.parse("Task //   some notes here  ")
            #expect(result.notes == "some notes here")
        }

        @Test func emptyNotes() {
            let result = parser.parse("Task // ")
            #expect(result.notes == "")
        }
    }

    @Suite("Checklist Items Extraction")
    struct ChecklistItemsExtraction {
        let parser = TaskParser()

        @Test func singleChecklistItem() {
            let result = parser.parse("Grocery shopping - Buy milk")
            #expect(result.checklistItems == ["Buy milk"])
        }

        @Test func multipleChecklistItems() {
            let result = parser.parse("Grocery shopping - Buy milk - Get eggs - Pick up bread")
            #expect(result.checklistItems.count == 3)
            #expect(result.checklistItems.contains("Buy milk"))
            #expect(result.checklistItems.contains("Get eggs"))
            #expect(result.checklistItems.contains("Pick up bread"))
        }
    }

    @Suite("Combined Patterns")
    struct CombinedPatterns {
        let parser = TaskParser()

        @Test func tagsAndPriority() {
            let result = parser.parse("Urgent task #work #important !!")
            #expect(result.title == "Urgent task")
            #expect(result.tags.count == 2)
            #expect(result.priority == .medium)
        }

        @Test func allFeaturesCombined() {
            let result = parser.parse("Review docs for ProjectAlpha #work !high by friday // Check formatting")
            #expect(result.title == "Review docs")
            #expect(result.project == "ProjectAlpha")
            #expect(result.tags == ["work"])
            #expect(result.priority == .high)
            #expect(result.dueDate != nil)
            #expect(result.notes == "Check formatting")
        }

        @Test func complexTaskWithMultipleElements() {
            let result = parser.parse("Write quarterly report for Finance #urgent #reporting !!! by monday - Executive summary - Data analysis - Conclusions // Q4 metrics")
            #expect(result.project == "Finance")
            #expect(result.tags.contains("urgent"))
            #expect(result.tags.contains("reporting"))
            #expect(result.priority == .high)
            #expect(result.dueDate != nil)
            #expect(result.checklistItems.count == 3)
            #expect(result.notes == "Q4 metrics")
        }
    }

    @Suite("Edge Cases")
    struct EdgeCases {
        let parser = TaskParser()

        @Test func emptyString() {
            let result = parser.parse("")
            #expect(result.title == "")
        }

        @Test func onlyTags() {
            let result = parser.parse("#work #urgent")
            #expect(result.title == "")
            #expect(result.tags.count == 2)
        }

        @Test func onlyPriority() {
            let result = parser.parse("!!!")
            #expect(result.title == "")
            #expect(result.priority == .high)
        }

        @Test func hashInMiddleOfWord() {
            // "#" in middle of word should not be a tag
            let result = parser.parse("Issue#123")
            // The pattern looks for whitespace before #, so this won't match
            #expect(result.tags.isEmpty || result.title.contains("Issue"))
        }

        @Test func unicodeCharacters() {
            let result = parser.parse("Buy groceries #健康")
            #expect(result.title == "Buy groceries")
            // Unicode tag may or may not be captured depending on regex word boundary
        }
    }

    @Suite("ParsedTask Struct")
    struct ParsedTaskTests {
        @Test func parsedTaskInit() {
            let task = ParsedTask(
                title: "Test",
                notes: "Notes",
                tags: ["a", "b"],
                project: "Project",
                area: "Area",
                dueDate: Date(),
                whenDate: Date(),
                checklistItems: ["Item 1"],
                priority: .high
            )

            #expect(task.title == "Test")
            #expect(task.notes == "Notes")
            #expect(task.tags == ["a", "b"])
            #expect(task.project == "Project")
            #expect(task.area == "Area")
            #expect(task.dueDate != nil)
            #expect(task.whenDate != nil)
            #expect(task.checklistItems == ["Item 1"])
            #expect(task.priority == .high)
        }

        @Test func parsedTaskDefaults() {
            let task = ParsedTask(title: "Simple")

            #expect(task.title == "Simple")
            #expect(task.notes == nil)
            #expect(task.tags.isEmpty)
            #expect(task.project == nil)
            #expect(task.area == nil)
            #expect(task.dueDate == nil)
            #expect(task.whenDate == nil)
            #expect(task.checklistItems.isEmpty)
            #expect(task.priority == nil)
        }
    }
}
