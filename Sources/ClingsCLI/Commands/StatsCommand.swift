// StatsCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation

struct StatsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show productivity statistics",
        discussion: """
        Display statistics about your todos including:
        - Total counts by status
        - Completion rates
        - Overdue items
        - Tag distribution
        """
    )

    @Option(name: .long, help: "Number of days to analyze (default: 30)")
    var days: Int = 30

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let stats = try StatsCollector().collect(days: days)

        if output.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(stats)
            print(String(data: data, encoding: .utf8) ?? "{}")
        } else {
            printPrettyStats(stats, useColors: !output.noColor)
        }
    }

    private func printPrettyStats(_ stats: Stats, useColors: Bool) {
        let green = useColors ? "\u{001B}[32m" : ""
        let yellow = useColors ? "\u{001B}[33m" : ""
        let red = useColors ? "\u{001B}[31m" : ""
        let cyan = useColors ? "\u{001B}[36m" : ""
        let bold = useColors ? "\u{001B}[1m" : ""
        let dim = useColors ? "\u{001B}[2m" : ""
        let reset = useColors ? "\u{001B}[0m" : ""

        print("\(bold)📊 Things 3 Statistics\(reset)")
        print("\(dim)─────────────────────────────────────\(reset)")

        // Overview
        print("\n\(bold)Overview\(reset)")
        print("  Total open todos:     \(stats.totalOpen)")
        print("  Completed (\(stats.days)d):     \(green)\(stats.completedInPeriod)\(reset)")
        print("  Canceled (\(stats.days)d):      \(stats.canceledInPeriod)")
        print("  Overdue:              \(red)\(stats.overdue)\(reset)")

        // Completion rate
        let rate = stats.completionRate
        let rateColor = rate >= 70 ? green : (rate >= 40 ? yellow : red)
        print("  Completion rate:      \(rateColor)\(String(format: "%.1f", rate))%\(reset)")

        // By List
        print("\n\(bold)By List\(reset)")
        print("  Inbox:      \(stats.inbox)")
        print("  Today:      \(stats.today)")
        print("  Upcoming:   \(stats.upcoming)")
        print("  Anytime:    \(stats.anytime)")
        print("  Someday:    \(stats.someday)")

        // Projects
        if !stats.topProjects.isEmpty {
            print("\n\(bold)Top Projects\(reset) \(dim)(by open todos)\(reset)")
            for (name, count) in stats.topProjects.prefix(5) {
                print("  \(cyan)\(name)\(reset): \(count)")
            }
        }

        // Tags
        if !stats.topTags.isEmpty {
            print("\n\(bold)Top Tags\(reset) \(dim)(by open todos)\(reset)")
            for (name, count) in stats.topTags.prefix(5) {
                print("  \(cyan)#\(name)\(reset): \(count)")
            }
        }

        // Areas
        if !stats.byArea.isEmpty {
            print("\n\(bold)By Area\(reset)")
            for (name, count) in stats.byArea.sorted(by: { $0.value > $1.value }).prefix(5) {
                print("  \(name): \(count)")
            }
        }

        print("")
    }
}

// MARK: - Stats Model

struct Stats: Codable {
    let days: Int
    let totalOpen: Int
    let completedInPeriod: Int
    let canceledInPeriod: Int
    let overdue: Int
    let completionRate: Double

    let inbox: Int
    let today: Int
    let upcoming: Int
    let anytime: Int
    let someday: Int

    let topProjects: [(String, Int)]
    let topTags: [(String, Int)]
    let byArea: [String: Int]

    enum CodingKeys: String, CodingKey {
        case days, totalOpen, completedInPeriod, canceledInPeriod, overdue, completionRate
        case inbox, today, upcoming, anytime, someday
        case topProjects, topTags, byArea
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(days, forKey: .days)
        try container.encode(totalOpen, forKey: .totalOpen)
        try container.encode(completedInPeriod, forKey: .completedInPeriod)
        try container.encode(canceledInPeriod, forKey: .canceledInPeriod)
        try container.encode(overdue, forKey: .overdue)
        try container.encode(completionRate, forKey: .completionRate)
        try container.encode(inbox, forKey: .inbox)
        try container.encode(today, forKey: .today)
        try container.encode(upcoming, forKey: .upcoming)
        try container.encode(anytime, forKey: .anytime)
        try container.encode(someday, forKey: .someday)

        // Convert tuples to dictionaries for JSON
        let projectsDict = Dictionary(uniqueKeysWithValues: topProjects)
        try container.encode(projectsDict, forKey: .topProjects)

        let tagsDict = Dictionary(uniqueKeysWithValues: topTags)
        try container.encode(tagsDict, forKey: .topTags)

        try container.encode(byArea, forKey: .byArea)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        days = try container.decode(Int.self, forKey: .days)
        totalOpen = try container.decode(Int.self, forKey: .totalOpen)
        completedInPeriod = try container.decode(Int.self, forKey: .completedInPeriod)
        canceledInPeriod = try container.decode(Int.self, forKey: .canceledInPeriod)
        overdue = try container.decode(Int.self, forKey: .overdue)
        completionRate = try container.decode(Double.self, forKey: .completionRate)
        inbox = try container.decode(Int.self, forKey: .inbox)
        today = try container.decode(Int.self, forKey: .today)
        upcoming = try container.decode(Int.self, forKey: .upcoming)
        anytime = try container.decode(Int.self, forKey: .anytime)
        someday = try container.decode(Int.self, forKey: .someday)

        let projectsDict = try container.decode([String: Int].self, forKey: .topProjects)
        topProjects = projectsDict.sorted { $0.value > $1.value }

        let tagsDict = try container.decode([String: Int].self, forKey: .topTags)
        topTags = tagsDict.sorted { $0.value > $1.value }

        byArea = try container.decode([String: Int].self, forKey: .byArea)
    }

    init(days: Int, totalOpen: Int, completedInPeriod: Int, canceledInPeriod: Int,
         overdue: Int, completionRate: Double, inbox: Int, today: Int, upcoming: Int,
         anytime: Int, someday: Int, topProjects: [(String, Int)], topTags: [(String, Int)],
         byArea: [String: Int]) {
        self.days = days
        self.totalOpen = totalOpen
        self.completedInPeriod = completedInPeriod
        self.canceledInPeriod = canceledInPeriod
        self.overdue = overdue
        self.completionRate = completionRate
        self.inbox = inbox
        self.today = today
        self.upcoming = upcoming
        self.anytime = anytime
        self.someday = someday
        self.topProjects = topProjects
        self.topTags = topTags
        self.byArea = byArea
    }
}

// MARK: - Stats Collector

struct StatsCollector {
    func collect(days: Int) throws -> Stats {
        let db = try ThingsDatabase()

        // Fetch all lists
        let inbox = try db.fetchList(.inbox)
        let today = try db.fetchList(.today)
        let upcoming = try db.fetchList(.upcoming)
        let anytime = try db.fetchList(.anytime)
        let someday = try db.fetchList(.someday)
        let logbook = try db.fetchList(.logbook)

        // Calculate totals
        let allOpen = inbox + today + upcoming + anytime + someday
        let totalOpen = allOpen.count

        // Completed/canceled in period
        let periodStart = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let completedInPeriod = logbook.filter { todo in
            todo.status == .completed && todo.modificationDate >= periodStart
        }.count

        let canceledInPeriod = logbook.filter { todo in
            todo.status == .canceled && todo.modificationDate >= periodStart
        }.count

        // Overdue
        let todayStart = Calendar.current.startOfDay(for: Date())
        let overdue = allOpen.filter { todo in
            guard let due = todo.dueDate else { return false }
            return due < todayStart
        }.count

        // Completion rate
        let totalActioned = completedInPeriod + canceledInPeriod
        let completionRate = totalActioned > 0
            ? Double(completedInPeriod) / Double(totalActioned) * 100
            : 0

        // Projects distribution
        var projectCounts: [String: Int] = [:]
        for todo in allOpen {
            if let project = todo.project {
                projectCounts[project.name, default: 0] += 1
            }
        }
        let topProjects = projectCounts.sorted { $0.value > $1.value }

        // Tags distribution
        var tagCounts: [String: Int] = [:]
        for todo in allOpen {
            for tag in todo.tags {
                tagCounts[tag.name, default: 0] += 1
            }
        }
        let topTags = tagCounts.sorted { $0.value > $1.value }

        // Area distribution
        var areaCounts: [String: Int] = [:]
        for todo in allOpen {
            let areaName = todo.area?.name ?? "No Area"
            areaCounts[areaName, default: 0] += 1
        }

        return Stats(
            days: days,
            totalOpen: totalOpen,
            completedInPeriod: completedInPeriod,
            canceledInPeriod: canceledInPeriod,
            overdue: overdue,
            completionRate: completionRate,
            inbox: inbox.count,
            today: today.count,
            upcoming: upcoming.count,
            anytime: anytime.count,
            someday: someday.count,
            topProjects: topProjects,
            topTags: topTags,
            byArea: areaCounts
        )
    }
}
