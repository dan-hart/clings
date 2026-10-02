import ArgumentParser
import ClingsCore
import Foundation

/// Completion reads names only: no config initialization, Things reads, or writes.
enum SavedNameCompletion {
    static var viewKind: CompletionKind { .custom { _, _, _ in views() } }
    static var templateKind: CompletionKind { .custom { _, _, _ in templates() } }

    static func views() -> [String] { names(in: "saved-views.json") }
    static func templates() -> [String] { names(in: "templates.json") }

    private static func names(in filename: String) -> [String] {
        struct Name: Decodable { let name: String }
        let url = ClingsConfig.directoryURL.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let definitions = try? JSONDecoder().decode([Name].self, from: data) else { return [] }
        // The pinned Bash generator passes custom candidates through compgen -W,
        // which expands shell substitutions. Omit metacharacter-bearing names
        // rather than evaluating them or changing their literal spelling.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_."))
        let names = definitions.map(\.name).filter {
            !$0.isEmpty && $0.unicodeScalars.allSatisfy { allowed.contains($0) }
        }
        return Array(Set(names)).sorted()
    }
}
