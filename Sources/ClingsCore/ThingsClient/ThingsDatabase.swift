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

    /// Initialize with an explicit database path.
    public init(dbPath: String) {
        self.dbPath = dbPath
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
                           userModificationDate, project, heading, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0
                          AND start = 0 AND project IS NULL AND startDate IS NULL
                          AND rt1_recurrenceRule IS NULL
                    ORDER BY "index"
                    """
                arguments = []

            case .today:
                let todayCode = thingsDateCode(Date())
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, heading, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0
                          AND rt1_recurrenceRule IS NULL
                          AND (
                              (start = 1 AND startDate IS NOT NULL AND startDate <= ?)
                              OR (start = 2 AND startDate IS NOT NULL AND startDate <= ?)
                              OR (startDate IS NULL AND deadline IS NOT NULL AND deadline <= ? AND deadlineSuppressionDate IS NULL)
                          )
                    ORDER BY todayIndex IS NULL, todayIndex, "index"
                    """
                arguments = [todayCode, todayCode, todayCode]

            case .upcoming:
                let todayCode = thingsDateCode(Date())
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, heading, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0 AND startDate > ?
                          AND rt1_recurrenceRule IS NULL
                    ORDER BY startDate, "index"
                    """
                arguments = [todayCode]

            case .anytime:
                let todayCode = thingsDateCode(Date())
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, heading, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0 AND start = 1
                          AND (startDate IS NULL OR startDate <= ?)
                          AND rt1_recurrenceRule IS NULL
                    ORDER BY "index"
                    """
                arguments = [todayCode]

            case .someday:
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, heading, area
                    FROM TMTask
                    WHERE status = 0 AND trashed = 0 AND type = 0 AND start = 2
                          AND startDate IS NULL
                          AND rt1_recurrenceRule IS NULL
                    ORDER BY "index"
                    """
                arguments = []

            case .logbook:
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, heading, area
                    FROM TMTask
                    WHERE status = 3 AND trashed = 0 AND type = 0
                          AND rt1_recurrenceRule IS NULL
                    ORDER BY stopDate DESC
                    LIMIT 500
                    """
                arguments = []

            case .trash:
                sql = """
                    SELECT uuid, title, notes, status, stopDate, deadline, creationDate,
                           userModificationDate, project, heading, area
                    FROM TMTask
                    WHERE trashed = 1 AND type = 0
                          AND rt1_recurrenceRule IS NULL
                    ORDER BY "index"
                    """
                arguments = []
            }

            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            return try rows.compactMap { row -> Todo? in
                // Things hides descendants of a trashed project from every list
                // (except Trash itself), even though the descendant's own
                // `trashed` flag stays 0. Mirror that here.
                if list != .trash {
                    let projectUuid: String? = row["project"]
                    let headingUuid: String? = row["heading"]
                    if try self.isAncestorProjectTrashed(projectUuid: projectUuid, headingUuid: headingUuid, db: db) {
                        return nil
                    }
                }
                return try self.todoFromRow(row, db: db)
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
                      AND rt1_recurrenceRule IS NULL
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

                let deadline = self.decodeDeadline(row["deadline"] as Int?)
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
                       userModificationDate, project, heading, area
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
                       userModificationDate, project, heading, area
                FROM TMTask
                WHERE type = 0 AND trashed = 0
                      AND rt1_recurrenceRule IS NULL
                      AND (title LIKE ? OR notes LIKE ?)
                ORDER BY todayIndex, "index"
                LIMIT 100
                """

            let pattern = "%\(query)%"
            let rows = try Row.fetchAll(db, sql: sql, arguments: [pattern, pattern])
            return try rows.compactMap { row -> Todo? in
                // Mirror fetchList: descendants of a trashed project stay hidden
                // even though their own `trashed` flag is 0.
                let projectUuid: String? = row["project"]
                let headingUuid: String? = row["heading"]
                if try self.isAncestorProjectTrashed(projectUuid: projectUuid, headingUuid: headingUuid, db: db) {
                    return nil
                }
                return try self.todoFromRow(row, db: db)
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
        let headingUuid: String? = row["heading"]
        let areaUuid: String? = row["area"]

        // A todo filed under a heading has `project` left blank; the real
        // parent project lives on the heading row instead.
        let resolvedProjectUuid = try projectUuid ?? headingUuid.flatMap {
            try self.projectUuid(forHeading: $0, db: db)
        }

        let project: Project? = try resolvedProjectUuid.flatMap { try self.fetchProjectBasic(uuid: $0, db: db) }
        let area: Area? = try areaUuid.flatMap { try self.fetchArea(uuid: $0, db: db) }
        let tags = try fetchTagsForTask(uuid: uuid, db: db)
        let checklistItems = try fetchChecklistItems(uuid: uuid, db: db)

        let deadline = decodeDeadline(row["deadline"] as Int?)
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

    /// Resolve the project a heading belongs to.
    private func projectUuid(forHeading headingUuid: String, db: Database) throws -> String? {
        let sql = "SELECT project FROM TMTask WHERE uuid = ? AND type = 2"
        return try Row.fetchOne(db, sql: sql, arguments: [headingUuid])?["project"]
    }

    /// Whether a todo's ancestor project (direct, or via a heading) is trashed.
    /// Things hides descendants of a trashed project from every list even
    /// though the descendant's own `trashed` column stays 0.
    private func isAncestorProjectTrashed(projectUuid: String?, headingUuid: String?, db: Database) throws -> Bool {
        let resolvedProjectUuid = try projectUuid ?? headingUuid.flatMap {
            try self.projectUuid(forHeading: $0, db: db)
        }
        guard let resolvedProjectUuid else { return false }

        let sql = "SELECT trashed FROM TMTask WHERE uuid = ? AND type = 1"
        guard let row = try Row.fetchOne(db, sql: sql, arguments: [resolvedProjectUuid]) else { return false }
        return (row["trashed"] as Int) == 1
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

    /// Encode a local calendar day using Things' packed integer date format.
    /// Format: `(year << 16) | (month << 12) | (day << 7)`.
    /// Things always packs/unpacks these dates using the Gregorian calendar,
    /// regardless of the user's preferred calendar (Buddhist, Hebrew, Persian,
    /// etc.), since the bit fields encode a fixed Gregorian year/month/day.
    private func thingsDateCode(_ date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return (year << 16) | (month << 12) | (day << 7)
    }

    /// Decode a `deadline` value stored using Things' packed integer date
    /// format (see `thingsDateCode`). Things uses year 4001 as an internal
    /// sentinel for "no real deadline" (visible via AppleScript as
    /// `January 1, 4001`), which is not a real date to surface to users.
    ///
    /// Note this is a date-only value (no time component); it was previously
    /// misdecoded as raw seconds since the Cocoa reference date, which
    /// produced nonsensical dates like April 23, 2009 for every task sharing
    /// that sentinel.
    private func decodeDeadline(_ value: Int?) -> Date? {
        guard let value else { return nil }

        let year = value >> 16
        let month = (value >> 12) & 0xF
        let day = (value >> 7) & 0x1F
        guard year > 0, year < 4001, month > 0, day > 0 else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar.date(from: components)
    }
}

extension ThingsDatabase: ThingsDatabaseReadable {}
