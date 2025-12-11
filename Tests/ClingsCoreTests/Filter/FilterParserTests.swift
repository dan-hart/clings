// FilterParserTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("FilterParser")
struct FilterParserTests {
    @Suite("Simple Conditions")
    struct SimpleConditions {
        @Test func parseSimpleEqual() throws {
            let expr = try FilterParser.parse("status = open")

            if case .condition(let cond) = expr {
                #expect(cond.field == "status")
                #expect(cond.operator == .equal)
                if case .string(let v) = cond.value {
                    #expect(v == "open")
                } else {
                    Issue.record("Expected string value")
                }
            } else {
                Issue.record("Expected condition")
            }
        }

        @Test func parseNotEqual() throws {
            let expr = try FilterParser.parse("status != completed")

            if case .condition(let cond) = expr {
                #expect(cond.operator == .notEqual)
            } else {
                Issue.record("Expected condition")
            }
        }

        @Test func parseLessThan() throws {
            let expr = try FilterParser.parse("due < today")

            if case .condition(let cond) = expr {
                #expect(cond.operator == .lessThan)
            } else {
                Issue.record("Expected condition")
            }
        }

        @Test func parseLessThanOrEqual() throws {
            let expr = try FilterParser.parse("due <= tomorrow")

            if case .condition(let cond) = expr {
                #expect(cond.operator == .lessThanOrEqual)
            } else {
                Issue.record("Expected condition")
            }
        }

        @Test func parseGreaterThan() throws {
            let expr = try FilterParser.parse("due > today")

            if case .condition(let cond) = expr {
                #expect(cond.operator == .greaterThan)
            } else {
                Issue.record("Expected condition")
            }
        }

        @Test func parseGreaterThanOrEqual() throws {
            let expr = try FilterParser.parse("due >= today")

            if case .condition(let cond) = expr {
                #expect(cond.operator == .greaterThanOrEqual)
            } else {
                Issue.record("Expected condition")
            }
        }
    }

    @Suite("String Operators")
    struct StringOperators {
        @Test func parseLike() throws {
            let expr = try FilterParser.parse("name LIKE '%report%'")

            if case .condition(let cond) = expr {
                #expect(cond.operator == .like)
                if case .string(let v) = cond.value {
                    #expect(v == "%report%")
                } else {
                    Issue.record("Expected string value")
                }
            } else {
                Issue.record("Expected condition")
            }
        }

        @Test func parseContains() throws {
            let expr = try FilterParser.parse("tags CONTAINS 'work'")

            if case .condition(let cond) = expr {
                #expect(cond.operator == .contains)
            } else {
                Issue.record("Expected condition")
            }
        }
    }

    @Suite("Null Checks")
    struct NullChecks {
        @Test func parseIsNull() throws {
            let expr = try FilterParser.parse("due IS NULL")

            if case .condition(let cond) = expr {
                #expect(cond.field == "due")
                #expect(cond.operator == .isNull)
                if case .none = cond.value {
                    // Expected
                } else {
                    Issue.record("Expected none value")
                }
            } else {
                Issue.record("Expected condition")
            }
        }

        @Test func parseIsNotNull() throws {
            let expr = try FilterParser.parse("project IS NOT NULL")

            if case .condition(let cond) = expr {
                #expect(cond.operator == .isNotNull)
            } else {
                Issue.record("Expected condition")
            }
        }
    }

    @Suite("IN Operator")
    struct InOperator {
        @Test func parseIn() throws {
            let expr = try FilterParser.parse("status IN ('open', 'completed')")

            if case .condition(let cond) = expr {
                #expect(cond.operator == .in)
                if case .stringList(let list) = cond.value {
                    #expect(list == ["open", "completed"])
                } else {
                    Issue.record("Expected string list value")
                }
            } else {
                Issue.record("Expected condition")
            }
        }
    }

    @Suite("Logical Operators")
    struct LogicalOperators {
        @Test func parseAnd() throws {
            let expr = try FilterParser.parse("status = open AND due < today")

            if case .compound(let left, let op, let right) = expr {
                #expect(op == .and)
                if case .condition(let leftCond) = left {
                    #expect(leftCond.field == "status")
                }
                if case .condition(let rightCond) = right {
                    #expect(rightCond.field == "due")
                }
            } else {
                Issue.record("Expected compound expression")
            }
        }

        @Test func parseOr() throws {
            let expr = try FilterParser.parse("status = open OR status = completed")

            if case .compound(_, let op, _) = expr {
                #expect(op == .or)
            } else {
                Issue.record("Expected compound expression")
            }
        }

        @Test func parseNot() throws {
            let expr = try FilterParser.parse("NOT status = completed")

            if case .not(let inner) = expr {
                if case .condition(let cond) = inner {
                    #expect(cond.field == "status")
                    #expect(cond.operator == .equal)
                } else {
                    Issue.record("Expected inner condition")
                }
            } else {
                Issue.record("Expected NOT expression")
            }
        }
    }

    @Suite("Parentheses")
    struct Parentheses {
        @Test func parseParentheses() throws {
            let expr = try FilterParser.parse("(status = open OR status = canceled) AND tags CONTAINS 'work'")

            if case .compound(let left, let op, let right) = expr {
                #expect(op == .and)

                if case .compound(_, let innerOp, _) = left {
                    #expect(innerOp == .or)
                } else {
                    Issue.record("Expected compound left")
                }

                if case .condition(let cond) = right {
                    #expect(cond.operator == .contains)
                } else {
                    Issue.record("Expected condition right")
                }
            } else {
                Issue.record("Expected compound expression")
            }
        }

        @Test func parseNestedParentheses() throws {
            let expr = try FilterParser.parse("((status = open))")

            if case .condition(let cond) = expr {
                #expect(cond.field == "status")
            } else {
                Issue.record("Expected condition")
            }
        }
    }

    @Suite("Quoted Strings")
    struct QuotedStrings {
        @Test func parseSingleQuotedString() throws {
            let expr = try FilterParser.parse("name = 'test value'")

            if case .condition(let cond) = expr {
                if case .string(let v) = cond.value {
                    #expect(v == "test value")
                } else {
                    Issue.record("Expected string value")
                }
            } else {
                Issue.record("Expected condition")
            }
        }

        @Test func parseDoubleQuotedString() throws {
            let expr = try FilterParser.parse("name = \"test value\"")

            if case .condition(let cond) = expr {
                if case .string(let v) = cond.value {
                    #expect(v == "test value")
                } else {
                    Issue.record("Expected string value")
                }
            } else {
                Issue.record("Expected condition")
            }
        }

        @Test func parseEscapedQuote() throws {
            let expr = try FilterParser.parse("name = 'it\\'s a test'")

            if case .condition(let cond) = expr {
                if case .string(let v) = cond.value {
                    #expect(v == "it's a test")
                } else {
                    Issue.record("Expected string value")
                }
            } else {
                Issue.record("Expected condition")
            }
        }
    }

    @Suite("Case Insensitivity")
    struct CaseInsensitivity {
        @Test func operatorsCaseInsensitive() throws {
            let exprs = [
                try FilterParser.parse("status = open and due < today"),
                try FilterParser.parse("status = open AND due < today"),
                try FilterParser.parse("name like '%test%'"),
                try FilterParser.parse("name LIKE '%test%'"),
                try FilterParser.parse("not status = completed"),
                try FilterParser.parse("NOT status = completed"),
            ]

            for expr in exprs {
                // Should not throw
                #expect(expr != nil)
            }
        }
    }

    @Suite("Error Cases")
    struct ErrorCases {
        @Test func errorExpectedIdentifier() {
            #expect(throws: FilterParseError.self) {
                try FilterParser.parse("= open")
            }
        }

        @Test func errorUnknownOperator() {
            #expect(throws: FilterParseError.self) {
                try FilterParser.parse("status ~ open")
            }
        }

        @Test func errorExpectedValue() {
            #expect(throws: FilterParseError.self) {
                try FilterParser.parse("status =")
            }
        }

        @Test func errorUnterminatedString() {
            #expect(throws: FilterParseError.self) {
                try FilterParser.parse("name = 'unterminated")
            }
        }

        @Test func errorExpectedClosingParen() {
            #expect(throws: FilterParseError.self) {
                try FilterParser.parse("(status = open")
            }
        }
    }

    @Suite("Complex Expressions")
    struct ComplexExpressions {
        @Test func complexExpression() throws {
            let expr = try FilterParser.parse(
                "status = open AND (tags CONTAINS 'urgent' OR project IS NOT NULL) AND due <= tomorrow"
            )

            // Just verify it parses without error
            #expect(expr != nil)
        }

        @Test func multipleAndConditions() throws {
            let expr = try FilterParser.parse("status = open AND due < today AND tags CONTAINS 'work'")

            // Should create left-associative compound
            if case .compound(let left, _, _) = expr {
                if case .compound(_, _, _) = left {
                    // Expected nested compound
                } else {
                    Issue.record("Expected nested compound")
                }
            } else {
                Issue.record("Expected compound")
            }
        }
    }

    @Suite("FilterParseError")
    struct FilterParseErrorTests {
        @Test func filterParseErrorDescriptions() {
            let errors: [FilterParseError] = [
                .expectedIdentifier,
                .unknownOperator,
                .expectedValue,
                .unterminatedString,
                .expectedClosingParen,
                .expectedList,
                .expectedCommaOrClosingParen,
                .listItemMustBeString,
            ]

            for error in errors {
                #expect(error.errorDescription != nil)
                #expect(!error.errorDescription!.isEmpty)
            }
        }
    }
}
