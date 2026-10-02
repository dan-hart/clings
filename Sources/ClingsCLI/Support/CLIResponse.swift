import ArgumentParser
import ClingsCore
import Foundation

/// Wrap JSON at the CLI boundary only. Inserting the already encoded payload
/// retains exact batch snapshot timestamps instead of round-tripping numbers.
enum CLIResponse {
    static func success(_ payload: String) -> String {
        "{\"schemaVersion\":1,\"success\":true,\"data\":\(payload)}"
    }

    static func failure(_ failure: CommandFailure) -> String {
        struct ErrorPayload: Encodable { let code: String; let message: String }
        // Strings are always JSON encodable; this fallback is itself actionable.
        let error = (try? JSONEncoder().encode(ErrorPayload(code: failure.code, message: failure.message)))
            .map { String(decoding: $0, as: UTF8.self) } ?? "{\"code\":\"encoding_failed\",\"message\":\"Cannot encode error\"}"
        return "{\"schemaVersion\":1,\"success\":false,\"data\":\(failure.dataJSON ?? "null"),\"error\":\(error)}"
    }

    static func render(_ payload: String, output: OutputOptions) -> String {
        output.json ? success(payload) : payload
    }
}

/// Shared production entry point with an exit status return for embedders/tests.
enum CommandBoundary {
    static func wantsJSON(_ arguments: [String]) -> Bool {
        arguments.prefix { $0 != "--" }.contains("--json")
    }

    static func classify(_ error: Error) -> CommandFailure {
        if let failure = error as? CommandFailure {
            return failure
        }
        if let error = error as? AppliedMutationError {
            let result = MutationOutcome(id: error.id, applied: true, undoRecorded: false, unsupportedUndo: ["this operation is not recorded for undo"], appliedFields: error.fields, message: error.localizedDescription)
            return CommandFailure(exitStatus: 2, code: "mutation_partial", message: error.localizedDescription, dataJSON: try? payloadJSON(result))
        }
        if let error = error as? ThingsError {
            switch error {
            case .invalidState: return CommandFailure(exitStatus: 1, code: "invalid_input", message: error.localizedDescription)
            case .notFound: return CommandFailure(exitStatus: 1, code: "not_found", message: error.localizedDescription)
            case .operationFailed, .jxaError: return CommandFailure(exitStatus: 2, code: "runtime_error", message: error.localizedDescription)
            }
        }
        if error is FilterParseError || error is ValidationError || Clings.exitCode(for: error) == .validationFailure {
            return CommandFailure(exitStatus: 1, code: "invalid_input", message: Clings.message(for: error))
        }
        return CommandFailure(exitStatus: 2, code: "runtime_error", message: error.localizedDescription)
    }

    static func execute(_ arguments: [String]) async -> Int32 {
        do {
            var command = try await Clings.asyncParseAsRoot(arguments)
            if var command = command as? any AsyncParsableCommand {
                try await command.run()
            } else {
                try command.run()
            }
            return 0
        } catch {
            if Clings.exitCode(for: error).isSuccess {
                let message = Clings.fullMessage(for: error)
                if !message.isEmpty {
                    print(message)
                }
                return 0
            }
            let failure = classify(error)
            if wantsJSON(arguments) {
                print(CLIResponse.failure(failure))
            } else {
                writeStderr("Error: \(failure.message)\n")
            }
            return failure.exitStatus
        }
    }
}
