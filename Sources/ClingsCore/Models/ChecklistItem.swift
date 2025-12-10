// ChecklistItem.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A checklist item within a todo.
public struct ChecklistItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var completed: Bool

    public init(id: String, name: String, completed: Bool = false) {
        self.id = id
        self.name = name
        self.completed = completed
    }

    /// Create a checklist item with just a name.
    public init(name: String, completed: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.completed = completed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case completed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
    }
}
