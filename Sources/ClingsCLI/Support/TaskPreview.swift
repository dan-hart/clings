import Foundation

struct TaskPreview: Encodable {
    var id: String?
    var title: String
    var notes: String?
    var tags: [String]
    var project: String?
    var area: String?
    var when: Date?
    var deadline: Date?
    var scheduleExpression: String?
    var heading: String?
    var undo: String
    var checklistItems: [String] = []
    var unsupportedUndo: [String] = []

    func render(json: Bool) throws -> String {
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try CLIResponse.success(String(decoding: encoder.encode(self), as: UTF8.self))
        }
        let formatter = ISO8601DateFormatter()
        return """
        Parsed Task
          Title: \(title)
          Notes: \(notes ?? "")
          Tags: \(tags.joined(separator: " "))
          Project: \(project ?? "")
          Area: \(area ?? "")
          When: \(when.map { formatter.string(from: $0) } ?? scheduleExpression ?? "")
          Deadline: \(deadline.map { formatter.string(from: $0) } ?? "")
          Heading: \(heading ?? "")
          Checklist: \(checklistItems.joined(separator: ", "))
          Undo: \(undo)
        """
    }
}
