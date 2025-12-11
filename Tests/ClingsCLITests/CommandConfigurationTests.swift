// CommandConfigurationTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import Testing
@testable import ClingsCLI

@Suite("Command Configuration")
struct CommandConfigurationTests {
    @Suite("Root Command")
    struct RootCommand {
        @Test func configuration() {
            let config = Clings.configuration
            #expect(config.commandName == "clings")
            #expect(!config.abstract.isEmpty)
        }

        @Test func hasVersion() {
            let config = Clings.configuration
            #expect(config.version != nil)
        }

        @Test func subcommands() {
            let config = Clings.configuration
            #expect(!config.subcommands.isEmpty)
        }
    }

    @Suite("List Commands")
    struct ListCommands {
        @Test func todayCommand() {
            let config = TodayCommand.configuration
            #expect(config.commandName == "today")
            #expect(config.aliases.contains("t"))
        }

        @Test func inboxCommand() {
            let config = InboxCommand.configuration
            #expect(config.commandName == "inbox")
            #expect(config.aliases.contains("i"))
        }

        @Test func upcomingCommand() {
            let config = UpcomingCommand.configuration
            #expect(config.commandName == "upcoming")
            #expect(config.aliases.contains("u"))
        }

        @Test func somedayCommand() {
            let config = SomedayCommand.configuration
            #expect(config.commandName == "someday")
            #expect(config.aliases.contains("s"))
        }

        @Test func logbookCommand() {
            let config = LogbookCommand.configuration
            #expect(config.commandName == "logbook")
            #expect(config.aliases.contains("l"))
        }

        @Test func anytimeCommand() {
            let config = AnytimeCommand.configuration
            #expect(config.commandName == "anytime")
        }

        @Test func projectsCommand() {
            let config = ProjectsCommand.configuration
            #expect(config.commandName == "projects")
        }

        @Test func areasCommand() {
            let config = AreasCommand.configuration
            #expect(config.commandName == "areas")
        }

        @Test func tagsCommand() {
            let config = TagsCommand.configuration
            #expect(config.commandName == "tags")
        }
    }

    @Suite("Mutation Commands")
    struct MutationCommands {
        @Test func completeCommand() {
            let config = CompleteCommand.configuration
            #expect(config.commandName == "complete")
            #expect(config.aliases.contains("done"))
        }

        @Test func cancelCommand() {
            let config = CancelCommand.configuration
            #expect(config.commandName == "cancel")
        }

        @Test func deleteCommand() {
            let config = DeleteCommand.configuration
            #expect(config.commandName == "delete")
            #expect(config.aliases.contains("rm"))
        }

        @Test func updateCommand() {
            let config = UpdateCommand.configuration
            #expect(config.commandName == "update")
            #expect(!config.discussion.isEmpty)
        }
    }

    @Suite("Add Command")
    struct AddCommandTests {
        @Test func configuration() {
            let config = AddCommand.configuration
            #expect(config.commandName == "add")
            #expect(!config.discussion.isEmpty)
        }

        @Test func discussionContainsExamples() {
            let config = AddCommand.configuration
            #expect(config.discussion.contains("clings add"))
            #expect(config.discussion.contains("#"))
        }
    }

    @Suite("Bulk Commands")
    struct BulkCommands {
        @Test func bulkCommand() {
            let config = BulkCommand.configuration
            #expect(config.commandName == "bulk")
            #expect(!config.subcommands.isEmpty)
        }

        @Test func bulkCompleteSubcommand() {
            let config = BulkCompleteCommand.configuration
            #expect(config.commandName == "complete")
        }

        @Test func bulkCancelSubcommand() {
            let config = BulkCancelCommand.configuration
            #expect(config.commandName == "cancel")
        }

        @Test func bulkTagSubcommand() {
            let config = BulkTagCommand.configuration
            #expect(config.commandName == "tag")
        }

        @Test func bulkMoveSubcommand() {
            let config = BulkMoveCommand.configuration
            #expect(config.commandName == "move")
        }
    }

    @Suite("Search Command")
    struct SearchCommandTests {
        @Test func configuration() {
            let config = SearchCommand.configuration
            #expect(config.commandName == "search")
        }
    }

    @Suite("Filter Command")
    struct FilterCommandTests {
        @Test func configuration() {
            let config = FilterCommand.configuration
            #expect(config.commandName == "filter")
        }
    }

    @Suite("Show Command")
    struct ShowCommandTests {
        @Test func configuration() {
            let config = ShowCommand.configuration
            #expect(config.commandName == "show")
        }
    }

    @Suite("Open Command")
    struct OpenCommandTests {
        @Test func configuration() {
            let config = OpenCommand.configuration
            #expect(config.commandName == "open")
        }
    }

    @Suite("Stats Command")
    struct StatsCommandTests {
        @Test func configuration() {
            let config = StatsCommand.configuration
            #expect(config.commandName == "stats")
        }
    }

    @Suite("Review Command")
    struct ReviewCommandTests {
        @Test func configuration() {
            let config = ReviewCommand.configuration
            #expect(config.commandName == "review")
        }
    }

    @Suite("Completions Command")
    struct CompletionsCommandTests {
        @Test func configuration() {
            let config = CompletionsCommand.configuration
            #expect(config.commandName == "completions")
        }
    }

    @Suite("All Commands Have Abstract")
    struct AllCommandsHaveAbstract {
        @Test func listCommands() {
            #expect(!TodayCommand.configuration.abstract.isEmpty)
            #expect(!InboxCommand.configuration.abstract.isEmpty)
            #expect(!UpcomingCommand.configuration.abstract.isEmpty)
            #expect(!AnytimeCommand.configuration.abstract.isEmpty)
            #expect(!SomedayCommand.configuration.abstract.isEmpty)
            #expect(!LogbookCommand.configuration.abstract.isEmpty)
            #expect(!ProjectsCommand.configuration.abstract.isEmpty)
            #expect(!AreasCommand.configuration.abstract.isEmpty)
            #expect(!TagsCommand.configuration.abstract.isEmpty)
        }

        @Test func mutationCommands() {
            #expect(!CompleteCommand.configuration.abstract.isEmpty)
            #expect(!CancelCommand.configuration.abstract.isEmpty)
            #expect(!DeleteCommand.configuration.abstract.isEmpty)
            #expect(!UpdateCommand.configuration.abstract.isEmpty)
        }

        @Test func bulkCommands() {
            #expect(!BulkCommand.configuration.abstract.isEmpty)
            #expect(!BulkCompleteCommand.configuration.abstract.isEmpty)
            #expect(!BulkCancelCommand.configuration.abstract.isEmpty)
            #expect(!BulkTagCommand.configuration.abstract.isEmpty)
            #expect(!BulkMoveCommand.configuration.abstract.isEmpty)
        }
    }
}
