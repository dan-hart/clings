// MockThingsClient.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import ClingsCore

/// A mock implementation of ThingsClientProtocol for testing.
///
/// Allows configuring return values and tracking method calls.
final class MockThingsClient: ThingsClientProtocol, @unchecked Sendable {
    // MARK: - Configuration

    /// Todos to return for each list type.
    var todosForList: [ListView: [Todo]] = [:]

    /// All projects to return.
    var projects: [Project] = []

    /// All areas to return.
    var areas: [Area] = []

    /// All tags to return.
    var tags: [Tag] = []

    /// Single todo lookup by ID.
    var todoById: [String: Todo] = [:]

    /// Search results to return.
    var searchResults: [Todo] = []

    /// Error to throw for any operation.
    var errorToThrow: Error?

    // MARK: - Call Tracking

    /// Track which lists were fetched.
    private(set) var fetchedLists: [ListView] = []

    /// Track which todo IDs were completed.
    private(set) var completedIds: [String] = []

    /// Track which todo IDs were canceled.
    private(set) var canceledIds: [String] = []

    /// Track which todo IDs were deleted.
    private(set) var deletedIds: [String] = []

    /// Track move operations (todoId, projectName).
    private(set) var moveOperations: [(String, String)] = []

    /// Track update operations.
    private(set) var updateOperations: [(id: String, name: String?, notes: String?, dueDate: Date?, tags: [String]?)] = []

    /// Track search queries.
    private(set) var searchQueries: [String] = []

    /// Track opened IDs.
    private(set) var openedIds: [String] = []

    /// Track opened lists.
    private(set) var openedLists: [ListView] = []

    // MARK: - ThingsClientProtocol Implementation

    func fetchList(_ list: ListView) async throws -> [Todo] {
        if let error = errorToThrow { throw error }
        fetchedLists.append(list)
        return todosForList[list] ?? []
    }

    func fetchProjects() async throws -> [Project] {
        if let error = errorToThrow { throw error }
        return projects
    }

    func fetchAreas() async throws -> [Area] {
        if let error = errorToThrow { throw error }
        return areas
    }

    func fetchTags() async throws -> [Tag] {
        if let error = errorToThrow { throw error }
        return tags
    }

    func fetchTodo(id: String) async throws -> Todo {
        if let error = errorToThrow { throw error }
        guard let todo = todoById[id] else {
            throw ThingsError.notFound(id)
        }
        return todo
    }

    func completeTodo(id: String) async throws {
        if let error = errorToThrow { throw error }
        completedIds.append(id)
    }

    func cancelTodo(id: String) async throws {
        if let error = errorToThrow { throw error }
        canceledIds.append(id)
    }

    func deleteTodo(id: String) async throws {
        if let error = errorToThrow { throw error }
        deletedIds.append(id)
    }

    func moveTodo(id: String, toProject projectName: String) async throws {
        if let error = errorToThrow { throw error }
        moveOperations.append((id, projectName))
    }

    func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, tags: [String]?) async throws {
        if let error = errorToThrow { throw error }
        updateOperations.append((id, name, notes, dueDate, tags))
    }

    func search(query: String) async throws -> [Todo] {
        if let error = errorToThrow { throw error }
        searchQueries.append(query)
        return searchResults
    }

    func openInThings(id: String) throws {
        if let error = errorToThrow { throw error }
        openedIds.append(id)
    }

    func openInThings(list: ListView) throws {
        if let error = errorToThrow { throw error }
        openedLists.append(list)
    }

    // MARK: - Tag Management

    /// Track created tags.
    private(set) var createdTags: [String] = []

    /// Track deleted tags.
    private(set) var deletedTags: [String] = []

    /// Track rename operations (oldName, newName).
    private(set) var renamedTags: [(String, String)] = []

    func createTag(name: String) async throws -> Tag {
        if let error = errorToThrow { throw error }
        createdTags.append(name)
        return Tag(id: "mock-tag-\(UUID().uuidString.prefix(8))", name: name)
    }

    func deleteTag(name: String) async throws {
        if let error = errorToThrow { throw error }
        deletedTags.append(name)
    }

    func renameTag(oldName: String, newName: String) async throws {
        if let error = errorToThrow { throw error }
        renamedTags.append((oldName, newName))
    }

    // MARK: - Convenience Setup

    /// Reset all tracking arrays.
    func reset() {
        fetchedLists = []
        completedIds = []
        canceledIds = []
        deletedIds = []
        moveOperations = []
        updateOperations = []
        searchQueries = []
        openedIds = []
        openedLists = []
        createdTags = []
        deletedTags = []
        renamedTags = []
        errorToThrow = nil
    }

    /// Configure with test data.
    func configureWithTestData() {
        todosForList = [
            .inbox: TestData.inboxTodos,
            .today: TestData.todayTodos,
            .upcoming: [],
            .anytime: TestData.openTodos,
            .someday: [],
            .logbook: TestData.completedTodos,
            .trash: []
        ]
        projects = TestData.allProjects
        areas = TestData.allAreas
        tags = TestData.allTags
        searchResults = TestData.openTodos

        for todo in TestData.allTodos {
            todoById[todo.id] = todo
        }
    }
}
