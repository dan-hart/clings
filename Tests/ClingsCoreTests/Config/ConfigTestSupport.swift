// ConfigTestSupport.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Darwin

enum ConfigTestSupport {
    private static let semaphoreName = "/clings-tests-config-dir-lock"

    private static func withConfigLock<T>(_ body: () throws -> T) rethrows -> T {
        let semaphore = sem_open(semaphoreName, O_CREAT, S_IRUSR | S_IWUSR, 1)
        precondition(semaphore != SEM_FAILED, "Failed to create shared config semaphore")
        defer { sem_close(semaphore) }

        sem_wait(semaphore)
        defer { sem_post(semaphore) }

        return try body()
    }

    static func withTemporaryConfigDirectory(_ body: (URL) throws -> Void) throws {
        try withConfigLock {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("clings-config-\(UUID().uuidString)")
            setenv("CLINGS_CONFIG_DIR", root.path, 1)
            defer {
                unsetenv("CLINGS_CONFIG_DIR")
                try? FileManager.default.removeItem(at: root)
            }

            try body(root)
        }
    }
}
