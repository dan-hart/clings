// ReviewAssistant.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct ReviewSummary: Equatable, Sendable {
    public let inboxCount: Int
    public let somedayCount: Int
    public let activeProjectCount: Int
    public let stalledProjects: [Project]
    public let upcomingDeadlines: [Todo]
    public let overdueTodos: [Todo]
    public let suggestedActions: [String]
}

public struct ReviewAssistant: Sendable {
    public init() {}

    public func summarize(
        inbox: [Todo],
        someday: [Todo],
        today: [Todo],
        upcoming: [Todo],
        projects: [Project],
        referenceDate: Date = Date()
    ) -> ReviewSummary {
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: referenceDate) ?? referenceDate
        let activeProjects = projects.filter { $0.status == .open }
        let openTimeline = (today + upcoming).filter(\.isOpen)

        let overdueTodos = openTimeline.filter(\.isOverdue)
        let upcomingDeadlines = openTimeline
            .filter {
                guard let dueDate = $0.dueDate else { return false }
                return dueDate <= nextWeek
            }
            .sorted { ($0.dueDate ?? nextWeek) < ($1.dueDate ?? nextWeek) }

        let stalledProjects = activeProjects.filter { project in
            !openTimeline.contains { $0.project?.id == project.id }
        }

        var suggestedActions: [String] = []
        if !inbox.isEmpty {
            suggestedActions.append("Inbox needs processing")
        }
        if !overdueTodos.isEmpty {
            suggestedActions.append("Overdue tasks need replanning")
        }
        if !stalledProjects.isEmpty {
            suggestedActions.append("Some projects have no visible next actions")
        }
        if !someday.isEmpty {
            suggestedActions.append("Review Someday for items worth activating")
        }
        if suggestedActions.isEmpty {
            suggestedActions.append("System looks healthy; keep the review lightweight")
        }

        return ReviewSummary(
            inboxCount: inbox.count,
            somedayCount: someday.count,
            activeProjectCount: activeProjects.count,
            stalledProjects: stalledProjects,
            upcomingDeadlines: upcomingDeadlines,
            overdueTodos: overdueTodos,
            suggestedActions: suggestedActions
        )
    }
}
