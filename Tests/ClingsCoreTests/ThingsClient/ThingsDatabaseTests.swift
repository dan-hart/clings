// ThingsDatabaseTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB
import Testing
@testable import ClingsCore

/// Regression coverage for https://github.com/dan-hart/clings/issues/5
@Suite("ThingsDatabase")
struct ThingsDatabaseTests {
    @Test("Issue #5: today list excludes non-today start=1 tasks")
    func todayListExcludesNonTodayStartTasks() throws {
        let fixture = try makeFixtureDatabase()

        let todayCode = thingsDateCode(Date())
        let yesterdayCode = todayCode - 128
        let tomorrowCode = todayCode + 128

        try fixture.db.write { db in
            try insertTask(db, id: "today-task", title: "Today Task", start: 1, startDate: todayCode, index: 0)
            try insertTask(db, id: "yesterday-task", title: "Yesterday Task", start: 1, startDate: yesterdayCode, index: 1)
            try insertTask(db, id: "tomorrow-task", title: "Tomorrow Task", start: 1, startDate: tomorrowCode, index: 2)
            try insertTask(db, id: "no-date-task", title: "No Date Task", start: 1, startDate: nil, index: 3)
            try insertTask(db, id: "start-two-today", title: "Start 2 Today", start: 2, startDate: todayCode, index: 4)
        }

        let database = ThingsDatabase(dbPath: fixture.path)
        let todoIDs = Set(try database.fetchList(.today).map(\.id))
        #expect(todoIDs == ["today-task"])
    }

    @Test("Issue #5: anytime list uses packed Things date format")
    func anytimeListIncludesStartOneTasksOnOrBeforeToday() throws {
        let fixture = try makeFixtureDatabase()

        let todayCode = thingsDateCode(Date())
        let yesterdayCode = todayCode - 128
        let tomorrowCode = todayCode + 128

        try fixture.db.write { db in
            try insertTask(db, id: "anytime-no-date", title: "Anytime No Date", start: 1, startDate: nil, index: 0)
            try insertTask(db, id: "anytime-yesterday", title: "Anytime Yesterday", start: 1, startDate: yesterdayCode, index: 1)
            try insertTask(db, id: "anytime-today", title: "Anytime Today", start: 1, startDate: todayCode, index: 2)
            try insertTask(db, id: "anytime-tomorrow", title: "Anytime Tomorrow", start: 1, startDate: tomorrowCode, index: 3)
            try insertTask(db, id: "start-two-yesterday", title: "Start 2 Yesterday", start: 2, startDate: yesterdayCode, index: 4)
        }

        let database = ThingsDatabase(dbPath: fixture.path)
        let todoIDs = Set(try database.fetchList(.anytime).map(\.id))

        #expect(todoIDs.contains("anytime-no-date"))
        #expect(todoIDs.contains("anytime-yesterday"))
        #expect(todoIDs.contains("anytime-today"))
        #expect(!todoIDs.contains("anytime-tomorrow"))
        #expect(!todoIDs.contains("start-two-yesterday"))
    }

    @Test("Issue #5: upcoming list excludes tasks starting today")
    func upcomingListExcludesTasksStartingToday() throws {
        let fixture = try makeFixtureDatabase()

        let todayCode = thingsDateCode(Date())
        let tomorrowCode = todayCode + 128

        try fixture.db.write { db in
            try insertTask(db, id: "start-today-task", title: "Start Today Task", start: 2, startDate: todayCode, index: 0)
            try insertTask(db, id: "start-tomorrow-task", title: "Start Tomorrow Task", start: 2, startDate: tomorrowCode, index: 1)
        }

        let database = ThingsDatabase(dbPath: fixture.path)
        let todoIDs = Set(try database.fetchList(.upcoming).map(\.id))

        #expect(!todoIDs.contains("start-today-task"))
        #expect(todoIDs.contains("start-tomorrow-task"))
    }

    @Test("Issue #5: list filters only include open, untrashed todos")
    func listQueriesExcludeClosedOrTrashedTodos() throws {
        let fixture = try makeFixtureDatabase()
        let todayCode = thingsDateCode(Date())

        try fixture.db.write { db in
            try insertTask(db, id: "open-today", title: "Open Today", start: 1, startDate: todayCode, index: 0)
            try insertTask(db, id: "completed-today", title: "Completed Today", start: 1, startDate: todayCode, index: 1, status: 3)
            try insertTask(db, id: "trashed-today", title: "Trashed Today", start: 1, startDate: todayCode, index: 2, trashed: 1)
        }

        let database = ThingsDatabase(dbPath: fixture.path)
        let todoIDs = Set(try database.fetchList(.today).map(\.id))
        #expect(todoIDs == ["open-today"])
    }

    private func makeFixtureDatabase() throws -> (path: String, db: DatabaseQueue) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clings-thingsdb-tests-\(UUID().uuidString).sqlite")
        let dbQueue = try DatabaseQueue(path: tempURL.path)

        try dbQueue.write { db in
            try db.execute(
                sql: """
                    CREATE TABLE TMTask (
                        uuid TEXT PRIMARY KEY,
                        title TEXT NOT NULL,
                        notes TEXT,
                        status INTEGER NOT NULL,
                        stopDate REAL,
                        deadline INTEGER,
                        creationDate REAL NOT NULL,
                        userModificationDate REAL NOT NULL,
                        project TEXT,
                        area TEXT,
                        trashed INTEGER NOT NULL,
                        type INTEGER NOT NULL,
                        start INTEGER,
                        startDate INTEGER,
                        todayIndex INTEGER,
                        "index" INTEGER NOT NULL
                    )
                    """
            )

            try db.execute(sql: "CREATE TABLE TMArea (uuid TEXT PRIMARY KEY, title TEXT NOT NULL)")
            try db.execute(sql: "CREATE TABLE TMTag (uuid TEXT PRIMARY KEY, title TEXT NOT NULL)")
            try db.execute(sql: "CREATE TABLE TMTaskTag (tasks TEXT NOT NULL, tags TEXT NOT NULL)")
            try db.execute(
                sql: """
                    CREATE TABLE TMChecklistItem (
                        uuid TEXT PRIMARY KEY,
                        title TEXT NOT NULL,
                        status INTEGER NOT NULL,
                        task TEXT NOT NULL,
                        "index" INTEGER NOT NULL DEFAULT 0
                    )
                    """
            )
        }

        return (path: tempURL.path, db: dbQueue)
    }

    private func insertTask(
        _ db: Database,
        id: String,
        title: String,
        start: Int,
        startDate: Int?,
        index: Int,
        status: Int = 0,
        trashed: Int = 0
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO TMTask (
                    uuid, title, notes, status, stopDate, deadline, creationDate, userModificationDate,
                    project, area, trashed, type, start, startDate, todayIndex, "index"
                ) VALUES (?, ?, NULL, ?, NULL, NULL, 0, 0, NULL, NULL, ?, 0, ?, ?, 0, ?)
                """,
            arguments: [id, title, status, trashed, start, startDate, index]
        )
    }

    /// Things packs local date components into an integer: yyyyMMMMdd0000000.
    private func thingsDateCode(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return (year << 16) | (month << 12) | (day << 7)
    }
}
