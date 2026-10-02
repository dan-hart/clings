import ArgumentParser
import ClingsCore
import Foundation
import GRDB
import Testing
@testable import ClingsCLI

struct LogbookQueryTests {
    @Test func closedQueryScopeIsCompleteBeforeFilteringAndLimiting() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("clings-query-history-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: path) }
        let queue = try DatabaseQueue(path: path.path)
        try await queue.write { db in
            try db.execute(sql: """
            CREATE TABLE TMTask (
              uuid TEXT PRIMARY KEY, title TEXT NOT NULL, notes TEXT, status INTEGER,
              stopDate REAL, deadline INTEGER, startDate INTEGER, creationDate REAL,
              userModificationDate REAL, project TEXT, heading TEXT, area TEXT,
              trashed INTEGER, type INTEGER, start INTEGER, todayIndex INTEGER,
              deadlineSuppressionDate INTEGER, rt1_recurrenceRule TEXT, "index" INTEGER
            )
            """)
            try db.execute(sql: "CREATE TABLE TMTag (uuid TEXT, title TEXT)")
            try db.execute(sql: "CREATE TABLE TMTaskTag (tasks TEXT, tags TEXT)")
            try db.execute(sql: "CREATE TABLE TMChecklistItem (uuid TEXT, title TEXT, status INTEGER, task TEXT, \"index\" INTEGER)")
            for index in 0 ... 600 {
                let id = index == 0 ? "old-match" : "completed-\(index)"
                try db.execute(sql: """
                INSERT INTO TMTask (uuid, title, status, stopDate, creationDate, userModificationDate, trashed, type, start, "index")
                VALUES (?, ?, 3, ?, ?, ?, 0, 0, 1, ?)
                """, arguments: [id, id, index, index, index, index])
            }
            try db.execute(sql: """
            INSERT INTO TMTask (uuid, title, status, stopDate, creationDate, userModificationDate, trashed, type, start, "index")
            VALUES ('canceled-match', 'Canceled Match', 2, 999999, 999999, 999999, 0, 0, 1, 999999)
            """)
        }
        let database = ThingsDatabase(dbPath: path.path)
        let standalone = try database.fetchList(.logbook)
        #expect(standalone.count == 500)
        #expect(standalone.allSatisfy { $0.status == .completed })
        let client = HybridThingsClient(databasePath: path.path)
        try await CommandTestSupport.withRuntime(client: client) {
            let canceled = try FilterCommand.parse(["status = canceled", "--include-logbook", "--sort", "name", "--limit", "1", "--json"])
            let (_, canceledOutput) = try await CommandTestSupport.captureStandardOutput { try await canceled.run() }
            #expect(canceledOutput.contains("canceled-match"))
            let old = try FilterCommand.parse(["id = 'old-match'", "--list", "logbook", "--sort", "created", "--limit", "1", "--json"])
            let (_, oldOutput) = try await CommandTestSupport.captureStandardOutput { try await old.run() }
            #expect(oldOutput.contains("old-match"))
            let oldest = try FilterCommand.parse(["status != open", "--list", "logbook", "--sort", "created", "--limit", "1", "--json"])
            let (_, oldestOutput) = try await CommandTestSupport.captureStandardOutput { try await oldest.run() }
            #expect(oldestOutput.contains("old-match"))
            let query = try FilterCommand.parse(["status != open", "--list", "logbook"])
            #expect(try await query.queryOptions.fetch(client: client).count == 602)
        }
    }
}
