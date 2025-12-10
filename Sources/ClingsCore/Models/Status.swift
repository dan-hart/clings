// Status.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// The completion status of a todo or project.
public enum Status: String, Codable, CaseIterable, Sendable {
    case open
    case completed
    case canceled

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .open: return "Open"
        case .completed: return "Completed"
        case .canceled: return "Canceled"
        }
    }

    /// Initialize from Things 3 status string.
    public init?(thingsStatus: String) {
        switch thingsStatus.lowercased() {
        case "open", "": self = .open
        case "completed": self = .completed
        case "canceled", "cancelled": self = .canceled
        default: return nil
        }
    }
}
