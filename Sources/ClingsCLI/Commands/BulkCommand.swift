import ArgumentParser
import ClingsCore

struct BulkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bulk", abstract: "Bulk operations on multiple todos",
        discussion: "Preview schema-versioned exact-ID plans with --dry-run --json. Save the plan locally, then use --execute-plan PATH --yes. Writes are sequential; successes are never retried. Status and tag changes support grouped undo; project moves do not.",
        subcommands: [BulkCompleteCommand.self, BulkCancelCommand.self, BulkTagCommand.self, BulkMoveCommand.self]
    )
}

struct BulkOptions: ParsableArguments {
    @Option(name: .long, help: "Filter expression scoped to the selected list")
    var `where`: String?
    @Flag(name: .long, help: "Preview a reusable plan without writing")
    var dryRun = false
    @Flag(name: [.customShort("y"), .long], help: "Authorize the whole plan without prompting")
    var yes = false
    @Option(name: .long, help: "Execute or resume a saved exact-ID plan")
    var executePlan: String?
    @OptionGroup var output: OutputOptions
}

struct BulkCompleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "complete", abstract: "Mark multiple todos as completed")
    @OptionGroup var bulkOptions: BulkOptions
    @Option(name: .long, help: "Source list (default: today)")
    var list: String?
    func run() async throws {
        try await runBatch(operation: .complete, list: list, options: bulkOptions)
    }
}

struct BulkCancelCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "cancel", abstract: "Cancel multiple todos")
    @OptionGroup var bulkOptions: BulkOptions
    @Option(name: .long, help: "Source list (default: today)")
    var list: String?
    func run() async throws {
        try await runBatch(operation: .cancel, list: list, options: bulkOptions)
    }
}

struct BulkTagCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tag", abstract: "Add tags to multiple todos")
    @Argument(help: "Comma-separated tags; omit when executing a plan")
    var tags: String?
    @OptionGroup var bulkOptions: BulkOptions
    @Option(name: .long, help: "Source list (default: today)")
    var list: String?
    mutating func validate() throws {
        if tags == nil, bulkOptions.executePlan == nil {
            throw ValidationError("Provide tags or --execute-plan")
        }
    }

    func run() async throws {
        try await runBatch(operation: .tag, list: list, tags: tags, options: bulkOptions)
    }
}

struct BulkMoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "move", abstract: "Move multiple todos to a project")
    @Option(name: .long, help: "Exact destination project ID or unambiguous name; omit when executing a plan")
    var to: String?
    @OptionGroup var bulkOptions: BulkOptions
    @Option(name: .long, help: "Source list (default: today)")
    var list: String?
    mutating func validate() throws {
        if to == nil, bulkOptions.executePlan == nil {
            throw ValidationError("Provide --to or --execute-plan")
        }
    }

    func run() async throws {
        try await runBatch(operation: .move, list: list, destination: to, options: bulkOptions)
    }
}

func filterTodos(_ todos: [Todo], with clause: String) throws -> [Todo] {
    let filter = try FilterParser.parse(clause)
    return todos.filter { filter.matches($0) }
}
