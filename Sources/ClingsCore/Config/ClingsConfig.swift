// ClingsConfig.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Shared configuration paths and helpers for local clings state.
public enum ClingsConfig {
    private static let envKey = "CLINGS_CONFIG_DIR"

    public static var directoryURL: URL {
        if let rawValue = getenv(envKey) {
            let override = String(cString: rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
            if !override.isEmpty {
                return URL(fileURLWithPath: override, isDirectory: true)
            }
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("clings")
    }

    @discardableResult
    public static func ensureDirectory() throws -> URL {
        let url = directoryURL
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func fileURL(named fileName: String) throws -> URL {
        try ensureDirectory().appendingPathComponent(fileName)
    }
}
