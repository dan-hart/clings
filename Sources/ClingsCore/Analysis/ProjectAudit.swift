// ProjectAudit.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct ProjectAuditSummary: Codable, Equatable, Sendable {
    public let totalProjects: Int
    public let projectsWithoutNextActions: Int
    public let projectsWithOverdueTasks: Int
    public let projectsWithoutDeadlines: Int
}

public struct ProjectAuditItem: Codable, Equatable, Sendable {
    public let project: Project
    public let openTodoCount: Int
    public let overdueCount: Int
    public let nextActionCount: Int
    public let findings: [String]
    public let latestActivityDate: Date?
}

public struct ProjectAuditReport: Codable, Equatable, Sendable {
    public let items: [ProjectAuditItem]
    public let summary: ProjectAuditSummary
}

public struct ProjectAudit: Sendable {
    public init() {}

    public func audit(projects: [Project], todos: [Todo], referenceDate: Date = Date()) -> ProjectAuditReport {
        let calendar = Calendar.current
        let staleThreshold = calendar.date(byAdding: .day, value: -14, to: referenceDate) ?? referenceDate

        let items = projects
            .filter { $0.status == .open }
            .map { project in
                let projectTodos = todos.filter { $0.status == .open && $0.project?.id == project.id }
                let overdue = projectTodos.filter(\.isOverdue)
                let latestActivity = projectTodos.map(\.modificationDate).max()

                var findings: [String] = []
                if projectTodos.isEmpty {
                    findings.append("No next actions")
                }
                if !overdue.isEmpty {
                    findings.append("Overdue tasks")
                }
                if project.dueDate == nil {
                    findings.append("No deadline")
                }
                if let latestActivity, latestActivity < staleThreshold {
                    findings.append("Stale activity")
                }

                return ProjectAuditItem(
                    project: project,
                    openTodoCount: projectTodos.count,
                    overdueCount: overdue.count,
                    nextActionCount: projectTodos.count,
                    findings: findings,
                    latestActivityDate: latestActivity
                )
            }
            .sorted {
                if $0.findings.count != $1.findings.count {
                    return $0.findings.count > $1.findings.count
                }
                return $0.project.name.localizedCaseInsensitiveCompare($1.project.name) == .orderedAscending
            }

        return ProjectAuditReport(
            items: items,
            summary: ProjectAuditSummary(
                totalProjects: items.count,
                projectsWithoutNextActions: items.filter { $0.findings.contains("No next actions") }.count,
                projectsWithOverdueTasks: items.filter { $0.findings.contains("Overdue tasks") }.count,
                projectsWithoutDeadlines: items.filter { $0.findings.contains("No deadline") }.count
            )
        )
    }
}
