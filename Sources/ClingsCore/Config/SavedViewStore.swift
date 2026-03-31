// SavedViewStore.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct SavedView: Codable, Equatable, Sendable {
    public let name: String
    public let expression: String
    public let note: String?
    public let createdAt: Date

    public init(name: String, expression: String, note: String? = nil, createdAt: Date = Date()) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.expression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

public enum SavedViewStore {
    private static let fileName = "saved-views.json"

    public static func list() throws -> [SavedView] {
        try JSONFileStore
            .load([SavedView].self, from: fileName, default: [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public static func load(name: String) throws -> SavedView? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return try list().first { $0.name == trimmed }
    }

    public static func save(_ view: SavedView) throws {
        guard !view.name.isEmpty else {
            throw ThingsError.invalidState("Saved view name cannot be empty")
        }
        guard !view.expression.isEmpty else {
            throw ThingsError.invalidState("Saved view expression cannot be empty")
        }

        var views = try list().filter { $0.name != view.name }
        views.append(view)
        try JSONFileStore.save(views, to: fileName)
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
