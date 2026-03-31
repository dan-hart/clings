// CommandRuntime.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ClingsCore
import Foundation

enum CommandRuntime {
    @TaskLocal static var makeClient: @Sendable () -> any ThingsClientProtocol = {
        ThingsClientFactory.create()
    }

    @TaskLocal static var makeDatabase: @Sendable () throws -> any ThingsDatabaseReadable = {
        try ThingsDatabase()
    }

    @TaskLocal static var inputReader: @Sendable () -> String? = {
        Swift.readLine()
    }

    @TaskLocal static var openURLScheme: @Sendable (String) throws -> Void = { urlString in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [urlString]
        do {
            try process.run()
        } catch {
            throw ThingsError.operationFailed("Failed to launch Things URL scheme handler: \(error.localizedDescription)")
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ThingsError.operationFailed("Failed to update via Things URL scheme (exit code \(process.terminationStatus))")
        }
    }
}
