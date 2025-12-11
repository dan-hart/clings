// HybridThingsClient.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation

/// Hybrid Things client that uses SQLite for fast reads and JXA/URL scheme for writes.
public final class HybridThingsClient: ThingsClientProtocol, @unchecked Sendable {
    private let database: ThingsDatabase
    private let jxaBridge: JXABridge

    public init() throws {
        self.database = try ThingsDatabase()
        self.jxaBridge = JXABridge()
    }

    // MARK: - Reads (via SQLite - fast)

    public func fetchList(_ list: ListView) async throws -> [Todo] {
        try database.fetchList(list)
    }

    public func fetchProjects() async throws -> [Project] {
        try database.fetchProjects()
    }

    public func fetchAreas() async throws -> [Area] {
        try database.fetchAreas()
    }

    public func fetchTags() async throws -> [Tag] {
        try database.fetchTags()
    }

    public func fetchTodo(id: String) async throws -> Todo {
        try database.fetchTodo(id: id)
    }

    public func search(query: String) async throws -> [Todo] {
        try database.search(query: query)
    }

    // MARK: - Writes (via JXA - safe)

    public func completeTodo(id: String) async throws {
        let script = JXAScripts.completeTodo(id: id)
        let result = try await jxaBridge.executeJSON(script, as: MutationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
    }

    public func cancelTodo(id: String) async throws {
        let script = JXAScripts.cancelTodo(id: id)
        let result = try await jxaBridge.executeJSON(script, as: MutationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
    }

    public func deleteTodo(id: String) async throws {
        let script = JXAScripts.deleteTodo(id: id)
        let result = try await jxaBridge.executeJSON(script, as: MutationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
    }

    public func moveTodo(id: String, toProject projectName: String) async throws {
        let script = JXAScripts.moveTodo(id: id, toProject: projectName)
        let result = try await jxaBridge.executeJSON(script, as: MutationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
    }

    public func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, tags: [String]?) async throws {
        let script = JXAScripts.updateTodo(id: id, name: name, notes: notes, dueDate: dueDate, tags: tags)
        let result = try await jxaBridge.executeJSON(script, as: MutationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
    }

    // MARK: - URL Scheme Operations

    public nonisolated func openInThings(id: String) throws {
        guard let url = URL(string: "things:///show?id=\(id)") else {
            throw ThingsError.invalidState("Invalid URL for id: \(id)")
        }
        NSWorkspace.shared.open(url)
    }

    public nonisolated func openInThings(list: ListView) throws {
        guard let url = URL(string: "things:///show?id=\(list.rawValue)") else {
            throw ThingsError.invalidState("Invalid URL for list: \(list)")
        }
        NSWorkspace.shared.open(url)
    }
}

/// Factory to create the appropriate Things client.
public enum ThingsClientFactory {
    /// Create a Things client - tries hybrid first, falls back to JXA-only.
    public static func create() -> any ThingsClientProtocol {
        do {
            return try HybridThingsClient()
        } catch {
            // Fall back to JXA-only client if database not available
            return ThingsClient()
        }
    }
}
