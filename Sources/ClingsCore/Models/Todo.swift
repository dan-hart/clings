// Todo.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A todo item from Things 3.
///
/// Represents a single task with metadata including title, notes, status,
/// due date, tags, and organizational hierarchy (project/area).
public struct Todo: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var notes: String?
    public var status: Status
    public var dueDate: Date?
    public var tags: [Tag]
    public var project: Project?
    public var area: Area?
    public var checklistItems: [ChecklistItem]
    public var creationDate: Date
    public var modificationDate: Date

    public init(
        id: String,
        name: String,
        notes: String? = nil,
        status: Status = .open,
        dueDate: Date? = nil,
        tags: [Tag] = [],
        project: Project? = nil,
        area: Area? = nil,
        checklistItems: [ChecklistItem] = [],
        creationDate: Date = Date(),
        modificationDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.status = status
        self.dueDate = dueDate
        self.tags = tags
        self.project = project
        self.area = area
        self.checklistItems = checklistItems
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case status
        case dueDate
        case tags
        case project
        case area
        case checklistItems
        case creationDate
        case modificationDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // Handle status as string from JXA
        if let statusString = try? container.decode(String.self, forKey: .status) {
            status = Status(thingsStatus: statusString) ?? .open
        } else {
            status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .open
        }

        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        project = try container.decodeIfPresent(Project.self, forKey: .project)
        area = try container.decodeIfPresent(Area.self, forKey: .area)
        checklistItems = try container.decodeIfPresent([ChecklistItem].self, forKey: .checklistItems) ?? []
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate) ?? Date()
        modificationDate = try container.decodeIfPresent(Date.self, forKey: .modificationDate) ?? Date()
    }

    // MARK: - Computed Properties

    public var isCompleted: Bool { status == .completed }
    public var isCanceled: Bool { status == .canceled }
    public var isOpen: Bool { status == .open }

    /// Whether the task is overdue (has a due date in the past and is still open).
    public var isOverdue: Bool {
        guard status == .open, let dueDate = dueDate else { return false }
        return dueDate < Date()
    }

    /// Human-readable summary for display.
    public var summary: String {
        var parts: [String] = [name]
        if let project = project {
            parts.append("[\(project.name)]")
        }
        if !tags.isEmpty {
            parts.append(tags.map { "#\($0.name)" }.joined(separator: " "))
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Todo, rhs: Todo) -> Bool {
        lhs.id == rhs.id
    }
}
