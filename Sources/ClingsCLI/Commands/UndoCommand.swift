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
        Supported bulk status/tag writes are grouped. Project/tag management
        and changes made in Things itself are not recorded. Update undo restores title, notes, deadline, and tags;
        it does not restore scheduling, headings, or project moves.
        Failed reversals retain the entry and unreversed group members for retry.
        This is not a backup system.

        EXAMPLES:
          clings undo
          clings undo --show

        Supported operations:
          create     Cancels the newly created todo through automation
          update     Restores the previous snapshot
          complete   Restores the prior status
          cancel     Restores the prior status
          delete     Restores the prior status
        """
    )

    @Flag(name: .long, help: "Show the most recent undo entry without applying it")
    var show = false

    @OptionGroup var output: OutputOptions

    func run() async throws {
        if show {
            try await perform(); return
        }
        try await MutationLock.withLock { try await perform() }
    }

    private func perform() async throws {
        if show {
            guard let entry = try UndoStore.latest() else {
                print(renderMessage("No undo history available", output: output))
                return
            }
            print(renderUndoEntry(entry))
            return
        }

        guard var entry = try UndoStore.latest() else {
            print(renderMessage("Nothing to undo", output: output))
            return
        }

        let client = CommandRuntime.makeClient()
        if var members = entry.members {
            while let member = members.first {
                do {
                    if member.operation == .update {
                        try await client.updateTodo(id: member.snapshot.id, name: nil, notes: nil, dueDate: nil, tags: member.snapshot.tags)
                    } else {
                        switch member.snapshot.status {
                        case .open: try await client.reopenTodo(id: member.snapshot.id)
                        case .completed: try await client.completeTodo(id: member.snapshot.id)
                        case .canceled: try await client.cancelTodo(id: member.snapshot.id)
                        }
                    }
                } catch {
                    throw try CommandFailure(exitStatus: 2, code: "undo_partial", message: "Undo stopped; remaining members retained: \(error.localizedDescription)", dataJSON: payloadJSON(entry))
                }
                members.removeFirst()
                entry.members = members
                do { try UndoStore.replace(entry) }
                catch { throw try CommandFailure(exitStatus: 2, code: "undo_storage_failed", message: "Undo applied but journal update failed: \(error.localizedDescription)", dataJSON: payloadJSON(MutationOutcome(applied: true, undoRecorded: false, message: "Undo applied"))) }
            }
            do { try UndoStore.remove(id: entry.id) }
            catch { throw try CommandFailure(exitStatus: 2, code: "undo_storage_failed", message: "Undo applied but journal removal failed", dataJSON: payloadJSON(MutationOutcome(applied: true, undoRecorded: false, message: "Undo applied"))) }
            try printOutcome(MutationOutcome(applied: true, undoRecorded: false, message: "Undid grouped changes"), output: output)
            return
        }
        do {
            switch entry.operation {
            case .create:
                try await client.deleteTodo(id: entry.todoID)
            case .update:
                guard let snapshot = entry.snapshot else {
                    throw ValidationError("Undo entry is missing update snapshot data")
                }
                try await client.restoreTodo(snapshot)
            case .complete, .cancel, .delete:
                guard let snapshot = entry.snapshot else { throw ValidationError("Undo entry is missing prior status") }
                switch snapshot.status {
                case .open: try await client.reopenTodo(id: entry.todoID)
                case .completed: try await client.completeTodo(id: entry.todoID)
                case .canceled: try await client.cancelTodo(id: entry.todoID)
                }
            }
        } catch let error as AppliedMutationError {
            throw try CommandFailure(exitStatus: 2, code: "undo_partial", message: error.localizedDescription, dataJSON: payloadJSON(MutationOutcome(id: error.id, applied: true, undoRecorded: false, appliedFields: error.fields, message: "Undo partially applied; entry retained")))
        }
        do { try UndoStore.remove(id: entry.id) }
        catch { throw try CommandFailure(exitStatus: 2, code: "undo_storage_failed", message: "Undo applied but journal could not be updated", dataJSON: payloadJSON(MutationOutcome(applied: true, undoRecorded: false, message: "Undo applied"))) }
        try printOutcome(MutationOutcome(applied: true, undoRecorded: false, message: "Undid \(entry.operation.rawValue) for \(entry.todoID)"), output: output)
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
