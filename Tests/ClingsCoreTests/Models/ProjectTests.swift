// ProjectTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import ClingsCore

@Suite("Project Model")
struct ProjectTests {
    @Suite("Initialization")
    struct Initialization {
        @Test func withAllParameters() {
            let area = Area(id: "a1", name: "Work")
            let tag = Tag(name: "important")
            let dueDate = Date().addingTimeInterval(86400 * 7)
            let created = Date()

            let project = Project(
                id: "p1",
                name: "Test Project",
                notes: "Project notes",
                status: .open,
                area: area,
                tags: [tag],
                dueDate: dueDate,
                creationDate: created
            )

            #expect(project.id == "p1")
            #expect(project.name == "Test Project")
            #expect(project.notes == "Project notes")
            #expect(project.status == .open)
            #expect(project.area?.name == "Work")
            #expect(project.tags.count == 1)
            #expect(project.dueDate == dueDate)
            #expect(project.creationDate == created)
        }

        @Test func withDefaults() {
            let project = Project(id: "p1", name: "Simple Project")

            #expect(project.id == "p1")
            #expect(project.name == "Simple Project")
            #expect(project.notes == nil)
            #expect(project.status == .open)
            #expect(project.area == nil)
            #expect(project.tags.isEmpty)
            #expect(project.dueDate == nil)
            #expect(project.creationDate == nil)
        }
    }

    @Suite("Status Properties")
    struct StatusProperties {
        @Test func isCompletedWhenCompleted() {
            let project = Project(id: "p1", name: "Done", status: .completed)
            #expect(project.isCompleted)
            #expect(!project.isCanceled)
            #expect(!project.isOpen)
        }

        @Test func isCanceledWhenCanceled() {
            let project = Project(id: "p1", name: "Canceled", status: .canceled)
            #expect(!project.isCompleted)
            #expect(project.isCanceled)
            #expect(!project.isOpen)
        }

        @Test func isOpenWhenOpen() {
            let project = Project(id: "p1", name: "Open", status: .open)
            #expect(!project.isCompleted)
            #expect(!project.isCanceled)
            #expect(project.isOpen)
        }
    }

    @Suite("Codable")
    struct CodableTests {
        @Test func decodeFromJSON() throws {
            let json = TestData.projectJSON.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let project = try decoder.decode(Project.self, from: json)

            #expect(project.id == "json-project")
            #expect(project.name == "JSON Project")
            #expect(project.notes == nil)
            #expect(project.status == .open)
            #expect(project.area == nil)
            #expect(project.tags.isEmpty)
        }

        @Test func decodeWithStatusString() throws {
            let json = """
            {
                "id": "p1",
                "name": "Test",
                "status": "completed"
            }
            """.data(using: .utf8)!
            let decoder = JSONDecoder()

            let project = try decoder.decode(Project.self, from: json)

            #expect(project.status == .completed)
        }

        @Test func encodeAndDecode() throws {
            let original = TestData.projectAlpha
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(Project.self, from: data)

            #expect(decoded.id == original.id)
            #expect(decoded.name == original.name)
            #expect(decoded.status == original.status)
        }
    }

    @Suite("Equatable and Hashable")
    struct EquatableHashable {
        @Test func equalityAllFields() {
            // Project uses synthesized Equatable - compares all fields
            let project1 = Project(id: "same-id", name: "Same Name", status: .open)
            let project2 = Project(id: "same-id", name: "Same Name", status: .open)
            let project3 = Project(id: "same-id", name: "Different Name", status: .open)
            let project4 = Project(id: "different-id", name: "Same Name", status: .open)

            #expect(project1 == project2)
            #expect(project1 != project3) // Different name
            #expect(project1 != project4) // Different ID
        }

        @Test func hashAllFields() {
            // Project uses synthesized Hashable - hashes all fields
            let project1 = Project(id: "same-id", name: "Same Name", status: .open)
            let project2 = Project(id: "same-id", name: "Same Name", status: .open)
            let project3 = Project(id: "same-id", name: "Different Name", status: .open)

            var set = Set<Project>()
            set.insert(project1)
            set.insert(project2) // Same as project1
            set.insert(project3) // Different name

            #expect(set.count == 2) // project1/project2 dedupe, project3 is different
        }
    }

    @Suite("Test Data Fixtures")
    struct Fixtures {
        @Test func projectAlphaFixture() {
            let project = TestData.projectAlpha
            #expect(project.isOpen)
            #expect(project.area != nil)
            #expect(!project.tags.isEmpty)
        }

        @Test func projectBetaFixture() {
            let project = TestData.projectBeta
            #expect(project.isCompleted)
            #expect(project.area == nil)
        }

        @Test func projectGammaFixture() {
            let project = TestData.projectGamma
            #expect(project.isCanceled)
        }
    }
}
