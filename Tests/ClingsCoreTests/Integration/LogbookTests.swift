// LogbookTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

/// Tests for logbook/completed task handling as used in ua-conductor.
/// task-watcher.sh monitors completed tasks to sync with external systems.
@Suite("Logbook Monitoring")
struct LogbookTests {
    @Suite("Completed Task Properties")
    struct CompletedTaskProperties {
        @Test func completedTaskHasStatus() {
            let task = UATestData.completedTask

            #expect(task.status == .completed)
            #expect(task.isCompleted)
            #expect(!task.isOpen)
        }

        @Test func completedTaskPreservesUUID() {
            // UUID must be stable for duplicate detection
            let task = UATestData.completedTask

            #expect(!task.id.isEmpty)
            #expect(task.id == "todo-completed-ua")
        }

        @Test func completedTaskPreservesArea() {
            let task = UATestData.completedTask

            #expect(task.area?.name == "🖥️ Under Armour")
        }

        @Test func completedTaskPreservesTags() {
            let task = UATestData.completedTask

            #expect(task.tags.contains { $0.name == "jira" })
        }
    }

    @Suite("JIRA Ticket Extraction")
    struct JIRATicketExtraction {
        @Test func extractJIRATicketFromTitle() {
            // ua-conductor extracts JIRA tickets from task titles
            let taskName = "Review SHOP-1234 implementation"

            // Pattern: [A-Z]+-\d+
            let pattern = #"[A-Z]+-\d+"#
            let matches = taskName.range(of: pattern, options: .regularExpression)

            #expect(matches != nil, "JIRA ticket pattern should match")

            if let range = matches {
                let ticket = String(taskName[range])
                #expect(ticket == "SHOP-1234")
            }
        }

        @Test func taskTitleCanContainJIRATicket() {
            let task = UATestData.jiraTask

            // Verify task contains JIRA ticket reference
            #expect(task.name.contains("SHOP-1234"))
        }
    }

    @Suite("Filtering Completed Tasks")
    struct FilteringCompletedTasks {
        @Test func filterByCompletedStatus() throws {
            let expr = try FilterParser.parse("status = completed")

            #expect(expr.matches(UATestData.completedTask))
            #expect(!expr.matches(UATestData.meetingAction))
        }

        @Test func filterCompletedInArea() throws {
            let expr = try FilterParser.parse("status = completed AND area LIKE '%Under Armour%'")

            #expect(expr.matches(UATestData.completedTask))
        }

        @Test func filterNotCompleted() throws {
            let expr = try FilterParser.parse("status != completed")

            #expect(!expr.matches(UATestData.completedTask))
            #expect(expr.matches(UATestData.meetingAction))
        }
    }

    @Suite("JSON Output for Completed Tasks")
    struct JSONOutputForCompletedTasks {
        let formatter = JSONOutputFormatter(prettyPrint: false)

        @Test func completedStatusInJSON() throws {
            let output = formatter.format(todos: [UATestData.completedTask])

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["items"] as! [[String: Any]]

            #expect(items[0]["status"] as? String == "completed")
        }

        @Test func completedTaskHasModificationDate() throws {
            let output = formatter.format(todos: [UATestData.completedTask])

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
            let output = formatter.format(todos: [UATestData.completedTask])

            // Completed tasks show checkmark
            #expect(output.contains("☑"))
        }
    }

    @Suite("Logbook Collection")
    struct LogbookCollection {
        @Test func filterOnlyCompletedTodos() {
            let allTodos = UATestData.allTodos
            let completedTodos = allTodos.filter { $0.isCompleted }

            #expect(completedTodos.count == 1)
            #expect(completedTodos[0].id == "todo-completed-ua")
        }

        @Test func completedTasksPreserveFullMetadata() {
            let completed = UATestData.completedTask

            // All metadata should be preserved for sync
            #expect(completed.id != "")
            #expect(completed.name != "")
            #expect(completed.area != nil)
            #expect(completed.project != nil)
        }
    }
}
