// AuthTokenStore.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Manages the Things 3 auth token used for URL scheme operations (e.g., heading updates).
public enum AuthTokenStore {
    private static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("clings")
    }

    private static var tokenFile: URL {
        configDir.appendingPathComponent("auth-token")
    }

    /// Load the stored auth token.
    public static func loadToken() throws -> String {
        let token = try String(contentsOf: tokenFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw ThingsError.invalidState("Auth token file is empty")
        }
        return token
    }

    /// Save an auth token to the config directory with restricted permissions (0600).
    /// Uses POSIX open() to ensure the file is never world-readable, even briefly.
    public static func saveToken(_ token: String) throws {
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        } catch {
            throw ThingsError.operationFailed(
                "Failed to create config directory at \(configDir.path): \(error.localizedDescription)"
            )
        }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ThingsError.invalidState("Auth token cannot be empty")
        }
        let tokenData = Data(trimmed.utf8)
        let path = tokenFile.path
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
        guard fd >= 0 else {
            let reason = String(cString: strerror(errno))
            throw ThingsError.operationFailed("Failed to open auth token file at \(path): \(reason)")
        }
        defer { close(fd) }
        // Enforce 0600 even on pre-existing files (open mode only applies on creation)
        guard fchmod(fd, 0o600) == 0 else {
            let reason = String(cString: strerror(errno))
            throw ThingsError.operationFailed("Failed to set permissions on auth token file at \(path): \(reason)")
        }
        let written = tokenData.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return -1 }
            return write(fd, base, buffer.count)
        }
        let writeErrno = errno // Capture before defer's close() can clobber it
        guard written == tokenData.count else {
            if written < 0 {
                let reason = String(cString: strerror(writeErrno))
                throw ThingsError.operationFailed("Failed to write auth token to \(path): \(reason)")
            } else {
                throw ThingsError.operationFailed(
                    "Failed to write auth token to \(path): short write (\(written) of \(tokenData.count) bytes)"
                )
            }
        }
    }
}
