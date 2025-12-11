// TodoTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("Todo Model")
struct TodoTests {
    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct Initialization {
        @Test func withAllParameters() {
            let now = Date()
            let dueDate = now.addingTimeInterval(86400)
            let tag = Tag(name: "test")
            let project = Project(id: "p1", name: "Test Project")
            let area = Area(id: "a1", name: "Test Area")
            let checklist = ChecklistItem(name: "Step 1")

            let todo = Todo(
                id: "t1",
                name: "Test Todo",
                notes: "Some notes",
                status: .open,
                dueDate: dueDate,
                tags: [tag],
                project: project,
                area: area,
                checklistItems: [checklist],
                creationDate: now,
                modificationDate: now
            )

            #expect(todo.id == "t1")
            #expect(todo.name == "Test Todo")
            #expect(todo.notes == "Some notes")
            #expect(todo.status == .open)
            #expect(todo.dueDate == dueDate)
            #expect(todo.tags.count == 1)
            #expect(todo.project?.name == "Test Project")
            #expect(todo.area?.name == "Test Area")
            #expect(todo.checklistItems.count == 1)
        }

        @Test func withDefaults() {
            let todo = Todo(id: "t1", name: "Simple Todo")

            #expect(todo.id == "t1")
            #expect(todo.name == "Simple Todo")
            #expect(todo.notes == nil)
            #expect(todo.status == .open)
            #expect(todo.dueDate == nil)
            #expect(todo.tags.isEmpty)
            #expect(todo.project == nil)
            #expect(todo.area == nil)
            #expect(todo.checklistItems.isEmpty)
        }
    }

    // MARK: - Computed Properties Tests

    @Suite("Computed Properties")
    struct ComputedProperties {
        @Test func isCompletedWhenCompleted() {
            let todo = Todo(id: "t1", name: "Done", status: .completed)
            #expect(todo.isCompleted)
            #expect(!todo.isCanceled)
            #expect(!todo.isOpen)
        }

        @Test func isCanceledWhenCanceled() {
            let todo = Todo(id: "t1", name: "Canceled", status: .canceled)
            #expect(!todo.isCompleted)
            #expect(todo.isCanceled)
            #expect(!todo.isOpen)
        }

        @Test func isOpenWhenOpen() {
            let todo = Todo(id: "t1", name: "Open", status: .open)
            #expect(!todo.isCompleted)
            #expect(!todo.isCanceled)
            #expect(todo.isOpen)
        }

        @Test func isOverdueWhenPastDueAndOpen() {
            let pastDate = Date().addingTimeInterval(-86400) // Yesterday
            let todo = Todo(id: "t1", name: "Overdue", status: .open, dueDate: pastDate)
            #expect(todo.isOverdue)
        }

        @Test func isNotOverdueWhenFutureDue() {
            let futureDate = Date().addingTimeInterval(86400) // Tomorrow
            let todo = Todo(id: "t1", name: "Not Overdue", status: .open, dueDate: futureDate)
            #expect(!todo.isOverdue)
        }

        @Test func isNotOverdueWhenCompleted() {
            let pastDate = Date().addingTimeInterval(-86400)
            let todo = Todo(id: "t1", name: "Completed", status: .completed, dueDate: pastDate)
            #expect(!todo.isOverdue)
        }

        @Test func isNotOverdueWhenNoDueDate() {
            let todo = Todo(id: "t1", name: "No Due Date", status: .open, dueDate: nil)
            #expect(!todo.isOverdue)
        }

        @Test func summaryWithProjectAndTags() {
            let project = Project(id: "p1", name: "MyProject")
            let tag1 = Tag(name: "work")
            let tag2 = Tag(name: "urgent")
            let todo = Todo(
                id: "t1",
                name: "Task Name",
                tags: [tag1, tag2],
                project: project
            )

            let summary = todo.summary
            #expect(summary.contains("Task Name"))
            #expect(summary.contains("[MyProject]"))
            #expect(summary.contains("#work"))
            #expect(summary.contains("#urgent"))
        }

        @Test func summaryWithoutProjectOrTags() {
            let todo = Todo(id: "t1", name: "Simple Task")
            #expect(todo.summary == "Simple Task")
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable")
    struct CodableTests {
        @Test func decodeFromJSON() throws {
            let json = TestData.todoJSON.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let todo = try decoder.decode(Todo.self, from: json)

            #expect(todo.id == "json-todo")
            #expect(todo.name == "JSON Todo")
            #expect(todo.notes == "Created from JSON")
            #expect(todo.status == .open)
            #expect(todo.dueDate != nil)
            #expect(todo.tags.count == 1)
            #expect(todo.tags.first?.name == "test")
        }

        @Test func decodeWithStatusString() throws {
            let json = TestData.todoJSONWithStatusString.data(using: .utf8)!
            let decoder = JSONDecoder()

            let todo = try decoder.decode(Todo.self, from: json)

            #expect(todo.status == .completed)
        }

        @Test func encodeAndDecode() throws {
            let original = TestData.todoOpen
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(Todo.self, from: data)

            #expect(decoded.id == original.id)
            #expect(decoded.name == original.name)
            #expect(decoded.status == original.status)
        }
    }

    // MARK: - Equatable and Hashable Tests

    @Suite("Equatable and Hashable")
    struct EquatableHashable {
        @Test func equalityBasedOnId() {
            let todo1 = Todo(id: "same-id", name: "First Name")
            let todo2 = Todo(id: "same-id", name: "Different Name")
            let todo3 = Todo(id: "different-id", name: "First Name")

            #expect(todo1 == todo2)
            #expect(todo1 != todo3)
        }

        @Test func hashBasedOnId() {
            let todo1 = Todo(id: "same-id", name: "First")
            let todo2 = Todo(id: "same-id", name: "Second")

            var set = Set<Todo>()
            set.insert(todo1)
            set.insert(todo2)

            #expect(set.count == 1)
        }
    }

    // MARK: - Filterable Tests

    @Suite("Filterable")
    struct FilterableTests {
        @Test func fieldValueId() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("id")

            if case .string(let id) = value {
                #expect(id == todo.id)
            } else {
                Issue.record("Expected string value for id")
            }
        }

        @Test func fieldValueName() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("name")

            if case .string(let name) = value {
                #expect(name == todo.name)
            } else {
                Issue.record("Expected string value for name")
            }
        }

        @Test func fieldValueTitleAlias() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("title")

            if case .string(let name) = value {
                #expect(name == todo.name)
            } else {
                Issue.record("Expected string value for title")
            }
        }

        @Test func fieldValueNotes() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("notes")

            if case .optionalString(let notes) = value {
                #expect(notes == todo.notes)
            } else {
                Issue.record("Expected optionalString value for notes")
            }
        }

        @Test func fieldValueStatus() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("status")

            if case .string(let status) = value {
                #expect(status == "open")
            } else {
                Issue.record("Expected string value for status")
            }
        }

        @Test func fieldValueDueDate() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("due")

            if case .optionalDate(let date) = value {
                #expect(date != nil)
            } else {
                Issue.record("Expected optionalDate value for due")
            }
        }

        @Test func fieldValueTags() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("tags")

            if case .stringList(let tags) = value {
                #expect(!tags.isEmpty)
            } else {
                Issue.record("Expected stringList value for tags")
            }
        }

        @Test func fieldValueProject() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("project")

            if case .optionalString(let project) = value {
                #expect(project != nil)
            } else {
                Issue.record("Expected optionalString value for project")
            }
        }

        @Test func fieldValueArea() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("area")

            if case .optionalString(let area) = value {
                #expect(area != nil)
            } else {
                Issue.record("Expected optionalString value for area")
            }
        }

        @Test func fieldValueCreated() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("created")

            if case .date = value {
                // Success
            } else {
                Issue.record("Expected date value for created")
            }
        }

        @Test func fieldValueUnknownField() {
            let todo = TestData.todoOpen
            let value = todo.fieldValue("unknown")
            #expect(value == nil)
        }

        @Test func fieldValueCaseInsensitive() {
            let todo = TestData.todoOpen

            #expect(todo.fieldValue("NAME") != nil)
            #expect(todo.fieldValue("Status") != nil)
            #expect(todo.fieldValue("DueDate") != nil)
        }
    }
}
