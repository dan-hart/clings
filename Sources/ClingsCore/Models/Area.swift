// Area.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// An area of responsibility in Things 3.
///
/// Areas are top-level organizational containers that group projects and todos.
public struct Area: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public var tags: [Tag]

    public init(id: String, name: String, tags: [Tag] = []) {
        self.id = id
        self.name = name
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
    }
}
