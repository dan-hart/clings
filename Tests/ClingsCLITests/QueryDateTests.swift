import ArgumentParser
@testable import ClingsCLI
import ClingsCore
import Foundation
import Testing

struct QueryDateTests {
    @Test func invalidTimesAcrossSchedulingStemsRejectBeforeWrites() async throws {
        let client = RecordingThingsClient()
        let stems = ["next friday", "tomorrow", "in 2 days", "on friday", "2027-01-15", "dec 15", "this evening", "tomorrow morning"]
        try await CommandTestSupport.withRuntime(client: client) {
            for stem in stems {
                for suffix in [" 13pm", " 999pm", " 25:00", "999pm"] {
                    for prefix in ["", "by "] {
                        let command = try AddCommand.parse(["Task \(prefix)\(stem)\(suffix)", "--parse-only", "--json"])
                        await #expect(throws: (any Error).self) { try await command.run() }
                    }
                }
            }
        }
        #expect(client.createdTodos.isEmpty)
    }

    @Test func templateRetainsEmbeddedRelativeDateExpressions() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let save = try TemplateSaveCommand.parse(["relative", "Task tomorrow by friday"])
            _ = try CommandTestSupport.captureStandardOutput { try save.run() }
            let saved = try #require(try TemplateStore.load(name: "relative"))
            #expect(saved.title == "Task")
            #expect(saved.whenExpression == "tomorrow")
            #expect(saved.deadlineExpression == "friday")
            let parser = NaturalLanguageDateParser()
            let reference = try #require(parser.parse("2027-01-01"))
            #expect(try parser.parse(#require(saved.whenExpression), referenceDate: reference) == parser.parse("2027-01-02"))
        }
    }

    @Test func queryScopesAndDeterministicOrdering() async throws {
        let client = RecordingThingsClient()
        let a = Todo(id: "a", name: "alpha")
        let b = Todo(id: "b", name: "ALPHA")
        let historic = Todo(id: "h", name: "History", status: .completed)
        client.todosForList[.today] = [b, a, a]
        client.todosForList[.logbook] = [historic]
        client.searchResults = [historic, b, a, a]
        try await CommandTestSupport.withRuntime(client: client) {
            let search = try SearchCommand.parse(["a", "--json"])
            let (_, normal) = try await CommandTestSupport.captureStandardOutput { try await search.run() }
            #expect(normal.contains("History"))
            let scoped = try SearchCommand.parse(["a", "--list", "today", "--sort", "name", "--limit", "1", "--json"])
            let (_, scopedOutput) = try await CommandTestSupport.captureStandardOutput { try await scoped.run() }
            #expect(scopedOutput.contains("\"id\" : \"a\""))
            #expect(!scopedOutput.contains("History"))
            let filtered = try FilterCommand.parse(["status = completed", "--include-logbook", "--json"])
            let (_, filteredOutput) = try await CommandTestSupport.captureStandardOutput { try await filtered.run() }
            #expect(filteredOutput.contains("History"))
        }
    }

    @Test func invalidTemplateDatesAreRejectedOnSaveAndRun() async throws {
        let client = RecordingThingsClient()
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            let save = try TemplateSaveCommand.parse(["bad", "Task", "--when", "nonsense"])
            #expect(throws: (any Error).self) { try save.run() }
            #expect(try TemplateStore.load(name: "bad") == nil)
            try TemplateStore.save(TaskTemplate(name: "legacy", title: "Task", whenExpression: "2027-02-30"))
            try await CommandTestSupport.withRuntime(client: client) {
                let run = try TemplateRunCommand.parse(["legacy"])
                await #expect(throws: (any Error).self) { try await run.run() }
            }
        }
        #expect(client.createdTodos.isEmpty)
    }

    @Test func invalidUpdateDatesRejectBeforeMutating() async throws {
        let client = RecordingThingsClient()
        try await CommandTestSupport.withRuntime(client: client) {
            let update = try UpdateCommand.parse(["a", "--name", "Changed", "--due", "2027-02-30"])
            await #expect(throws: (any Error).self) { try await update.run() }
        }
        #expect(client.updatedTodos.isEmpty)
    }

    @Test func queryOptionsValidateAndSort() throws {
        #expect(throws: (any Error).self) { try SearchCommand.parse(["x", "--limit", "0"]) }
        #expect(throws: (any Error).self) { try FilterCommand.parse(["status = open", "--sort", "bad"]) }
        let command = try SearchCommand.parse(["x", "--sort", "-due", "--limit", "2"])
        let todos = [Todo(id: "z", name: "Null"), Todo(id: "b", name: "B", dueDate: Date(timeIntervalSince1970: 2)), Todo(id: "a", name: "A", dueDate: Date(timeIntervalSince1970: 2))]
        #expect(command.queryOptions.apply(todos).map(\.id) == ["a", "b"])
    }

    @Test func invalidAddDateDoesNotWrite() async throws {
        let client = RecordingThingsClient()
        try await CommandTestSupport.withRuntime(client: client) {
            for args in [["Task", "--when", "2027-02-30"], ["Task tomorrow 13pm"], ["Task by tomorrow 13pm", "--parse-only", "--json"], ["Task tomorrow 25:00"], ["Task dec 15 25:00"], ["Task by 2027-02-30"], ["Task", "--deadline", "today 9:99"]] {
                let command = try AddCommand.parse(args)
                await #expect(throws: (any Error).self) { try await command.run() }
            }
        }
        #expect(client.createdTodos.isEmpty)
    }

    @Test func updatePreviewNeedsNoTokenAndDoesNotWrite() async throws {
        let client = RecordingThingsClient()
        client.todosByID["a"] = Todo(id: "a", name: "Old", notes: "Keep")
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try await CommandTestSupport.withRuntime(client: client) {
                let command = try UpdateCommand.parse(["a", "--name", "New", "--when", "tomorrow", "--parse-only", "--json"])
                let (_, output) = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                #expect(output.contains("New"))
                #expect(output.contains("Keep"))
                #expect(output.contains("undo"))
            }
        }
        #expect(client.updatedTodos.isEmpty)
    }
}
