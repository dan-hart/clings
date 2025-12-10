// JXABridge.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Errors that can occur during JXA script execution.
public enum JXAError: Error, LocalizedError {
    case executionFailed(String)
    case timeout
    case invalidJSON(String)
    case thingsNotRunning
    case scriptError(String)
    case processError(Int32, String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let msg):
            return "JXA execution failed: \(msg)"
        case .timeout:
            return "JXA script timed out"
        case .invalidJSON(let msg):
            return "Invalid JSON response: \(msg)"
        case .thingsNotRunning:
            return "Things 3 is not running. Please launch Things 3 and try again."
        case .scriptError(let msg):
            return "Script error: \(msg)"
        case .processError(let code, let msg):
            return "Process exited with code \(code): \(msg)"
        }
    }
}

/// Bridge for executing JavaScript for Automation (JXA) scripts against Things 3.
///
/// This actor provides safe, concurrent access to osascript execution with
/// timeout handling and proper error reporting.
public actor JXABridge {
    /// Default timeout for script execution in seconds.
    public static let defaultTimeout: TimeInterval = 30.0

    private let timeout: TimeInterval

    /// Create a new JXA bridge with the specified timeout.
    /// - Parameter timeout: Maximum time to wait for script execution.
    public init(timeout: TimeInterval = JXABridge.defaultTimeout) {
        self.timeout = timeout
    }

    /// Execute a JXA script and return the raw output.
    /// - Parameter script: The JavaScript code to execute.
    /// - Returns: The script's stdout output as a string.
    /// - Throws: `JXAError` if execution fails.
    public func execute(_ script: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withThrowingTaskGroup(of: String.self) { group in
            // Task to run the process
            group.addTask {
                do {
                    try process.run()
                } catch {
                    throw JXAError.executionFailed(error.localizedDescription)
                }

                process.waitUntilExit()

                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

                let outputString = String(data: outputData, encoding: .utf8) ?? ""
                let errorString = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    // Check for common errors
                    if errorString.contains("not running") || errorString.contains("Connection is invalid") {
                        throw JXAError.thingsNotRunning
                    }
                    throw JXAError.processError(process.terminationStatus, errorString)
                }

                return outputString.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Task for timeout
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeout))
                process.terminate()
                throw JXAError.timeout
            }

            // Return first completed result (either success or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Execute a JXA script and decode the JSON output to a specific type.
    /// - Parameters:
    ///   - script: The JavaScript code to execute.
    ///   - type: The type to decode the JSON into.
    /// - Returns: The decoded value.
    /// - Throws: `JXAError` if execution or decoding fails.
    public func executeJSON<T: Decodable>(_ script: String, as type: T.Type) async throws -> T {
        let output = try await execute(script)

        guard !output.isEmpty else {
            throw JXAError.invalidJSON("Empty response")
        }

        guard let data = output.data(using: .utf8) else {
            throw JXAError.invalidJSON("Could not convert output to UTF-8 data")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 first
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }

            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try simple date format
            let simpleFormatter = DateFormatter()
            simpleFormatter.dateFormat = "yyyy-MM-dd"
            if let date = simpleFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw JXAError.invalidJSON("Decoding error: \(error.localizedDescription)\nRaw output: \(output.prefix(500))")
        }
    }

    /// Check if Things 3 is running.
    /// - Returns: `true` if Things 3 is running.
    public func isThingsRunning() async -> Bool {
        let script = """
        (() => {
            const app = Application('Things3');
            return app.running();
        })()
        """

        do {
            let output = try await execute(script)
            return output.lowercased() == "true"
        } catch {
            return false
        }
    }
}
