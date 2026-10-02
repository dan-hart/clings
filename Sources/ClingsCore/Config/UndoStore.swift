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
    public var projectID: String? = nil
    public var areaID: String? = nil
    public var scheduledDate: Date? = nil
    public var creationDate: Date? = nil
    public var modificationDate: Date? = nil

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
        projectID = todo.project?.id
        areaID = todo.area?.id
        scheduledDate = todo.scheduledDate
        creationDate = todo.creationDate
        modificationDate = todo.modificationDate
    }
}

public struct UndoEntry: Codable, Equatable, Sendable {
    public let id: String
    public let operation: UndoOperation
    public let todoID: String
    public let snapshot: TodoSnapshot?
    public var createdAt: Date
    public var members: [UndoMember]? = nil

    public init(operation: UndoOperation, todoID: String, snapshot: TodoSnapshot?, createdAt: Date = Date()) {
        id = UUID().uuidString
        self.operation = operation
        self.todoID = todoID
        self.snapshot = snapshot
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey { case id, operation, todoID, snapshot, createdAt, members }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operation = try container.decode(UndoOperation.self, forKey: .operation)
        todoID = try container.decode(String.self, forKey: .todoID)
        snapshot = try container.decodeIfPresent(TodoSnapshot.self, forKey: .snapshot)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        members = try container.decodeIfPresent([UndoMember].self, forKey: .members)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "legacy:\(operation.rawValue):\(todoID):\(createdAt.timeIntervalSinceReferenceDate)"
    }
}

public struct UndoMember: Codable, Equatable, Sendable {
    public var operation: UndoOperation
    public var snapshot: TodoSnapshot
    public init(operation: UndoOperation, snapshot: TodoSnapshot) {
        self.operation = operation
        self.snapshot = snapshot
    }
}

public enum UndoStore {
    @TaskLocal public static var beforeSave: @Sendable () throws -> Void = {}
    private static let fileName = "undo-history.json"
    private static let maxEntries = 20

    public static func list() throws -> [UndoEntry] {
        let url = try ClingsConfig.fileURL(named: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try StateJSON.decoder().decode([UndoEntry].self, from: Data(contentsOf: url)).sorted { $0.createdAt > $1.createdAt }
    }

    public static func latest() throws -> UndoEntry? {
        try list().first
    }

    public static func record(_ entry: UndoEntry) throws {
        try MutationLock.withLock { try recordLocked(entry) }
    }

    private static func recordLocked(_ entry: UndoEntry) throws {
        var entries = try list().filter { !($0.todoID == entry.todoID && $0.createdAt == entry.createdAt) }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        try save(entries)
    }

    public static func replace(_ entry: UndoEntry) throws {
        try MutationLock.withLock {
            var entries = try list().filter { $0.id != entry.id }
            entries.append(entry)
            try save(Array(entries.sorted { $0.createdAt > $1.createdAt }.prefix(maxEntries)))
        }
    }

    public static func remove(id: String) throws {
        try MutationLock.withLock { try save(list().filter { $0.id != id }) }
    }

    private static func save(_ entries: [UndoEntry]) throws {
        try beforeSave()
        let url = try ClingsConfig.fileURL(named: fileName)
        try StateJSON.encoder().encode(entries).write(to: url, options: .atomic)
    }

    public static func popLatest() throws -> UndoEntry? {
        try MutationLock.withLock { try popLocked() }
    }

    private static func popLocked() throws -> UndoEntry? {
        var entries = try list()
        guard !entries.isEmpty else {
            return nil
        }
        let latest = entries.removeFirst()
        try save(entries)
        return latest
    }

    public static func clear() throws {
        try MutationLock.withLock { try save([]) }
    }
}
