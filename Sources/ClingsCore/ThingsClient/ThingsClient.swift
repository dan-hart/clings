// ThingsClient.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

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
    func createTodo(
        name: String,
        notes: String?,
        when: Date?,
        deadline: Date?,
        tags: [String],
        project: String?,
        area: String?,
        checklistItems: [String]
    ) async throws -> String
    func createProject(
        name: String,
        notes: String?,
        when: Date?,
        deadline: Date?,
        tags: [String],
        area: String?
    ) async throws -> String
    func completeTodo(id: String) async throws
    func cancelTodo(id: String) async throws
    func deleteTodo(id: String) async throws
    func moveTodo(id: String, toProject: String) async throws
    func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, tags: [String]?) async throws

    // Search
    func search(query: String) async throws -> [Todo]

    // Tag management
    func createTag(name: String) async throws -> Tag
    func deleteTag(name: String) async throws
    func renameTag(oldName: String, newName: String) async throws

    // Open (disabled)
    func openInThings(id: String) throws
    func openInThings(list: ListView) throws
}

/// Result from a mutation operation.
struct MutationResult: Decodable {
    let success: Bool
    let error: String?
    let id: String?
}

/// Result from a creation operation.
struct CreationResult: Decodable {
    let success: Bool
    let error: String?
    let id: String?
    let name: String?
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
        if (try? JSONDecoder().decode(ErrorResponse.self, from: data)) != nil {
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

    public func createTodo(
        name: String,
        notes: String?,
        when: Date?,
        deadline: Date?,
        tags: [String],
        project: String?,
        area: String?,
        checklistItems: [String]
    ) async throws -> String {
        let whenStr = when.map { appleScriptDateString($0) }
        let deadlineStr = deadline.map { appleScriptDateString($0) }

        let script = JXAScripts.createTodo(
            name: name,
            notes: notes,
            when: whenStr,
            deadline: deadlineStr,
            tags: [],
            project: project,
            area: area,
            checklistItems: checklistItems
        )

        let id = try await bridge.executeAppleScript(script)
        guard !id.isEmpty else {
            throw ThingsError.operationFailed("Missing created todo ID")
        }

        if !tags.isEmpty {
            let tagScript = JXAScripts.setTodoTagsAppleScript(id: id, tags: tags)
            do {
                _ = try await bridge.executeAppleScript(tagScript)
            } catch let error as JXAError {
                throw ThingsError.jxaError(error)
            }
        }

        return id
    }

    public func createProject(
        name: String,
        notes: String?,
        when: Date?,
        deadline: Date?,
        tags: [String],
        area: String?
    ) async throws -> String {
        let script = JXAScripts.createProject(
            name: name,
            notes: notes,
            when: when,
            deadline: deadline,
            area: area
        )

        let result = try await bridge.executeJSON(script, as: CreationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
        guard let id = result.id else {
            throw ThingsError.operationFailed("Missing created project ID")
        }

        if !tags.isEmpty {
            let tagScript = JXAScripts.setProjectTagsAppleScript(id: id, tags: tags)
            do {
                _ = try await bridge.executeAppleScript(tagScript)
            } catch let error as JXAError {
                throw ThingsError.jxaError(error)
            }
        }

        return id
    }

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

    public func moveTodo(id: String, toProject projectName: String) async throws {
        let script = JXAScripts.moveTodo(id: id, toProject: projectName)
        let result = try await bridge.executeJSON(script, as: MutationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
    }

    public func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, tags: [String]?) async throws {
        // Handle non-tag updates via JXA (name, notes, dueDate work fine)
        if name != nil || notes != nil || dueDate != nil {
            let script = JXAScripts.updateTodo(id: id, name: name, notes: notes, dueDate: dueDate, tags: nil)
            let result = try await bridge.executeJSON(script, as: MutationResult.self)
            if !result.success {
                throw ThingsError.operationFailed(result.error ?? "Unknown error")
            }
        }

        if let tags = tags {
            let tagScript = JXAScripts.setTodoTagsAppleScript(id: id, tags: tags)
            do {
                _ = try await bridge.executeAppleScript(tagScript)
            } catch let error as JXAError {
                throw ThingsError.jxaError(error)
            }
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

    // MARK: - Tag Management

    public func createTag(name: String) async throws -> Tag {
        let script = JXAScripts.createTagAppleScript(name: name)
        do {
            let tagId = try await bridge.executeAppleScript(script)
            return Tag(id: tagId, name: name)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    public func deleteTag(name: String) async throws {
        let script = JXAScripts.deleteTagAppleScript(name: name)
        do {
            _ = try await bridge.executeAppleScript(script)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    public func renameTag(oldName: String, newName: String) async throws {
        let script = JXAScripts.renameTagAppleScript(oldName: oldName, newName: newName)
        do {
            _ = try await bridge.executeAppleScript(script)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    // MARK: - Open (disabled)

    public nonisolated func openInThings(id: String) throws {
        throw ThingsError.invalidState("Open command is disabled: URL schemes are not allowed.")
    }

    public nonisolated func openInThings(list: ListView) throws {
        throw ThingsError.invalidState("Open command is disabled: URL schemes are not allowed.")
    }

    private func appleScriptDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MMMM d, yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
}
