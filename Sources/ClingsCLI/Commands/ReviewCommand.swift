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
        abstract: "Start or resume a weekly review"
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let session = ReviewSession.load() ?? ReviewSession()

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        let useColors = !output.noColor
        let bold = useColors ? "\u{001B}[1m" : ""
        let green = useColors ? "\u{001B}[32m" : ""
        let yellow = useColors ? "\u{001B}[33m" : ""
        let cyan = useColors ? "\u{001B}[36m" : ""
        let dim = useColors ? "\u{001B}[2m" : ""
        let reset = useColors ? "\u{001B}[0m" : ""

        print("\(bold)📋 Weekly Review\(reset)")
        print("\(dim)─────────────────────────────────────\(reset)")

        let db = try ThingsDatabase()

        // Step 1: Inbox
        print("\n\(bold)Step 1: Process Inbox\(reset)")
        let inbox = try db.fetchList(.inbox)
        if inbox.isEmpty {
            print("  \(green)✓ Inbox is empty!\(reset)")
        } else {
            print("  \(yellow)⚠ \(inbox.count) items in inbox\(reset)")
            print("  \(dim)Run: clings inbox\(reset)")
        }

        // Step 2: Someday/Maybe
        print("\n\(bold)Step 2: Review Someday/Maybe\(reset)")
        let someday = try db.fetchList(.someday)
        print("  \(someday.count) items in Someday")
        if !someday.isEmpty {
            print("  \(dim)Consider: Which items should be activated?\(reset)")
        }

        // Step 3: Projects
        print("\n\(bold)Step 3: Check Projects\(reset)")
        let projects = try db.fetchProjects()
        let activeProjects = projects.filter { $0.status == .open }
        print("  \(activeProjects.count) active projects")

        // Find stalled projects (no recent activity)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        var stalledCount = 0
        for project in activeProjects {
            // A project is "stalled" if it has no todos in today/upcoming
            // This is a simplified heuristic
            if let created = project.creationDate, created < weekAgo {
                stalledCount += 1
            }
        }
        if stalledCount > 0 {
            print("  \(yellow)⚠ \(stalledCount) projects may need attention\(reset)")
        }

        // Step 4: Deadlines
        print("\n\(bold)Step 4: Review Deadlines\(reset)")
        let upcoming = try db.fetchList(.upcoming)
        let today = try db.fetchList(.today)
        let allOpen = upcoming + today

        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let upcomingDeadlines = allOpen.filter { todo in
            guard let due = todo.dueDate else { return false }
            return due <= nextWeek
        }

        if upcomingDeadlines.isEmpty {
            print("  \(green)✓ No deadlines in the next 7 days\(reset)")
        } else {
            print("  \(cyan)\(upcomingDeadlines.count) deadlines in the next 7 days:\(reset)")
            for todo in upcomingDeadlines.prefix(5) {
                let dueStr = todo.dueDate.map { formatDate($0) } ?? ""
                print("    • \(todo.name) \(dim)(\(dueStr))\(reset)")
            }
            if upcomingDeadlines.count > 5 {
                print("    \(dim)... and \(upcomingDeadlines.count - 5) more\(reset)")
            }
        }

        // Step 5: Summary
        print("\n\(bold)Step 5: Summary\(reset)")
        let todayCount = try db.fetchList(.today).count
        let stats = try StatsCollector().collect(days: 7)

        print("  Today's todos:        \(todayCount)")
        print("  Completed this week:  \(green)\(stats.completedInPeriod)\(reset)")
        print("  Inbox items:          \(inbox.count)")
        print("  Overdue items:        \(stats.overdue > 0 ? "\(yellow)\(stats.overdue)\(reset)" : "0")")

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
        abstract: "Show current review session status"
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
        abstract: "Clear the current review session"
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
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".clings")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("review-session.json")
    }

    static func load() -> ReviewSession? {
        guard let data = try? Data(contentsOf: sessionPath) else { return nil }
        return try? JSONDecoder().decode(ReviewSession.self, from: data)
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: Self.sessionPath)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: sessionPath)
    }
}
