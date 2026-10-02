import ClingsCore
import Foundation

func renderBatchPlan(_ plan: BatchPlan) -> String {
    var lines = ["Frozen \(plan.operation.rawValue) plan: \(plan.items.count) exact IDs"]
    for item in plan.items {
        lines.append("  [\(item.id)] \(item.snapshot.name.debugDescription)")
        switch plan.operation {
        case .complete, .cancel:
            lines.append("    status: \(item.snapshot.status.rawValue) -> \(item.final.status.rawValue)")
        case .tag:
            lines.append("    tags: [\(item.snapshot.tags.sorted().joined(separator: ", "))] -> [\(item.final.tags.sorted().joined(separator: ", "))]")
        case .move:
            lines.append("    project ID: \(item.snapshot.projectID ?? "none") -> \(item.final.projectID ?? "none")")
        }
        lines.append("    result: \(item.state.rawValue); applied: \(item.applied); undo recorded: \(item.undoRecorded)")
        if let error = item.error {
            lines.append("    error: \(error.debugDescription)")
        }
    }
    if !plan.unsupportedUndo.isEmpty {
        lines.append("Warning: undo cannot restore \(plan.unsupportedUndo.joined(separator: ", ")).")
    }
    return lines.joined(separator: "\n")
}

func runBatch(operation: BatchOperation, list: String?, tags: String? = nil, destination: String? = nil, options: BulkOptions) async throws {
    if options.dryRun {
        try await executeBatch(operation: operation, list: list, tags: tags, destination: destination, options: options)
        return
    }
    try await MutationLock.withPlanLock(path: options.executePlan) {
        try await MutationLock.withLock {
            try await executeBatch(operation: operation, list: list, tags: tags, destination: destination, options: options)
        }
    }
}

private func executeBatch(operation: BatchOperation, list: String?, tags: String?, destination: String?, options: BulkOptions) async throws {
    let client = CommandRuntime.makeClient()
    var plan: BatchPlan
    let path: String
    if let source = options.executePlan {
        guard list == nil, options.where == nil, tags == nil, destination == nil, !options.dryRun else {
            throw CommandFailure(exitStatus: 1, code: "plan_options_mismatch", message: "--execute-plan cannot be combined with selection/change flags or --dry-run")
        }
        do { plan = try BatchPlan.load(path: source) }
        catch { throw CommandFailure(exitStatus: 1, code: "invalid_plan", message: "Cannot read plan: \(error.localizedDescription)") }
        guard plan.operation == operation else { throw CommandFailure(exitStatus: 1, code: "plan_operation_mismatch", message: "Plan operation does not match command") }
        path = URL(fileURLWithPath: source).standardizedFileURL.resolvingSymlinksInPath().path
    } else {
        guard let scope = ListView(rawValue: (list ?? "today").lowercased()) else { throw CommandFailure(exitStatus: 1, code: "invalid_list", message: "Unknown list") }
        let filter = try options.where.map { try FilterParser.parse($0) }
        let todos = try uniqueTodos(await client.fetchQueryList(scope)).filter { filter?.matches($0) ?? true }
        let tagNames = tags?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var projectID: String?
        if let destination {
            let matches = try await client.fetchProjects().filter { $0.id == destination || $0.name == destination }
            guard matches.count == 1, let project = matches.first else { throw CommandFailure(exitStatus: 1, code: "ambiguous_project", message: "Destination must identify exactly one project") }
            projectID = project.id
        }
        plan = BatchPlan(operation: operation, todos: todos, tags: tagNames, projectID: projectID)
        path = options.dryRun ? "" : try ClingsConfig.fileURL(named: "batch-\(plan.id).json").path
    }
    do { try plan.validate() }
    catch { throw CommandFailure(exitStatus: 1, code: "invalid_plan", message: error.localizedDescription) }
    if options.dryRun {
        try print(options.output.json ? payloadJSON(plan) : "[DRY RUN] No changes made\n\(renderBatchPlan(plan))")
        return
    }
    if options.yes {
        warnUnsupported(plan.unsupportedUndo)
    } else {
        writeStderr(renderBatchPlan(plan) + "\n")
    }
    guard !plan.items.isEmpty else { try print(options.output.json ? payloadJSON(plan) : "No todos match the criteria"); return }
    guard try confirmMutation("Apply \(operation.rawValue) plan to \(plan.items.count) exact IDs?", authorized: options.yes) else {
        try print(options.output.json ? payloadJSON(plan) : "Aborted; no changes made")
        return
    }

    var entry = try UndoStore.list().first { $0.todoID == plan.id } ?? UndoEntry(operation: .update, todoID: plan.id, snapshot: nil, createdAt: plan.createdAt)
    entry.members = entry.members ?? []

    func save() throws {
        do { try CommandRuntime.persistPlan(plan, path) }
        catch { throw try CommandFailure(exitStatus: 2, code: "plan_storage_failed", message: "Stopped because plan persistence failed: \(error.localizedDescription)", dataJSON: payloadJSON(plan)) }
    }

    func recordMember(_ item: BatchPlanItem) throws {
        guard operation != .move else { return }
        if entry.members?.contains(where: { $0.snapshot.id == item.id }) != true {
            entry.members?.append(UndoMember(operation: operation == .complete ? .complete : operation == .cancel ? .cancel : .update, snapshot: item.snapshot))
        }
        try UndoStore.replace(entry)
    }

    func reconcileUndo(at index: Int) throws {
        do {
            try recordMember(plan.items[index])
            plan.items[index].undoRecorded = operation != .move
            plan.items[index].error = nil
        } catch {
            plan.items[index].undoRecorded = false
            plan.items[index].error = "Applied but undo journal reconciliation failed: \(error.localizedDescription)"
            try save()
            throw try CommandFailure(exitStatus: 2, code: "undo_storage_failed", message: "Applied but undo journal reconciliation failed", dataJSON: payloadJSON(plan))
        }
    }

    // Validate all candidates before any write; do not rely on Todo's ID-only equality.
    for index in plan.items.indices where plan.items[index].state != .succeeded || (operation != .move && !plan.items[index].undoRecorded) {
        do {
            // A known successful write needs only its missing journal record repaired.
            // Do not turn it back into a pending API operation, even after later edits.
            if plan.items[index].state == .succeeded {
                try reconcileUndo(at: index)
                continue
            }
            let current = try await client.fetchTodo(id: plan.items[index].id)
            let item = plan.items[index]
            if [.inProgress, .uncertain, .failed].contains(item.state), plan.finalMatches(current, item: item) {
                plan.items[index].state = .succeeded
                plan.items[index].applied = true
                try reconcileUndo(at: index)
            } else if !item.snapshot.matches(current) {
                plan.items[index].state = .conflict
                plan.items[index].error = "Current fields differ from expected snapshot"
            } else {
                plan.items[index].state = .pending
                plan.items[index].error = nil
            }
        } catch let failure as CommandFailure {
            throw failure
        } catch {
            plan.items[index].state = .failed
            plan.items[index].error = error.localizedDescription
        }
    }
    try save()
    guard !plan.items.contains(where: { $0.state == .conflict || $0.state == .failed }) else {
        let stale = plan.items.contains { $0.state == .conflict }
        throw try CommandFailure(exitStatus: stale ? 1 : 2, code: stale ? "stale_plan" : "plan_read_failed", message: "Plan validation failed; inspect every item result before retrying", dataJSON: payloadJSON(plan))
    }
    for index in plan.items.indices where plan.items[index].state == .pending {
        plan.items[index].state = .inProgress
        try save() // Durable intent precedes the API write.
        do {
            let item = plan.items[index]
            switch operation {
            case .complete: try await client.completeTodo(id: item.id)
            case .cancel: try await client.cancelTodo(id: item.id)
            case .tag: try await client.updateTodo(id: item.id, name: nil, notes: nil, dueDate: nil, tags: item.final.tags)
            case .move: guard let projectID = plan.projectID else { throw ThingsError.invalidState("Missing destination ID") }; try await client.moveTodo(id: item.id, toProjectID: projectID)
            }
        } catch {
            plan.items[index].state = error is AppliedMutationError ? .uncertain : .failed
            plan.items[index].applied = error is AppliedMutationError
            plan.items[index].error = error.localizedDescription
            try save()
            continue
        }
        plan.items[index].state = .succeeded
        plan.items[index].applied = true
        do {
            try recordMember(plan.items[index])
            plan.items[index].undoRecorded = operation != .move
        } catch {
            plan.items[index].error = "Applied, but undo journal failed: \(error.localizedDescription)"
            try save()
            throw try CommandFailure(exitStatus: 2, code: "undo_storage_failed", message: plan.items[index].error ?? "Undo storage failed", dataJSON: payloadJSON(plan))
        }
        do { try save() }
        catch {
            plan.items[index].state = .uncertain
            plan.items[index].error = "Write applied but outcome persistence failed"
            throw try CommandFailure(exitStatus: 2, code: "plan_storage_failed", message: "Write applied but outcome persistence failed; reconcile on resume", dataJSON: payloadJSON(plan))
        }
    }
    if plan.items.contains(where: { $0.state != .succeeded }) {
        throw try CommandFailure(exitStatus: 2, code: "batch_partial", message: "Some batch items failed; results retained for retry", dataJSON: payloadJSON(plan))
    }
    try print(options.output.json ? payloadJSON(plan) : "Applied \(operation.rawValue): \(plan.items.count) items. Plan: \(path)")
}
