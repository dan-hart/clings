// LocaleIndependentTodoDateTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("Locale-independent todo dates")
struct LocaleIndependentTodoDateTests {
    @Test func scheduledDateAvoidsLocaleSensitiveDateParsing() {
        let script = JXAScripts.createTodo(
            name: "Task",
            when: "September 12, 2026 00:00:00"
        )

        #expect(!script.contains("date \"September 12, 2026 00:00:00\""))
        #expect(script.contains("set scheduledDate to current date"))
        #expect(script.contains("set day of scheduledDate to 1"))
        #expect(script.contains("set year of scheduledDate to 2026"))
        #expect(script.contains("set month of scheduledDate to September"))
        #expect(script.contains("set day of scheduledDate to 12"))
        #expect(!script.contains("set time of scheduledDate"))
        #expect(script.contains("set minutes of scheduledDate to 0"))
        #expect(script.contains("set seconds of scheduledDate to 0"))
        #expect(script.contains("set hours of scheduledDate to 0"))
        #expect(script.contains("schedule newTodo for scheduledDate"))
    }

    @Test func deadlinePreservesTimeWithoutLocaleSensitiveDateParsing() {
        let script = JXAScripts.createTodo(
            name: "Task",
            deadline: "September 13, 2026 17:30:45"
        )

        #expect(!script.contains("date \"September 13, 2026 17:30:45\""))
        #expect(script.contains("set deadlineDate to current date"))
        #expect(script.contains("set year of deadlineDate to 2026"))
        #expect(script.contains("set month of deadlineDate to September"))
        #expect(script.contains("set day of deadlineDate to 13"))
        #expect(!script.contains("set time of deadlineDate"))
        #expect(script.contains("set minutes of deadlineDate to 30"))
        #expect(script.contains("set seconds of deadlineDate to 45"))
        #expect(script.contains("set hours of deadlineDate to 17"))
        #expect(script.contains("set due date of newTodo to deadlineDate"))
    }

    @Test func noDateSetupIsGeneratedWhenDatesAreAbsent() {
        let script = JXAScripts.createTodo(name: "Task")

        #expect(!script.contains("set scheduledDate to current date"))
        #expect(!script.contains("set deadlineDate to current date"))
        #expect(!script.contains("schedule newTodo"))
        #expect(!script.contains("set due date of newTodo"))
    }
}
