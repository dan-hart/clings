// clings - A powerful CLI for Things 3
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check clings setup and local environment",
        discussion: """
        Check database readability, local config readiness, automation runtime,
        and the optional URL-scheme token without creating config or tasks.

        Missing tokens are warnings, not failures for read-only health. Required
        capability failures return exit 2. --probe-automation sends a read-only
        Things version query; it may launch Things or show a permission prompt.
        JSON and support bundles redact private paths, tokens, and task content.
        --support-bundle creates a new redacted JSON file; existing files are
        never overwritten. --verbose adds local paths only to human output.

        EXAMPLES:
          clings doctor
          clings doctor --verbose
          clings doctor --probe-automation --json
          clings doctor --support-bundle clings-support.json --json
        """
    )

    @Flag(name: .long, help: "Include local paths in human output; JSON remains redacted")
    var verbose = false

    @Flag(name: .long, help: "Opt in to a read-only Things automation query")
    var probeAutomation = false

    @Option(name: .long, help: "Create a new redacted support JSON file without overwriting")
    var supportBundle: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        var report = await DoctorReport.generate(probe: probeAutomation)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let initialJSON = try String(decoding: encoder.encode(report), as: UTF8.self)
        if let supportBundle {
            struct Bundle: Encodable {
                let schemaVersion = 1
                let version: String
                let platform: String
                let report: DoctorReport
            }
            var bundledReport = report
            bundledReport.supportBundleCreated = true
            let bundle = Bundle(version: Clings.configuration.version, platform: ProcessInfo.processInfo.operatingSystemVersionString, report: bundledReport)
            let data = try encoder.encode(bundle)
            let path = URL(fileURLWithPath: supportBundle).path
            let descriptor = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else { throw CommandFailure(exitStatus: 2, code: "support_storage_failed", message: "Cannot create support bundle. Choose a new filename in a writable directory.", dataJSON: initialJSON) }
            defer { close(descriptor) }
            let count = data.withUnsafeBytes { bytes in
                guard let base = bytes.baseAddress else { return -1 }
                return write(descriptor, base, bytes.count)
            }
            guard count == data.count else { throw CommandFailure(exitStatus: 2, code: "support_storage_failed", message: "Support bundle write was incomplete. Inspect the file and use a new filename when retrying.", dataJSON: initialJSON) }
            report.supportBundleCreated = true
        }
        let json = try String(decoding: encoder.encode(report), as: UTF8.self)
        let failure = CommandFailure(exitStatus: 2, code: "doctor_unhealthy", message: "Required clings capabilities need attention. Inspect the diagnostic checks.", dataJSON: json)
        if output.json {
            if !report.healthy {
                throw failure
            }
            print(json)
            return
        }
        print("clings doctor\n─────────────────────────────────────")
        for check in report.checks {
            print("\(check.status == "ok" ? "✓" : "!") \(check.name): \(check.message)")
        }
        if verbose {
            print("Config location: \(ClingsConfig.directoryURL.path)")
        }
        if report.supportBundleCreated {
            print("Redacted support bundle created")
        }
        print("\nOverall: \(report.overallStatus)")
        if !report.healthy {
            throw failure
        }
    }
}
