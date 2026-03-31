// TodoLineFormatter.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Formats a todo using placeholder substitution.
public struct TodoLineFormatter: Sendable {
    public let template: String

    public init(template: String) {
        self.template = template
    }

    public func format(todo: Todo) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let replacements: [String: String] = [
            "id": todo.id,
            "name": todo.name,
            "status": todo.status.rawValue,
            "due": todo.dueDate.map { formatter.string(from: $0) } ?? "",
            "project": todo.project?.name ?? "",
            "area": todo.area?.name ?? "",
            "tags": todo.tags.map { "#\($0.name)" }.joined(separator: " "),
        ]

        var output = template
        for (key, value) in replacements {
            output = output.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return output
    }
}
