// ArgumentParsingTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import Testing
@testable import ClingsCLI

@Suite("Argument Parsing")
struct ArgumentParsingTests {
    @Suite("OutputOptions")
    struct OutputOptionsTests {
        @Test func defaults() throws {
            let options = try OutputOptions.parse([])
            #expect(!options.json)
            #expect(!options.noColor)
        }

        @Test func jsonFlag() throws {
            let options = try OutputOptions.parse(["--json"])
            #expect(options.json)
        }

        @Test func noColorFlag() throws {
            let options = try OutputOptions.parse(["--no-color"])
            #expect(options.noColor)
        }

        @Test func bothFlags() throws {
            let options = try OutputOptions.parse(["--json", "--no-color"])
            #expect(options.json)
            #expect(options.noColor)
        }
    }

    @Suite("Complete Command")
    struct CompleteCommandParsing {
        // Note: ID is now optional when using --title flag.
        // Runtime validation ensures at least one of id or --title is provided.
        @Test func parsesWithNoArgs() throws {
            // Parsing succeeds, but run() will throw ValidationError
            let command = try CompleteCommand.parse([])
            #expect(command.id == nil)
            #expect(command.title == nil)
        }

        @Test func acceptsId() throws {
            let command = try CompleteCommand.parse(["ABC123"])
            #expect(command.id == "ABC123")
        }

        @Test func acceptsTitle() throws {
            let command = try CompleteCommand.parse(["--title", "buy milk"])
            #expect(command.title == "buy milk")
            #expect(command.id == nil)
        }

        @Test func acceptsTitleShort() throws {
            let command = try CompleteCommand.parse(["-t", "groceries"])
            #expect(command.title == "groceries")
        }

        @Test func acceptsBothIdAndTitle() throws {
            // When both are provided, title takes precedence (by implementation)
            let command = try CompleteCommand.parse(["ABC123", "--title", "search"])
            #expect(command.id == "ABC123")
            #expect(command.title == "search")
        }

        @Test func withJsonOutput() throws {
            let command = try CompleteCommand.parse(["ABC123", "--json"])
            #expect(command.id == "ABC123")
            #expect(command.output.json)
        }

        @Test func titleWithJsonOutput() throws {
            let command = try CompleteCommand.parse(["--title", "task", "--json"])
            #expect(command.title == "task")
            #expect(command.output.json)
        }
    }

    @Suite("Cancel Command")
    struct CancelCommandParsing {
        @Test func requiresId() {
            #expect(throws: Error.self) {
                try CancelCommand.parse([])
            }
        }

        @Test func acceptsId() throws {
            let command = try CancelCommand.parse(["DEF456"])
            #expect(command.id == "DEF456")
        }
    }

    @Suite("Delete Command")
    struct DeleteCommandParsing {
        @Test func requiresId() {
            #expect(throws: Error.self) {
                try DeleteCommand.parse([])
            }
        }

        @Test func acceptsId() throws {
            let command = try DeleteCommand.parse(["GHI789"])
            #expect(command.id == "GHI789")
        }

        @Test func forceFlag() throws {
            let command = try DeleteCommand.parse(["GHI789", "-f"])
            #expect(command.force)
        }

        @Test func forceLongFlag() throws {
            let command = try DeleteCommand.parse(["GHI789", "--force"])
            #expect(command.force)
        }
    }

    @Suite("Update Command")
    struct UpdateCommandParsing {
        @Test func requiresId() {
            #expect(throws: Error.self) {
                try UpdateCommand.parse([])
            }
        }

        @Test func acceptsId() throws {
            let command = try UpdateCommand.parse(["JKL012"])
            #expect(command.id == "JKL012")
        }

        @Test func nameOption() throws {
            let command = try UpdateCommand.parse(["JKL012", "--name", "New Title"])
            #expect(command.name == "New Title")
        }

        @Test func notesOption() throws {
            let command = try UpdateCommand.parse(["JKL012", "--notes", "Some notes"])
            #expect(command.notes == "Some notes")
        }

        @Test func dueOption() throws {
            let command = try UpdateCommand.parse(["JKL012", "--due", "2024-12-25"])
            #expect(command.due == "2024-12-25")
        }

        @Test func tagsOption() throws {
            let command = try UpdateCommand.parse(["JKL012", "--tags", "work", "urgent"])
            #expect(command.tags == ["work", "urgent"])
        }

        @Test func allOptions() throws {
            let command = try UpdateCommand.parse([
                "JKL012",
                "--name", "New Title",
                "--notes", "Notes",
                "--due", "today",
                "--tags", "tag1", "tag2",
            ])
            #expect(command.name == "New Title")
            #expect(command.notes == "Notes")
            #expect(command.due == "today")
            #expect(command.tags == ["tag1", "tag2"])
        }
    }

    @Suite("Add Command")
    struct AddCommandParsing {
        @Test func requiresTitle() {
            #expect(throws: Error.self) {
                try AddCommand.parse([])
            }
        }

        @Test func acceptsTitle() throws {
            let command = try AddCommand.parse(["Buy groceries"])
            #expect(command.title == "Buy groceries")
        }

        @Test func notesOption() throws {
            let command = try AddCommand.parse(["Task", "--notes", "Some notes"])
            #expect(command.notes == "Some notes")
        }

        @Test func whenOption() throws {
            let command = try AddCommand.parse(["Task", "--when", "tomorrow"])
            #expect(command.when == "tomorrow")
        }

        @Test func deadlineOption() throws {
            let command = try AddCommand.parse(["Task", "--deadline", "friday"])
            #expect(command.deadline == "friday")
        }

        @Test func tagsOption() throws {
            let command = try AddCommand.parse(["Task", "--tags", "work", "urgent"])
            #expect(command.tags == ["work", "urgent"])
        }

        @Test func projectOption() throws {
            let command = try AddCommand.parse(["Task", "--project", "My Project"])
            #expect(command.project == "My Project")
        }

        @Test func areaOption() throws {
            let command = try AddCommand.parse(["Task", "--area", "Work"])
            #expect(command.area == "Work")
        }

        @Test func parseOnlyFlag() throws {
            let command = try AddCommand.parse(["Task", "--parse-only"])
            #expect(command.parseOnly)
        }
    }

    @Suite("Search Command")
    struct SearchCommandParsing {
        @Test func requiresQuery() {
            #expect(throws: Error.self) {
                try SearchCommand.parse([])
            }
        }

        @Test func acceptsQuery() throws {
            let command = try SearchCommand.parse(["meeting"])
            #expect(command.query == "meeting")
        }

        @Test func multiWordQuery() throws {
            let command = try SearchCommand.parse(["project status report"])
            #expect(command.query == "project status report")
        }
    }

    @Suite("Filter Command")
    struct FilterCommandParsing {
        @Test func requiresExpression() {
            #expect(throws: Error.self) {
                try FilterCommand.parse([])
            }
        }

        @Test func acceptsExpression() throws {
            let command = try FilterCommand.parse(["status = open"])
            #expect(command.expression == "status = open")
        }

        @Test func complexExpression() throws {
            let command = try FilterCommand.parse(["tags CONTAINS 'work' AND due < today"])
            #expect(command.expression == "tags CONTAINS 'work' AND due < today")
        }

        @Test func withJsonOutput() throws {
            let command = try FilterCommand.parse(["status = open", "--json"])
            #expect(command.output.json)
        }
    }

    @Suite("Show Command")
    struct ShowCommandParsing {
        @Test func requiresId() {
            #expect(throws: Error.self) {
                try ShowCommand.parse([])
            }
        }

        @Test func acceptsId() throws {
            let command = try ShowCommand.parse(["MNO345"])
            #expect(command.id == "MNO345")
        }
    }

    @Suite("Bulk Options")
    struct BulkOptionsParsing {
        @Test func defaults() throws {
            let options = try BulkOptions.parse([])
            #expect(options.where == nil)
            #expect(!options.dryRun)
            #expect(!options.yes)
        }

        @Test func whereClause() throws {
            let options = try BulkOptions.parse(["--where", "status = open"])
            #expect(options.where == "status = open")
        }

        @Test func dryRun() throws {
            let options = try BulkOptions.parse(["--dry-run"])
            #expect(options.dryRun)
        }

        @Test func yes() throws {
            let options = try BulkOptions.parse(["--yes"])
            #expect(options.yes)
        }

        @Test func yesShort() throws {
            let options = try BulkOptions.parse(["-y"])
            #expect(options.yes)
        }
    }

    @Suite("Bulk Move Command")
    struct BulkMoveCommandParsing {
        @Test func requiresTo() {
            #expect(throws: Error.self) {
                try BulkMoveCommand.parse([])
            }
        }

        @Test func acceptsTo() throws {
            let command = try BulkMoveCommand.parse(["--to", "My Project"])
            #expect(command.to == "My Project")
        }

        @Test func listOption() throws {
            let command = try BulkMoveCommand.parse(["--to", "Project", "--list", "inbox"])
            #expect(command.list == "inbox")
        }
    }

    @Suite("Bulk Tag Command")
    struct BulkTagCommandParsing {
        @Test func requiresTags() {
            #expect(throws: Error.self) {
                try BulkTagCommand.parse([])
            }
        }

        @Test func acceptsTags() throws {
            let command = try BulkTagCommand.parse(["work,urgent"])
            #expect(command.tags == "work,urgent")
        }
    }

    @Suite("Open Command")
    struct OpenCommandParsing {
        @Test func requiresTarget() {
            #expect(throws: Error.self) {
                try OpenCommand.parse([])
            }
        }

        @Test func acceptsTarget() throws {
            let command = try OpenCommand.parse(["today"])
            #expect(command.target == "today")
        }

        @Test func acceptsId() throws {
            let command = try OpenCommand.parse(["XYZ789"])
            #expect(command.target == "XYZ789")
        }
    }

    @Suite("Stats Command")
    struct StatsCommandParsing {
        @Test func configuration() {
            // Stats command has subcommands
            let config = StatsCommand.configuration
            #expect(!config.subcommands.isEmpty)
        }
    }

    @Suite("Review Command")
    struct ReviewCommandParsing {
        @Test func configuration() {
            // Review command has subcommands with default
            let config = ReviewCommand.configuration
            #expect(!config.subcommands.isEmpty)
            #expect(config.defaultSubcommand != nil)
        }
    }

    @Suite("Invalid Arguments")
    struct InvalidArguments {
        @Test func completeRejectsUnknownOption() {
            #expect(throws: Error.self) {
                try CompleteCommand.parse(["ABC", "--unknown"])
            }
        }

        @Test func addRejectsUnknownOption() {
            #expect(throws: Error.self) {
                try AddCommand.parse(["Task", "--unknown"])
            }
        }
    }
}
