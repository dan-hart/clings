import ArgumentParser
@testable import ClingsCLI
@testable import ClingsCore
import Foundation
import Testing

@Suite("Machine interface contracts", .serialized)
struct MachineInterfaceTests {
    func object(_ text: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    @Test func previewUsesVersionedEnvelope() async throws {
        let command = try AddCommand.parse(["Draft guide tomorrow #docs", "--parse-only", "--json"])
        let (_, text) = try await CommandTestSupport.captureStandardOutput { try await command.run() }
        let response = try object(text)
        #expect(response["schemaVersion"] as? Int == 1)
        #expect(response["success"] as? Bool == true)
        #expect((response["data"] as? [String: Any])?["title"] as? String == "Draft guide")
    }

    @Test func emptyReviewStatusIsJSON() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            let command = try ReviewStatusCommand.parse(["--json"])
            let (_, text) = try await CommandTestSupport.captureStandardOutput { try await command.run() }
            let response = try object(text)
            #expect(response["schemaVersion"] as? Int == 1)
            #expect(response["data"] is NSNull)
            #expect(!FileManager.default.fileExists(atPath: directory.path))
        }
    }

    @Test func ambiguousTitleFailsWithoutWriting() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let client = RecordingThingsClient()
            client.searchResults = [Todo(id: "one", name: "Milk"), Todo(id: "two", name: "Milk too")]
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try CompleteCommand.parse(["--title", "Milk", "--json"])
                var failure: CommandFailure?
                let (_, text) = try await CommandTestSupport.captureStandardOutput {
                    do { try await command.run() } catch let error as CommandFailure { failure = error }
                }
                #expect(text.isEmpty)
                #expect(failure?.exitStatus == 1)
                #expect(failure?.code == "ambiguous_title")
                #expect(failure?.dataJSON?.contains("one") == true)
                #expect(client.completedIDs.isEmpty)
            }
        }
    }

    @Test func noninteractiveTagDeleteRefusesWithoutTextPollution() async throws {
        let client = RecordingThingsClient()
        try await CommandTestSupport.withRuntime(client: client, terminal: false) {
            let command = try TagsDeleteCommand.parse(["docs", "--json"])
            var failure: CommandFailure?
            let (_, text) = try await CommandTestSupport.captureStandardOutput {
                do { try await command.run() } catch let error as CommandFailure { failure = error }
            }
            #expect(text.isEmpty)
            #expect(failure?.exitStatus == 1)
            #expect(client.deletedTags.isEmpty)
        }
    }

    @Test func corruptReviewSessionIsNotReportedAsMissing() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("broken".utf8).write(to: directory.appendingPathComponent("review-session.json"))
            var failed = false
            _ = try await CommandTestSupport.captureStandardOutput {
                do { try await ReviewStatusCommand.parse(["--json"]).run() } catch { failed = true }
            }
            #expect(failed)
        }
    }

    @Test func successfulPublicJSONPathsHaveOneEnvelope() async throws {
        let paths: [[String]] = [
            [], ["today"], ["t"], ["inbox"], ["i"], ["upcoming"], ["u"],
            ["anytime"], ["someday"], ["s"], ["logbook"], ["l"], ["projects"], ["areas"],
            ["project"], ["project", "list"], ["project", "ls"], ["project", "audit"], ["project", "add", "Project"],
            ["tags"], ["tags", "list"], ["tags", "ls"], ["tags", "add", "docs"],
            ["tags", "delete", "docs", "--force"], ["tags", "rename", "docs", "documentation"],
            ["show", "one"], ["add", "Draft guide", "--parse-only"], ["add", "Draft guide"],
            ["complete", "one"], ["done", "one"], ["complete", "--title", "Draft"],
            ["cancel", "one"], ["delete", "one", "--force"], ["rm", "one", "--force"],
            ["update", "one", "--name", "Updated"], ["update", "one", "--name", "Updated", "--parse-only"],
            ["search", "Draft"], ["find", "Draft"], ["f", "Draft"], ["filter", "name CONTAINS 'Draft'"], ["focus"],
            ["views"], ["views", "list"], ["views", "ls"], ["views", "save", "new-view", "status == open"],
            ["views", "run", "docs"], ["views", "delete", "docs"],
            ["template"], ["template", "list"], ["template", "ls"], ["template", "save", "new-template", "Draft"],
            ["template", "run", "docs"], ["template", "delete", "docs"], ["undo", "--show"], ["undo"],
            ["bulk", "complete", "--dry-run"], ["bulk", "cancel", "--dry-run"],
            ["bulk", "tag", "docs", "--dry-run"], ["bulk", "move", "--to", "Release", "--dry-run"],
            ["bulk", "complete", "--yes"], ["bulk", "cancel", "--yes"],
            ["bulk", "tag", "docs", "--yes"], ["bulk", "move", "--to", "Release", "--yes"],
            ["stats"], ["stats", "trends"], ["stats", "heatmap"],
            ["review"], ["review", "start"], ["review", "status"], ["review", "clear"],
            ["doctor"], ["config", "set-auth-token", "private-token"],
        ]
        for path in paths {
            try await CommandTestSupport.withTemporaryConfigDirectory { _ in
                try SavedViewStore.save(SavedView(name: "docs", expression: "name CONTAINS 'Draft'"))
                try TemplateStore.save(TaskTemplate(name: "docs", title: "Draft guide"))
                let todo = CommandFixtures.todo(id: "one", name: "Draft guide")
                let client = RecordingThingsClient()
                client.todosByID = [todo.id: todo]
                client.todosForList = [.today: [todo]]
                client.searchResults = [todo]
                client.projects = [CommandFixtures.releaseProject]
                let db = MockThingsDatabase(lists: [.today: [todo]], projects: client.projects, todosByID: [todo.id: todo], searchResults: [todo])
                try await CommandTestSupport.withRuntime(client: client, database: db, terminal: false) {
                    let (status, text) = try await CommandTestSupport.captureStandardOutput { await CommandBoundary.execute(path + ["--json"]) }
                    #expect(status == 0, "Path: \(path)")
                    let response = try object(text)
                    #expect(response["schemaVersion"] as? Int == 1, "Path: \(path)")
                    #expect(response["success"] as? Bool == true, "Path: \(path)")
                    #expect(response["data"] != nil, "Path: \(path)")
                    #expect(!text.contains("private-token"))
                }
            }
        }
    }

    @Test func inputErrorsAreJSONWithExitOne() async throws {
        let paths: [[String]] = [
            ["unknown"], ["add"], ["today", "--unknown"], ["today", "--limit", "0"],
            ["add", "Task", "--parse-only", "--when", "2026-02-30"],
            ["add", "Task next friday 13pm", "--parse-only"], ["filter", "broken !"],
            ["views", "run", "missing"], ["template", "run", "missing"], ["show", "missing"],
            ["pick"], ["pick", "complete"], ["tags", "delete", "docs"], ["tags", "add", " "],
        ]
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try await CommandTestSupport.withRuntime(client: RecordingThingsClient(), database: MockThingsDatabase(), terminal: false) {
                for path in paths {
                    let (status, text) = try await CommandTestSupport.captureStandardOutput { await CommandBoundary.execute(path + ["--json"]) }
                    #expect(status == 1, "Path: \(path)")
                    let response = try object(text)
                    #expect(response["schemaVersion"] as? Int == 1)
                    #expect(response["success"] as? Bool == false)
                    #expect(response["error"] is [String: Any])
                }
            }
        }
    }

    @Test func runtimeErrorsAndPartialResultsAreRetained() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let client = RecordingThingsClient()
            client.error = ThingsError.operationFailed("Automation unavailable")
            try await CommandTestSupport.withRuntime(client: client) {
                let (status, text) = try await CommandTestSupport.captureStandardOutput { await CommandBoundary.execute(["search", "Draft", "--json"]) }
                #expect(status == 2)
                #expect(try object(text)["success"] as? Bool == false)
            }
            let raw = "{\"applied\":true,\"referenceSeconds\":12345.123456789}"
            let failure = CommandFailure(exitStatus: 2, code: "partial", message: "Failure \"quoted\"\nnext line", dataJSON: raw)
            let text = CLIResponse.failure(failure)
            #expect(text.contains(raw))
            let response = try object(text)
            #expect((response["data"] as? [String: Any])?["applied"] as? Bool == true)
            #expect((response["error"] as? [String: Any])?["message"] as? String == failure.message)
        }
    }

    @Test func nativeHelpVersionMetadataAndCompletionsStayText() async throws {
        for path in [["today", "--help", "--json"], ["--version"], ["--experimental-dump-help"], ["completions", "bash"], ["help", "today"]] {
            let (status, text) = try await CommandTestSupport.captureStandardOutput { await CommandBoundary.execute(path) }
            #expect(status == 0)
            #expect(!text.contains("\"success\""))
            #expect(!text.isEmpty)
        }
        #expect(!CommandBoundary.wantsJSON(["add", "--", "--json"]))
        #expect(CommandBoundary.wantsJSON(["add", "--json", "--", "Task"]))
        #expect(CommandBoundary.classify(ValidationError("bad")).exitStatus == 1)
        #expect(CommandBoundary.classify(ThingsError.notFound("missing")).exitStatus == 1)
        #expect(CommandBoundary.classify(ThingsError.jxaError(.thingsNotRunning)).exitStatus == 2)
        #expect(CommandBoundary.classify(NSError(domain: "filesystem", code: 1)).exitStatus == 2)
    }

    @Test func numericValidationRejectsEmptyReportsInsteadOfSuccess() async throws {
        try await CommandTestSupport.withRuntime(client: RecordingThingsClient(), database: MockThingsDatabase()) {
            for path in [["focus", "--limit", "0"], ["focus", "--limit", "-1"], ["stats", "--days", "0"], ["stats", "--days", String(Int.max)], ["stats", "trends", "--weeks", "0"], ["stats", "heatmap", "--weeks", "0"], ["stats", "trends", "--weeks", String(Int.max)], ["stats", "heatmap", "--weeks", "-1"]] {
                let (status, text) = try await CommandTestSupport.captureStandardOutput { await CommandBoundary.execute(path + ["--json"]) }
                #expect(status == 1)
                #expect(try object(text)["success"] as? Bool == false)
            }
        }
    }

    @Test func appliedMutationFallbackNeverLosesRealIDOrClaimsUndo() throws {
        let error = AppliedMutationError(id: "created-project", fields: ["create", "deadline"], message: "Later tag assignment failed")
        let failure = CommandBoundary.classify(error)
        #expect(failure.exitStatus == 2)
        #expect(failure.code == "mutation_partial")
        let response = try object(CLIResponse.failure(failure))
        let data = try #require(response["data"] as? [String: Any])
        #expect(data["id"] as? String == "created-project")
        #expect(data["applied"] as? Bool == true)
        #expect(data["undoRecorded"] as? Bool == false)
        #expect(data["appliedFields"] as? [String] == ["create", "deadline"])
        #expect(!(data["unsupportedUndo"] as? [String] ?? []).isEmpty)
    }

    @Test func humanErrorsUseStderrAndKeepMeaningfulExit() async throws {
        let (status, text) = try await CommandTestSupport.captureStandardError { await CommandBoundary.execute(["unknown"]) }
        #expect(status == 1)
        #expect(text.contains("Error:"))
    }

    @Test func reviewSaveAndDoctorHealthFailuresRetainJSONData() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            try Data("not a config directory".utf8).write(to: directory)
            try await CommandTestSupport.withRuntime(database: MockThingsDatabase()) {
                let (status, text) = try await CommandTestSupport.captureStandardOutput { await CommandBoundary.execute(["review", "start", "--json"]) }
                #expect(status == 2)
                let response = try object(text)
                #expect((response["error"] as? [String: Any])?["code"] as? String == "review_storage_failed")
                #expect((response["data"] as? [String: Any])?["sessionSaved"] as? Bool == false)
                let (doctorStatus, doctorText) = try await CommandTestSupport.captureStandardOutput { await CommandBoundary.execute(["doctor", "--json"]) }
                #expect(doctorStatus == 2)
                #expect((try object(doctorText)["data"] as? [String: Any])?["checks"] is [Any])
            }
        }
    }
}
