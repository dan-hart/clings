// JXAScriptsTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("JXAScripts")
struct JXAScriptsTests {
    @Suite("String Escaping")
    struct StringEscaping {
        @Test func jxaEscapedBackslash() {
            let input = "path\\to\\file"
            let escaped = input.jxaEscaped
            #expect(escaped == "path\\\\to\\\\file")
        }

        @Test func jxaEscapedSingleQuote() {
            let input = "it's a test"
            let escaped = input.jxaEscaped
            #expect(escaped == "it\\'s a test")
        }

        @Test func jxaEscapedNewline() {
            let input = "line1\nline2"
            let escaped = input.jxaEscaped
            #expect(escaped == "line1\\nline2")
        }

        @Test func jxaEscapedCarriageReturn() {
            let input = "line1\rline2"
            let escaped = input.jxaEscaped
            #expect(escaped == "line1\\rline2")
        }

        @Test func jxaEscapedTab() {
            let input = "col1\tcol2"
            let escaped = input.jxaEscaped
            #expect(escaped == "col1\\tcol2")
        }

        @Test func jxaEscapedCombined() {
            let input = "It's a test\nwith\\path"
            let escaped = input.jxaEscaped
            #expect(escaped == "It\\'s a test\\nwith\\\\path")
        }

        @Test func jxaEscapedEmpty() {
            let input = ""
            let escaped = input.jxaEscaped
            #expect(escaped == "")
        }

        @Test func jxaEscapedNoSpecialChars() {
            let input = "simple text"
            let escaped = input.jxaEscaped
            #expect(escaped == "simple text")
        }
    }

    @Suite("Fetch List Script")
    struct FetchListScript {
        @Test func containsListName() {
            let script = JXAScripts.fetchList("Today")
            #expect(script.contains("'Today'"))
            #expect(script.contains("Application('Things3')"))
            #expect(script.contains("JSON.stringify"))
        }

        @Test func escapesListName() {
            let script = JXAScripts.fetchList("It's a list")
            #expect(script.contains("It\\'s a list"))
        }

        @Test func hasCorrectStructure() {
            let script = JXAScripts.fetchList("Inbox")

            // Check for key JSON properties
            #expect(script.contains("id: todo.id()"))
            #expect(script.contains("name: todo.name()"))
            #expect(script.contains("status: todo.status()"))
            #expect(script.contains("dueDate:"))
            #expect(script.contains("tags:"))
            #expect(script.contains("project:"))
            #expect(script.contains("area:"))
            #expect(script.contains("checklistItems:"))
        }
    }

    @Suite("Fetch Todo Script")
    struct FetchTodoScript {
        @Test func containsId() {
            let script = JXAScripts.fetchTodo(id: "test-id-123")
            #expect(script.contains("'test-id-123'"))
            #expect(script.contains("app.toDos.byId"))
        }

        @Test func checksExistence() {
            let script = JXAScripts.fetchTodo(id: "test")
            #expect(script.contains("if (!todo.exists())"))
            #expect(script.contains("error"))
        }

        @Test func escapesId() {
            let script = JXAScripts.fetchTodo(id: "id'with'quotes")
            #expect(script.contains("id\\'with\\'quotes"))
        }
    }

    @Suite("Fetch Projects Script")
    struct FetchProjectsScript {
        @Test func hasCorrectStructure() {
            let script = JXAScripts.fetchProjects()
            #expect(script.contains("app.projects()"))
            #expect(script.contains("id: proj.id()"))
            #expect(script.contains("name: proj.name()"))
            #expect(script.contains("status: proj.status()"))
        }
    }

    @Suite("Fetch Areas Script")
    struct FetchAreasScript {
        @Test func hasCorrectStructure() {
            let script = JXAScripts.fetchAreas()
            #expect(script.contains("app.areas()"))
            #expect(script.contains("id: area.id()"))
            #expect(script.contains("name: area.name()"))
        }
    }

    @Suite("Fetch Tags Script")
    struct FetchTagsScript {
        @Test func hasCorrectStructure() {
            let script = JXAScripts.fetchTags()
            #expect(script.contains("app.tags()"))
            #expect(script.contains("id: tag.id()"))
            #expect(script.contains("name: tag.name()"))
        }
    }

    @Suite("Complete Todo Script")
    struct CompleteTodoScript {
        @Test func containsId() {
            let script = JXAScripts.completeTodo(id: "todo-123")
            #expect(script.contains("'todo-123'"))
            #expect(script.contains("todo.status = 'completed'"))
        }

        @Test func checksExistence() {
            let script = JXAScripts.completeTodo(id: "test")
            #expect(script.contains("if (!todo.exists())"))
            #expect(script.contains("success: false"))
        }

        @Test func returnsSuccess() {
            let script = JXAScripts.completeTodo(id: "test")
            #expect(script.contains("success: true"))
        }
    }

    @Suite("Cancel Todo Script")
    struct CancelTodoScript {
        @Test func setsStatus() {
            let script = JXAScripts.cancelTodo(id: "todo-456")
            #expect(script.contains("todo.status = 'canceled'"))
        }

        @Test func checksExistence() {
            let script = JXAScripts.cancelTodo(id: "test")
            #expect(script.contains("if (!todo.exists())"))
        }
    }

    @Suite("Delete Todo Script")
    struct DeleteTodoScript {
        @Test func setsStatusCanceled() {
            // Note: Things 3 doesn't have true delete, so this cancels
            let script = JXAScripts.deleteTodo(id: "todo-789")
            #expect(script.contains("todo.status = 'canceled'"))
        }
    }

    @Suite("Move Todo Script")
    struct MoveTodoScript {
        @Test func containsIdsAndProject() {
            let script = JXAScripts.moveTodo(id: "todo-123", toProject: "My Project")
            #expect(script.contains("'todo-123'"))
            #expect(script.contains("'My Project'"))
            #expect(script.contains("app.projects.byName"))
        }

        @Test func checksProjectExistence() {
            let script = JXAScripts.moveTodo(id: "test", toProject: "Project")
            #expect(script.contains("if (!project.exists())"))
            #expect(script.contains("Project not found"))
        }

        @Test func setsProject() {
            let script = JXAScripts.moveTodo(id: "test", toProject: "Project")
            #expect(script.contains("todo.project = project"))
        }
    }

    @Suite("Update Todo Script")
    struct UpdateTodoScript {
        @Test func withName() {
            let script = JXAScripts.updateTodo(id: "todo-123", name: "New Name")
            #expect(script.contains("todo.name = 'New Name'"))
        }

        @Test func withNotes() {
            let script = JXAScripts.updateTodo(id: "todo-123", notes: "Updated notes")
            #expect(script.contains("todo.notes = 'Updated notes'"))
        }

        @Test func withDueDate() {
            let date = Date()
            let script = JXAScripts.updateTodo(id: "todo-123", dueDate: date)
            #expect(script.contains("todo.dueDate = new Date("))
        }

        @Test func withTags() {
            // Note: Tags parameter is accepted but ignored in JXA script.
            // Tag updates must use the Things URL scheme instead (JXA's todo.tags.push() silently fails).
            // This test verifies the script is still valid and returns success.
            let script = JXAScripts.updateTodo(id: "todo-123", tags: ["work", "urgent"])
            #expect(script.contains("todo-123"))
            #expect(script.contains("success: true"))
            // Tags are NOT included in the JXA script - they're handled via URL scheme
        }

        @Test func withNoChanges() {
            let script = JXAScripts.updateTodo(id: "todo-123")
            #expect(script.contains("todo-123"))
            // Should still check existence and return success
            #expect(script.contains("if (!todo.exists())"))
            #expect(script.contains("success: true"))
        }

        @Test func escapesValues() {
            let script = JXAScripts.updateTodo(id: "test", name: "It's done", notes: "Line1\nLine2")
            #expect(script.contains("It\\'s done"))
            #expect(script.contains("Line1\\nLine2"))
        }
    }

    @Suite("Create Todo Script")
    struct CreateTodoScript {
        @Test func withName() {
            let script = JXAScripts.createTodo(name: "New Task")
            #expect(script.contains("name: 'New Task'"))
            #expect(script.contains("app.make({ new: 'to do'"))
        }

        @Test func withNotes() {
            let script = JXAScripts.createTodo(name: "Task", notes: "Some notes")
            #expect(script.contains("notes: 'Some notes'"))
        }

        @Test func withTags() {
            let script = JXAScripts.createTodo(name: "Task", tags: ["tag1", "tag2"])
            #expect(script.contains("'tag1'"))
            #expect(script.contains("'tag2'"))
        }

        @Test func withProject() {
            let script = JXAScripts.createTodo(name: "Task", project: "My Project")
            #expect(script.contains("app.projects.byName('My Project')"))
            #expect(script.contains("todo.project = project"))
        }

        @Test func withArea() {
            let script = JXAScripts.createTodo(name: "Task", area: "Work Area")
            #expect(script.contains("app.areas.byName('Work Area')"))
            #expect(script.contains("todo.area = area"))
        }

        @Test func withChecklistItems() {
            let script = JXAScripts.createTodo(name: "Task", checklistItems: ["Step 1", "Step 2"])
            #expect(script.contains("'Step 1'"))
            #expect(script.contains("'Step 2'"))
        }

        @Test func returnsIdAndName() {
            let script = JXAScripts.createTodo(name: "Task")
            #expect(script.contains("id: todo.id()"))
            #expect(script.contains("name: todo.name()"))
        }
    }

    @Suite("Search Script")
    struct SearchScript {
        @Test func containsQuery() {
            let script = JXAScripts.search(query: "test search")
            #expect(script.contains("'test search'"))
        }

        @Test func searchesBothNameAndNotes() {
            let script = JXAScripts.search(query: "test")
            #expect(script.contains("name.includes(query)"))
            #expect(script.contains("notes.includes(query)"))
        }

        @Test func isCaseInsensitive() {
            let script = JXAScripts.search(query: "test")
            #expect(script.contains("toLowerCase()"))
        }

        @Test func escapesQuery() {
            let script = JXAScripts.search(query: "it's a test")
            #expect(script.contains("it\\'s a test"))
        }
    }

    @Suite("Script Validity")
    struct ScriptValidity {
        @Test func allScriptsAreIIFE() {
            // All scripts should be Immediately Invoked Function Expressions
            let scripts = [
                JXAScripts.fetchList("Today"),
                JXAScripts.fetchTodo(id: "test"),
                JXAScripts.fetchProjects(),
                JXAScripts.fetchAreas(),
                JXAScripts.fetchTags(),
                JXAScripts.completeTodo(id: "test"),
                JXAScripts.cancelTodo(id: "test"),
                JXAScripts.deleteTodo(id: "test"),
                JXAScripts.moveTodo(id: "test", toProject: "Project"),
                JXAScripts.updateTodo(id: "test", name: "Name"),
                JXAScripts.createTodo(name: "Task"),
                JXAScripts.search(query: "test"),
            ]

            for script in scripts {
                #expect(script.hasPrefix("(() => {"), "Script should start with IIFE")
                #expect(script.hasSuffix("})()"), "Script should end with IIFE invocation")
            }
        }

        @Test func allScriptsUseThings3App() {
            let scripts = [
                JXAScripts.fetchList("Today"),
                JXAScripts.fetchTodo(id: "test"),
                JXAScripts.fetchProjects(),
                JXAScripts.fetchAreas(),
                JXAScripts.fetchTags(),
                JXAScripts.completeTodo(id: "test"),
                JXAScripts.cancelTodo(id: "test"),
                JXAScripts.deleteTodo(id: "test"),
                JXAScripts.moveTodo(id: "test", toProject: "Project"),
                JXAScripts.updateTodo(id: "test", name: "Name"),
                JXAScripts.createTodo(name: "Task"),
                JXAScripts.search(query: "test"),
            ]

            for script in scripts {
                #expect(script.contains("Application('Things3')"))
            }
        }
    }
}
