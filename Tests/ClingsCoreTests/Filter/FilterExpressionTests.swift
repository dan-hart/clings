// FilterExpressionTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("FilterExpression")
struct FilterExpressionTests {
    @Suite("FilterValue.parse")
    struct FilterValueParse {
        @Test func parseQuotedString() {
            let value = FilterValue.parse("'hello world'")
            if case .string(let s) = value {
                #expect(s == "hello world")
            } else {
                Issue.record("Expected string")
            }
        }

        @Test func parseDoubleQuotedString() {
            let value = FilterValue.parse("\"hello world\"")
            if case .string(let s) = value {
                #expect(s == "hello world")
            } else {
                Issue.record("Expected string")
            }
        }

        @Test func parseBoolean() {
            #expect(FilterValue.parse("true") == .bool(true))
            #expect(FilterValue.parse("false") == .bool(false))
            #expect(FilterValue.parse("TRUE") == .bool(true))
            #expect(FilterValue.parse("FALSE") == .bool(false))
        }

        @Test func parseInteger() {
            let value = FilterValue.parse("42")
            if case .integer(let n) = value {
                #expect(n == 42)
            } else {
                Issue.record("Expected integer")
            }
        }

        @Test func parseNegativeInteger() {
            let value = FilterValue.parse("-10")
            if case .integer(let n) = value {
                #expect(n == -10)
            } else {
                Issue.record("Expected integer")
            }
        }

        @Test func parseList() {
            let value = FilterValue.parse("('a', 'b', 'c')")
            if case .stringList(let list) = value {
                #expect(list == ["a", "b", "c"])
            } else {
                Issue.record("Expected string list")
            }
        }

        @Test func parseDateToday() {
            let value = FilterValue.parse("today")
            if case .date(let d) = value {
                #expect(Calendar.current.isDateInToday(d))
            } else {
                Issue.record("Expected date")
            }
        }

        @Test func parseDateTomorrow() {
            let value = FilterValue.parse("tomorrow")
            if case .date(let d) = value {
                #expect(Calendar.current.isDateInTomorrow(d))
            } else {
                Issue.record("Expected date")
            }
        }

        @Test func parseDateYesterday() {
            let value = FilterValue.parse("yesterday")
            if case .date(let d) = value {
                #expect(Calendar.current.isDateInYesterday(d))
            } else {
                Issue.record("Expected date")
            }
        }

        @Test func parseDateISO() {
            let value = FilterValue.parse("2024-12-25")
            if case .date(let d) = value {
                let components = Calendar.current.dateComponents([.year, .month, .day], from: d)
                #expect(components.year == 2024)
                #expect(components.month == 12)
                #expect(components.day == 25)
            } else {
                Issue.record("Expected date")
            }
        }

        @Test func parseDateWeekday() {
            let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            for (index, day) in weekdays.enumerated() {
                let value = FilterValue.parse(day)
                if case .date(let d) = value {
                    let weekday = Calendar.current.component(.weekday, from: d)
                    #expect(weekday == index + 1, "Failed for \(day)")
                } else {
                    Issue.record("Expected date for \(day)")
                }
            }
        }

        @Test func parseUnquotedString() {
            let value = FilterValue.parse("open")
            if case .string(let s) = value {
                #expect(s == "open")
            } else {
                Issue.record("Expected string")
            }
        }
    }

    @Suite("FieldValue")
    struct FieldValueTests {
        @Test func fieldValueIsNull() {
            #expect(FieldValue.optionalString(nil).isNull)
            #expect(FieldValue.optionalDate(nil).isNull)

            #expect(!FieldValue.optionalString("value").isNull)
            #expect(!FieldValue.optionalDate(Date()).isNull)
            #expect(!FieldValue.string("test").isNull)
            #expect(!FieldValue.date(Date()).isNull)
            #expect(!FieldValue.bool(true).isNull)
            #expect(!FieldValue.integer(42).isNull)
            #expect(!FieldValue.stringList(["a"]).isNull)
        }
    }

    @Suite("FilterExpression.matches")
    struct Matches {
        @Test func matchesEqualString() throws {
            let expr = try FilterParser.parse("status = open")
            let todo = TestData.todoOpen

            #expect(expr.matches(todo))
        }

        @Test func matchesNotEqual() throws {
            let expr = try FilterParser.parse("status != completed")
            let openTodo = TestData.todoOpen
            let completedTodo = TestData.todoCompleted

            #expect(expr.matches(openTodo))
            #expect(!expr.matches(completedTodo))
        }

        @Test func matchesCaseInsensitive() throws {
            let expr = try FilterParser.parse("status = OPEN")
            let todo = TestData.todoOpen

            #expect(expr.matches(todo))
        }

        @Test func matchesDateComparison() throws {
            let overdueTodo = TestData.todoOverdue

            let exprPast = try FilterParser.parse("due < today")
            #expect(exprPast.matches(overdueTodo))

            let exprFuture = try FilterParser.parse("due > tomorrow")
            #expect(!exprFuture.matches(overdueTodo))
        }

        @Test func matchesLikePattern() throws {
            let expr = try FilterParser.parse("name LIKE '%task%'")
            let todo = TestData.todoOpen

            #expect(expr.matches(todo))
        }

        @Test func matchesLikePatternStartsWith() throws {
            let expr = try FilterParser.parse("name LIKE 'Open%'")
            let todo = TestData.todoOpen

            #expect(expr.matches(todo))
        }

        @Test func matchesLikePatternEndsWith() throws {
            let expr = try FilterParser.parse("name LIKE '%task'")
            let todo = TestData.todoOpen

            #expect(expr.matches(todo))
        }

        @Test func matchesContains() throws {
            let expr = try FilterParser.parse("tags CONTAINS 'work'")
            let todoWithTag = TestData.todoOpen
            let todoWithoutTag = TestData.todoNoProject

            #expect(expr.matches(todoWithTag))
            #expect(!expr.matches(todoWithoutTag))
        }

        @Test func matchesContainsInStringField() throws {
            let expr = try FilterParser.parse("name CONTAINS 'task'")
            let todo = TestData.todoOpen

            #expect(expr.matches(todo))
        }

        @Test func matchesIsNull() throws {
            let expr = try FilterParser.parse("notes IS NULL")
            let todoWithNotes = TestData.todoOpen
            let todoWithoutNotes = TestData.todoCompleted

            #expect(!expr.matches(todoWithNotes))
            #expect(expr.matches(todoWithoutNotes))
        }

        @Test func matchesIsNotNull() throws {
            let expr = try FilterParser.parse("project IS NOT NULL")
            let todoWithProject = TestData.todoOpen
            let todoWithoutProject = TestData.todoNoProject

            #expect(expr.matches(todoWithProject))
            #expect(!expr.matches(todoWithoutProject))
        }

        @Test func matchesIn() throws {
            let expr = try FilterParser.parse("status IN ('open', 'canceled')")
            let openTodo = TestData.todoOpen
            let completedTodo = TestData.todoCompleted
            let canceledTodo = TestData.todoCanceled

            #expect(expr.matches(openTodo))
            #expect(!expr.matches(completedTodo))
            #expect(expr.matches(canceledTodo))
        }

        @Test func matchesAnd() throws {
            let expr = try FilterParser.parse("status = open AND tags CONTAINS 'work'")
            let todoMatch = TestData.todoOpen
            let todoNoTags = TestData.todoNoProject

            #expect(expr.matches(todoMatch))
            #expect(!expr.matches(todoNoTags))
        }

        @Test func matchesOr() throws {
            let expr = try FilterParser.parse("status = completed OR status = canceled")
            let completedTodo = TestData.todoCompleted
            let canceledTodo = TestData.todoCanceled
            let openTodo = TestData.todoOpen

            #expect(expr.matches(completedTodo))
            #expect(expr.matches(canceledTodo))
            #expect(!expr.matches(openTodo))
        }

        @Test func matchesNot() throws {
            let expr = try FilterParser.parse("NOT status = completed")
            let completedTodo = TestData.todoCompleted
            let openTodo = TestData.todoOpen

            #expect(!expr.matches(completedTodo))
            #expect(expr.matches(openTodo))
        }

        @Test func matchesComplex() throws {
            let expr = try FilterParser.parse(
                "(status = open OR status = canceled) AND tags CONTAINS 'urgent'"
            )
            let urgentCanceled = TestData.todoCanceled // has urgent tag, canceled
            let urgentOpen = TestData.todoOverdue // has urgent tag, open
            let completedTodo = TestData.todoCompleted

            #expect(expr.matches(urgentCanceled))
            #expect(expr.matches(urgentOpen))
            #expect(!expr.matches(completedTodo))
        }

        @Test func matchesUnknownField() throws {
            let expr = try FilterParser.parse("unknown_field IS NULL")
            let todo = TestData.todoOpen

            // Unknown field returns true for IS NULL
            #expect(expr.matches(todo))
        }
    }

    @Suite("FilterOperator")
    struct FilterOperatorTests {
        @Test func filterOperatorRawValues() {
            #expect(FilterOperator.equal.rawValue == "=")
            #expect(FilterOperator.notEqual.rawValue == "!=")
            #expect(FilterOperator.lessThan.rawValue == "<")
            #expect(FilterOperator.lessThanOrEqual.rawValue == "<=")
            #expect(FilterOperator.greaterThan.rawValue == ">")
            #expect(FilterOperator.greaterThanOrEqual.rawValue == ">=")
            #expect(FilterOperator.like.rawValue == "LIKE")
            #expect(FilterOperator.contains.rawValue == "CONTAINS")
            #expect(FilterOperator.isNull.rawValue == "IS NULL")
            #expect(FilterOperator.isNotNull.rawValue == "IS NOT NULL")
            #expect(FilterOperator.in.rawValue == "IN")
        }
    }

    @Suite("LogicalOperator")
    struct LogicalOperatorTests {
        @Test func logicalOperatorRawValues() {
            #expect(LogicalOperator.and.rawValue == "AND")
            #expect(LogicalOperator.or.rawValue == "OR")
        }
    }

    @Suite("FilterCondition")
    struct FilterConditionTests {
        @Test func filterConditionInit() {
            let condition = FilterCondition(
                field: "status",
                operator: .equal,
                value: .string("open")
            )

            #expect(condition.field == "status")
            #expect(condition.operator == .equal)
            if case .string(let v) = condition.value {
                #expect(v == "open")
            } else {
                Issue.record("Expected string value")
            }
        }
    }

    @Suite("FilterValue Equatable")
    struct FilterValueEquatable {
        @Test func filterValueEquatable() {
            #expect(FilterValue.string("a") == FilterValue.string("a"))
            #expect(FilterValue.string("a") != FilterValue.string("b"))

            #expect(FilterValue.bool(true) == FilterValue.bool(true))
            #expect(FilterValue.bool(true) != FilterValue.bool(false))

            #expect(FilterValue.integer(1) == FilterValue.integer(1))
            #expect(FilterValue.integer(1) != FilterValue.integer(2))

            #expect(FilterValue.stringList(["a"]) == FilterValue.stringList(["a"]))
            #expect(FilterValue.stringList(["a"]) != FilterValue.stringList(["b"]))

            #expect(FilterValue.none == FilterValue.none)
        }
    }
}
