// TagCommands.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore

// MARK: - Tags Command (Parent)

struct TagsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tags",
        abstract: "Manage tags",
        discussion: """
        List, create, rename, and delete tags in Things 3.

        Tags allow cross-cutting organization across projects and areas.
        Common uses include:
        - Context (e.g., @phone, @computer, @errands)
        - Priority (e.g., urgent, important)
        - Time needed (e.g., 5min, 30min)

        EXAMPLES:
          clings tags                   List all tags
          clings tags list              Same as above
          clings tags add "NewTag"      Create a new tag
          clings tags delete "OldTag"   Delete a tag
          clings tags rename "Old" "New" Rename a tag

        SEE ALSO:
          add --tags, filter, bulk tag
        """,
        subcommands: [
            TagsListCommand.self,
            TagsAddCommand.self,
            TagsDeleteCommand.self,
            TagsRenameCommand.self,
        ],
        defaultSubcommand: TagsListCommand.self
    )
}

// MARK: - Tags List Command

struct TagsListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all tags",
        aliases: ["ls"]
    )

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let client = ThingsClientFactory.create()
        let tags = try await client.fetchTags()

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(tags: tags))
    }
}

// MARK: - Tags Add Command

struct TagsAddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Create a new tag",
        discussion: """
        Creates a new tag in Things 3.

        EXAMPLES:
          clings tags add "urgent"
          clings tags add "@phone"
          clings tags add "5min" --json
        """
    )

    @Argument(help: "Name of the tag to create")
    var name: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        // Validate name is not empty
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ThingsError.invalidState("Tag name cannot be empty")
        }

        let client = ThingsClientFactory.create()
        let tag = try await client.createTag(name: trimmedName)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        if output.json {
            print(formatter.format(tags: [tag]))
        } else {
            print(formatter.format(message: "Created tag: \(tag.name)"))
        }
    }
}

// MARK: - Tags Delete Command

struct TagsDeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a tag",
        discussion: """
        Deletes a tag from Things 3.

        WARNING: This will remove the tag from all todos that have it.
        Use --force to skip the confirmation prompt.

        EXAMPLES:
          clings tags delete "old-tag"
          clings tags delete "temp" --force
        """,
        aliases: ["rm"]
    )

    @Argument(help: "Name of the tag to delete")
    var name: String

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ThingsError.invalidState("Tag name cannot be empty")
        }

        // Confirmation unless --force
        if !force {
            print("Delete tag '\(trimmedName)'? This will remove it from all todos. [y/N] ", terminator: "")
            guard let response = readLine()?.lowercased(),
                  response == "y" || response == "yes" else {
                print("Cancelled")
                return
            }
        }

        let client = ThingsClientFactory.create()
        try await client.deleteTag(name: trimmedName)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Deleted tag: \(trimmedName)"))
    }
}

// MARK: - Tags Rename Command

struct TagsRenameCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rename",
        abstract: "Rename a tag",
        discussion: """
        Renames an existing tag in Things 3.

        All todos with the old tag name will automatically have the new name.

        EXAMPLES:
          clings tags rename "old-name" "new-name"
          clings tags rename "@phone" "@calls"
        """,
        aliases: ["mv"]
    )

    @Argument(help: "Current name of the tag")
    var oldName: String

    @Argument(help: "New name for the tag")
    var newName: String

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let trimmedOld = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOld.isEmpty else {
            throw ThingsError.invalidState("Old tag name cannot be empty")
        }
        guard !trimmedNew.isEmpty else {
            throw ThingsError.invalidState("New tag name cannot be empty")
        }
        guard trimmedOld != trimmedNew else {
            throw ThingsError.invalidState("Old and new names are the same")
        }

        let client = ThingsClientFactory.create()
        try await client.renameTag(oldName: trimmedOld, newName: trimmedNew)

        let formatter: OutputFormatter = output.json
            ? JSONOutputFormatter()
            : TextOutputFormatter(useColors: !output.noColor)

        print(formatter.format(message: "Renamed tag: \(trimmedOld) -> \(trimmedNew)"))
    }
}
