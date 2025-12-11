// UATestData.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import ClingsCore

/// Test fixtures for ua-conductor real-world integration tests.
/// These test patterns used in production for Things 3 automation.
enum UATestData {
    // MARK: - Tags (matching ua-conductor patterns)

    static let meetingActionTag = Tag(id: "tag-meeting-action", name: "meeting-action")
    static let jiraTag = Tag(id: "tag-jira", name: "jira")
    static let urgentTag = Tag(id: "tag-urgent", name: "urgent")
    static let reviewTag = Tag(id: "tag-review", name: "review")

    static let allTags = [meetingActionTag, jiraTag, urgentTag, reviewTag]

    // MARK: - Areas (with emoji prefixes as used in ua-conductor)

    static let underArmourArea = Area(
        id: "area-ua",
        name: "🖥️ Under Armour",
        tags: [jiraTag]
    )

    static let personalArea = Area(
        id: "area-personal",
        name: "🏠 Personal",
        tags: []
    )

    static let healthArea = Area(
        id: "area-health",
        name: "💪 Health",
        tags: []
    )

    static let allAreas = [underArmourArea, personalArea, healthArea]

    // MARK: - Projects

    static let mobileProject = Project(
        id: "proj-mobile",
        name: "Mobile App",
        notes: "iOS and Android development",
        status: .open,
        area: underArmourArea,
        tags: [jiraTag],
        dueDate: nil,
        creationDate: Date().addingTimeInterval(-86400 * 30)
    )

    // MARK: - Todos (matching ua-conductor use cases)

    /// Meeting action item - created from sync-action-items.sh
    static let meetingAction = Todo(
        id: "todo-meeting-1",
        name: "Follow up on API changes discussed in standup",
        notes: "From meeting on 2025-12-10",
        status: .open,
        dueDate: Date().addingTimeInterval(86400 * 2),
        tags: [meetingActionTag],
        project: mobileProject,
        area: underArmourArea,
        checklistItems: [],
        creationDate: Date().addingTimeInterval(-3600),
        modificationDate: Date()
    )

    /// JIRA ticket task - created with ticket reference
    static let jiraTask = Todo(
        id: "todo-jira-1",
        name: "Review SHOP-1234 implementation",
        notes: "PR needs review before merge",
        status: .open,
        dueDate: Date().addingTimeInterval(86400),
        tags: [jiraTag, reviewTag],
        project: mobileProject,
        area: underArmourArea,
        checklistItems: [],
        creationDate: Date().addingTimeInterval(-86400),
        modificationDate: Date()
    )

    /// Completed task (for logbook tests)
    static let completedTask = Todo(
        id: "todo-completed-ua",
        name: "Merge PR #267",
        notes: "Feature branch merged",
        status: .completed,
        dueDate: nil,
        tags: [jiraTag],
        project: mobileProject,
        area: underArmourArea,
        checklistItems: [],
        creationDate: Date().addingTimeInterval(-86400 * 3),
        modificationDate: Date().addingTimeInterval(-3600)
    )

    /// Task with escaped hash in title
    static let hashEscapedTask = Todo(
        id: "todo-hash-escape",
        name: "Review PR #267 changes",
        notes: "Hash should not be parsed as tag",
        status: .open,
        dueDate: nil,
        tags: [],
        project: mobileProject,
        area: underArmourArea,
        checklistItems: [],
        creationDate: Date(),
        modificationDate: Date()
    )

    /// Task with multiple inline tags (NLP parsing test)
    static let inlineTagsTask = Todo(
        id: "todo-inline-tags",
        name: "Update documentation",
        notes: nil,
        status: .open,
        dueDate: nil,
        tags: [urgentTag, reviewTag],
        project: nil,
        area: underArmourArea,
        checklistItems: [],
        creationDate: Date(),
        modificationDate: Date()
    )

    /// Personal area task (for area filtering tests)
    static let personalTask = Todo(
        id: "todo-personal",
        name: "Schedule dentist appointment",
        notes: nil,
        status: .open,
        dueDate: Date().addingTimeInterval(86400 * 7),
        tags: [],
        project: nil,
        area: personalArea,
        checklistItems: [],
        creationDate: Date(),
        modificationDate: Date()
    )

    // MARK: - Collections

    static let allTodos = [
        meetingAction,
        jiraTask,
        completedTask,
        hashEscapedTask,
        inlineTagsTask,
        personalTask,
    ]

    static let openTodos = allTodos.filter { $0.status == .open }
    static let uaTodos = allTodos.filter { $0.area?.name == "🖥️ Under Armour" }
    static let taggedMeetingAction = allTodos.filter { $0.tags.contains { $0.name == "meeting-action" } }
}
