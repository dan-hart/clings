// AuthTokenStoreTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

/// Tests for AuthTokenStore. All tests that mutate the token file
/// save and restore the original value to avoid clobbering real config.
@Suite("AuthTokenStore", .serialized)
struct AuthTokenStoreTests {

    private static let tokenPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/clings/auth-token")

    /// Read the current token file contents (raw bytes), or nil if missing.
    private static func backupToken() -> Data? {
        try? Data(contentsOf: tokenPath)
    }

    /// Restore the token file to its previous state.
    private static func restoreToken(_ backup: Data?) {
        if let backup = backup {
            try? backup.write(to: tokenPath)
            // Re-enforce 0600 permissions
            let fd = open(tokenPath.path, O_WRONLY, 0o600)
            if fd >= 0 {
                fchmod(fd, 0o600)
                close(fd)
            }
        } else {
            try? FileManager.default.removeItem(at: tokenPath)
        }
    }

    @Suite("saveToken validation")
    struct SaveTokenValidation {
        @Test func rejectsEmptyToken() {
            #expect(throws: (any Error).self) {
                try AuthTokenStore.saveToken("")
            }
        }

        @Test func rejectsWhitespaceOnlyToken() {
            #expect(throws: (any Error).self) {
                try AuthTokenStore.saveToken("   \n\t  ")
            }
        }
    }

    @Suite("saveToken and loadToken round-trip", .serialized)
    struct RoundTrip {
        @Test func savesAndLoadsToken() throws {
            let backup = AuthTokenStoreTests.backupToken()
            defer { AuthTokenStoreTests.restoreToken(backup) }

            let testToken = "test-token-\(UUID().uuidString)"
            try AuthTokenStore.saveToken(testToken)
            let loaded = try AuthTokenStore.loadToken()
            #expect(loaded == testToken)
        }

        @Test func trimsWhitespace() throws {
            let backup = AuthTokenStoreTests.backupToken()
            defer { AuthTokenStoreTests.restoreToken(backup) }

            let core = "trimmed-token-\(UUID().uuidString)"
            let testToken = "  \(core)  \n"
            try AuthTokenStore.saveToken(testToken)
            let loaded = try AuthTokenStore.loadToken()
            #expect(loaded == core)
        }

        @Test func setsRestrictedPermissions() throws {
            let backup = AuthTokenStoreTests.backupToken()
            defer { AuthTokenStoreTests.restoreToken(backup) }

            try AuthTokenStore.saveToken("perm-test-\(UUID().uuidString)")
            let attrs = try FileManager.default.attributesOfItem(atPath: AuthTokenStoreTests.tokenPath.path)
            let perms = (attrs[.posixPermissions] as? Int) ?? 0
            #expect(perms == 0o600)
        }

        @Test func overwritesPreviousToken() throws {
            let backup = AuthTokenStoreTests.backupToken()
            defer { AuthTokenStoreTests.restoreToken(backup) }

            let first = "first-\(UUID().uuidString)"
            let second = "second-\(UUID().uuidString)"
            try AuthTokenStore.saveToken(first)
            try AuthTokenStore.saveToken(second)
            let loaded = try AuthTokenStore.loadToken()
            #expect(loaded == second)
        }
    }

    @Suite("loadToken errors")
    struct LoadTokenErrors {
        @Test func throwsWhenTokenFileIsEmpty() throws {
            let backup = AuthTokenStoreTests.backupToken()
            defer { AuthTokenStoreTests.restoreToken(backup) }

            // Write an empty file (bypassing saveToken which rejects empty)
            try Data().write(to: AuthTokenStoreTests.tokenPath)
            #expect(throws: (any Error).self) {
                _ = try AuthTokenStore.loadToken()
            }
        }
    }
}
