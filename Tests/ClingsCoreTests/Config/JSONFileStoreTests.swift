// JSONFileStoreTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("JSONFileStore", .serialized)
struct JSONFileStoreTests {
    struct Fixture: Codable, Equatable {
        var name: String
        var count: Int
    }

    @Test func usesEnvironmentOverrideForConfigDirectory() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { root in
            #expect(ClingsConfig.directoryURL.standardizedFileURL.path == root.standardizedFileURL.path)
            let ensured = try ClingsConfig.ensureDirectory()
            #expect(ensured.standardizedFileURL.path == root.standardizedFileURL.path)
            #expect(FileManager.default.fileExists(atPath: root.path))
        }
    }

    @Test func savesAndLoadsCodableValues() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { _ in
            let fixture = Fixture(name: "views", count: 3)
            try JSONFileStore.save(fixture, to: "fixture.json")

            let loaded = try JSONFileStore.load(Fixture.self, from: "fixture.json", default: Fixture(name: "default", count: 0))
            #expect(loaded == fixture)
        }
    }

    @Test func returnsDefaultWhenFileIsMissing() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { _ in
            let loaded = try JSONFileStore.load(Fixture.self, from: "missing.json", default: Fixture(name: "fallback", count: 9))
            #expect(loaded == Fixture(name: "fallback", count: 9))
        }
    }
}
