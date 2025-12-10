// OutputFormatter.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Protocol for formatting output.
public protocol OutputFormatter {
    func format(todos: [Todo]) -> String
    func format(projects: [Project]) -> String
    func format(areas: [Area]) -> String
    func format(tags: [Tag]) -> String
    func format(todo: Todo) -> String
    func format(message: String) -> String
    func format(error: Error) -> String
}

/// Output format options.
public enum OutputFormat: String, CaseIterable, Sendable {
    case pretty
    case json

    public var description: String {
        switch self {
        case .pretty: return "Human-readable colored output"
        case .json: return "Machine-readable JSON output"
        }
    }
}

/// JSON output formatter.
public struct JSONOutputFormatter: OutputFormatter {
    private let encoder: JSONEncoder

    public init(prettyPrint: Bool = true) {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
    }

    public func format(todos: [Todo]) -> String {
        let response = TodoListResponse(count: todos.count, items: todos)
        return encode(response)
    }

    public func format(projects: [Project]) -> String {
        let response = ProjectListResponse(count: projects.count, items: projects)
        return encode(response)
    }

    public func format(areas: [Area]) -> String {
        let response = AreaListResponse(count: areas.count, items: areas)
        return encode(response)
    }

    public func format(tags: [Tag]) -> String {
        let response = TagListResponse(count: tags.count, items: tags)
        return encode(response)
    }

    public func format(todo: Todo) -> String {
        encode(todo)
    }

    public func format(message: String) -> String {
        encode(MessageResponse(message: message))
    }

    public func format(error: Error) -> String {
        encode(OutputErrorResponse(error: error.localizedDescription))
    }

    private func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

/// Text output formatter with optional colors.
public struct TextOutputFormatter: OutputFormatter {
    private let useColors: Bool

    public init(useColors: Bool = true) {
        // Check if stdout is a terminal
        self.useColors = useColors && isatty(STDOUT_FILENO) != 0
    }

    public func format(todos: [Todo]) -> String {
        if todos.isEmpty {
            return dim("No todos found")
        }

        var lines: [String] = []
        for todo in todos {
            lines.append(formatTodoLine(todo))
        }
        return lines.joined(separator: "\n")
    }

    public func format(projects: [Project]) -> String {
        if projects.isEmpty {
            return dim("No projects found")
        }

        var lines: [String] = []
        for project in projects {
            var line = bold(project.name)
            if let area = project.area {
                line += " " + dim("[\(area.name)]")
            }
            if project.status == .completed {
                line = strikethrough(line) + " " + green("✓")
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    public func format(areas: [Area]) -> String {
        if areas.isEmpty {
            return dim("No areas found")
        }

        return areas.map { bold($0.name) }.joined(separator: "\n")
    }

    public func format(tags: [Tag]) -> String {
        if tags.isEmpty {
            return dim("No tags found")
        }

        return tags.map { cyan("#\($0.name)") }.joined(separator: "\n")
    }

    public func format(todo: Todo) -> String {
        var lines: [String] = []

        // Title
        lines.append(bold(todo.name))

        // Status and dates
        var metaLine = "Status: \(statusColor(todo.status))"
        if let dueDate = todo.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            metaLine += "  Due: \(formatter.string(from: dueDate))"
        }
        lines.append(metaLine)

        // Project/Area
        if let project = todo.project {
            lines.append("Project: \(project.name)")
        }
        if let area = todo.area {
            lines.append("Area: \(area.name)")
        }

        // Tags
        if !todo.tags.isEmpty {
            let tagStr = todo.tags.map { cyan("#\($0.name)") }.joined(separator: " ")
            lines.append("Tags: \(tagStr)")
        }

        // Notes
        if let notes = todo.notes, !notes.isEmpty {
            lines.append("")
            lines.append(dim("Notes:"))
            lines.append(notes)
        }

        // Checklist
        if !todo.checklistItems.isEmpty {
            lines.append("")
            lines.append(dim("Checklist:"))
            for item in todo.checklistItems {
                let checkbox = item.completed ? green("☑") : "☐"
                let text = item.completed ? strikethrough(item.name) : item.name
                lines.append("  \(checkbox) \(text)")
            }
        }

        // ID
        lines.append("")
        lines.append(dim("ID: \(todo.id)"))

        return lines.joined(separator: "\n")
    }

    public func format(message: String) -> String {
        message
    }

    public func format(error: Error) -> String {
        red("Error: \(error.localizedDescription)")
    }

    // MARK: - Private Helpers

    private func formatTodoLine(_ todo: Todo) -> String {
        var parts: [String] = []

        // Checkbox
        let checkbox: String
        switch todo.status {
        case .open:
            checkbox = "☐"
        case .completed:
            checkbox = green("☑")
        case .canceled:
            checkbox = red("☒")
        }
        parts.append(checkbox)

        // Name
        var name = todo.name
        if todo.status == .completed || todo.status == .canceled {
            name = strikethrough(name)
        }
        parts.append(name)

        // Due date indicator
        if let dueDate = todo.dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let dateStr = formatter.string(from: dueDate)
            if todo.isOverdue {
                parts.append(red("(\(dateStr))"))
            } else {
                parts.append(dim("(\(dateStr))"))
            }
        }

        // Project
        if let project = todo.project {
            parts.append(dim("[\(project.name)]"))
        }

        // Tags
        if !todo.tags.isEmpty {
            let tagStr = todo.tags.map { cyan("#\($0.name)") }.joined(separator: " ")
            parts.append(tagStr)
        }

        return parts.joined(separator: " ")
    }

    private func statusColor(_ status: Status) -> String {
        switch status {
        case .open: return yellow("Open")
        case .completed: return green("Completed")
        case .canceled: return red("Canceled")
        }
    }

    // MARK: - ANSI Color Helpers

    private func color(_ text: String, code: String) -> String {
        guard useColors else { return text }
        return "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }

    private func bold(_ text: String) -> String { color(text, code: "1") }
    private func dim(_ text: String) -> String { color(text, code: "2") }
    private func strikethrough(_ text: String) -> String { color(text, code: "9") }
    private func red(_ text: String) -> String { color(text, code: "31") }
    private func green(_ text: String) -> String { color(text, code: "32") }
    private func yellow(_ text: String) -> String { color(text, code: "33") }
    private func cyan(_ text: String) -> String { color(text, code: "36") }
}

// MARK: - Response Types for JSON

struct TodoListResponse: Encodable {
    let count: Int
    let items: [Todo]
}

struct ProjectListResponse: Encodable {
    let count: Int
    let items: [Project]
}

struct AreaListResponse: Encodable {
    let count: Int
    let items: [Area]
}

struct TagListResponse: Encodable {
    let count: Int
    let items: [Tag]
}

struct MessageResponse: Encodable {
    let message: String
}

struct OutputErrorResponse: Encodable {
    let error: String
}
