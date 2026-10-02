import Darwin
import Foundation

/// One nonblocking interprocess lock spans mutation execution and journal updates.
public enum MutationLock {
    @TaskLocal private static var held = false

    public static func withPlanLock<T>(path: String?, _ body: () async throws -> T) async throws -> T {
        guard let path else { return try await body() }
        let companion = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path + ".lock"
        let descriptor = open(companion, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw ThingsError.operationFailed("Cannot open batch plan lock") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { close(descriptor); throw ThingsError.operationFailed("Another process is executing this plan") }
        defer { close(descriptor) }
        return try await body()
    }

    private static func acquire() throws -> Int32 {
        let path = try ClingsConfig.fileURL(named: "mutation.lock").path
        let descriptor = open(path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw ThingsError.operationFailed("Cannot open mutation lock") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw ThingsError.operationFailed("Another clings mutation is running; retry after it finishes")
        }
        return descriptor
    }

    public static func withLock<T>(_ body: () async throws -> T) async throws -> T {
        if held {
            return try await body()
        }
        let descriptor = try acquire()
        defer { close(descriptor) }
        return try await $held.withValue(true) { try await body() }
    }

    public static func withLock<T>(_ body: () throws -> T) throws -> T {
        if held {
            return try body()
        }
        let descriptor = try acquire()
        defer { close(descriptor) }
        return try $held.withValue(true) { try body() }
    }
}

public enum StateJSON {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(["referenceSeconds": date.timeIntervalSinceReferenceDate])
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode([String: Double].self), let seconds = value["referenceSeconds"] {
                return Date(timeIntervalSinceReferenceDate: seconds)
            }
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: string) {
                return date
            }
            formatter.formatOptions.remove(.withFractionalSeconds)
            guard let date = formatter.date(from: string) else { throw ThingsError.invalidState("Invalid stored timestamp") }
            return date
        }
        return decoder
    }
}
