// NaturalLanguageDateParserTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("NaturalLanguageDateParser")
struct NaturalLanguageDateParserTests {
    let parser = NaturalLanguageDateParser()

    @Test func parsesMonthAndDayWithoutYear() {
        let result = parser.parse("dec 15")
        #expect(result != nil)
    }

    @Test func parsesRelativeDateWithTime() {
        let result = parser.parse("tomorrow 3pm")
        #expect(result != nil)

        let hour = Calendar.current.component(.hour, from: result!)
        #expect(hour == 15)
    }

    @Test func parsesEveningKeyword() {
        let result = parser.parse("this evening")
        #expect(result != nil)

        let hour = Calendar.current.component(.hour, from: result!)
        #expect(hour == 18)
    }
}
