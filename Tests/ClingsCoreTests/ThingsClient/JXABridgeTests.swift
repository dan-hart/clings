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
            const app = Application('Things3');
            return app.running();
        })()
        """)
        let isRunning = await bridge.isThingsRunning()

        #expect(isRunning == (expectedOutput.lowercased() == "true"))
    }
}
