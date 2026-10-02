// AutomationProcess.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation

/// One-shot subprocess lifetime and pipe reads outside Swift's cooperative executor.
/// All mutable lifecycle state is protected by `lock`; only one result is delivered.
internal final class AutomationProcess: @unchecked Sendable {
    private let lock = NSLock()
    private let process = Process()
    private let stdout = Pipe()
    private let stderr = Pipe()
    private let deadline: DispatchTime
    private var continuation: CheckedContinuation<String, any Error>?
    private var result: Result<String, any Error>?

    init(arguments: [String], timeout: TimeInterval, executableURL: URL = URL(fileURLWithPath: "/usr/bin/osascript")) {
        deadline = .now() + max(0, timeout)
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
    }

    func run() async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                let existingResult = result
                if existingResult == nil { self.continuation = continuation }
                lock.unlock()
                if let existingResult {
                    continuation.resume(with: existingResult)
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async { self.launchAndWait() }
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: deadline) { [weak self] in
                    self?.finish(.failure(JXAError.timeout), stopProcess: true)
                }
            }
        } onCancel: {
            self.finish(.failure(CancellationError()), stopProcess: true)
        }
    }

    private func launchAndWait() {
        // Serialize launch against cancellation: a cancelled queued operation never starts.
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        guard DispatchTime.now() < deadline else {
            lock.unlock()
            finish(.failure(JXAError.timeout), stopProcess: false)
            return
        }
        do {
            try process.run()
        } catch {
            lock.unlock()
            finish(.failure(JXAError.executionFailed(error.localizedDescription)), stopProcess: false)
            return
        }
        lock.unlock()

        let output = PipeRead(stdout.fileHandleForReading)
        let errors = PipeRead(stderr.fileHandleForReading)
        output.start()
        errors.start()
        process.waitUntilExit() // Dispatch worker, never a cooperative Swift task.
        let outputString = String(data: output.value(), encoding: .utf8) ?? ""
        let errorString = String(data: errors.value(), encoding: .utf8) ?? ""
        // A delayed timer cannot turn an overdue process into success.
        if DispatchTime.now() >= deadline {
            finish(.failure(JXAError.timeout), stopProcess: false)
        } else if process.terminationStatus != 0 {
            let error: JXAError = errorString.contains("not running") || errorString.contains("Connection is invalid")
                ? .thingsNotRunning : .processError(process.terminationStatus, errorString)
            finish(.failure(error), stopProcess: false)
        } else {
            finish(.success(outputString.trimmingCharacters(in: .whitespacesAndNewlines)), stopProcess: false)
        }
    }

    private func finish(_ result: Result<String, any Error>, stopProcess: Bool) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        if stopProcess, process.isRunning {
            // SIGKILL bounds cleanup even if an automation script ignores SIGTERM.
            kill(process.processIdentifier, SIGKILL)
        }
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

/// Each pipe must be drained concurrently: either one can exceed kernel capacity.
private final class PipeRead: @unchecked Sendable {
    private let handle: FileHandle
    private let group = DispatchGroup()
    private var data = Data()

    init(_ handle: FileHandle) { self.handle = handle }

    func start() {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.data = self.handle.readDataToEndOfFile()
            try? self.handle.close()
            self.group.leave()
        }
    }

    func value() -> Data {
        group.wait()
        return data
    }
}
