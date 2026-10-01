// UndoCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation

struct UndoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "undo",
        abstract: "Undo the most recent supported mutation",
        discussion: """
        Reverses the most recent supported write operation recorded by clings.

        Inspect --show first. History keeps up to 20 entries in local config.
        Bulk writes, project/tag management, and changes made in Things itself
        are not recorded. Update undo restores title, notes, deadline, and tags;
        it does not restore scheduling, headings, or project moves.
        Undo removes the history entry before attempting the reversal; a failed
        reversal cannot be retried from that entry. It is not a backup system.

        EXAMPLES:
          clings undo
          clings undo --show

        Supported operations:
          create     Cancels the newly created todo through automation
          update     Restores the previous snapshot
          complete   Reopens the todo
          cancel     Reopens the todo
          delete     Reopens the todo
        """
    )

    @Flag(name: .long, help: "Show the most recent undo entry without applying it")
    var show = false

    @OptionGroup var output: OutputOptions

    func run() async throws {
        if show {
            guard let entry = try UndoStore.latest() else {
                print(renderMessage("No undo history available", output: output))
                return
            }
            print(renderUndoEntry(entry))
            return
        }

        guard let entry = try UndoStore.popLatest() else {
            print(renderMessage("Nothing to undo", output: output))
            return
        }

        let client = CommandRuntime.makeClient()
        switch entry.operation {
        case .create:
            try await client.deleteTodo(id: entry.todoID)
        case .update:
            guard let snapshot = entry.snapshot else {
                throw ValidationError("Undo entry is missing update snapshot data")
            }
            try await client.updateTodo(
                id: entry.todoID,
                name: snapshot.name,
                notes: snapshot.notes,
                dueDate: snapshot.dueDate,
                tags: snapshot.tags
            )
        case .complete, .cancel, .delete:
            try await client.reopenTodo(id: entry.todoID)
        }

        print(renderMessage("Undid \(entry.operation.rawValue) for \(entry.todoID)", output: output))
    }

    private func renderUndoEntry(_ entry: UndoEntry) -> String {
        if output.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try? encoder.encode(entry)
            return String(data: data ?? Data("{}".utf8), encoding: .utf8) ?? "{}"
        }

        return "Latest undo: \(entry.operation.rawValue) \(entry.todoID)"
    }
}
