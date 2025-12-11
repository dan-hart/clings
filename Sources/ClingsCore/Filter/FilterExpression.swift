// FilterExpression.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Comparison operators for filter conditions.
public enum FilterOperator: String, Sendable {
    case equal = "="
    case notEqual = "!="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="
    case like = "LIKE"
    case contains = "CONTAINS"
    case isNull = "IS NULL"
    case isNotNull = "IS NOT NULL"
    case `in` = "IN"
}

/// Logical operators for combining conditions.
public enum LogicalOperator: String, Sendable {
    case and = "AND"
    case or = "OR"
}

/// A value in a filter expression.
public enum FilterValue: Sendable, Equatable {
    case string(String)
    case date(Date)
    case bool(Bool)
    case integer(Int)
    case stringList([String])
    case none

    /// Parse a value from a string.
    public static func parse(_ input: String) -> FilterValue {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Check for quoted string
        if (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
           (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) {
            let start = trimmed.index(after: trimmed.startIndex)
            let end = trimmed.index(before: trimmed.endIndex)
            return .string(String(trimmed[start..<end]))
        }

        // Check for list (for IN operator)
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            let start = trimmed.index(after: trimmed.startIndex)
            let end = trimmed.index(before: trimmed.endIndex)
            let inner = String(trimmed[start..<end])
            let items = inner.split(separator: ",").map { part -> String in
                let t = part.trimmingCharacters(in: .whitespaces)
                if (t.hasPrefix("'") && t.hasSuffix("'")) ||
                   (t.hasPrefix("\"") && t.hasSuffix("\"")) {
                    let s = t.index(after: t.startIndex)
                    let e = t.index(before: t.endIndex)
                    return String(t[s..<e])
                }
                return t
            }
            return .stringList(items)
        }

        // Check for boolean
        switch trimmed.lowercased() {
        case "true": return .bool(true)
        case "false": return .bool(false)
        default: break
        }

        // Check for integer
        if let n = Int(trimmed) {
            return .integer(n)
        }

        // Check for date (natural language)
        if let date = parseNaturalDate(trimmed) {
            return .date(date)
        }

        // Default to string
        return .string(trimmed)
    }

    /// Parse natural language dates like "today", "tomorrow", "next monday".
    private static func parseNaturalDate(_ input: String) -> Date? {
        let lowercased = input.lowercased()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch lowercased {
        case "today":
            return today
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: today)
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: today)
        default:
            break
        }

        // Check for ISO date (YYYY-MM-DD)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: input) {
            return date
        }

        // Check for relative days like "in 3 days"
        if lowercased.hasPrefix("in ") && lowercased.hasSuffix(" days") {
            let numberPart = lowercased.dropFirst(3).dropLast(5).trimmingCharacters(in: .whitespaces)
            if let days = Int(numberPart) {
                return calendar.date(byAdding: .day, value: days, to: today)
            }
        }

        // Check for weekday names
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        if let targetWeekday = weekdays.firstIndex(of: lowercased) {
            let todayWeekday = calendar.component(.weekday, from: today) - 1 // 0-based
            var daysToAdd = targetWeekday - todayWeekday
            if daysToAdd <= 0 {
                daysToAdd += 7
            }
            return calendar.date(byAdding: .day, value: daysToAdd, to: today)
        }

        return nil
    }
}

/// A single filter condition.
public struct FilterCondition: Sendable {
    public let field: String
    public let `operator`: FilterOperator
    public let value: FilterValue

    public init(field: String, operator: FilterOperator, value: FilterValue) {
        self.field = field
        self.operator = `operator`
        self.value = value
    }
}

/// A filter expression (condition or compound expression).
public indirect enum FilterExpression: Sendable {
    case condition(FilterCondition)
    case not(FilterExpression)
    case compound(left: FilterExpression, op: LogicalOperator, right: FilterExpression)

    /// Evaluate this expression against a filterable item.
    public func matches(_ item: Filterable) -> Bool {
        switch self {
        case .condition(let cond):
            return evaluateCondition(item, cond)
        case .not(let expr):
            return !expr.matches(item)
        case .compound(let left, let op, let right):
            switch op {
            case .and:
                return left.matches(item) && right.matches(item)
            case .or:
                return left.matches(item) || right.matches(item)
            }
        }
    }
}

/// Protocol for items that can be filtered.
public protocol Filterable {
    func fieldValue(_ field: String) -> FieldValue?
}

/// A field value from a filterable item.
public enum FieldValue: Sendable {
    case string(String)
    case optionalString(String?)
    case date(Date)
    case optionalDate(Date?)
    case bool(Bool)
    case integer(Int)
    case stringList([String])

    public var isNull: Bool {
        switch self {
        case .optionalString(let s): return s == nil
        case .optionalDate(let d): return d == nil
        default: return false
        }
    }
}

// MARK: - Evaluation Functions

private func evaluateCondition(_ item: Filterable, _ condition: FilterCondition) -> Bool {
    guard let fieldValue = item.fieldValue(condition.field) else {
        // Unknown field - check if it's a null check
        return condition.operator == .isNull
    }

    switch condition.operator {
    case .equal:
        return matchEqual(fieldValue, condition.value)
    case .notEqual:
        return !matchEqual(fieldValue, condition.value)
    case .lessThan:
        return matchCompare(fieldValue, condition.value) { $0 < $1 }
    case .lessThanOrEqual:
        return matchCompare(fieldValue, condition.value) { $0 <= $1 }
    case .greaterThan:
        return matchCompare(fieldValue, condition.value) { $0 > $1 }
    case .greaterThanOrEqual:
        return matchCompare(fieldValue, condition.value) { $0 >= $1 }
    case .like:
        return matchLike(fieldValue, condition.value)
    case .contains:
        return matchContains(fieldValue, condition.value)
    case .isNull:
        return fieldValue.isNull
    case .isNotNull:
        return !fieldValue.isNull
    case .in:
        return matchIn(fieldValue, condition.value)
    }
}

private func matchEqual(_ fieldValue: FieldValue, _ filterValue: FilterValue) -> Bool {
    switch (fieldValue, filterValue) {
    case (.string(let s), .string(let v)),
         (.optionalString(.some(let s)), .string(let v)):
        return s.lowercased() == v.lowercased()
    case (.date(let d), .date(let v)),
         (.optionalDate(.some(let d)), .date(let v)):
        return Calendar.current.isDate(d, inSameDayAs: v)
    case (.bool(let b), .bool(let v)):
        return b == v
    case (.integer(let i), .integer(let v)):
        return i == v
    case (.stringList(let list), .string(let v)):
        return list.contains { $0.lowercased() == v.lowercased() }
    default:
        return false
    }
}

private func matchCompare(_ fieldValue: FieldValue, _ filterValue: FilterValue, _ compare: (Date, Date) -> Bool) -> Bool {
    switch (fieldValue, filterValue) {
    case (.date(let d), .date(let v)),
         (.optionalDate(.some(let d)), .date(let v)):
        return compare(d, v)
    default:
        return false
    }
}

private func matchLike(_ fieldValue: FieldValue, _ filterValue: FilterValue) -> Bool {
    guard case .string(let pattern) = filterValue else {
        return false
    }

    let text: String
    switch fieldValue {
    case .string(let s), .optionalString(.some(let s)):
        text = s
    default:
        return false
    }

    // Convert SQL LIKE pattern to regex
    // % matches any sequence, _ matches single character
    var regexPattern = "^"
    for char in pattern {
        switch char {
        case "%":
            regexPattern += ".*"
        case "_":
            regexPattern += "."
        case ".", "+", "*", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|", "\\":
            regexPattern += "\\\(char)"
        default:
            regexPattern += String(char)
        }
    }
    regexPattern += "$"

    return text.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) != nil
}

private func matchContains(_ fieldValue: FieldValue, _ filterValue: FilterValue) -> Bool {
    guard case .string(let needle) = filterValue else {
        return false
    }

    switch fieldValue {
    case .string(let s), .optionalString(.some(let s)):
        return s.localizedCaseInsensitiveContains(needle)
    case .stringList(let list):
        return list.contains { $0.lowercased() == needle.lowercased() }
    default:
        return false
    }
}

private func matchIn(_ fieldValue: FieldValue, _ filterValue: FilterValue) -> Bool {
    guard case .stringList(let allowed) = filterValue else {
        return false
    }

    switch fieldValue {
    case .string(let s), .optionalString(.some(let s)):
        return allowed.contains { $0.lowercased() == s.lowercased() }
    case .stringList(let list):
        return list.contains { item in
            allowed.contains { $0.lowercased() == item.lowercased() }
        }
    default:
        return false
    }
}
