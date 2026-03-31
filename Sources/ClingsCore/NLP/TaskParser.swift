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
    private let dateParser = NaturalLanguageDateParser()

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

        // Extract quoted project (for "Project Name")
        let quotedProjectPattern = #"\bfor\s+"([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: quotedProjectPattern, options: []),
           let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
           let projectRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining) {
            project = String(remaining[projectRange]).trimmingCharacters(in: .whitespaces)
            remaining.removeSubrange(fullRange)
        }

        // Extract project (for ProjectName)
        let projectPattern = #"\bfor\s+([A-Z][^\s#!]+(?:\s+[A-Z][^\s#!]+)*)"#
        if project == nil,
           let regex = try? NSRegularExpression(pattern: projectPattern, options: []),
           let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
           let projectRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining) {
            project = String(remaining[projectRange]).trimmingCharacters(in: .whitespaces)
            remaining.removeSubrange(fullRange)
        }

        // Extract quoted area (in "Area Name")
        let quotedAreaPattern = #"\bin\s+"([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: quotedAreaPattern, options: []),
           let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
           let areaRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining) {
            area = String(remaining[areaRange]).trimmingCharacters(in: .whitespaces)
            remaining.removeSubrange(fullRange)
        }

        // Extract area (in AreaName) - but not "in X days"
        let areaPattern = #"\bin\s+([A-Z][^\s#!]+(?:\s+[A-Z][^\s#!]+)*)(?!\s+days?)"#
        if area == nil,
           let regex = try? NSRegularExpression(pattern: areaPattern, options: []),
           let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
           let areaRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining) {
            area = String(remaining[areaRange]).trimmingCharacters(in: .whitespaces)
            remaining.removeSubrange(fullRange)
        }

        // Extract deadline (by friday, by dec 15, by dec 15 3pm)
        let deadlinePattern = #"\bby\s+((?:next\s+\w+|today|tomorrow|this evening|tomorrow morning|tomorrow evening|in\s+\d+\s+days?|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+\d{1,2}(?:\s+\d{1,2}(?::\d{2})?\s*(?:am|pm))?|\w+(?:\s+\d{1,2}(?::\d{2})?\s*(?:am|pm))?))"#
        if let regex = try? NSRegularExpression(pattern: deadlinePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
           let dateRange = Range(match.range(at: 1), in: remaining),
           let fullRange = Range(match.range, in: remaining) {
            let dateStr = String(remaining[dateRange])
            dueDate = dateParser.parse(dateStr)
            remaining.removeSubrange(fullRange)
        }

        // Extract when date (tomorrow, next monday, dec 15, dec 15 3pm)
        let whenPatterns = [
            #"\btomorrow\s+(?:morning|evening|\d{1,2}(?::\d{2})?\s*(?:am|pm))\b"#,
            #"\btoday\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)\b"#,
            #"\bthis evening\b"#,
            #"\btomorrow\b"#,
            #"\btoday\b"#,
            #"\bnext\s+\w+\b"#,
            #"\bin\s+\d+\s+days?\b"#,
            #"\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+\d{1,2}(?:\s+\d{1,2}(?::\d{2})?\s*(?:am|pm))?\b"#,
            #"\b(?:monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)(?:\s+\d{1,2}(?::\d{2})?\s*(?:am|pm))?\b"#,
        ]
        for pattern in whenPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
               let range = Range(match.range, in: remaining) {
                let dateStr = String(remaining[range])
                whenDate = dateParser.parse(dateStr)
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
        dateParser.parse(str)
    }
}
