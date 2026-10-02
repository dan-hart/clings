import ClingsCore
import Foundation

struct CommandFailure: LocalizedError {
    let exitStatus: Int32
    let code: String
    let message: String
    var dataJSON: String? = nil
    var errorDescription: String? {
        message
    }
}

struct MutationOutcome: Codable {
    var id: String? = nil
    var applied: Bool
    var undoRecorded: Bool
    var unsupportedUndo: [String] = []
    var appliedFields: [String] = []
    var message: String
}

func payloadJSON<T: Encodable>(_ value: T) throws -> String {
    try String(decoding: StateJSON.encoder().encode(value), as: UTF8.self)
}

func printOutcome(_ outcome: MutationOutcome, output: OutputOptions) throws {
    try print(output.json ? payloadJSON(outcome) : outcome.message)
}

func recordApplied(_ entry: UndoEntry, message: String, unsupported: [String] = []) throws -> MutationOutcome {
    do { try UndoStore.record(entry) }
    catch {
        let result = MutationOutcome(id: entry.todoID, applied: true, undoRecorded: false, unsupportedUndo: unsupported, message: message)
        throw try CommandFailure(exitStatus: 2, code: "undo_storage_failed", message: "Change applied, but undo could not be recorded: \(error.localizedDescription)", dataJSON: payloadJSON(result))
    }
    return MutationOutcome(id: entry.todoID, applied: true, undoRecorded: true, unsupportedUndo: unsupported, message: message)
}

func reportPartial(_ error: AppliedMutationError, entry: UndoEntry) throws -> Never {
    var outcome = try recordApplied(entry, message: error.localizedDescription)
    outcome.appliedFields = error.fields
    throw try CommandFailure(exitStatus: 2, code: "mutation_partial", message: error.localizedDescription, dataJSON: payloadJSON(outcome))
}

func writeStderr(_ text: String) {
    FileHandle.standardError.write(Data(text.utf8))
}

func confirmMutation(_ prompt: String, authorized: Bool) throws -> Bool {
    if authorized {
        return true
    }
    guard CommandRuntime.isTerminal() else {
        throw CommandFailure(exitStatus: 1, code: "confirmation_required", message: "Noninteractive writes require explicit confirmation (--force or --yes).")
    }
    writeStderr(prompt + " [y/N]: ")
    return ["y", "yes"].contains(CommandRuntime.inputReader()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "")
}

func warnUnsupported(_ fields: [String]) {
    if !fields.isEmpty {
        writeStderr("Warning: undo cannot restore \(fields.joined(separator: ", ")).\n")
    }
}
