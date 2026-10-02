import Foundation

public enum BatchOperation: String, Codable, Sendable { case complete, cancel, tag, move }
public enum BatchItemState: String, Codable, Sendable { case pending, inProgress, succeeded, failed, uncertain, conflict }

public struct BatchPlanItem: Codable, Sendable {
    public var id: String
    public var snapshot: TodoSnapshot
    public var final: TodoSnapshot
    public var state: BatchItemState = .pending
    public var error: String? = nil
    public var undoRecorded: Bool = false
    public var applied: Bool = false
    public init(snapshot: TodoSnapshot, final: TodoSnapshot) {
        id = snapshot.id; self.snapshot = snapshot; self.final = final
    }
}

public struct BatchPlan: Codable, Sendable {
    public var schemaVersion = 1
    public var id = UUID().uuidString
    public var operation: BatchOperation
    public var createdAt = Date()
    public var items: [BatchPlanItem]
    public var projectID: String?
    public var tags: [String]?
    public var unsupportedUndo: [String]
    public init(operation: BatchOperation, todos: [Todo], tags: [String]? = nil, projectID: String? = nil) {
        self.operation = operation; self.tags = tags; self.projectID = projectID
        unsupportedUndo = operation == .move ? ["project move"] : []
        items = todos.map { todo in
            let snapshot = TodoSnapshot(todo: todo)
            var final = snapshot
            switch operation {
            case .complete: final = snapshot.withStatus(.completed)
            case .cancel: final = snapshot.withStatus(.canceled)
            case .tag: final = snapshot.withTags(Array(Set(snapshot.tags + (tags ?? []))).sorted())
            case .move: final.projectID = projectID
            }
            return BatchPlanItem(snapshot: snapshot, final: final)
        }
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw ThingsError.invalidState("Unsupported batch plan schema") }
        guard Set(items.map(\.id)).count == items.count else { throw ThingsError.invalidState("Duplicate batch plan IDs") }
        guard operation != .move || projectID?.isEmpty == false else { throw ThingsError.invalidState("Move plan requires exact project ID") }
        guard operation != .tag || tags?.isEmpty == false else { throw ThingsError.invalidState("Tag plan requires tags") }
        for item in items {
            guard item.id == item.snapshot.id, item.id == item.final.id else { throw ThingsError.invalidState("Mismatched plan item ID") }
            var expected = item.snapshot
            switch operation {
            case .complete: expected = expected.withStatus(.completed)
            case .cancel: expected = expected.withStatus(.canceled)
            case .tag: expected = expected.withTags(Array(Set(expected.tags + (tags ?? []))).sorted())
            case .move: expected.projectID = projectID
            }
            guard expected == item.final else { throw ThingsError.invalidState("Plan final changes do not match operation") }
        }
    }

    public func finalMatches(_ todo: Todo, item: BatchPlanItem) -> Bool {
        switch operation {
        case .complete, .cancel: return todo.status == item.final.status
        case .tag: return Set(todo.tags.map(\.name)) == Set(item.final.tags)
        case .move: return todo.project?.id == projectID
        }
    }

    public static func load(path: String) throws -> BatchPlan {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = object?["data"].map { try? JSONSerialization.data(withJSONObject: $0) } ?? nil
        return try StateJSON.decoder().decode(BatchPlan.self, from: payload ?? data)
    }

    public func save(path: String) throws {
        try StateJSON.encoder().encode(self).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

public extension TodoSnapshot {
    func matches(_ todo: Todo) -> Bool {
        self == TodoSnapshot(todo: todo)
    }

    func withStatus(_ status: Status) -> TodoSnapshot {
        var snapshot = TodoSnapshot(id: id, name: name, notes: notes, dueDate: dueDate, tags: tags, status: status, projectName: projectName, areaName: areaName)
        snapshot.projectID = projectID; snapshot.areaID = areaID; snapshot.scheduledDate = scheduledDate
        snapshot.creationDate = creationDate; snapshot.modificationDate = modificationDate
        return snapshot
    }

    func withTags(_ tags: [String]) -> TodoSnapshot {
        var snapshot = TodoSnapshot(id: id, name: name, notes: notes, dueDate: dueDate, tags: tags, status: status, projectName: projectName, areaName: areaName)
        snapshot.projectID = projectID; snapshot.areaID = areaID; snapshot.scheduledDate = scheduledDate
        snapshot.creationDate = creationDate; snapshot.modificationDate = modificationDate
        return snapshot
    }
}
