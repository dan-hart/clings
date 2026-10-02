// JXABridgeTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("JXABridge", .serialized)
struct JXABridgeTests {
    private struct Payload: Decodable {
        let value: Int
        let date: Date
    }

    @Test func largeOutputIsDrainedBeforeProcessExit() async throws {
        let bridge = JXABridge(timeout: 2)
        let output = try await bridge.execute("'x'.repeat(512 * 1024)")
        #expect(output.count == 512 * 1024)
        let stderrOutput = try await bridge.execute("console.log('x'.repeat(512 * 1024)); 'done'")
        #expect(stderrOutput == "done")
    }

    @Test func cancellationStopsExecutionPromptly() async throws {
        let bridge = JXABridge(timeout: 10)
        let task = Task { try await bridge.execute("delay(2); 'done'") }
        try await Task.sleep(for: .milliseconds(100))
        let start = ContinuousClock.now
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation, not script success")
        } catch is CancellationError {
            #expect(start.duration(to: .now) < .seconds(1))
        }
    }

    @Test func alreadyCancelledOperationDoesNotExecute() async throws {
        let bridge = JXABridge(timeout: 10)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await bridge.execute("'must not execute'")
        }
        do {
            _ = try await task.value
            Issue.record("Expected cancellation before execution")
        } catch is CancellationError {}
    }

    @Test func simultaneousDeadlinesRemainIndependent() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    let bridge = JXABridge(timeout: 0.01)
                    do {
                        _ = try await bridge.execute("delay(0.2); 'overdue'")
                        Issue.record("Expected each concurrent script to time out")
                    } catch JXAError.timeout {}
                }
            }
            try await group.waitForAll()
        }
    }

    @Test func expiredDeadlineDoesNotLaunchQueuedWork() async throws {
        // A missing executable would produce executionFailed if launch were attempted.
        let runner = AutomationProcess(arguments: [], timeout: 0,
            executableURL: URL(fileURLWithPath: "/private/tmp/clings-missing-\(UUID().uuidString)"))
        do {
            _ = try await runner.run()
            Issue.record("Expected timeout before launch")
        } catch JXAError.timeout {}
    }

    @Test func launchFailureKeepsActionableErrorClassification() async throws {
        let runner = AutomationProcess(arguments: [], timeout: 1,
            executableURL: URL(fileURLWithPath: "/private/tmp/clings-missing-\(UUID().uuidString)"))
        do {
            _ = try await runner.run()
            Issue.record("Expected launch failure")
        } catch JXAError.executionFailed(let message) {
            #expect(!message.isEmpty)
        }
    }

    @Test func executeReturnsTrimmedOutput() async throws {
        let bridge = JXABridge(timeout: 1)
        let output = try await bridge.execute("(() => '  trimmed output  ')()")
        #expect(output == "trimmed output")
    }

    @Test func executeJSONDecodesMultipleDateFormats() async throws {
        let bridge = JXABridge(timeout: 1)

        let isoPayload = try await bridge.executeJSON(
            "JSON.stringify({ value: 1, date: '2024-12-25T00:00:00Z' })",
            as: Payload.self
        )
        let fractionalPayload = try await bridge.executeJSON(
            "JSON.stringify({ value: 2, date: '2024-12-25T00:00:00.123Z' })",
            as: Payload.self
        )
        let simplePayload = try await bridge.executeJSON(
            "JSON.stringify({ value: 3, date: '2024-12-25' })",
            as: Payload.self
        )

        #expect(isoPayload.value == 1)
        #expect(fractionalPayload.value == 2)
        #expect(simplePayload.value == 3)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: simplePayload.date)
        #expect(components.year == 2024)
        #expect(components.month == 12)
        #expect(components.day == 25)
    }

    @Test func executeJSONThrowsHelpfulInvalidJSONErrors() async throws {
        let bridge = JXABridge(timeout: 1)

        do {
            _ = try await bridge.executeJSON("\"\"", as: Payload.self)
            Issue.record("Expected empty JSON response to fail")
        } catch let error as JXAError {
            switch error {
            case .invalidJSON(let message):
                #expect(message.contains("Empty response"))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        do {
            _ = try await bridge.executeJSON("JSON.stringify({ value: 1, date: 'not-a-date' })", as: Payload.self)
            Issue.record("Expected bad date to fail")
        } catch let error as JXAError {
            switch error {
            case .invalidJSON(let message):
                #expect(message.contains("Decoding error"))
                #expect(message.contains("Raw output"))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func executeAndExecuteAppleScriptSurfaceProcessErrors() async throws {
        let bridge = JXABridge(timeout: 1)

        do {
            _ = try await bridge.execute("(() => { throw new Error('boom'); })()")
            Issue.record("Expected JXA process error")
        } catch let error as JXAError {
            switch error {
            case .processError(let code, let message):
                #expect(code != 0)
                #expect(message.contains("boom"))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        do {
            _ = try await bridge.executeAppleScript("error \"boom\"")
            Issue.record("Expected AppleScript process error")
        } catch let error as JXAError {
            switch error {
            case .processError(let code, let message):
                #expect(code != 0)
                #expect(message.contains("boom"))
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func executeAndAppleScriptHonorTimeouts() async throws {
        let bridge = JXABridge(timeout: 0.01)

        do {
            _ = try await bridge.execute("delay(0.2); 'done'")
            Issue.record("Expected JXA timeout")
        } catch let error as JXAError {
            switch error {
            case .timeout:
                #expect(error.localizedDescription == "JXA script timed out")
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        do {
            _ = try await bridge.executeAppleScript("delay 0.2\nreturn \"done\"")
            Issue.record("Expected AppleScript timeout")
        } catch let error as JXAError {
            switch error {
            case .timeout:
                #expect(error.localizedDescription == "JXA script timed out")
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func executeAppleScriptAndRunningCheckUseSystemOsaScript() async throws {
        let bridge = JXABridge(timeout: 1)
        let appleScriptOutput = try await bridge.executeAppleScript("return \"hello from applescript\"")
        #expect(appleScriptOutput == "hello from applescript")

        let expectedOutput = try await bridge.execute("""
        (() => {
            try {
                const app = Application('Things3');
                return app.running();
            } catch (error) {
                return '__missing__';
            }
        })()
        """)
        let isRunning = await bridge.isThingsRunning()

        if expectedOutput == "__missing__" {
            #expect(isRunning == false)
        } else {
            #expect(isRunning == (expectedOutput.lowercased() == "true"))
        }
    }
}
