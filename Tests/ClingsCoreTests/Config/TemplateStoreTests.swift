// TemplateStoreTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("TemplateStore", .serialized)
struct TemplateStoreTests {
    @Test func savesAndLoadsRelativeTemplateExpressions() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { _ in
            let template = TaskTemplate(
                name: "weekly-review",
                title: "Weekly review",
                notes: "Check inbox and projects",
                tags: ["planning"],
                project: "Operations",
                area: "Work",
                whenExpression: "tomorrow morning",
                deadlineExpression: "next friday",
                checklistItems: ["Process inbox", "Review deadlines"]
            )
            try TemplateStore.save(template)

            let loaded = try TemplateStore.load(name: "weekly-review")
            #expect(loaded?.whenExpression == "tomorrow morning")
            #expect(loaded?.deadlineExpression == "next friday")
            #expect(loaded?.checklistItems == ["Process inbox", "Review deadlines"])
        }
    }

    @Test func deleteReturnsFalseWhenTemplateDoesNotExist() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { _ in
            let deleted = try TemplateStore.delete(name: "missing-template")
            #expect(!deleted)
        }
    }
}
