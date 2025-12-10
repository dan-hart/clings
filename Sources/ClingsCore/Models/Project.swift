// Project.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A project in Things 3.
///
/// Projects are containers for related todos, with their own status,
/// due date, and organizational placement (area).
public struct Project: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var notes: String?
    public var status: Status
    public var area: Area?
    public var tags: [Tag]
    public var dueDate: Date?
    public var creationDate: Date?

    public init(
        id: String,
        name: String,
        notes: String? = nil,
        status: Status = .open,
        area: Area? = nil,
        tags: [Tag] = [],
        dueDate: Date? = nil,
        creationDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.status = status
        self.area = area
        self.tags = tags
        self.dueDate = dueDate
        self.creationDate = creationDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case status
        case area
        case tags
        case dueDate
        case creationDate
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

        area = try container.decodeIfPresent(Area.self, forKey: .area)
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
    }

    public var isCompleted: Bool { status == .completed }
    public var isCanceled: Bool { status == .canceled }
    public var isOpen: Bool { status == .open }
}
