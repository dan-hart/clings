// ListView.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A list view in Things 3.
///
/// Represents the built-in smart lists that organize todos by their scheduling state.
public enum ListView: String, Codable, CaseIterable, Sendable {
    /// Unprocessed todos awaiting organization.
    case inbox
    /// Todos scheduled for today.
    case today
    /// Todos scheduled for future dates.
    case upcoming
    /// Todos available anytime (no specific schedule).
    case anytime
    /// Todos deferred for someday/maybe.
    case someday
    /// Completed todos archive.
    case logbook
    /// Deleted todos.
    case trash

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .anytime: return "Anytime"
        case .someday: return "Someday"
        case .logbook: return "Logbook"
        case .trash: return "Trash"
        }
    }

    /// The list name as used in Things 3 JXA/AppleScript.
    public var thingsListName: String {
        displayName
    }

    /// The list name in lowercase for JXA access.
    public var jxaListName: String {
        rawValue
    }
}
