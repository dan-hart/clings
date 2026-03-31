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

    @Test func fetchProjectsIncludesAreaTagsAndDates() throws {
        let fixture = try makeFixtureDatabase()
        let deadline = 1_234
        let createdAt = 4_567.0

        try fixture.db.write { db in
            try insertArea(db, id: "area-work", title: "Work", index: 0)
            try insertTag(db, id: "tag-docs", title: "docs")
            try insertTask(
                db,
                id: "project-1",
                title: "Documentation",
                start: 0,
                startDate: nil,
                index: 0,
                type: 1,
                notes: "Project notes",
                deadline: deadline,
                creationDate: createdAt,
                area: "area-work"
            )
            try insertTaskTag(db, taskID: "project-1", tagID: "tag-docs")
        }

        let database = ThingsDatabase(dbPath: fixture.path)
        let projects = try database.fetchProjects()

        #expect(projects.count == 1)
        #expect(projects[0].id == "project-1")
        #expect(projects[0].name == "Documentation")
        #expect(projects[0].notes == "Project notes")
        #expect(projects[0].area?.name == "Work")
        #expect(projects[0].tags.map(\.name) == ["docs"])
        #expect(projects[0].dueDate == Date(timeIntervalSinceReferenceDate: TimeInterval(deadline)))
        #expect(projects[0].creationDate == Date(timeIntervalSinceReferenceDate: TimeInterval(createdAt)))
    }

    @Test func fetchAreasAndTagsReturnAttachedMetadata() throws {
        let fixture = try makeFixtureDatabase()

        try fixture.db.write { db in
            try insertArea(db, id: "area-home", title: "Home", index: 0)
            try insertTag(db, id: "tag-home", title: "home")
            try insertTag(db, id: "tag-errands", title: "errands")
            try db.execute(
                sql: "INSERT INTO TMAreaTag (areas, tags) VALUES (?, ?), (?, ?)",
                arguments: ["area-home", "tag-home", "area-home", "tag-errands"]
            )
        }

        let database = ThingsDatabase(dbPath: fixture.path)
        let areas = try database.fetchAreas()
        let tags = try database.fetchTags()

        #expect(areas.count == 1)
        #expect(areas[0].name == "Home")
        #expect(areas[0].tags.map(\.name).sorted() == ["errands", "home"])
        #expect(tags.map(\.name) == ["errands", "home"])
    }

    @Test func fetchTodoAndSearchReturnRichTodoMetadata() throws {
        let fixture = try makeFixtureDatabase()

        try fixture.db.write { db in
            try insertArea(db, id: "area-work", title: "Work", index: 0)
            try insertTag(db, id: "tag-docs", title: "docs")
            try insertTask(
                db,
                id: "project-1",
                title: "Documentation",
                start: 0,
                startDate: nil,
                index: 0,
                type: 1
            )
            try insertTask(
                db,
                id: "todo-1",
                title: "Ship docs",
                start: 1,
                startDate: thingsDateCode(Date()),
                index: 1,
                notes: "Coordinate release notes",
                deadline: 900,
                creationDate: 100,
                modificationDate: 200,
                project: "project-1",
                area: "area-work"
            )
            try insertTaskTag(db, taskID: "todo-1", tagID: "tag-docs")
            try db.execute(
                sql: """
                    INSERT INTO TMChecklistItem (uuid, title, status, task, "index")
                    VALUES
                        ('check-1', 'Draft outline', 3, 'todo-1', 0),
                        ('check-2', 'Publish examples', 0, 'todo-1', 1)
                    """
            )
        }

        let database = ThingsDatabase(dbPath: fixture.path)
        let todo = try database.fetchTodo(id: "todo-1")
        let searchResults = try database.search(query: "release")

        #expect(todo.name == "Ship docs")
        #expect(todo.notes == "Coordinate release notes")
        #expect(todo.project?.name == "Documentation")
        #expect(todo.area?.name == "Work")
        #expect(todo.tags.map(\.name) == ["docs"])
        #expect(todo.checklistItems.map(\.name) == ["Draft outline", "Publish examples"])
        #expect(todo.checklistItems.map(\.completed) == [true, false])
        #expect(todo.dueDate == Date(timeIntervalSinceReferenceDate: 900))
        #expect(todo.creationDate == Date(timeIntervalSinceReferenceDate: 100))
        #expect(todo.modificationDate == Date(timeIntervalSinceReferenceDate: 200))
        #expect(searchResults.map(\.id) == ["todo-1"])
    }

    @Test func fetchTodoThrowsNotFoundForUnknownID() throws {
        let fixture = try makeFixtureDatabase()
        let database = ThingsDatabase(dbPath: fixture.path)

        #expect(throws: ThingsError.self) {
            _ = try database.fetchTodo(id: "missing")
        }
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

            try db.execute(
                sql: """
                    CREATE TABLE TMArea (
                        uuid TEXT PRIMARY KEY,
                        title TEXT NOT NULL,
                        "index" INTEGER NOT NULL DEFAULT 0
                    )
                    """
            )
            try db.execute(sql: "CREATE TABLE TMTag (uuid TEXT PRIMARY KEY, title TEXT NOT NULL)")
            try db.execute(sql: "CREATE TABLE TMTaskTag (tasks TEXT NOT NULL, tags TEXT NOT NULL)")
            try db.execute(sql: "CREATE TABLE TMAreaTag (areas TEXT NOT NULL, tags TEXT NOT NULL)")
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
        trashed: Int = 0,
        type: Int = 0,
        notes: String? = nil,
        deadline: Int? = nil,
        creationDate: Double = 0,
        modificationDate: Double? = nil,
        project: String? = nil,
        area: String? = nil
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO TMTask (
                    uuid, title, notes, status, stopDate, deadline, creationDate, userModificationDate,
                    project, area, trashed, type, start, startDate, todayIndex, "index"
                ) VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
                """,
            arguments: [
                id,
                title,
                notes,
                status,
                deadline,
                creationDate,
                modificationDate ?? creationDate,
                project,
                area,
                trashed,
                type,
                start,
                startDate,
                index,
            ]
        )
    }

    private func insertArea(_ db: Database, id: String, title: String, index: Int) throws {
        try db.execute(
            sql: "INSERT INTO TMArea (uuid, title, \"index\") VALUES (?, ?, ?)",
            arguments: [id, title, index]
        )
    }

    private func insertTag(_ db: Database, id: String, title: String) throws {
        try db.execute(
            sql: "INSERT INTO TMTag (uuid, title) VALUES (?, ?)",
            arguments: [id, title]
        )
    }

    private func insertTaskTag(_ db: Database, taskID: String, tagID: String) throws {
        try db.execute(
            sql: "INSERT INTO TMTaskTag (tasks, tags) VALUES (?, ?)",
            arguments: [taskID, tagID]
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
