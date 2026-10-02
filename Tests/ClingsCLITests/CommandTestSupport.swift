// CommandTestSupport.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import ClingsCLI
import ClingsCore
import Darwin
import Foundation
import Testing

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

    private static func beginCapture() throws -> (URL, Int32, FileHandle) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clings-stdout-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw ThingsError.operationFailed("Cannot create stdout capture") }
        let handle = try FileHandle(forWritingTo: url)
        let original = dup(STDOUT_FILENO)
        fflush(stdout)
        dup2(handle.fileDescriptor, STDOUT_FILENO)
        return (url, original, handle)
    }

    private static func finishCapture(_ capture: (URL, Int32, FileHandle)) throws -> String {
        fflush(stdout)
        dup2(capture.1, STDOUT_FILENO)
        close(capture.1)
        try capture.2.close()
        return try String(decoding: Data(contentsOf: capture.0), as: UTF8.self)
    }

    static func captureStandardOutput<T>(_ body: () throws -> T) throws -> (T, String) {
        acquire(stdoutSemaphore)
        defer { release(stdoutSemaphore) }
        let capture = try beginCapture()
        defer { try? FileManager.default.removeItem(at: capture.0) }
        let result: T
        do { result = try body() }
        catch { _ = try? finishCapture(capture); throw error }
        return try (result, finishCapture(capture))
    }

    static func captureStandardOutput<T>(_ body: () async throws -> T) async throws -> (T, String) {
        acquire(stdoutSemaphore)
        defer { release(stdoutSemaphore) }
        let capture = try beginCapture()
        defer { try? FileManager.default.removeItem(at: capture.0) }
        let result: T
        do { result = try await body() }
        catch { _ = try? finishCapture(capture); throw error }
        return try (result, finishCapture(capture))
    }

    static func withRuntime<T>(
        client: (any ThingsClientProtocol)? = nil,
        database: (any ThingsDatabaseReadable)? = nil,
        inputs: [String] = [],
        openedURLs: URLRecorder? = nil,
        terminal: Bool? = nil,
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

        return try await CommandRuntime.$isTerminal.withValue({ terminal ?? !inputs.isEmpty }) {
            try await CommandRuntime.$makeClient.withValue(clientFactory) {
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

    func search(query _: String) throws -> [Todo] {
        searchResults
    }
}

final class RecordingThingsClient: ThingsClientProtocol, @unchecked Sendable {
    var failedIDs: Set<String> = []
    private(set) var restoredSnapshots: [TodoSnapshot] = []
    func restoreTodo(_ snapshot: TodoSnapshot) async throws {
        if let error {
            throw error
        }
        if failedIDs.contains(snapshot.id) {
            throw ThingsError.operationFailed("Failed: \(snapshot.id)")
        }
        restoredSnapshots.append(snapshot)
        updatedTodos.append((snapshot.id, snapshot.name, snapshot.notes, snapshot.dueDate, snapshot.tags))
        var todo = todosByID[snapshot.id] ?? Todo(id: snapshot.id, name: snapshot.name)
        todo.name = snapshot.name; todo.notes = snapshot.notes; todo.dueDate = snapshot.dueDate
        todo.tags = snapshot.tags.map { ClingsCore.Tag(id: $0, name: $0) }; todo.status = snapshot.status
        todosByID[snapshot.id] = todo
    }

    func moveTodo(id: String, toProjectID: String) async throws {
        if let error {
            throw error
        }
        if failedIDs.contains(id) {
            throw ThingsError.operationFailed("Failed: \(id)")
        }
        movedTodos.append((id, toProjectID))
        todosByID[id]?.project = projects.first { $0.id == toProjectID }
    }

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
        if let error {
            throw error
        }
        fetchedLists.append(list)
        return (todosForList[list] ?? []).map { todosByID[$0.id] ?? $0 }
    }

    func fetchProjects() async throws -> [Project] {
        if let error {
            throw error
        }
        return projects
    }

    func fetchAreas() async throws -> [Area] {
        if let error {
            throw error
        }
        return areas
    }

    func fetchTags() async throws -> [ClingsCore.Tag] {
        if let error {
            throw error
        }
        return tags
    }

    func fetchTodo(id: String) async throws -> Todo {
        if let error {
            throw error
        }
        if todosByID[id] == nil, let todo = (Array(todosForList.values).flatMap { $0 } + searchResults).first(where: { $0.id == id }) {
            todosByID[id] = todo
        }
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
        if let error {
            throw error
        }
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
        if let error {
            throw error
        }
        createdProjects.append((name, notes, when, deadline, tags, area))
        return createProjectID
    }

    func completeTodo(id: String) async throws {
        if let error {
            throw error
        }
        if failedIDs.contains(id) {
            throw ThingsError.operationFailed("Failed: \(id)")
        }
        completedIDs.append(id)
        todosByID[id]?.status = .completed
    }

    func reopenTodo(id: String) async throws {
        if let error {
            throw error
        }
        if failedIDs.contains(id) {
            throw ThingsError.operationFailed("Failed: \(id)")
        }
        reopenedIDs.append(id)
        todosByID[id]?.status = .open
    }

    func cancelTodo(id: String) async throws {
        if let error {
            throw error
        }
        if failedIDs.contains(id) {
            throw ThingsError.operationFailed("Failed: \(id)")
        }
        canceledIDs.append(id)
        todosByID[id]?.status = .canceled
    }

    func deleteTodo(id: String) async throws {
        if let error {
            throw error
        }
        deletedIDs.append(id)
    }

    func moveTodo(id: String, toProject projectName: String) async throws {
        if let error {
            throw error
        }
        movedTodos.append((id, projectName))
    }

    func updateTodo(id: String, name: String?, notes: String?, dueDate: Date?, tags: [String]?) async throws {
        if let error {
            throw error
        }
        if failedIDs.contains(id) {
            throw ThingsError.operationFailed("Failed: \(id)")
        }
        updatedTodos.append((id, name, notes, dueDate, tags))
        if let name {
            todosByID[id]?.name = name
        }
        if let notes {
            todosByID[id]?.notes = notes
        }
        if let dueDate {
            todosByID[id]?.dueDate = dueDate
        }
        if let tags {
            todosByID[id]?.tags = tags.map { ClingsCore.Tag(id: $0, name: $0) }
        }
    }

    func search(query: String) async throws -> [Todo] {
        if let error {
            throw error
        }
        searchQueries.append(query)
        return searchResults
    }

    func createTag(name: String) async throws -> ClingsCore.Tag {
        if let error {
            throw error
        }
        createdTags.append(name)
        return ClingsCore.Tag(id: "tag-\(name)", name: name)
    }

    func deleteTag(name: String) async throws {
        if let error {
            throw error
        }
        deletedTags.append(name)
    }

    func renameTag(oldName: String, newName: String) async throws {
        if let error {
            throw error
        }
        renamedTags.append((oldName, newName))
    }

    func openInThings(id _: String) throws {}
    func openInThings(list _: ListView) throws {}
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
