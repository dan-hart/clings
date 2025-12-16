// JSONOutputIntegrationTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

/// Tests for JSON output format compatibility with automation scripts.
/// Uses jq to parse JSON output from clings for automation workflows.
@Suite("JSON Output Integration")
struct JSONOutputIntegrationTests {
    let formatter = JSONOutputFormatter(prettyPrint: false)

    @Suite("JSON Structure for jq")
    struct JSONStructureForJQ {
        let formatter = JSONOutputFormatter(prettyPrint: false)

        @Test func todayJSONContainsExpectedFields() throws {
            let todos = WorkTestData.openTodos
            let output = formatter.format(todos: todos)

            // Parse JSON to verify structure used by automation
            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            // Expects .items[] array structure for jq
            #expect(json["count"] != nil)
            #expect(json["items"] != nil)

            let items = json["items"] as! [[String: Any]]
            #expect(!items.isEmpty)

            // Check first item has all expected fields
            let item = items[0]
            #expect(item["id"] != nil, "id field required for duplicate detection")
            #expect(item["name"] != nil, "name field required for display")
            #expect(item["status"] != nil, "status field required for filtering")
            #expect(item["area"] != nil || item["area"] is NSNull, "area field required (can be null)")
            #expect(item["project"] != nil || item["project"] is NSNull, "project field required (can be null)")
            #expect(item["tags"] != nil, "tags field required for filtering")
            #expect(item["notes"] != nil, "notes field required (empty string if none)")
        }

        @Test func itemsArrayIsDirectlyAccessible() throws {
            let todos = [WorkTestData.meetingAction]
            let output = formatter.format(todos: todos)

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            // jq accesses with .items[]
            let items = json["items"] as! [[String: Any]]
            #expect(items.count == 1)
        }
    }

    @Suite("Area Field with Emoji")
    struct AreaFieldWithEmoji {
        let formatter = JSONOutputFormatter(prettyPrint: false)

        @Test func areaFieldPreservesEmoji() throws {
            let todos = [WorkTestData.meetingAction]
            let output = formatter.format(todos: todos)

            // Area names with emoji must be preserved exactly
            #expect(output.contains("🖥️ Work"))

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["items"] as! [[String: Any]]
            let area = items[0]["area"] as? String

            #expect(area == "🖥️ Work", "Emoji prefix must be preserved in area name")
        }

        @Test func areaFieldIsNullWhenMissing() throws {
            let todoWithoutArea = Todo(
                id: "no-area",
                name: "No area task",
                notes: nil,
                status: .open,
                area: nil
            )
            let output = formatter.format(todos: [todoWithoutArea])

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["items"] as! [[String: Any]]

            // null values are important for jq filtering
            #expect(items[0]["area"] is NSNull || items[0]["area"] == nil)
        }
    }

    @Suite("Status Field")
    struct StatusField {
        let formatter = JSONOutputFormatter(prettyPrint: false)

        @Test func statusIsStringValue() throws {
            let todos = [WorkTestData.meetingAction, WorkTestData.completedTask]
            let output = formatter.format(todos: todos)

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["items"] as! [[String: Any]]

            // Status should be lowercase string matching jq filter patterns
            let openStatus = items.first { ($0["name"] as? String)?.contains("Follow up") == true }?["status"] as? String
            let completedStatus = items.first { ($0["name"] as? String)?.contains("Merge PR") == true }?["status"] as? String

            #expect(openStatus == "open")
            #expect(completedStatus == "completed")
        }
    }

    @Suite("Tags Field")
    struct TagsField {
        let formatter = JSONOutputFormatter(prettyPrint: false)

        @Test func tagsAreStringArray() throws {
            let todos = [WorkTestData.jiraTask]
            let output = formatter.format(todos: todos)

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["items"] as! [[String: Any]]
            let tags = items[0]["tags"] as? [String]

            #expect(tags != nil)
            #expect(tags?.contains("jira") == true)
            #expect(tags?.contains("review") == true)
        }

        @Test func tagsAreEmptyArrayNotNull() throws {
            let todoNoTags = Todo(
                id: "no-tags",
                name: "No tags",
                tags: []
            )
            let output = formatter.format(todos: [todoNoTags])

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["items"] as! [[String: Any]]
            let tags = items[0]["tags"] as? [String]

            // Empty array, not null - important for jq contains check
            #expect(tags != nil)
            #expect(tags?.isEmpty == true)
        }
    }

    @Suite("Date Fields")
    struct DateFields {
        let formatter = JSONOutputFormatter(prettyPrint: false)

        @Test func datesAreISO8601Format() throws {
            let todos = [WorkTestData.meetingAction]
            let output = formatter.format(todos: todos)

            // Check for ISO8601 date pattern
            let isoDatePattern = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"#
            #expect(output.range(of: isoDatePattern, options: .regularExpression) != nil,
                    "Dates must be ISO8601 format for consistent parsing")
        }

        @Test func nullDueDateIsPreserved() throws {
            let todoNoDue = Todo(
                id: "no-due",
                name: "No due date",
                dueDate: nil
            )
            let output = formatter.format(todos: [todoNoDue])

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["items"] as! [[String: Any]]

            #expect(items[0]["dueDate"] is NSNull || items[0]["dueDate"] == nil)
        }
    }

    @Suite("List Parameter")
    struct ListParameter {
        let formatter = JSONOutputFormatter(prettyPrint: false)

        @Test func listNameIncludedWhenProvided() throws {
            let todos = [WorkTestData.meetingAction]
            let output = formatter.format(todos: todos, list: "Today")

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["list"] as? String == "Today")
        }

        @Test func listNameOmittedWhenNotProvided() throws {
            let todos = [WorkTestData.meetingAction]
            let output = formatter.format(todos: todos)

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            // list should be null or not present
            #expect(json["list"] == nil || json["list"] is NSNull)
        }
    }

    @Suite("UUID Stability")
    struct UUIDStability {
        let formatter = JSONOutputFormatter(prettyPrint: false)

        @Test func idFieldIsStable() throws {
            // Same todo formatted twice should have same ID
            let todos = [WorkTestData.completedTask]

            let output1 = formatter.format(todos: todos)
            let output2 = formatter.format(todos: todos)

            let data1 = output1.data(using: .utf8)!
            let data2 = output2.data(using: .utf8)!

            let json1 = try JSONSerialization.jsonObject(with: data1) as! [String: Any]
            let json2 = try JSONSerialization.jsonObject(with: data2) as! [String: Any]

            let items1 = json1["items"] as! [[String: Any]]
            let items2 = json2["items"] as! [[String: Any]]

            #expect(items1[0]["id"] as? String == items2[0]["id"] as? String,
                    "ID must be stable for duplicate detection in task-watcher")
        }
    }
}
