// FilterParser.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Parser for filter expressions.
///
/// Syntax: field OPERATOR value [AND|OR condition...]
///
/// Examples:
/// - status = open
/// - status = open AND due < today
/// - tags CONTAINS 'work' OR project = 'Home'
/// - name LIKE '%report%' AND status != completed
public struct FilterParser {
    private let input: String
    private var position: String.Index

    /// Parse a filter expression string.
    public static func parse(_ input: String) throws -> FilterExpression {
        var parser = FilterParser(input: input)
        return try parser.parseExpression()
    }

    private init(input: String) {
        self.input = input
        self.position = input.startIndex
    }

    // MARK: - Parsing

    private mutating func parseExpression() throws -> FilterExpression {
        var left = try parseConditionOrGroup()

        while true {
            skipWhitespace()

            if let op = tryParseLogicalOperator() {
                let right = try parseConditionOrGroup()
                left = .compound(left: left, op: op, right: right)
            } else {
                break
            }
        }

        return left
    }

    private mutating func parseConditionOrGroup() throws -> FilterExpression {
        skipWhitespace()

        // Check for NOT
        if tryConsume("NOT") {
            skipWhitespace()
            let expr = try parseConditionOrGroup()
            return .not(expr)
        }

        // Check for parentheses
        if tryConsume("(") {
            let expr = try parseExpression()
            skipWhitespace()
            guard tryConsume(")") else {
                throw FilterParseError.expectedClosingParen
            }
            return expr
        }

        return try parseCondition()
    }

    private mutating func parseCondition() throws -> FilterExpression {
        skipWhitespace()

        // Parse field name
        let field = try parseIdentifier()
        skipWhitespace()

        // Parse operator
        let op = try parseOperator()
        skipWhitespace()

        // Parse value (if needed)
        let value: FilterValue
        switch op {
        case .isNull, .isNotNull:
            value = .none
        default:
            value = try parseValue()
        }

        return .condition(FilterCondition(field: field, operator: op, value: value))
    }

    private mutating func parseIdentifier() throws -> String {
        var identifier = ""
        while position < input.endIndex {
            let char = input[position]
            if char.isLetter || char.isNumber || char == "_" {
                identifier.append(char)
                position = input.index(after: position)
            } else {
                break
            }
        }

        guard !identifier.isEmpty else {
            throw FilterParseError.expectedIdentifier
        }

        return identifier
    }

    private mutating func parseOperator() throws -> FilterOperator {
        // Try multi-character operators first
        if tryConsume("IS NOT NULL") {
            return .isNotNull
        }
        if tryConsume("IS NULL") {
            return .isNull
        }
        if tryConsume("CONTAINS") {
            return .contains
        }
        if tryConsume("LIKE") {
            return .like
        }
        if tryConsume("IN") {
            return .in
        }
        if tryConsume("<=") {
            return .lessThanOrEqual
        }
        if tryConsume(">=") {
            return .greaterThanOrEqual
        }
        if tryConsume("!=") {
            return .notEqual
        }
        if tryConsume("<") {
            return .lessThan
        }
        if tryConsume(">") {
            return .greaterThan
        }
        if tryConsume("=") {
            return .equal
        }

        throw FilterParseError.unknownOperator
    }

    private mutating func parseValue() throws -> FilterValue {
        skipWhitespace()

        guard position < input.endIndex else {
            throw FilterParseError.expectedValue
        }

        let char = input[position]

        // Quoted string
        if char == "'" || char == "\"" {
            return try parseQuotedString()
        }

        // List (for IN operator)
        if char == "(" {
            return try parseList()
        }

        // Unquoted value (until whitespace or end)
        var value = ""
        while position < input.endIndex {
            let c = input[position]
            if c.isWhitespace || c == ")" {
                break
            }
            value.append(c)
            position = input.index(after: position)
        }

        return FilterValue.parse(value)
    }

    private mutating func parseQuotedString() throws -> FilterValue {
        let quote = input[position]
        position = input.index(after: position)

        var value = ""
        while position < input.endIndex {
            let char = input[position]
            position = input.index(after: position)

            if char == quote {
                return .string(value)
            }

            // Handle escape sequences
            if char == "\\" && position < input.endIndex {
                let next = input[position]
                position = input.index(after: position)
                value.append(next)
            } else {
                value.append(char)
            }
        }

        throw FilterParseError.unterminatedString
    }

    private mutating func parseList() throws -> FilterValue {
        guard tryConsume("(") else {
            throw FilterParseError.expectedList
        }

        var items: [String] = []

        while true {
            skipWhitespace()

            if tryConsume(")") {
                break
            }

            // Skip comma between items
            if !items.isEmpty {
                guard tryConsume(",") else {
                    throw FilterParseError.expectedCommaOrClosingParen
                }
                skipWhitespace()
            }

            // Parse item
            let value = try parseValue()
            if case .string(let s) = value {
                items.append(s)
            } else {
                throw FilterParseError.listItemMustBeString
            }
        }

        return .stringList(items)
    }

    // MARK: - Helpers

    private mutating func skipWhitespace() {
        while position < input.endIndex && input[position].isWhitespace {
            position = input.index(after: position)
        }
    }

    private mutating func tryConsume(_ str: String) -> Bool {
        let start = position
        skipWhitespace()

        var strIndex = str.startIndex
        var inputIndex = position

        while strIndex < str.endIndex && inputIndex < input.endIndex {
            if str[strIndex].lowercased() != input[inputIndex].lowercased() {
                position = start
                return false
            }
            strIndex = str.index(after: strIndex)
            inputIndex = input.index(after: inputIndex)
        }

        if strIndex == str.endIndex {
            // Make sure it's a word boundary for keywords
            if str.first?.isLetter == true {
                if inputIndex < input.endIndex && (input[inputIndex].isLetter || input[inputIndex].isNumber) {
                    position = start
                    return false
                }
            }
            position = inputIndex
            return true
        }

        position = start
        return false
    }

    private mutating func tryParseLogicalOperator() -> LogicalOperator? {
        if tryConsume("AND") {
            return .and
        }
        if tryConsume("OR") {
            return .or
        }
        return nil
    }
}

/// Errors that can occur during filter parsing.
public enum FilterParseError: Error, LocalizedError {
    case expectedIdentifier
    case unknownOperator
    case expectedValue
    case unterminatedString
    case expectedClosingParen
    case expectedList
    case expectedCommaOrClosingParen
    case listItemMustBeString

    public var errorDescription: String? {
        switch self {
        case .expectedIdentifier:
            return "Expected field name"
        case .unknownOperator:
            return "Unknown operator"
        case .expectedValue:
            return "Expected value"
        case .unterminatedString:
            return "Unterminated string"
        case .expectedClosingParen:
            return "Expected closing parenthesis"
        case .expectedList:
            return "Expected list (e.g., ('a', 'b'))"
        case .expectedCommaOrClosingParen:
            return "Expected comma or closing parenthesis"
        case .listItemMustBeString:
            return "List items must be strings"
        }
    }
}
