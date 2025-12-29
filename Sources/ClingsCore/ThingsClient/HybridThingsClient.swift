// HybridThingsClient.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Hybrid Things client that uses SQLite for fast reads and JXA/AppleScript for writes.
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

        let id = try await jxaBridge.executeAppleScript(script)
        guard !id.isEmpty else {
            throw ThingsError.operationFailed("Missing created todo ID")
        }

        if !tags.isEmpty {
            let tagScript = JXAScripts.setTodoTagsAppleScript(id: id, tags: tags)
            do {
                _ = try await jxaBridge.executeAppleScript(tagScript)
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

        let result = try await jxaBridge.executeJSON(script, as: CreationResult.self)
        if !result.success {
            throw ThingsError.operationFailed(result.error ?? "Unknown error")
        }
        guard let id = result.id else {
            throw ThingsError.operationFailed("Missing created project ID")
        }

        if !tags.isEmpty {
            let tagScript = JXAScripts.setProjectTagsAppleScript(id: id, tags: tags)
            do {
                _ = try await jxaBridge.executeAppleScript(tagScript)
            } catch let error as JXAError {
                throw ThingsError.jxaError(error)
            }
        }

        return id
    }

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
        // Handle non-tag updates via JXA (name, notes, dueDate work fine)
        if name != nil || notes != nil || dueDate != nil {
            let script = JXAScripts.updateTodo(id: id, name: name, notes: notes, dueDate: dueDate, tags: nil)
            let result = try await jxaBridge.executeJSON(script, as: MutationResult.self)
            if !result.success {
                throw ThingsError.operationFailed(result.error ?? "Unknown error")
            }
        }

        if let tags = tags {
            let tagScript = JXAScripts.setTodoTagsAppleScript(id: id, tags: tags)
            do {
                _ = try await jxaBridge.executeAppleScript(tagScript)
            } catch let error as JXAError {
                throw ThingsError.jxaError(error)
            }
        }
    }

    // MARK: - Tag Management

    public func createTag(name: String) async throws -> Tag {
        let script = JXAScripts.createTagAppleScript(name: name)
        do {
            let tagId = try await jxaBridge.executeAppleScript(script)
            return Tag(id: tagId, name: name)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    public func deleteTag(name: String) async throws {
        let script = JXAScripts.deleteTagAppleScript(name: name)
        do {
            _ = try await jxaBridge.executeAppleScript(script)
        } catch let error as JXAError {
            throw ThingsError.jxaError(error)
        }
    }

    public func renameTag(oldName: String, newName: String) async throws {
        let script = JXAScripts.renameTagAppleScript(oldName: oldName, newName: newName)
        do {
            _ = try await jxaBridge.executeAppleScript(script)
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
