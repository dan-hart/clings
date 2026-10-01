import ArgumentParser
import ClingsCore
import Foundation

struct QueryOptions: ParsableArguments {
    @Option(name: .long, help: "Scope to a Things list: today, inbox, upcoming, anytime, someday, logbook, trash")
    var list: String?
    @Flag(name: .long, help: "Include completed and canceled tasks from Logbook")
    var includeLogbook = false
    @Option(name: .long, parsing: .unconditional, help: "Sort by id, name, due, when, created, modified; prefix with - for descending")
    var sort: String?
    @Option(name: .long, help: "Maximum results (positive integer)")
    var limit: Int?

    mutating func validate() throws {
        if let list, ListView(rawValue: list.lowercased()) == nil {
            throw ValidationError("Unknown list: \(list)")
        }
        if let limit, limit <= 0 {
            throw ValidationError("--limit must be positive")
        }
        if let sort, !["id", "name", "due", "when", "created", "modified"].contains(sort.hasPrefix("-") ? String(sort.dropFirst()) : sort) {
            throw ValidationError("Unknown sort: \(sort). Use id, name, due, when, created, or modified.")
        }
    }

    func fetch(client: any ThingsClientProtocol) async throws -> [Todo] {
        if let list, let scope = ListView(rawValue: list.lowercased()) {
            var todos = try await client.fetchList(scope)
            if includeLogbook && scope != .logbook {
                todos += try await client.fetchList(.logbook)
            }
            return uniqueTodos(todos)
        }
        return try await fetchVisibleTodos(client: client, includeLogbook: includeLogbook)
    }

    func apply(_ todos: [Todo]) -> [Todo] {
        var result = uniqueTodos(todos)
        if let sort {
            let descending = sort.hasPrefix("-")
            let field = descending ? String(sort.dropFirst()) : sort
            result.sort { lhs, rhs in
                let comparison: ComparisonResult
                switch field {
                case "name": comparison = lhs.name.lowercased().compare(rhs.name.lowercased())
                case "id": comparison = lhs.id.compare(rhs.id)
                default:
                    func date(_ todo: Todo) -> Date? {
                        switch field {
                        case "due": return todo.dueDate
                        case "when": return todo.scheduledDate
                        case "created": return todo.creationDate
                        default: return todo.modificationDate
                        }
                    }
                    let left = date(lhs), right = date(rhs)
                    if left == nil, right != nil {
                        return false
                    }
                    if left != nil, right == nil {
                        return true
                    }
                    comparison = left.flatMap { l in right.map { l.compare($0) } } ?? .orderedSame
                }
                if comparison == .orderedSame {
                    return lhs.id < rhs.id
                }
                return descending ? comparison == .orderedDescending : comparison == .orderedAscending
            }
        }
        return limit.map { Array(result.prefix($0)) } ?? result
    }
}
