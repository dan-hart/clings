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
    private static func tokenPath() throws -> URL {
        try ClingsConfig.fileURL(named: "auth-token")
    }

    @Suite("saveToken validation")
    struct SaveTokenValidation {
        @Test func rejectsEmptyToken() {
            try? ConfigTestSupport.withTemporaryConfigDirectory { _ in
                #expect(throws: (any Error).self) {
                    try AuthTokenStore.saveToken("")
                }
            }
        }

        @Test func rejectsWhitespaceOnlyToken() {
            try? ConfigTestSupport.withTemporaryConfigDirectory { _ in
                #expect(throws: (any Error).self) {
                    try AuthTokenStore.saveToken("   \n\t  ")
                }
            }
        }
    }

    @Suite("saveToken and loadToken round-trip", .serialized)
    struct RoundTrip {
        @Test func savesAndLoadsToken() throws {
            try ConfigTestSupport.withTemporaryConfigDirectory { _ in
                let testToken = "test-token-\(UUID().uuidString)"
                try AuthTokenStore.saveToken(testToken)
                let loaded = try AuthTokenStore.loadToken()
                #expect(loaded == testToken)
            }
        }

        @Test func trimsWhitespace() throws {
            try ConfigTestSupport.withTemporaryConfigDirectory { _ in
                let core = "trimmed-token-\(UUID().uuidString)"
                let testToken = "  \(core)  \n"
                try AuthTokenStore.saveToken(testToken)
                let loaded = try AuthTokenStore.loadToken()
                #expect(loaded == core)
            }
        }

        @Test func setsRestrictedPermissions() throws {
            try ConfigTestSupport.withTemporaryConfigDirectory { _ in
                try AuthTokenStore.saveToken("perm-test-\(UUID().uuidString)")
                let attrs = try FileManager.default.attributesOfItem(atPath: AuthTokenStoreTests.tokenPath().path)
                let perms = (attrs[.posixPermissions] as? Int) ?? 0
                #expect(perms == 0o600)
            }
        }

        @Test func overwritesPreviousToken() throws {
            try ConfigTestSupport.withTemporaryConfigDirectory { _ in
                let first = "first-\(UUID().uuidString)"
                let second = "second-\(UUID().uuidString)"
                try AuthTokenStore.saveToken(first)
                try AuthTokenStore.saveToken(second)
                let loaded = try AuthTokenStore.loadToken()
                #expect(loaded == second)
            }
        }
    }

    @Suite("loadToken errors")
    struct LoadTokenErrors {
        @Test func throwsWhenTokenFileIsEmpty() throws {
            try ConfigTestSupport.withTemporaryConfigDirectory { _ in
                // Write an empty file (bypassing saveToken which rejects empty)
                try Data().write(to: try AuthTokenStoreTests.tokenPath())
                #expect(throws: (any Error).self) {
                    _ = try AuthTokenStore.loadToken()
                }
            }
        }
    }
}
