// TaskParser.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Result of parsing a natural language task description.
public struct ParsedTask: Sendable {
    public var title: String
    public var notes: String?
    public var tags: [String]
    public var project: String?
    public var area: String?
    public var dueDate: Date?
    public var whenDate: Date?
    public var checklistItems: [String]
    public var priority: Priority?

    public init(
        title: String,
        notes: String? = nil,
        tags: [String] = [],
        project: String? = nil,
        area: String? = nil,
        dueDate: Date? = nil,
        whenDate: Date? = nil,
        checklistItems: [String] = [],
        priority: Priority? = nil
    ) {
        self.title = title
        self.notes = notes
        self.tags = tags
        self.project = project
        self.area = area
        self.dueDate = dueDate
        self.whenDate = whenDate
        self.checklistItems = checklistItems
        self.priority = priority
    }
}

/// Parses natural language task descriptions into structured data.
public struct TaskParser: Sendable {
    public init() {}

    /// Parse a natural language task string.
    public func parse(_ input: String) -> ParsedTask {
        var remaining = input
        var tags: [String] = []
        var project: String?
        var area: String?
        var dueDate: Date?
        var whenDate: Date?
        var checklistItems: [String] = []
        var notes: String?
        var priority: Priority?

        // Extract notes (// at end)
        if let notesRange = remaining.range(of: " //") {
            notes = String(remaining[notesRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            remaining = String(remaining[..<notesRange.lowerBound])
        }

        // Extract checklist items (- item1 - item2)
        let checklistPattern = #"\s+-\s+(.+?)(?=\s+-\s+|$)"#
        if let regex = try? NSRegularExpression(pattern: checklistPattern, options: []) {
            let nsRange = NSRange(remaining.startIndex..., in: remaining)
            let matches = regex.matches(in: remaining, options: [], range: nsRange)
            for match in matches.reversed() {
                if let itemRange = Range(match.range(at: 1), in: remaining) {
                    checklistItems.insert(String(remaining[itemRange]), at: 0)
                }
                if let fullRange = Range(match.range, in: remaining) {
                    remaining.removeSubrange(fullRange)
                }
            }
        }

        // Extract tags (#tag)
        let tagPattern = #"(?<!\\)#(\w+)"#
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let nsRange = NSRange(remaining.startIndex..., in: remaining)
            let matches = regex.matches(in: remaining, options: [], range: nsRange)
            for match in matches.reversed() {
                if let tagRange = Range(match.range(at: 1), in: remaining) {
                    tags.insert(String(remaining[tagRange]), at: 0)
                }
                if let fullRange = Range(match.range, in: remaining) {
                    remaining.removeSubrange(fullRange)
                }
            }
        }

        // Extract priority (!, !!, !!!, !high, !medium, !low)
        let priorityPatterns = [
            (#"!!!(?!\w)"#, Priority.high),
            (#"!!(?!\w)"#, Priority.medium),
            (#"!(?!\w)"#, Priority.low),
            (#"!high"#, Priority.high),
            (#"!medium"#, Priority.medium),
            (#"!low"#, Priority.low),
        ]
        for (pattern, p) in priorityPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
               let range = Range(match.range, in: remaining) {
                priority = p
                remaining.removeSubrange(range)
                break
            }
        }

        // Extract project (for ProjectName)
        let projectPattern = #"\bfor\s+([A-Z][^\s#!]+(?:\s+[A-Z][^\s#!]+)*)"#
        if let regex = try? NSRegularExpression(pattern: projectPattern, options: []),
           let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
           let projectRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining) {
            project = String(remaining[projectRange]).trimmingCharacters(in: .whitespaces)
            remaining.removeSubrange(fullRange)
        }

        // Extract area (in AreaName) - but not "in X days"
        let areaPattern = #"\bin\s+([A-Z][^\s#!]+(?:\s+[A-Z][^\s#!]+)*)(?!\s+days?)"#
        if let regex = try? NSRegularExpression(pattern: areaPattern, options: []),
           let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
           let areaRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining) {
            area = String(remaining[areaRange]).trimmingCharacters(in: .whitespaces)
            remaining.removeSubrange(fullRange)
        }

        // Extract deadline (by friday, by dec 15)
        let deadlinePattern = #"\bby\s+(\w+(?:\s+\d+)?)"#
        if let regex = try? NSRegularExpression(pattern: deadlinePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
           let dateRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining) {
            let dateStr = String(remaining[dateRange])
            dueDate = parseDate(dateStr)
            remaining.removeSubrange(fullRange)
        }

        // Extract when date (tomorrow, next monday, dec 15)
        let whenPatterns = [
            #"\btomorrow\b"#,
            #"\btoday\b"#,
            #"\bnext\s+\w+"#,
            #"\bin\s+\d+\s+days?"#,
        ]
        for pattern in whenPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
               let range = Range(match.range, in: remaining) {
                let dateStr = String(remaining[range])
                whenDate = parseDate(dateStr)
                remaining.removeSubrange(range)
                break
            }
        }

        // Clean up title
        let title = remaining
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\#", with: "#") // Unescape literal #

        return ParsedTask(
            title: title,
            notes: notes,
            tags: tags,
            project: project,
            area: area,
            dueDate: dueDate,
            whenDate: whenDate,
            checklistItems: checklistItems,
            priority: priority
        )
    }

    /// Parse a date string into a Date.
    private func parseDate(_ str: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        let lower = str.lowercased()

        // Relative dates
        if lower == "today" {
            return calendar.startOfDay(for: now)
        }
        if lower == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        }

        // "in X days"
        if lower.hasPrefix("in ") {
            let parts = lower.split(separator: " ")
            if parts.count >= 2, let days = Int(parts[1]) {
                return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))
            }
        }

        // "next monday", "next friday", etc.
        if lower.hasPrefix("next ") {
            let dayName = String(lower.dropFirst(5))
            if let weekday = weekdayFromName(dayName) {
                return nextOccurrence(of: weekday, from: now)
            }
        }

        // Day names (monday, tuesday, etc.)
        if let weekday = weekdayFromName(lower) {
            return nextOccurrence(of: weekday, from: now)
        }

        return nil
    }

    private func weekdayFromName(_ name: String) -> Int? {
        let mapping: [String: Int] = [
            "sunday": 1, "sun": 1,
            "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3,
            "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5,
            "friday": 6, "fri": 6,
            "saturday": 7, "sat": 7,
        ]
        return mapping[name.lowercased()]
    }

    private func nextOccurrence(of weekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: date)
        var daysToAdd = weekday - todayWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }
        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: date))
    }
}
