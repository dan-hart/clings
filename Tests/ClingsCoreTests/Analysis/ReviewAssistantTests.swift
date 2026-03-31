// ReviewAssistantTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("ReviewAssistant")
struct ReviewAssistantTests {
    @Test func summarizesBacklogDeadlinesAndSuggestions() {
        let summary = ReviewAssistant().summarize(
            inbox: [TestData.todoNoProject],
            someday: [TestData.todoWithChecklist],
            today: [TestData.todoOpen],
            upcoming: [TestData.todoOverdue],
            projects: [TestData.projectAlpha],
            referenceDate: Date()
        )

        #expect(summary.inboxCount == 1)
        #expect(summary.somedayCount == 1)
        #expect(summary.upcomingDeadlines.count >= 1)
        #expect(summary.suggestedActions.contains(where: { $0.contains("Inbox") }))
    }
}
