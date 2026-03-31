// CommandTestSupport.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ClingsCore
import Darwin
import Foundation
import Testing
@testable import ClingsCLI

enum CommandTestSupport {
    private static let stdoutSemaphore = DispatchSemaphore(value: 1)
    private static let configSemaphoreName = "/clings-tests-config-dir-lock"

    private static func acquire(_ semaphore: DispatchSemaphore) {
        semaphore.wait()
    }

    private static func release(_ semaphore: DispatchSemaphore) {
        semaphore.signal()
    }

    private static func withConfigLock<T>(_ body: () async throws -> T) async throws -> T {
        let semaphore = sem_open(configSemaphoreName, O_CREAT, S_IRUSR | S_IWUSR, 1)
        precondition(semaphore != SEM_FAILED, "Failed to create shared config semaphore")
        defer { sem_close(semaphore) }

        sem_wait(semaphore)
        defer { sem_post(semaphore) }

        return try await body()
    }

    static func withTemporaryConfigDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        try await withConfigLock {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("clings-cli-config-\(UUID().uuidString)")
            setenv("CLINGS_CONFIG_DIR", root.path, 1)
            defer {
                unsetenv("CLINGS_CONFIG_DIR")
                try? FileManager.default.removeItem(at: root)
            }

            return try await body(root)
        }
    }

    static func captureStandardOutput<T>(_ body: () throws -> T) throws -> (T, String) {
        acquire(stdoutSemaphore)
        defer { release(stdoutSemaphore) }

        let pipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)
        precondition(originalStdout >= 0, "Failed to duplicate stdout")

        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        do {
            let result = try body()
            fflush(stdout)
            dup2(originalStdout, STDOUT_FILENO)
            close(originalStdout)
            try pipe.fileHandleForWriting.close()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (result, String(data: data, encoding: .utf8) ?? "")
        } catch {
            fflush(stdout)
            dup2(originalStdout, STDOUT_FILENO)
            close(originalStdout)
            try? pipe.fileHandleForWriting.close()
            throw error
        }
    }

    static func captureStandardOutput<T>(_ body: () async throws -> T) async throws -> (T, String) {
        acquire(stdoutSemaphore)
        defer { release(stdoutSemaphore) }

        let pipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)
        precondition(originalStdout >= 0, "Failed to duplicate stdout")

        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        do {
            let result = try await body()
            fflush(stdout)
            dup2(originalStdout, STDOUT_FILENO)
            close(originalStdout)
            try pipe.fileHandleForWriting.close()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (result, String(data: data, encoding: .utf8) ?? "")
        } catch {
            fflush(stdout)
            dup2(originalStdout, STDOUT_FILENO)
            close(originalStdout)
            try? pipe.fileHandleForWriting.close()
            throw error
        }
    }

    static func withRuntime<T>(
        client: (any ThingsClientProtocol)? = nil,
        database: (any ThingsDatabaseReadable)? = nil,
        inputs: [String] = [],
        openedURLs: URLRecorder? = nil,
        body: () async throws -> T
    ) async throws -> T {
        let feeder = InputFeeder(inputs: inputs)
        let currentClientFactory = CommandRuntime.makeClient
        let currentDatabaseFactory = CommandRuntime.makeDatabase
        let currentInputReader = CommandRuntime.inputReader
        let currentOpenURLScheme = CommandRuntime.openURLScheme

        let clientFactory: @Sendable () -> any ThingsClientProtocol = {
            if let client {
                return client
            }
            return currentClientFactory()
        }

        let databaseFactory: @Sendable () throws -> any ThingsDatabaseReadable = {
            if let database {
                return database
            }
            return try currentDatabaseFactory()
        }

        let inputReader: @Sendable () -> String? = {
            if inputs.isEmpty {
                return currentInputReader()
            }
            return feeder.read()
        }

        let openURLScheme: @Sendable (String) throws -> Void = { url in
            if let openedURLs {
                openedURLs.urls.append(url)
                return
            }
            try currentOpenURLScheme(url)
        }

        return try await CommandRuntime.$makeClient.withValue(clientFactory) {
            try await CommandRuntime.$makeDatabase.withValue(databaseFactory) {
                try await CommandRuntime.$inputReader.withValue(inputReader) {
                    try await CommandRuntime.$openURLScheme.withValue(openURLScheme) {
                        try await body()
                    }
                }
            }
        }
    }
}

final class URLRecorder: @unchecked Sendable {
    var urls: [String] = []
}

private final class InputFeeder: @unchecked Sendable {
    private var inputs: [String]

    init(inputs: [String]) {
        self.inputs = inputs
    }

    func read() -> String? {
        guard !inputs.isEmpty else { return nil }
        return inputs.removeFirst()
    }
}

struct MockThingsDatabase: ThingsDatabaseReadable {
    var lists: [ListView: [Todo]] = [:]
    var projects: [Project] = []
    var areas: [Area] = []
    var tags: [ClingsCore.Tag] = []
    var todosByID: [String: Todo] = [:]
    var searchResults: [Todo] = []

    func fetchList(_ list: ListView) throws -> [Todo] {
        lists[list] ?? []
    }

    func fetchProjects() throws -> [Project] {
        projects
    }

    func fetchAreas() throws -> [Area] {
        areas
    }

    func fetchTags() throws -> [ClingsCore.Tag] {
        tags
    }

    func fetchTodo(id: String) throws -> Todo {
        guard let todo = todosByID[id] else {
            throw ThingsError.notFound(id)
        }
        return todo
    }

    func search(query: String) throws -> [Todo] {
        searchResults
    }
}

final class RecordingThingsClient: ThingsClientProtocol, @unchecked Sendable {
    var todosForList: [ListView: [Todo]] = [:]
    var projects: [Project] = []
    var areas: [Area] = []
    var tags: [ClingsCore.Tag] = []
    var todosByID: [String: Todo] = [:]
    var searchResults: [Todo] = []
    var createTodoID = "created-todo-id"
    var createProjectID = "created-project-id"
    var error: Error?

    private(set) var fetchedLists: [ListView] = []
    private(set) var completedIDs: [String] = []
    private(set) var reopenedIDs: [String] = []
    private(set) var canceledIDs: [String] = []
    private(set) var deletedIDs: [String] = []
    private(set) var movedTodos: [(String, String)] = []
    private(set) var updatedTodos: [(String, String?, String?, Date?, [String]?)] = []
    private(set) var createdTodos: [(String, String?, Date?, Date?, [String], String?, String?, [String])] = []
    private(set) var createdProjects: [(String, String?, Date?, Date?, [String], String?)] = []
    private(set) var searchQueries: [String] = []
    private(set) var createdTags: [String] = []
    private(set) var deletedTags: [String] = []
    private(set) var renamedTags: [(String, String)] = []

    func fetchList(_ list: ListView) async throws -> [Todo] {
        if let error { throw error }
        fetchedLists.append(list)
        return todosForList[list] ?? []
    }

    func fetchProjects() async throws -> [Project] {
        if let error { throw error }
        return projects
    }

    func fetchAreas() async throws -> [Area] {
        if let error { throw error }
        return areas
    }

    func fetchTags() async throws -> [ClingsCore.Tag] {
        if let error { throw error }
        return tags
    }

    func fetchTodo(id: String) async throws -> Todo {
        if let error { throw error }
        guard let todo = todosByID[id] else {
            throw ThingsError.notFound(id)
        }
        return todo
    }

    func createTodo(
        name: String,
        notes: String?,
        when: Date?,
        deadline: Date?,
        tags: [String],
        project: String?,
        area: String?,
        checklistItems: [String]
    ) async throws -> String {
        if let error { throw error }
        createdTodos.append((name, notes, when, deadline, tags, project, area, checklistItems))
        return createTodoID
    }

    func createProject(
        name: String,
        notes: String?,
        when: Date?,
        deadline: Date?,
        tags: [String],
        area: String?
    ) async throws -> String {
        if let error { throw error }
        createdProjects.append((name, notes, when, deadline, tags, area))
        return createProjectID
    }

    func completeTodo(id: String) async throws {
        if let error { throw error }
        completedIDs.append(id)
    }

    func reopenTodo(id: String) async throws {
        if let error { throw error }
        reopenedIDs.append(id)
    }

    func cancelTodo(id: String) async throws {
        if let error { throw error }
        canceledIDs.append(id)
    }

    func deleteTodo(id: String) async throws {
        if let error { throw error }
        deletedIDs.append(id)
    }

    func moveTodo(id: String, toProject projectName: String) async throws {
        if let error { throw error }
        movedTodos.append((id, projectName))
    }

    func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, tags: [String]?) async throws {
        if let error { throw error }
        updatedTodos.append((id, name, notes, dueDate, tags))
    }

    func search(query: String) async throws -> [Todo] {
        if let error { throw error }
        searchQueries.append(query)
        return searchResults
    }

    func createTag(name: String) async throws -> ClingsCore.Tag {
        if let error { throw error }
        createdTags.append(name)
        return ClingsCore.Tag(id: "tag-\(name)", name: name)
    }

    func deleteTag(name: String) async throws {
        if let error { throw error }
        deletedTags.append(name)
    }

    func renameTag(oldName: String, newName: String) async throws {
        if let error { throw error }
        renamedTags.append((oldName, newName))
    }

    func openInThings(id: String) throws {}
    func openInThings(list: ListView) throws {}
}

enum CommandFixtures {
    static let workArea = Area(id: "area-work", name: "Work", tags: [])
    static let personalArea = Area(id: "area-personal", name: "Personal", tags: [])
    static let docsTag = ClingsCore.Tag(id: "tag-docs", name: "docs")
    static let urgentTag = ClingsCore.Tag(id: "tag-urgent", name: "urgent")
    static let reviewTag = ClingsCore.Tag(id: "tag-review", name: "review")

    static let releaseProject = Project(
        id: "project-release",
        name: "Release",
        notes: "Ship it",
        status: .open,
        area: workArea,
        tags: [docsTag],
        dueDate: nil,
        creationDate: Date(timeIntervalSinceReferenceDate: 1000)
    )

    static func todo(
        id: String,
        name: String,
        status: Status = .open,
        dueDate: Date? = nil,
        tags: [ClingsCore.Tag] = [],
        project: Project? = releaseProject,
        area: Area? = workArea,
        notes: String? = nil,
        checklistItems: [ChecklistItem] = []
    ) -> Todo {
        Todo(
            id: id,
            name: name,
            notes: notes,
            status: status,
            dueDate: dueDate,
            tags: tags,
            project: project,
            area: area,
            checklistItems: checklistItems,
            creationDate: Date(timeIntervalSinceReferenceDate: 1000),
            modificationDate: Date(timeIntervalSinceReferenceDate: 2000)
        )
    }
}
