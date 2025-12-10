// ThingsClient.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation

/// Errors that can occur when interacting with Things 3.
public enum ThingsError: Error, LocalizedError {
    case notFound(String)
    case operationFailed(String)
    case invalidState(String)
    case jxaError(JXAError)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Item not found: \(id)"
        case .operationFailed(let msg):
            return "Operation failed: \(msg)"
        case .invalidState(let msg):
            return "Invalid state: \(msg)"
        case .jxaError(let error):
            return error.localizedDescription
        }
    }
}

/// Protocol for Things 3 client operations.
///
/// This protocol allows for mocking in tests.
public protocol ThingsClientProtocol: Sendable {
    // Lists
    func fetchList(_ list: ListView) async throws -> [Todo]
    func fetchProjects() async throws -> [Project]
    func fetchAreas() async throws -> [Area]
    func fetchTags() async throws -> [Tag]

    // Single item
    func fetchTodo(id: String) async throws -> Todo

    // Mutations
    func completeTodo(id: String) async throws
    func cancelTodo(id: String) async throws
    func deleteTodo(id: String) async throws

    // Search
    func search(query: String) async throws -> [Todo]

    // URL scheme
    func openInThings(id: String) throws
    func openInThings(list: ListView) throws
}

/// Result from a mutation operation.
struct MutationResult: Decodable {
    let success: Bool
    let error: String?
    let id: String?
}

/// Error response from JXA.
struct ErrorResponse: Decodable {
    let error: String
    let id: String?
}

/// Client for interacting with Things 3 via JXA.
public actor ThingsClient: ThingsClientProtocol {
    private let bridge: JXABridge

    /// Create a new Things client.
    /// - Parameter bridge: The JXA bridge to use for script execution.
    public init(bridge: JXABridge = JXABridge()) {
        self.bridge = bridge
    }

    // MARK: - Lists

    public func fetchList(_ list: ListView) async throws -> [Todo] {
        let script = JXAScripts.fetchList(list.displayName)
        do {
            return try await bridge.executeJSON(script, as: [Todo].self)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    public func fetchProjects() async throws -> [Project] {
        let script = JXAScripts.fetchProjects()
        do {
            return try await bridge.executeJSON(script, as: [Project].self)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    public func fetchAreas() async throws -> [Area] {
        let script = JXAScripts.fetchAreas()
        do {
            return try await bridge.executeJSON(script, as: [Area].self)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    public func fetchTags() async throws -> [Tag] {
        let script = JXAScripts.fetchTags()
        do {
            return try await bridge.executeJSON(script, as: [Tag].self)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    // MARK: - Single Item

    public func fetchTodo(id: String) async throws -> Todo {
        let script = JXAScripts.fetchTodo(id: id)
        let output = try await bridge.execute(script)

        guard let data = output.data(using: .utf8) else {
            throw ThingsError.operationFailed("Invalid response")
        }

        // Check if it's an error response
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw ThingsError.notFound(id)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(Todo.self, from: data)
        } catch {
            throw ThingsError.operationFailed("Failed to decode todo: \(error.localizedDescription)")
        }
    }

    // MARK: - Mutations

    public func completeTodo(id: String) async throws {
        let script = JXAScripts.completeTodo(id: id)
        let result = try await bridge.executeJSON(script, as: MutationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
    }

    public func cancelTodo(id: String) async throws {
        let script = JXAScripts.cancelTodo(id: id)
        let result = try await bridge.executeJSON(script, as: MutationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
    }

    public func deleteTodo(id: String) async throws {
        let script = JXAScripts.deleteTodo(id: id)
        let result = try await bridge.executeJSON(script, as: MutationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
    }

    // MARK: - Search

    public func search(query: String) async throws -> [Todo] {
        let script = JXAScripts.search(query: query)
        do {
            return try await bridge.executeJSON(script, as: [Todo].self)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    // MARK: - URL Scheme

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
