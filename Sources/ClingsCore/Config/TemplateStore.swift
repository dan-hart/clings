// TemplateStore.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct TaskTemplate: Codable, Equatable, Sendable {
    public let name: String
    public let title: String
    public let notes: String?
    public let tags: [String]
    public let project: String?
    public let area: String?
    public let whenExpression: String?
    public let deadlineExpression: String?
    public let checklistItems: [String]
    public let createdAt: Date

    public init(
        name: String,
        title: String,
        notes: String? = nil,
        tags: [String] = [],
        project: String? = nil,
        area: String? = nil,
        whenExpression: String? = nil,
        deadlineExpression: String? = nil,
        checklistItems: [String] = [],
        createdAt: Date = Date()
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tags = tags
        self.project = project?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.area = area?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.whenExpression = whenExpression?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deadlineExpression = deadlineExpression?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.checklistItems = checklistItems
        self.createdAt = createdAt
    }
}

public enum TemplateStore {
    private static let fileName = "templates.json"

    public static func list() throws -> [TaskTemplate] {
        try JSONFileStore
            .load([TaskTemplate].self, from: fileName, default: [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public static func load(name: String) throws -> TaskTemplate? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return try list().first { $0.name == trimmed }
    }

    public static func save(_ template: TaskTemplate) throws {
        guard !template.name.isEmpty else {
            throw ThingsError.invalidState("Template name cannot be empty")
        }
        guard !template.title.isEmpty else {
            throw ThingsError.invalidState("Template title cannot be empty")
        }

        var templates = try list().filter { $0.name != template.name }
        templates.append(template)
        try JSONFileStore.save(templates, to: fileName)
    }

    @discardableResult
    public static func delete(name: String) throws -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = try list()
        let remaining = existing.filter { $0.name != trimmed }
        guard remaining.count != existing.count else {
            return false
        }
        try JSONFileStore.save(remaining, to: fileName)
        return true
    }
}
