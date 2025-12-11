// TestData.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import ClingsCore

/// Test fixtures for unit tests.
enum TestData {
    // MARK: - Tags

    static let workTag = Tag(id: "tag-work", name: "work")
    static let urgentTag = Tag(id: "tag-urgent", name: "urgent")
    static let homeTag = Tag(id: "tag-home", name: "home")
    static let errandsTag = Tag(id: "tag-errands", name: "errands")

    static let allTags = [workTag, urgentTag, homeTag, errandsTag]

    // MARK: - Areas

    static let personalArea = Area(id: "area-personal", name: "Personal", tags: [homeTag])
    static let workArea = Area(id: "area-work", name: "Work", tags: [workTag])

    static let allAreas = [personalArea, workArea]

    // MARK: - Projects

    static let projectAlpha = Project(
        id: "proj-alpha",
        name: "Project Alpha",
        notes: "The first project",
        status: .open,
        area: workArea,
        tags: [workTag],
        dueDate: Date().addingTimeInterval(86400 * 7),
        creationDate: Date().addingTimeInterval(-86400 * 30)
    )

    static let projectBeta = Project(
        id: "proj-beta",
        name: "Project Beta",
        notes: nil,
        status: .completed,
        area: nil,
        tags: [],
        dueDate: nil,
        creationDate: Date().addingTimeInterval(-86400 * 60)
    )

    static let projectGamma = Project(
        id: "proj-gamma",
        name: "Project Gamma",
        notes: "Canceled project",
        status: .canceled,
        area: personalArea,
        tags: [],
        dueDate: nil,
        creationDate: Date().addingTimeInterval(-86400 * 90)
    )

    static let allProjects = [projectAlpha, projectBeta, projectGamma]
    static let openProjects = [projectAlpha]

    // MARK: - Checklist Items

    static let checklistItem1 = ChecklistItem(id: "check-1", name: "Step 1", completed: true)
    static let checklistItem2 = ChecklistItem(id: "check-2", name: "Step 2", completed: false)
    static let checklistItem3 = ChecklistItem(id: "check-3", name: "Step 3", completed: false)

    // MARK: - Todos

    static let todoOpen = Todo(
        id: "todo-open",
        name: "Open task",
        notes: "This is an open task",
        status: .open,
        dueDate: Date().addingTimeInterval(86400),
        tags: [workTag],
        project: projectAlpha,
        area: workArea,
        checklistItems: [],
        creationDate: Date().addingTimeInterval(-86400),
        modificationDate: Date()
    )

    static let todoCompleted = Todo(
        id: "todo-completed",
        name: "Completed task",
        notes: nil,
        status: .completed,
        dueDate: nil,
        tags: [],
        project: nil,
        area: nil,
        checklistItems: [],
        creationDate: Date().addingTimeInterval(-86400 * 2),
        modificationDate: Date().addingTimeInterval(-86400)
    )

    static let todoCanceled = Todo(
        id: "todo-canceled",
        name: "Canceled task",
        notes: "Was not needed",
        status: .canceled,
        dueDate: nil,
        tags: [urgentTag],
        project: nil,
        area: nil,
        checklistItems: [],
        creationDate: Date().addingTimeInterval(-86400 * 3),
        modificationDate: Date().addingTimeInterval(-86400 * 2)
    )

    static let todoOverdue = Todo(
        id: "todo-overdue",
        name: "Overdue task",
        notes: "This should have been done",
        status: .open,
        dueDate: Date().addingTimeInterval(-86400), // Yesterday
        tags: [urgentTag, workTag],
        project: projectAlpha,
        area: workArea,
        checklistItems: [checklistItem1, checklistItem2],
        creationDate: Date().addingTimeInterval(-86400 * 7),
        modificationDate: Date()
    )

    static let todoNoProject = Todo(
        id: "todo-no-project",
        name: "Task without project",
        notes: nil,
        status: .open,
        dueDate: nil,
        tags: [homeTag],
        project: nil,
        area: personalArea,
        checklistItems: [],
        creationDate: Date(),
        modificationDate: Date()
    )

    static let todoWithChecklist = Todo(
        id: "todo-checklist",
        name: "Task with checklist",
        notes: "Has multiple steps",
        status: .open,
        dueDate: Date().addingTimeInterval(86400 * 3),
        tags: [],
        project: nil,
        area: nil,
        checklistItems: [checklistItem1, checklistItem2, checklistItem3],
        creationDate: Date(),
        modificationDate: Date()
    )

    static let allTodos = [todoOpen, todoCompleted, todoCanceled, todoOverdue, todoNoProject, todoWithChecklist]
    static let openTodos = [todoOpen, todoOverdue, todoNoProject, todoWithChecklist]
    static let completedTodos = [todoCompleted]
    static let inboxTodos = [todoNoProject]
    static let todayTodos = [todoOpen, todoOverdue]

    // MARK: - JSON Fixtures

    static let todoJSON = """
    {
        "id": "json-todo",
        "name": "JSON Todo",
        "notes": "Created from JSON",
        "status": "open",
        "dueDate": "2024-12-25T00:00:00Z",
        "tags": [{"id": "t1", "name": "test"}],
        "project": null,
        "area": null,
        "checklistItems": [],
        "creationDate": "2024-01-01T00:00:00Z",
        "modificationDate": "2024-06-15T00:00:00Z"
    }
    """

    static let todoJSONWithStatusString = """
    {
        "id": "json-todo-2",
        "name": "JSON Todo 2",
        "status": "completed",
        "tags": []
    }
    """

    static let projectJSON = """
    {
        "id": "json-project",
        "name": "JSON Project",
        "notes": null,
        "status": "open",
        "area": null,
        "tags": [],
        "dueDate": null,
        "creationDate": "2024-01-01T00:00:00Z"
    }
    """

    static let areaJSON = """
    {
        "id": "json-area",
        "name": "JSON Area",
        "tags": []
    }
    """

    static let tagJSON = """
    {
        "id": "json-tag",
        "name": "json-tag"
    }
    """

    static let checklistItemJSON = """
    {
        "name": "Checklist from JSON",
        "completed": true
    }
    """

    static let checklistItemJSONMinimal = """
    {
        "name": "Minimal checklist"
    }
    """
}
