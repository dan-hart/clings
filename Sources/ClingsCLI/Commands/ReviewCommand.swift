// ReviewCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation

struct ReviewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "review",
        abstract: "GTD weekly review workflow",
        discussion: """
        Interactive weekly review process:
        1. Process inbox items
        2. Review someday/maybe items
        3. Check project status
        4. Review deadlines
        5. Generate summary

        EXAMPLES:
          clings review
          clings review status
          clings review clear
        """,
        subcommands: [
            ReviewStartCommand.self,
            ReviewStatusCommand.self,
            ReviewClearCommand.self,
        ],
        defaultSubcommand: ReviewStartCommand.self
    )
}

// MARK: - Review Start Command

struct ReviewStartCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start or resume a weekly review",
        discussion: """
        Walk through inbox, someday, projects, deadlines, and a short weekly
        summary, then persist the review session locally.

        EXAMPLES:
          clings review
          clings review start
        """
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let session = ReviewSession.load() ?? ReviewSession()

        let useColors = !output.noColor
        let bold = useColors ? "\u{001B}[1m" : ""
        let green = useColors ? "\u{001B}[32m" : ""
        let yellow = useColors ? "\u{001B}[33m" : ""
        let cyan = useColors ? "\u{001B}[36m" : ""
        let dim = useColors ? "\u{001B}[2m" : ""
        let reset = useColors ? "\u{001B}[0m" : ""

        print("\(bold)📋 Weekly Review\(reset)")
        print("\(dim)─────────────────────────────────────\(reset)")

        let db = try CommandRuntime.makeDatabase()
        let inbox = try db.fetchList(.inbox)
        let someday = try db.fetchList(.someday)
        let projects = try db.fetchProjects()
        let upcoming = try db.fetchList(.upcoming)
        let today = try db.fetchList(.today)
        let summary = ReviewAssistant().summarize(
            inbox: inbox,
            someday: someday,
            today: today,
            upcoming: upcoming,
            projects: projects
        )

        // Step 1: Inbox
        print("\n\(bold)Step 1: Process Inbox\(reset)")
        if inbox.isEmpty {
            print("  \(green)✓ Inbox is empty!\(reset)")
        } else {
            print("  \(yellow)⚠ \(inbox.count) items in inbox\(reset)")
            print("  \(dim)Run: clings inbox\(reset)")
        }

        // Step 2: Someday/Maybe
        print("\n\(bold)Step 2: Review Someday/Maybe\(reset)")
        print("  \(someday.count) items in Someday")
        if !someday.isEmpty {
            print("  \(dim)Consider: Which items should be activated?\(reset)")
        }

        // Step 3: Projects
        print("\n\(bold)Step 3: Check Projects\(reset)")
        let activeProjects = projects.filter { $0.status == .open }
        print("  \(activeProjects.count) active projects")
        if !summary.stalledProjects.isEmpty {
            print("  \(yellow)⚠ \(summary.stalledProjects.count) projects may need attention\(reset)")
        }

        // Step 4: Deadlines
        print("\n\(bold)Step 4: Review Deadlines\(reset)")
        if summary.upcomingDeadlines.isEmpty {
            print("  \(green)✓ No deadlines in the next 7 days\(reset)")
        } else {
            print("  \(cyan)\(summary.upcomingDeadlines.count) deadlines in the next 7 days:\(reset)")
            for todo in summary.upcomingDeadlines.prefix(5) {
                let dueStr = todo.dueDate.map { formatDate($0) } ?? ""
                print("    • \(todo.name) \(dim)(\(dueStr))\(reset)")
            }
            if summary.upcomingDeadlines.count > 5 {
                print("    \(dim)... and \(summary.upcomingDeadlines.count - 5) more\(reset)")
            }
        }

        // Step 5: Summary
        print("\n\(bold)Step 5: Summary\(reset)")
        let todayCount = today.count
        let stats = try StatsCollector().collect(days: 7)

        print("  Today's todos:        \(todayCount)")
        print("  Completed this week:  \(green)\(stats.completedInPeriod)\(reset)")
        print("  Inbox items:          \(inbox.count)")
        print("  Overdue items:        \(stats.overdue > 0 ? "\(yellow)\(stats.overdue)\(reset)" : "0")")
        if !summary.suggestedActions.isEmpty {
            print("\n\(bold)Suggested Actions\(reset)")
            for action in summary.suggestedActions {
                print("  • \(action)")
            }
        }

        // Save session
        var updatedSession = session
        updatedSession.lastReviewDate = Date()
        updatedSession.inboxProcessed = inbox.isEmpty
        updatedSession.deadlinesReviewed = true
        updatedSession.save()

        print("\n\(dim)Review session saved.\(reset)")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Review Status Command

struct ReviewStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current review session status",
        discussion: """
        Show the last saved review timestamp and whether the core review steps
        have been marked complete.

        EXAMPLES:
          clings review status
        """
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        guard let session = ReviewSession.load() else {
            print("No active review session. Run: clings review start")
            return
        }

        let useColors = !output.noColor
        let bold = useColors ? "\u{001B}[1m" : ""
        let green = useColors ? "\u{001B}[32m" : ""
        let dim = useColors ? "\u{001B}[2m" : ""
        let reset = useColors ? "\u{001B}[0m" : ""

        print("\(bold)Review Session Status\(reset)")
        print("\(dim)─────────────────────────────────────\(reset)")

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        print("  Last review:       \(formatter.string(from: session.lastReviewDate))")
        print("  Inbox processed:   \(session.inboxProcessed ? "\(green)✓\(reset)" : "○")")
        print("  Deadlines reviewed: \(session.deadlinesReviewed ? "\(green)✓\(reset)" : "○")")
    }
}

// MARK: - Review Clear Command

struct ReviewClearCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Clear the current review session",
        discussion: """
        Delete the saved weekly review session so the next run starts fresh.

        EXAMPLES:
          clings review clear
        """
    )

    func run() async throws {
        ReviewSession.clear()
        print("Review session cleared.")
    }
}

// MARK: - Review Session

struct ReviewSession: Codable {
    var lastReviewDate: Date
    var inboxProcessed: Bool
    var deadlinesReviewed: Bool

    init() {
        self.lastReviewDate = Date()
        self.inboxProcessed = false
        self.deadlinesReviewed = false
    }

    private static var sessionPath: URL {
        (try? ClingsConfig.fileURL(named: "review-session.json"))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".clings/review-session.json")
    }

    static func load() -> ReviewSession? {
        if !FileManager.default.fileExists(atPath: sessionPath.path) {
            return nil
        }
        return try? JSONFileStore.load(ReviewSession.self, from: "review-session.json", default: ReviewSession())
    }

    func save() {
        try? JSONFileStore.save(self, to: "review-session.json")
    }

    static func clear() {
        try? JSONFileStore.delete(fileName: "review-session.json")
    }
}
