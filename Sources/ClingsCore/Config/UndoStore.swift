// UndoStore.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum UndoOperation: String, Codable, Equatable, Sendable {
    case create
    case update
    case complete
    case cancel
    case delete
}

public struct TodoSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let notes: String?
    public let dueDate: Date?
    public let tags: [String]
    public let status: Status
    public let projectName: String?
    public let areaName: String?

    public init(
        id: String,
        name: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        tags: [String] = [],
        status: Status,
        projectName: String? = nil,
        areaName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.dueDate = dueDate
        self.tags = tags
        self.status = status
        self.projectName = projectName
        self.areaName = areaName
    }

    public init(todo: Todo) {
        self.init(
            id: todo.id,
            name: todo.name,
            notes: todo.notes,
            dueDate: todo.dueDate,
            tags: todo.tags.map(\.name),
            status: todo.status,
            projectName: todo.project?.name,
            areaName: todo.area?.name
        )
    }
}

public struct UndoEntry: Codable, Equatable, Sendable {
    public let operation: UndoOperation
    public let todoID: String
    public let snapshot: TodoSnapshot?
    public let createdAt: Date

    public init(operation: UndoOperation, todoID: String, snapshot: TodoSnapshot?, createdAt: Date = Date()) {
        self.operation = operation
        self.todoID = todoID
        self.snapshot = snapshot
        self.createdAt = createdAt
    }
}

public enum UndoStore {
    private static let fileName = "undo-history.json"
    private static let maxEntries = 20

    public static func list() throws -> [UndoEntry] {
        try JSONFileStore
            .load([UndoEntry].self, from: fileName, default: [])
            .sorted { $0.createdAt > $1.createdAt }
    }

    public static func latest() throws -> UndoEntry? {
        try list().first
    }

    public static func record(_ entry: UndoEntry) throws {
        var entries = try list().filter { !($0.todoID == entry.todoID && $0.createdAt == entry.createdAt) }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        try JSONFileStore.save(entries, to: fileName)
    }

    public static func popLatest() throws -> UndoEntry? {
        var entries = try list()
        guard !entries.isEmpty else {
            return nil
        }
        let latest = entries.removeFirst()
        try JSONFileStore.save(entries, to: fileName)
        return latest
    }

    public static func clear() throws {
        try JSONFileStore.save([UndoEntry](), to: fileName)
    }
}
