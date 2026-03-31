// DoctorCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser
import ClingsCore
import Foundation

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check clings setup and local environment",
        discussion: """
        Run local diagnostics for config storage, database access, automation
        runtime availability, and auth-token configuration.

        EXAMPLES:
          clings doctor
          clings doctor --verbose
          clings doctor --json
        """
    )

    @Flag(name: .long, help: "Include paths and extra detail")
    var verbose = false

    @OptionGroup var output: OutputOptions

    func run() throws {
        let report = DoctorReport.generate(verbose: verbose)

        if output.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            print(String(data: data, encoding: .utf8) ?? "{}")
            return
        }

        print("clings doctor")
        print("─────────────────────────────────────")
        for check in report.checks {
            let marker = check.status == "ok" ? "✓" : "!"
            print("\(marker) \(check.name): \(check.message)")
            if verbose, let detail = check.detail {
                print("  \(detail)")
            }
        }
        print("")
        print("Overall: \(report.overallStatus)")
    }
}

private struct DoctorReport: Codable {
    let overallStatus: String
    let checks: [DoctorCheck]

    static func generate(verbose: Bool) -> DoctorReport {
        var checks: [DoctorCheck] = []

        do {
            let configDir = try ClingsConfig.ensureDirectory()
            checks.append(DoctorCheck(name: "Config directory", status: "ok", message: "Writable", detail: verbose ? configDir.path : nil))
        } catch {
            checks.append(DoctorCheck(name: "Config directory", status: "warning", message: error.localizedDescription, detail: nil))
        }

        do {
            let _ = try CommandRuntime.makeDatabase()
            checks.append(DoctorCheck(name: "Things database", status: "ok", message: "Readable", detail: nil))
        } catch {
            checks.append(DoctorCheck(name: "Things database", status: "warning", message: error.localizedDescription, detail: nil))
        }

        let osascriptPath = "/usr/bin/osascript"
        if FileManager.default.fileExists(atPath: osascriptPath) {
            checks.append(DoctorCheck(name: "Automation runtime", status: "ok", message: "osascript available", detail: verbose ? osascriptPath : nil))
        } else {
            checks.append(DoctorCheck(name: "Automation runtime", status: "warning", message: "osascript missing", detail: nil))
        }

        do {
            _ = try AuthTokenStore.loadToken()
            checks.append(DoctorCheck(name: "Auth token", status: "ok", message: "Configured", detail: nil))
        } catch {
            checks.append(DoctorCheck(name: "Auth token", status: "warning", message: "Not configured for URL-scheme features", detail: nil))
        }

        let overallStatus = checks.contains(where: { $0.status != "ok" }) ? "needs-attention" : "ok"
        return DoctorReport(overallStatus: overallStatus, checks: checks)
    }
}

private struct DoctorCheck: Codable {
    let name: String
    let status: String
    let message: String
    let detail: String?
}
