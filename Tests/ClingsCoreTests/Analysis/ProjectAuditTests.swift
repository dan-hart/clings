// ProjectAuditTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("ProjectAudit")
struct ProjectAuditTests {
    @Test func flagsProjectsWithNoNextActionsAndOverdueWork() {
        let report = ProjectAudit().audit(
            projects: [TestData.projectAlpha],
            todos: [TestData.todoOverdue],
            referenceDate: Date()
        )

        #expect(report.items.count == 1)
        #expect(report.items[0].overdueCount == 1)
        #expect(report.items[0].findings.contains("Overdue tasks"))
    }

    @Test func flagsProjectsWithNoOpenTodos() {
        let report = ProjectAudit().audit(
            projects: [TestData.projectAlpha],
            todos: [],
            referenceDate: Date()
        )

        #expect(report.items.first?.findings.contains("No next actions") == true)
        #expect(report.summary.projectsWithoutNextActions == 1)
    }
}
