// TodoDateRuntimeTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest
@testable import ClingsCore

/// Execute only date assignments extracted from the production template.
/// Never compile or execute the Things application block or create real todos.
final class TodoDateRuntimeTests: XCTestCase {
    private struct Fixture {
        let zone: String
        let input: String
        let expected: [Int]
    }

    private let fixtures = [
        Fixture(zone: "America/Santiago", input: "September 6, 2026 01:00:00",
                expected: [2026, 9, 6, 3600]),
        Fixture(zone: "America/Santiago", input: "September 6, 2026 17:30:45",
                expected: [2026, 9, 6, 63045]),
        Fixture(zone: "America/Santiago", input: "September 5, 2026 23:59:59",
                expected: [2026, 9, 5, 86399]),
        Fixture(zone: "America/Santiago", input: "September 7, 2026 00:00:00",
                expected: [2026, 9, 7, 0]),
        Fixture(zone: "Australia/Lord_Howe", input: "October 4, 2026 02:30:45",
                expected: [2026, 10, 4, 9045]),
        Fixture(zone: "America/New_York", input: "March 8, 2026 03:00:00",
                expected: [2026, 3, 8, 10800]),
        Fixture(zone: "America/New_York", input: "November 1, 2026 01:30:00",
                expected: [2026, 11, 1, 5400]),
        Fixture(zone: "Asia/Shanghai", input: "February 29, 2028 00:00:00",
                expected: [2028, 2, 29, 0]),
        Fixture(zone: "UTC", input: "December 31, 2026 23:59:59",
                expected: [2026, 12, 31, 86399])
    ]

    func testSchedulingDatesAtRuntime() throws {
        for fixture in fixtures {
            let script = JXAScripts.createTodo(name: "Task", when: fixture.input)
            XCTAssertTrue(script.contains("schedule newTodo for scheduledDate"))
            XCTAssertFalse(script.contains("set due date of newTodo"))
            try checkDates(script, variables: ["scheduledDate"], fixture: fixture)
        }
    }

    func testDeadlineDatesAtRuntime() throws {
        for fixture in fixtures {
            let script = JXAScripts.createTodo(name: "Task", deadline: fixture.input)
            XCTAssertTrue(script.contains("set due date of newTodo to deadlineDate"))
            XCTAssertFalse(script.contains("schedule newTodo"))
            try checkDates(script, variables: ["deadlineDate"], fixture: fixture)
        }
    }

    func testBothDatesAtRuntime() throws {
        for fixture in fixtures {
            // Different values catch accidental reuse/aliasing of the two dates.
            let script = JXAScripts.createTodo(
                name: "Task", when: fixture.input, deadline: "January 15, 2027 17:30:45"
            )
            XCTAssertTrue(script.contains("schedule newTodo for scheduledDate"))
            XCTAssertTrue(script.contains("set due date of newTodo to deadlineDate"))
            try checkDates(script, variables: ["scheduledDate", "deadlineDate"],
                           fixture: fixture, extraExpected: [2027, 1, 15, 63045])
        }
    }

    func testUndatedTodoHasNoDateOperations() throws {
        let script = JXAScripts.createTodo(name: "Task")
        XCTAssertTrue(script.contains("make new to do with properties {name: \"Task\"}"))
        XCTAssertFalse(script.contains("scheduledDate"))
        XCTAssertFalse(script.contains("deadlineDate"))
        XCTAssertFalse(script.contains("schedule newTodo"))
        XCTAssertFalse(script.contains("set due date of newTodo"))
        XCTAssertTrue(dateAssignments(script).isEmpty)
        XCTAssertEqual(try execute("return {}", zone: "America/Santiago"), "")
    }

    private func dateAssignments(_ script: String) -> [String] {
        // A strict allowlist keeps application commands out of the runtime probe.
        script.components(separatedBy: .newlines).map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { line in
            ["scheduledDate", "deadlineDate"].contains { variable in
                line == "set \(variable) to current date" ||
                    ["year", "month", "day", "time", "hours", "minutes", "seconds"].contains {
                        line.hasPrefix("set \($0) of \(variable) to ")
                    }
            }
        }
    }

    private func checkDates(_ script: String, variables: [String], fixture: Fixture,
                            extraExpected: [Int] = []) throws {
        XCTAssertFalse(script.contains("date \""), "Locale-sensitive date parser")
        XCTAssertFalse(script.contains("error \"Invalid date"))
        let assignments = dateAssignments(script)
        XCTAssertFalse(assignments.isEmpty)
        let result = variables.map {
            "{year of \($0), month of \($0) as integer, day of \($0), time of \($0)}"
        }.joined(separator: " & ")

        // Month-end seeds exercise rollover; different times prevent clock-dependent passes.
        for seedHour in [0, 23] {
            let seed = """
            set seedDate to current date
            set hours of seedDate to 12
            set day of seedDate to 1
            set year of seedDate to 2024
            set month of seedDate to January
            set day of seedDate to 31
            set minutes of seedDate to 15
            set seconds of seedDate to 19
            set hours of seedDate to \(seedHour)
            """
            let setup = assignments.map {
                $0.replacingOccurrences(of: "to current date", with: "to seedDate")
                    .replacingOccurrences(of: "set scheduledDate to seedDate", with: "copy seedDate to scheduledDate")
                    .replacingOccurrences(of: "set deadlineDate to seedDate", with: "copy seedDate to deadlineDate")
            }.joined(separator: "\n")
            let actual = try execute(seed + "\n" + setup + "\nreturn " + result, zone: fixture.zone)
            let expected = (fixture.expected + extraExpected).map(String.init).joined(separator: ", ")
            XCTAssertEqual(actual, expected, "\(fixture.zone): \(fixture.input), seed hour \(seedHour)")
        }
    }

    private func execute(_ script: String, zone: String) throws -> String {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        var environment = ProcessInfo.processInfo.environment
        environment["TZ"] = zone
        process.environment = environment
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let stdout = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0, stderr)
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw XCTSkip("AppleScript runtime validation requires macOS")
        #endif
    }
}
