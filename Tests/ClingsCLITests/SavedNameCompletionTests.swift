@testable import ClingsCLI
import ArgumentParser
import ClingsCore
import Foundation
import Testing

@Suite("Local saved-name completions", .serialized)
struct SavedNameCompletionTests {
    @Test func absentConfigIsNotCreated() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            #expect(SavedNameCompletion.views() == [])
            #expect(SavedNameCompletion.templates() == [])
            #expect(!FileManager.default.fileExists(atPath: directory.path))
        }
    }

    @Test func readsOnlyNamesAndSafelyHandlesCorruption() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            try SavedViewStore.save(SavedView(name: "docs queue", expression: "tags CONTAINS 'docs'"))
            try SavedViewStore.save(SavedView(name: "alpha", expression: "status = open"))
            try SavedViewStore.save(SavedView(name: "unsafe\nname", expression: "status = open"))
            try TemplateStore.save(TaskTemplate(name: "release prep", title: "Prepare release"))
            #expect(SavedNameCompletion.views() == ["alpha", "docs queue"])
            #expect(SavedNameCompletion.templates() == ["release prep"])
            try Data("invalid JSON".utf8).write(to: directory.appendingPathComponent("saved-views.json"))
            #expect(SavedNameCompletion.views() == [])
        }
    }

    @Test func generatedScriptsInvokeLocalCompletionCallbacks() {
        for shell in CompletionsCommand.Shell.allCases {
            let script = Clings.completionScript(for: shell.completionShell)
            #expect(script.contains("---completion"))
            #expect(script.contains("views"))
            #expect(script.contains("template"))
        }
    }

    @Test func parserCallbacksReturnSavedNamesForEveryAnnotatedArgument() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try SavedViewStore.save(SavedView(name: "docs queue", expression: "status = open"))
            try TemplateStore.save(TaskTemplate(name: "release prep", title: "Prepare release"))
            let cases: [([String], String, String)] = [
                (["views", "save"], "positional@0", "docs queue"),
                (["views", "run"], "positional@0", "docs queue"),
                (["views", "delete"], "positional@0", "docs queue"),
                (["template", "save"], "positional@0", "release prep"),
                (["template", "run"], "positional@0", "release prep"),
                (["template", "delete"], "positional@0", "release prep"),
                (["add"], "--template", "release prep"),
            ]
            for (path, argument, expected) in cases {
                do {
                    _ = try Clings.parseAsRoot(["---completion"] + path + ["--", argument, "0", "0", ""])
                    Issue.record("Custom completion did not return a native completion response")
                } catch {
                    #expect(Clings.exitCode(for: error).rawValue == 0)
                    #expect(Clings.fullMessage(for: error).contains(expected))
                }
            }
        }
    }

    @Test func bashCompletionPreservesSpacesWithoutExpandingSavedNames() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try SavedViewStore.save(SavedView(name: "docs queue", expression: "status = open"))
            try SavedViewStore.save(SavedView(name: "literal $(printf COMPLETION_EXECUTED) and spaces", expression: "status = open"))
            try SavedViewStore.save(SavedView(name: "literal `printf BACKTICK_EXECUTED`", expression: "status = open"))
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", #"IFS=$'\n'; compgen -W "$1" -- ''"#, "completion-test", SavedNameCompletion.views().joined(separator: "\n")]
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()
            process.waitUntilExit()
            let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            #expect(process.terminationStatus == 0)
            #expect(output.contains("docs queue"))
            #expect(!output.contains("COMPLETION_EXECUTED"))
            #expect(!output.contains("BACKTICK_EXECUTED"))
        }
    }
}
