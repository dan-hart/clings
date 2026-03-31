// FocusPlanner.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct FocusItem: Codable, Equatable, Sendable {
    public let todo: Todo
    public let score: Int
    public let reasons: [String]
}

public struct FocusPlan: Codable, Equatable, Sendable {
    public let items: [FocusItem]
}

public struct FocusPlanner: Sendable {
    public init() {}

    public func build(todos: [Todo], limit: Int = 10, referenceDate: Date = Date()) -> FocusPlan {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? startOfToday

        let items = todos
            .filter(\.isOpen)
            .map { todo in
                var score = 0
                var reasons: [String] = []

                if todo.isOverdue {
                    score += 100
                    reasons.append("Overdue")
                }

                if let dueDate = todo.dueDate {
                    if calendar.isDate(dueDate, inSameDayAs: referenceDate) {
                        score += 60
                        reasons.append("Due today")
                    } else if dueDate < endOfTomorrow {
                        score += 35
                        reasons.append("Due soon")
                    }
                }

                if todo.tags.contains(where: { ["urgent", "priority", "high"].contains($0.name.lowercased()) }) {
                    score += 25
                    reasons.append("Urgent tag")
                }

                if todo.project == nil {
                    score += 5
                    reasons.append("Unassigned")
                }

                return FocusItem(todo: todo, score: score, reasons: reasons)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                switch (lhs.todo.dueDate, rhs.todo.dueDate) {
                case let (left?, right?):
                    if left != right {
                        return left < right
                    }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }
                return lhs.todo.name.localizedCaseInsensitiveCompare(rhs.todo.name) == .orderedAscending
            }

        return FocusPlan(items: Array(items.prefix(limit)))
    }
}
