// ThingsClientTestSupport.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import ClingsCore

final class MockJXAExecutor: JXAExecuting, @unchecked Sendable {
    enum StubError: Error {
        case missingStub(String)
    }

    enum Stub {
        case success(String)
        case failure(Error)
    }

    private(set) var executeScripts: [String] = []
    private(set) var executeJSONScripts: [String] = []
    private(set) var appleScriptScripts: [String] = []

    var executeResponses: [Stub] = []
    var jsonResponses: [Stub] = []
    var appleScriptResponses: [Stub] = []
    var isThingsRunningValue = false

    func execute(_ script: String) async throws -> String {
        executeScripts.append(script)
        return try popNext(from: &executeResponses, label: "execute")
    }

    func executeJSON<T: Decodable & Sendable>(_ script: String, as type: T.Type) async throws -> T {
        executeJSONScripts.append(script)
        let raw = try popNext(from: &jsonResponses, label: "executeJSON")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: Data(raw.utf8))
    }

    func executeAppleScript(_ script: String) async throws -> String {
        appleScriptScripts.append(script)
        return try popNext(from: &appleScriptResponses, label: "executeAppleScript")
    }

    func isThingsRunning() async -> Bool {
        isThingsRunningValue
    }

    private func popNext(from responses: inout [Stub], label: String) throws -> String {
        guard !responses.isEmpty else {
            throw StubError.missingStub(label)
        }

        let response = responses.removeFirst()
        switch response {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

final class MockThingsDatabaseReader: ThingsDatabaseReadable, @unchecked Sendable {
    var lists: [ListView: [Todo]] = [:]
    var projects: [Project] = []
    var areas: [Area] = []
    var tags: [Tag] = []
    var todosByID: [String: Todo] = [:]
    var searchResults: [Todo] = []
    var error: Error?

    private(set) var fetchedLists: [ListView] = []
    private(set) var fetchedTodoIDs: [String] = []
    private(set) var searchQueries: [String] = []

    func fetchList(_ list: ListView) throws -> [Todo] {
        if let error {
            throw error
        }
        fetchedLists.append(list)
        return lists[list] ?? []
    }

    func fetchProjects() throws -> [Project] {
        if let error {
            throw error
        }
        return projects
    }

    func fetchAreas() throws -> [Area] {
        if let error {
            throw error
        }
        return areas
    }

    func fetchTags() throws -> [Tag] {
        if let error {
            throw error
        }
        return tags
    }

    func fetchTodo(id: String) throws -> Todo {
        if let error {
            throw error
        }
        fetchedTodoIDs.append(id)
        guard let todo = todosByID[id] else {
            throw ThingsError.notFound(id)
        }
        return todo
    }

    func search(query: String) throws -> [Todo] {
        if let error {
            throw error
        }
        searchQueries.append(query)
        return searchResults
    }
}

func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    guard let string = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "ThingsClientTestSupport", code: 1)
    }
    return string
}

func jsonObjectString(_ object: [String: Any?]) throws -> String {
    let sanitized = object.reduce(into: [String: Any]()) { partial, entry in
        partial[entry.key] = entry.value ?? NSNull()
    }
    let data = try JSONSerialization.data(withJSONObject: sanitized, options: [.sortedKeys])
    guard let string = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "ThingsClientTestSupport", code: 2)
    }
    return string
}

func mutationResultJSON(success: Bool, error: String? = nil, id: String? = nil) throws -> String {
    try jsonObjectString([
        "success": success,
        "error": error,
        "id": id,
    ])
}

func creationResultJSON(success: Bool, error: String? = nil, id: String? = nil, name: String? = nil) throws -> String {
    try jsonObjectString([
        "success": success,
        "error": error,
        "id": id,
        "name": name,
    ])
}

func errorResponseJSON(error: String, id: String? = nil) throws -> String {
    try jsonObjectString([
        "error": error,
        "id": id,
    ])
}
