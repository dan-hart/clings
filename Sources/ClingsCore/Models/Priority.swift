// Priority.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Priority levels for tasks.
public enum Priority: Int, Codable, CaseIterable, Comparable, Sendable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Symbol representation for display.
    public var symbol: String {
        switch self {
        case .none: return ""
        case .low: return "!"
        case .medium: return "!!"
        case .high: return "!!!"
        }
    }

    /// Human-readable name.
    public var name: String {
        switch self {
        case .none: return "none"
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }

    /// Initialize from a string like "high", "!!", etc.
    public init?(string: String) {
        switch string.lowercased() {
        case "none", "": self = .none
        case "low", "!", "!low": self = .low
        case "medium", "!!", "!medium": self = .medium
        case "high", "!!!", "!high": self = .high
        default: return nil
        }
    }

    /// Convert to Things 3 priority value (optional, since Things doesn't have explicit priority).
    public var thingsValue: Int? {
        switch self {
        case .none: return nil
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}
