// ThingsDatabase.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB

/// Direct SQLite access to the Things 3 database for fast reads.
/// Note: This is an undocumented API and may break with Things updates.
public final class ThingsDatabase: Sendable {
    private let dbPath: String

    /// Initialize with the Things 3 database path.
    public init() throws {
        // Find the Things database - it may be in a ThingsData-XXXX subdirectory
        let groupContainerBase = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac")

        // Try to find the database in any ThingsData-* subdirectory
        var dbPathFound: String?

        if let contents = try? FileManager.default.contentsOfDirectory(atPath: groupContainerBase.path) {
            for item in contents where item.hasPrefix("ThingsData-") {
                let candidatePath = groupContainerBase
                    .appendingPathComponent(item)
                    .appendingPathComponent("Things Database.thingsdatabase/main.sqlite")
                if FileManager.default.fileExists(atPath: candidatePath.path) {
                    dbPathFound = candidatePath.path
                    break
                }
            }
        }

        // Fallback: try the old location (Things Database.thingsdatabase directly in container)
        if dbPathFound == nil {
            let fallbackPath = groupContainerBase
                .appendingPathComponent("Things Database.thingsdatabase/main.sqlite")
            if FileManager.default.fileExists(atPath: fallbackPath.path) {
                dbPathFound = fallbackPath.path
            }
        }

        guard let path = dbPathFound else {
            throw ThingsError.operationFailed("Things 3 database not found. Is Things 3 installed?")
        }

        self.dbPath = path
    }

    /// Open a read-only connection to the database.
    private func openDatabase() throws -> DatabaseQueue {
        var config = Configuration()
        config.readonly = true
        return try DatabaseQueue(path: dbPath, configuration: config)
    }

    // MARK: - List Queries

    /// Fetch todos from a specific list view.
    public func fetchList(_ list: ListView) throws -> [Todo] {
        let db = try openDatabase()

        return try db.read { db in
            let sql: String
            let arguments: StatementArguments

            switch list {
            case .inbox:
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0
                          AND start = 0 AND project IS NULL AND startDate IS NULL
                    ORDER BY "index"
                    """
                arguments = []

            case .today:
                let todayStart = Calendar.current.startOfDay(for: Date())
                let todayInt = Int(todayStart.timeIntervalSinceReferenceDate)
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0
                          AND (start = 1 OR startDate = ?)
                    ORDER BY todayIndex, "index"
                    """
                arguments = [todayInt]

            case .upcoming:
                let todayStart = Calendar.current.startOfDay(for: Date())
                let todayInt = Int(todayStart.timeIntervalSinceReferenceDate)
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0 AND startDate > ?
                    ORDER BY startDate, "index"
                    """
                arguments = [todayInt]

            case .anytime:
                let todayStart = Calendar.current.startOfDay(for: Date())
                let todayInt = Int(todayStart.timeIntervalSinceReferenceDate)
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0 AND start = 1
                          AND (startDate IS NULL OR startDate <= ?)
                    ORDER BY "index"
                    """
                arguments = [todayInt]

            case .someday:
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0 AND start = 2
                    ORDER BY "index"
                    """
                arguments = []

            case .logbook:
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, area
                    FROM TMTask
                    WHERE status = 3 AND trashed = 0 AND type = 0
                    ORDER BY stopDate DESC
                    LIMIT 500
                    """
                arguments = []

            case .trash:
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, area
                    FROM TMTask
                    WHERE trashed = 1 AND type = 0
                    ORDER BY "index"
                    """
                arguments = []
            }

            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            return try rows.map { row in
                try self.todoFromRow(row, db: db)
            }
        }
    }

    /// Fetch all projects.
    public func fetchProjects() throws -> [Project] {
        let db = try openDatabase()

        return try db.read { db in
            let sql = """
                SELECT uuid, title, notes, status, stopDate, deadline, creationDate, area
                FROM TMTask
                WHERE type = 1 AND trashed = 0 AND status = 0
                ORDER BY "index"
                """

            let rows = try Row.fetchAll(db, sql: sql)
            return try rows.map { row in
                let uuid: String = row["uuid"]
                let title: String = row["title"]
                let notes: String? = row["notes"]
                let statusInt: Int = row["status"]
                let areaUuid: String? = row["area"]

                let area: Area? = try areaUuid.flatMap { try self.fetchArea(uuid: $0, db: db) }
                let tags = try self.fetchTagsForTask(uuid: uuid, db: db)

                let deadline: Date? = (row["deadline"] as Int?).flatMap {
                    Date(timeIntervalSinceReferenceDate: TimeInterval($0))
                }
                let creationDate = Date(timeIntervalSinceReferenceDate: TimeInterval(row["creationDate"] as Int))

                return Project(
                    id: uuid,
                    name: title,
                    notes: notes,
                    status: statusFromInt(statusInt),
                    area: area,
                    tags: tags,
                    dueDate: deadline,
                    creationDate: creationDate
                )
            }
        }
    }

    /// Fetch all areas.
    public func fetchAreas() throws -> [Area] {
        let db = try openDatabase()

        return try db.read { db in
            let sql = "SELECT uuid, title FROM TMArea ORDER BY \"index\""
            let rows = try Row.fetchAll(db, sql: sql)

            return try rows.map { row in
                let uuid: String = row["uuid"]
                let title: String = row["title"]
                let tags = try self.fetchTagsForArea(uuid: uuid, db: db)

                return Area(id: uuid, name: title, tags: tags)
            }
        }
    }

    /// Fetch all tags.
    public func fetchTags() throws -> [Tag] {
        let db = try openDatabase()

        return try db.read { db in
            let sql = "SELECT uuid, title FROM TMTag ORDER BY title"
            let rows = try Row.fetchAll(db, sql: sql)

            return rows.map { row in
                Tag(id: row["uuid"], name: row["title"])
            }
        }
    }

    /// Fetch a single todo by ID.
    public func fetchTodo(id: String) throws -> Todo {
        let db = try openDatabase()

        return try db.read { db in
            let sql = """
                SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                       userModificationDate, project, area
                FROM TMTask
                WHERE uuid = ? AND type = 0
                """

            guard let row = try Row.fetchOne(db, sql: sql, arguments: [id]) else {
                throw ThingsError.notFound(id)
            }

            return try self.todoFromRow(row, db: db)
        }
    }

    /// Search todos by text.
    public func search(query: String) throws -> [Todo] {
        let db = try openDatabase()

        return try db.read { db in
            let sql = """
                SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                       userModificationDate, project, area
                FROM TMTask
                WHERE type = 0 AND trashed = 0
                      AND (title LIKE ? OR notes LIKE ?)
                ORDER BY todayIndex, "index"
                LIMIT 100
                """

            let pattern = "%\(query)%"
            let rows = try Row.fetchAll(db, sql: sql, arguments: [pattern, pattern])
            return try rows.map { row in
                try self.todoFromRow(row, db: db)
            }
        }
    }

    // MARK: - Helper Methods

    private func todoFromRow(_ row: Row, db: Database) throws -> Todo {
        let uuid: String = row["uuid"]
        let title: String = row["title"]
        let notes: String? = row["notes"]
        let statusInt: Int = row["status"]
        let projectUuid: String? = row["project"]
        let areaUuid: String? = row["area"]

        let project: Project? = try projectUuid.flatMap { try self.fetchProjectBasic(uuid: $0, db: db) }
        let area: Area? = try areaUuid.flatMap { try self.fetchArea(uuid: $0, db: db) }
        let tags = try fetchTagsForTask(uuid: uuid, db: db)
        let checklistItems = try fetchChecklistItems(uuid: uuid, db: db)

        let deadline: Date? = (row["deadline"] as Int?).flatMap {
            Date(timeIntervalSinceReferenceDate: TimeInterval($0))
        }
        let creationDate: Date = (row["creationDate"] as Double?).flatMap {
            Date(timeIntervalSinceReferenceDate: $0)
        } ?? Date()
        let modificationDate: Date = (row["userModificationDate"] as Double?).flatMap {
            Date(timeIntervalSinceReferenceDate: $0)
        } ?? creationDate

        return Todo(
            id: uuid,
            name: title,
            notes: notes,
            status: statusFromInt(statusInt),
            dueDate: deadline,
            tags: tags,
            project: project,
            area: area,
            checklistItems: checklistItems,
            creationDate: creationDate,
            modificationDate: modificationDate
        )
    }

    private func fetchProjectBasic(uuid: String, db: Database) throws -> Project? {
        let sql = "SELECT title, status FROM TMTask WHERE uuid = ? AND type = 1"
        guard let row = try Row.fetchOne(db, sql: sql, arguments: [uuid]) else {
            return nil
        }

        return Project(
            id: uuid,
            name: row["title"],
            notes: nil,
            status: statusFromInt(row["status"]),
            area: nil,
            tags: [],
            dueDate: nil,
            creationDate: Date()
        )
    }

    private func fetchArea(uuid: String, db: Database) throws -> Area? {
        let sql = "SELECT title FROM TMArea WHERE uuid = ?"
        guard let row = try Row.fetchOne(db, sql: sql, arguments: [uuid]) else {
            return nil
        }

        return Area(id: uuid, name: row["title"], tags: [])
    }

    private func fetchTagsForTask(uuid: String, db: Database) throws -> [Tag] {
        let sql = """
            SELECT tag.uuid, tag.title
            FROM TMTaskTag AS tt
            JOIN TMTag AS tag ON tt.tags = tag.uuid
            WHERE tt.tasks = ?
            """
        let rows = try Row.fetchAll(db, sql: sql, arguments: [uuid])
        return rows.map { Tag(id: $0["uuid"], name: $0["title"]) }
    }

    private func fetchTagsForArea(uuid: String, db: Database) throws -> [Tag] {
        let sql = """
            SELECT tag.uuid, tag.title
            FROM TMAreaTag AS at
            JOIN TMTag AS tag ON at.tags = tag.uuid
            WHERE at.areas = ?
            """
        let rows = try Row.fetchAll(db, sql: sql, arguments: [uuid])
        return rows.map { Tag(id: $0["uuid"], name: $0["title"]) }
    }

    private func fetchChecklistItems(uuid: String, db: Database) throws -> [ChecklistItem] {
        let sql = """
            SELECT uuid, title, status
            FROM TMChecklistItem
            WHERE task = ?
            ORDER BY "index"
            """
        let rows = try Row.fetchAll(db, sql: sql, arguments: [uuid])
        return rows.map { row in
            ChecklistItem(
                id: row["uuid"],
                name: row["title"],
                completed: (row["status"] as Int) == 3
            )
        }
    }

    private func statusFromInt(_ value: Int) -> Status {
        switch value {
        case 0: return .open
        case 2: return .canceled
        case 3: return .completed
        default: return .open
        }
    }
}
