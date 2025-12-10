// Tag.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A tag for categorizing todos and projects.
public struct Tag: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    /// Create a tag with just a name (id will be generated).
    public init(name: String) {
        self.id = UUID().uuidString
        self.name = name
    }
}
