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
            #expect(!config.version.isEmpty)
        }

        @Test func subcommands() {
            let config = Clings.configuration
            #expect(!config.subcommands.isEmpty)
        }

        @Test func includesNewTopLevelCommands() {
            let subcommandNames = Set(Clings.configuration.subcommands.map { $0.configuration.commandName })
            #expect(subcommandNames.contains("doctor"))
            #expect(subcommandNames.contains("views"))
            #expect(subcommandNames.contains("template"))
            #expect(subcommandNames.contains("undo"))
            #expect(subcommandNames.contains("focus"))
            #expect(subcommandNames.contains("pick"))
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
            #expect(config.discussion.contains("EXAMPLES:"))
            #expect(config.discussion.contains("clings add"))
            #expect(config.discussion.contains("#"))
        }
    }

    @Suite("Help Text")
    struct HelpText {
        @Test func keyCommandsIncludeExamplesInDiscussion() {
            let discussions: [(String, String)] = [
                ("clings", Clings.configuration.discussion),
                ("add", AddCommand.configuration.discussion),
                ("stats", StatsCommand.configuration.discussion),
                ("doctor", DoctorCommand.configuration.discussion),
                ("focus", FocusCommand.configuration.discussion),
                ("undo", UndoCommand.configuration.discussion),
                ("views", ViewsCommand.configuration.discussion),
                ("views list", ViewsListCommand.configuration.discussion),
                ("views save", ViewsSaveCommand.configuration.discussion),
                ("views run", ViewsRunCommand.configuration.discussion),
                ("views delete", ViewsDeleteCommand.configuration.discussion),
                ("template", TemplateCommand.configuration.discussion),
                ("template list", TemplateListCommand.configuration.discussion),
                ("template save", TemplateSaveCommand.configuration.discussion),
                ("template run", TemplateRunCommand.configuration.discussion),
                ("template delete", TemplateDeleteCommand.configuration.discussion),
                ("pick", PickCommand.configuration.discussion),
                ("pick show", PickShowCommand.configuration.discussion),
                ("pick complete", PickCompleteCommand.configuration.discussion),
                ("pick cancel", PickCancelCommand.configuration.discussion),
                ("pick delete", PickDeleteCommand.configuration.discussion),
                ("review", ReviewCommand.configuration.discussion),
                ("review start", ReviewStartCommand.configuration.discussion),
                ("review status", ReviewStatusCommand.configuration.discussion),
                ("review clear", ReviewClearCommand.configuration.discussion),
                ("project list", ProjectListCommand.configuration.discussion),
                ("project audit", ProjectAuditCommand.configuration.discussion),
                ("tags list", TagsListCommand.configuration.discussion),
                ("completions", CompletionsCommand.configuration.discussion),
                ("config set-auth-token", SetAuthToken.configuration.discussion),
            ]

            for (name, discussion) in discussions {
                #expect(!discussion.isEmpty, "\(name) should include detailed help text")
                #expect(discussion.contains("EXAMPLES:"), "\(name) should include examples")
            }
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

    @Suite("New Commands")
    struct NewCommands {
        @Test func doctorCommand() {
            let config = DoctorCommand.configuration
            #expect(config.commandName == "doctor")
        }

        @Test func viewsCommand() {
            let config = ViewsCommand.configuration
            #expect(config.commandName == "views")
            #expect(!config.subcommands.isEmpty)
        }

        @Test func templateCommand() {
            let config = TemplateCommand.configuration
            #expect(config.commandName == "template")
            #expect(!config.subcommands.isEmpty)
        }

        @Test func undoCommand() {
            let config = UndoCommand.configuration
            #expect(config.commandName == "undo")
        }

        @Test func focusCommand() {
            let config = FocusCommand.configuration
            #expect(config.commandName == "focus")
        }

        @Test func pickCommand() {
            let config = PickCommand.configuration
            #expect(config.commandName == "pick")
            #expect(!config.subcommands.isEmpty)
        }

        @Test func projectAuditCommand() {
            let config = ProjectAuditCommand.configuration
            #expect(config.commandName == "audit")
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
