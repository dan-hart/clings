// OutputFormatterTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("OutputFormatter")
struct OutputFormatterTests {
    @Suite("OutputFormat")
    struct OutputFormatTests {
        @Test func outputFormatRawValues() {
            #expect(OutputFormat.pretty.rawValue == "pretty")
            #expect(OutputFormat.json.rawValue == "json")
        }

        @Test func outputFormatDescriptions() {
            #expect(!OutputFormat.pretty.description.isEmpty)
            #expect(!OutputFormat.json.description.isEmpty)
        }

        @Test func outputFormatAllCases() {
            #expect(OutputFormat.allCases.count == 2)
            #expect(OutputFormat.allCases.contains(.pretty))
            #expect(OutputFormat.allCases.contains(.json))
        }
    }

    @Suite("JSONOutputFormatter")
    struct JSONOutputFormatterTests {
        @Test func formatTodos() {
            let formatter = JSONOutputFormatter()
            let todos = [TestData.todoOpen, TestData.todoCompleted]

            let output = formatter.format(todos: todos)

            // Pretty-printed JSON has spaces around colons
            #expect(output.contains("\"count\" : 2"))
            #expect(output.contains("\"items\""))
            #expect(output.contains(TestData.todoOpen.id))
            #expect(output.contains(TestData.todoCompleted.id))
        }

        @Test func formatTodosWithList() {
            let formatter = JSONOutputFormatter()
            let todos = [TestData.todoOpen]

            let output = formatter.format(todos: todos, list: "Today")

            #expect(output.contains("\"count\" : 1"))
            #expect(output.contains("\"list\" : \"Today\""))
        }

        @Test func formatEmptyTodos() {
            let formatter = JSONOutputFormatter()
            let output = formatter.format(todos: [])

            #expect(output.contains("\"count\" : 0"))
            #expect(output.contains("\"items\" : ["))
        }

        @Test func formatProjects() {
            let formatter = JSONOutputFormatter()
            let projects = [TestData.projectAlpha, TestData.projectBeta]

            let output = formatter.format(projects: projects)

            #expect(output.contains("\"count\" : 2"))
            #expect(output.contains("Project Alpha"))
            #expect(output.contains("Project Beta"))
        }

        @Test func formatAreas() {
            let formatter = JSONOutputFormatter()
            let areas = TestData.allAreas

            let output = formatter.format(areas: areas)

            #expect(output.contains("\"count\" : 2"))
            #expect(output.contains("Personal"))
            #expect(output.contains("Work"))
        }

        @Test func formatTags() {
            let formatter = JSONOutputFormatter()
            let tags = TestData.allTags

            let output = formatter.format(tags: tags)

            #expect(output.contains("\"count\" : 4"))
            #expect(output.contains("work"))
            #expect(output.contains("urgent"))
        }

        @Test func formatSingleTodo() {
            let formatter = JSONOutputFormatter()
            let output = formatter.format(todo: TestData.todoOpen)

            #expect(output.contains(TestData.todoOpen.id))
            #expect(output.contains(TestData.todoOpen.name))
            #expect(output.contains("\"status\" : \"open\""))
        }

        @Test func formatMessage() {
            let formatter = JSONOutputFormatter()
            let output = formatter.format(message: "Success!")

            #expect(output.contains("\"message\" : \"Success!\""))
        }

        @Test func formatError() {
            let formatter = JSONOutputFormatter()
            let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

            let output = formatter.format(error: error)

            #expect(output.contains("\"error\" : \"Test error\""))
        }

        @Test func prettyPrintEnabled() {
            let formatter = JSONOutputFormatter(prettyPrint: true)
            let output = formatter.format(todos: [TestData.todoOpen])

            // Pretty printed output has newlines
            #expect(output.contains("\n"))
        }

        @Test func prettyPrintDisabled() {
            let formatter = JSONOutputFormatter(prettyPrint: false)
            let output = formatter.format(todos: [TestData.todoOpen])

            // Non-pretty printed output is single line (no newlines)
            #expect(!output.contains("\n"))
        }

        @Test func includesDateInISO8601() {
            let formatter = JSONOutputFormatter()
            let output = formatter.format(todos: [TestData.todoOpen])

            // Should contain ISO8601 formatted dates (e.g., 2024-12-11T)
            let isoDatePattern = #"\d{4}-\d{2}-\d{2}T"#
            #expect(output.range(of: isoDatePattern, options: .regularExpression) != nil)
        }

        @Test func includesChecklistItems() {
            let formatter = JSONOutputFormatter()
            let output = formatter.format(todo: TestData.todoWithChecklist)

            #expect(output.contains("\"checklistItems\""))
            #expect(output.contains("Step 1"))
        }
    }

    @Suite("TextOutputFormatter")
    struct TextOutputFormatterTests {
        @Test func formatTodos() {
            // Test with colors disabled since tests don't run in a TTY
            let formatter = TextOutputFormatter(useColors: false)
            let todos = [TestData.todoOpen, TestData.todoCompleted]

            let output = formatter.format(todos: todos)

            #expect(output.contains(TestData.todoOpen.name))
            #expect(output.contains(TestData.todoCompleted.name))
        }

        @Test func formatEmptyTodos() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(todos: [])

            #expect(output.contains("No todos found"))
        }

        @Test func checkboxSymbols() {
            let formatter = TextOutputFormatter(useColors: false)

            let openOutput = formatter.format(todos: [TestData.todoOpen])
            #expect(openOutput.contains("☐"))

            let completedOutput = formatter.format(todos: [TestData.todoCompleted])
            #expect(completedOutput.contains("☑"))

            let canceledOutput = formatter.format(todos: [TestData.todoCanceled])
            #expect(canceledOutput.contains("☒"))
        }

        @Test func formatProjects() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(projects: TestData.allProjects)

            #expect(output.contains("Project Alpha"))
            #expect(output.contains("Project Beta"))
        }

        @Test func formatEmptyProjects() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(projects: [])

            #expect(output.contains("No projects found"))
        }

        @Test func formatAreas() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(areas: TestData.allAreas)

            #expect(output.contains("Personal"))
            #expect(output.contains("Work"))
        }

        @Test func formatEmptyAreas() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(areas: [])

            #expect(output.contains("No areas found"))
        }

        @Test func formatTags() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(tags: TestData.allTags)

            #expect(output.contains("#work"))
            #expect(output.contains("#urgent"))
            #expect(output.contains("#home"))
        }

        @Test func formatEmptyTags() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(tags: [])

            #expect(output.contains("No tags found"))
        }

        @Test func formatSingleTodo() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(todo: TestData.todoOpen)

            #expect(output.contains(TestData.todoOpen.name))
            #expect(output.contains("Status:"))
            #expect(output.contains("Project:"))
            #expect(output.contains("ID:"))
        }

        @Test func formatTodoWithChecklist() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(todo: TestData.todoWithChecklist)

            #expect(output.contains("Checklist:"))
            #expect(output.contains("Step 1"))
            #expect(output.contains("☑")) // Completed item
            #expect(output.contains("☐")) // Incomplete items
        }

        @Test func formatTodoWithNotes() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(todo: TestData.todoOpen)

            #expect(output.contains("Notes:"))
            #expect(output.contains(TestData.todoOpen.notes!))
        }

        @Test func formatMessage() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(message: "Task completed!")

            #expect(output == "Task completed!")
        }

        @Test func formatError() {
            let formatter = TextOutputFormatter(useColors: false)
            let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Something went wrong"])

            let output = formatter.format(error: error)

            #expect(output.contains("Error:"))
            #expect(output.contains("Something went wrong"))
        }
    }

    @Suite("JSON Structure")
    struct JSONStructureTests {
        @Test func todoJSONStructure() throws {
            let formatter = JSONOutputFormatter(prettyPrint: false)
            let output = formatter.format(todos: [TestData.todoOpen])

            // Parse JSON to verify structure
            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["count"] as? Int == 1)

            let items = json["items"] as! [[String: Any]]
            let item = items[0]

            #expect(item["id"] != nil)
            #expect(item["name"] != nil)
            #expect(item["status"] != nil)
            #expect(item["notes"] != nil)
            #expect(item["tags"] != nil)
            #expect(item["creationDate"] != nil)
            #expect(item["modificationDate"] != nil)
        }

        @Test func projectJSONStructure() throws {
            let formatter = JSONOutputFormatter(prettyPrint: false)
            let output = formatter.format(projects: [TestData.projectAlpha])

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["count"] as? Int == 1)

            let items = json["items"] as! [[String: Any]]
            let item = items[0]

            #expect(item["id"] != nil)
            #expect(item["name"] != nil)
            #expect(item["status"] != nil)
        }

        @Test func areaJSONStructure() throws {
            let formatter = JSONOutputFormatter(prettyPrint: false)
            let output = formatter.format(areas: [TestData.personalArea])

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["count"] as? Int == 1)

            let items = json["items"] as! [[String: Any]]
            let item = items[0]

            #expect(item["id"] != nil)
            #expect(item["name"] != nil)
            #expect(item["tags"] != nil)
        }

        @Test func tagJSONStructure() throws {
            let formatter = JSONOutputFormatter(prettyPrint: false)
            let output = formatter.format(tags: [TestData.workTag])

            let data = output.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["count"] as? Int == 1)

            let items = json["items"] as! [[String: Any]]
            let item = items[0]

            #expect(item["id"] != nil)
            #expect(item["name"] != nil)
        }
    }

    @Suite("Date Formatting")
    struct DateFormattingTests {
        @Test func todoJSONDateFormatting() {
            let formatter = JSONOutputFormatter()
            let output = formatter.format(todo: TestData.todoOpen)

            // Dates should be ISO8601 format
            #expect(output.contains("creationDate"))
            #expect(output.contains("modificationDate"))
        }

        @Test func textFormatterDateDisplay() {
            let formatter = TextOutputFormatter(useColors: false)
            let output = formatter.format(todo: TestData.todoOpen)

            // Should contain formatted due date
            #expect(output.contains("Due:"))
        }
    }
}
