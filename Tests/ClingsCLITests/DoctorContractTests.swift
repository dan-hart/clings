@testable import ClingsCLI
import ClingsCore
import Foundation
import Testing

@Suite("Read-only doctor contracts", .serialized)
struct DoctorContractTests {
    private func strings(in value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }
        if let values = value as? [Any] {
            return values.flatMap { strings(in: $0) }
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.values.flatMap { strings(in: $0) }
        }
        return []
    }

    @Test func doesNotCreateConfiguration() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            try await CommandTestSupport.withRuntime(database: MockThingsDatabase()) {
                let command = try DoctorCommand.parse(["--json"])
                _ = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                #expect(!FileManager.default.fileExists(atPath: directory.path))
            }
        }
    }

    @Test func requiredFailureIsNonzeroAndRetainsReport() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            try await CommandRuntime.$makeDatabase.withValue({ throw ThingsError.operationFailed("private diagnostic at /private/user-data") }) {
                var failure: CommandFailure?
                _ = try await CommandTestSupport.captureStandardOutput {
                    do { try await DoctorCommand.parse(["--json"]).run() }
                    catch let error as CommandFailure { failure = error }
                }
                #expect(failure?.exitStatus == 2)
                #expect(failure?.dataJSON?.contains("checks") == true)
                if let json = failure?.dataJSON {
                    let data = try JSONSerialization.jsonObject(with: Data(json.utf8))
                    #expect(!strings(in: data).contains { $0.contains("/private/user-data") })
                }
                #expect(!FileManager.default.fileExists(atPath: directory.path))
            }
        }
    }

    @Test func verboseJSONDoesNotExposePrivatePathsOrTokens() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            try AuthTokenStore.saveToken("private-doctor-token")
            try await CommandTestSupport.withRuntime(database: MockThingsDatabase()) {
                let command = try DoctorCommand.parse(["--verbose", "--json"])
                let (_, output) = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                let data = try JSONSerialization.jsonObject(with: Data(output.utf8))
                let values = strings(in: data)
                #expect(!values.contains { $0.contains(directory.path) })
                #expect(!values.contains { $0.contains("private-doctor-token") })
            }
        }
    }

    @Test func missingTokenDoesNotBlockReadableHealth() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try await CommandTestSupport.withRuntime(database: MockThingsDatabase()) {
                let report = await DoctorReport.generate(probe: false)
                #expect(report.healthy)
                #expect(report.overallStatus == "ok")
                #expect(report.checks.contains { $0.id == "token" && $0.status == "warning" && !$0.required })
                #expect(report.checks.contains { $0.id == "automation" && $0.status == "not-tested" })
            }
        }
    }

    @Test func probesOnlyWhenRequestedAndRedactsDenial() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try await CommandTestSupport.withRuntime(database: MockThingsDatabase()) {
                let counter = ProbeCounter()
                await DoctorRuntime.$probeAutomation.withValue({ await counter.hit() }) {
                    _ = await DoctorReport.generate(probe: false)
                    #expect(await counter.count == 0)
                    let report = await DoctorReport.generate(probe: true)
                    #expect(report.healthy)
                    #expect(await counter.count == 1)
                }
                await DoctorRuntime.$probeAutomation.withValue({ throw JXAError.processError(1, "Private /user-secret path (-1743)") }) {
                    let report = await DoctorReport.generate(probe: true)
                    #expect(!report.healthy)
                    #expect(report.checks.contains { $0.id == "automation-denied" && $0.message.contains("System Settings") })
                    let data = try? JSONEncoder().encode(report)
                    #expect(data.map { !String(decoding: $0, as: UTF8.self).contains("user-secret") } == true)
                }
            }
        }
    }

    @Test func runtimeFailureIsRequiredAndDoesNotProbe() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { _ in
            try await CommandTestSupport.withRuntime(database: MockThingsDatabase()) {
                await DoctorRuntime.$runtimeAvailable.withValue({ false }) {
                    let report = await DoctorReport.generate(probe: true)
                    #expect(!report.healthy)
                    #expect(report.checks.contains { $0.id == "runtime" && $0.required && $0.status == "error" })
                }
            }
        }
    }

    @Test func databaseConstructionIsNotMistakenForReadability() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let path = directory.appendingPathComponent("broken.sqlite").path
            try Data("not a database".utf8).write(to: URL(fileURLWithPath: path))
            await CommandRuntime.$makeDatabase.withValue({ ThingsDatabase(dbPath: path) }) {
                let report = await DoctorReport.generate(probe: false)
                #expect(!report.healthy)
                #expect(report.checks.contains { $0.id == "database" && $0.status == "error" })
            }
        }
    }

    @Test func supportBundleIsPrivateRedactedAndNeverOverwritten() async throws {
        try await CommandTestSupport.withTemporaryConfigDirectory { directory in
            try AuthTokenStore.saveToken("private-doctor-token")
            let bundle = directory.appendingPathComponent("support.json")
            try await CommandTestSupport.withRuntime(database: MockThingsDatabase()) {
                let command = try DoctorCommand.parse(["--support-bundle", bundle.path, "--json"])
                _ = try await CommandTestSupport.captureStandardOutput { try await command.run() }
                let original = try Data(contentsOf: bundle)
                let object = try JSONSerialization.jsonObject(with: original)
                let bundleReport = (object as? [String: Any])?["report"] as? [String: Any]
                #expect(bundleReport?["supportBundleCreated"] as? Bool == true)
                #expect(!strings(in: object).contains { $0.contains("private-doctor-token") || $0.contains(directory.path) })
                let permissions = try FileManager.default.attributesOfItem(atPath: bundle.path)[.posixPermissions] as? NSNumber
                #expect(permissions?.intValue == 0o600)
                do { try await command.run(); Issue.record("Existing bundle was overwritten") }
                catch let failure as CommandFailure { #expect(failure.exitStatus == 2) }
                #expect(try Data(contentsOf: bundle) == original)
            }
        }
    }
}

private actor ProbeCounter {
    var count = 0
    func hit() {
        count += 1
    }
}
