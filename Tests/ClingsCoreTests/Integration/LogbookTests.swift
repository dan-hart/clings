// LogbookTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

/// Tests for logbook/completed task handling.
/// task-watcher.sh monitors completed tasks to sync with external systems.
@Suite("Logbook Monitoring")
struct LogbookTests {
    @Suite("Completed Task Properties")
    struct CompletedTaskProperties {
        @Test func completedTaskHasStatus() {
            let task = WorkTestData.completedTask

            #expect(task.status == .completed)
            #expect(task.isCompleted)
            #expect(!task.isOpen)
        }

        @Test func completedTaskPreservesUUID() {
            // UUID must be stable for duplicate detection
            let task = WorkTestData.completedTask

            #expect(!task.id.isEmpty)
            #expect(task.id == "todo-completed-work")
        }

        @Test func completedTaskPreservesArea() {
            let task = WorkTestData.completedTask

            #expect(task.area?.name == "🖥️ Work")
        }

        @Test func completedTaskPreservesTags() {
            let task = WorkTestData.completedTask

            #expect(task.tags.contains { $0.name == "jira" })
        }
    }

    @Suite("JIRA Ticket Extraction")
    struct JIRATicketExtraction {
        @Test func extractJIRATicketFromTitle() {
            // Extract JIRA tickets from task titles
            let taskName = "Review PROJ-1234 implementation"

            // Pattern: [A-Z]+-\d+
            let pattern = #"[A-Z]+-\d+"#
            let matches = taskName.range(of: pattern, options: .regularExpression)

            #expect(matches != nil, "JIRA ticket pattern should match")

            if let range = matches {
                let ticket = String(taskName[range])
                #expect(ticket == "PROJ-1234")
            }
        }

        @Test func taskTitleCanContainJIRATicket() {
            let task = WorkTestData.jiraTask

            // Verify task contains JIRA ticket reference
            #expect(task.name.contains("PROJ-1234"))
        }
    }

    @Suite("Filtering Completed Tasks")
    struct FilteringCompletedTasks {
        @Test func filterByCompletedStatus() throws {
            let expr = try FilterParser.parse("status = completed")

            #expect(expr.matches(WorkTestData.completedTask))
            #expect(!expr.matches(WorkTestData.meetingAction))
        }

        @Test func filterCompletedInArea() throws {
            let expr = try FilterParser.parse("status = completed AND area LIKE '%Work%'")

            #expect(expr.matches(WorkTestData.completedTask))
        }

        @Test func filterNotCompleted() throws {
            let expr = try FilterParser.parse("status != completed")

            #expect(!expr.matches(WorkTestData.completedTask))
            #expect(expr.matches(WorkTestData.meetingAction))
        }
    }

    @Suite("JSON Output for Completed Tasks")
    struct JSONOutputForCompletedTasks {
        let formatter = JSONOutputFormatter(prettyPrint: false)

        @Test func completedStatusInJSON() throws {
            let output = formatter.format(todos: [WorkTestData.completedTask])

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["items"] as! [[String: Any]]

            #expect(items[0]["status"] as? String == "completed")
        }

        @Test func completedTaskHasModificationDate() throws {
            let output = formatter.format(todos: [WorkTestData.completedTask])

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["items"] as! [[String: Any]]

            #expect(items[0]["modificationDate"] != nil)
        }
    }

    @Suite("Text Output for Completed Tasks")
    struct TextOutputForCompletedTasks {
        let formatter = TextOutputFormatter(useColors: false)

        @Test func completedCheckbox() {
            let output = formatter.format(todos: [WorkTestData.completedTask])

            // Completed tasks show checkmark
            #expect(output.contains("☑"))
        }
    }

    @Suite("Logbook Collection")
    struct LogbookCollection {
        @Test func filterOnlyCompletedTodos() {
            let allTodos = WorkTestData.allTodos
            let completedTodos = allTodos.filter { $0.isCompleted }

            #expect(completedTodos.count == 1)
            #expect(completedTodos[0].id == "todo-completed-work")
        }

        @Test func completedTasksPreserveFullMetadata() {
            let completed = WorkTestData.completedTask

            // All metadata should be preserved for sync
            #expect(completed.id != "")
            #expect(completed.name != "")
            #expect(completed.area != nil)
            #expect(completed.project != nil)
        }
    }
}
