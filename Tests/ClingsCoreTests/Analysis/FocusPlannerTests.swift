// FocusPlannerTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("FocusPlanner")
struct FocusPlannerTests {
    @Test func ranksOverdueAndUrgentItemsFirst() {
        let plan = FocusPlanner().build(
            todos: [TestData.todoOpen, TestData.todoOverdue, TestData.todoNoProject],
            limit: 3,
            referenceDate: Date()
        )

        #expect(plan.items.count == 3)
        #expect(plan.items.first?.todo.id == TestData.todoOverdue.id)
        #expect(plan.items.first?.reasons.contains("Overdue") == true)
    }
}
