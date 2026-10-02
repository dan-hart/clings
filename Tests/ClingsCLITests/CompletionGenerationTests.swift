import ArgumentParser
@testable import ClingsCLI
import Testing

@Suite("Generated shell completions")
struct CompletionGenerationTests {
    @Test func scriptsUseTheCommandTree() throws {
        for shell in CompletionShell.allCases {
            let command = try CompletionsCommand.parse([shell.rawValue])
            let output = command.script
            #expect(output.trimmingCharacters(in: .newlines) == Clings.completionScript(for: shell).trimmingCharacters(in: .newlines))
            #expect(output.contains("include-logbook"))
            #expect(output.contains("sort"))
            #expect(output.contains("parse-only"))
            #expect(output.contains("audit"))
        }
    }
}
