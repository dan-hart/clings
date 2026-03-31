// TodoLineFormatterTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("TodoLineFormatter")
struct TodoLineFormatterTests {
    @Test func replacesKnownPlaceholders() {
        let formatter = TodoLineFormatter(template: "{status} {name} [{project}] {tags}")
        let output = formatter.format(todo: TestData.todoOverdue)

        #expect(output.contains("open"))
        #expect(output.contains(TestData.todoOverdue.name))
        #expect(output.contains("[Project Alpha]"))
        #expect(output.contains("#urgent"))
    }

    @Test func missingFieldsResolveToEmptyStrings() {
        let formatter = TodoLineFormatter(template: "{project}|{area}|{due}")
        let output = formatter.format(todo: TestData.todoNoProject)

        #expect(output.contains("|Personal|"))
    }
}
