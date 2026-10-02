import ClingsCore
import Foundation

enum DoctorRuntime {
    @TaskLocal static var runtimeAvailable: @Sendable () -> Bool = {
        FileManager.default.isExecutableFile(atPath: "/usr/bin/osascript")
    }

    @TaskLocal static var probeAutomation: @Sendable () async throws -> Void = {
        // Reading version sends an Apple event but does not change any task.
        _ = try await JXABridge().execute("Application('Things3').version()")
    }
}

struct DoctorCheck: Codable, Sendable {
    let id: String
    let name: String
    let status: String
    let required: Bool
    let message: String
}

struct DoctorReport: Codable, Sendable {
    let overallStatus: String
    let checks: [DoctorCheck]
    var supportBundleCreated = false

    var healthy: Bool {
        !checks.contains { $0.required && $0.status != "ok" }
    }

    static func generate(probe: Bool) async -> DoctorReport {
        var checks = [configCheck()]
        do {
            // Constructing ThingsDatabase alone does not prove it can be read.
            _ = try CommandRuntime.makeDatabase().fetchList(.today)
            checks.append(DoctorCheck(id: "database", name: "Things database", status: "ok", required: true, message: "Readable"))
        } catch {
            checks.append(DoctorCheck(id: "database", name: "Things database", status: "error", required: true, message: "Cannot read Things data. Install and open Things 3, then retry. If it is installed, check database access; do not edit the database."))
        }
        let runtime = DoctorRuntime.runtimeAvailable()
        checks.append(DoctorCheck(id: "runtime", name: "Automation runtime", status: runtime ? "ok" : "error", required: true, message: runtime ? "osascript available" : "osascript is unavailable. Use a supported macOS installation."))
        let hasToken = (try? AuthTokenStore.loadToken()) != nil
        checks.append(DoctorCheck(id: "token", name: "Auth token", status: hasToken ? "ok" : "warning", required: false, message: hasToken ? "Configured, not validated" : "Optional token is not configured. Reads and normal automation writes do not require it; update --when/--heading does."))
        if probe && runtime {
            do {
                try await DoctorRuntime.probeAutomation()
                checks.append(DoctorCheck(id: "automation", name: "Automation access", status: "ok", required: true, message: "Read-only Things version query succeeded"))
            } catch {
                let description = error.localizedDescription.lowercased()
                let denied = description.contains("-1743") || description.contains("not authorized") || description.contains("not permitted") || description.contains("permission denied")
                let unavailable = (error as? JXAError).map {
                    if case .thingsNotRunning = $0 {
                        return true
                    }; return false
                } ?? false
                let message = denied
                    ? "Automation access denied. Grant the calling app access to Things in System Settings > Privacy & Security > Automation, then retry."
                    : unavailable ? "Things 3 is not running. Open Things and retry the read-only probe."
                    : "The read-only automation query failed. Check that Things is installed and accessible, then retry."
                checks.append(DoctorCheck(id: denied ? "automation-denied" : "automation-unavailable", name: "Automation access", status: "error", required: true, message: message))
            }
        } else {
            checks.append(DoctorCheck(id: "automation", name: "Automation access", status: probe ? "error" : "not-tested", required: probe, message: probe ? "Cannot probe without osascript" : "Not tested. Use --probe-automation to send a read-only query; it may launch Things or show a permission prompt."))
        }
        checks.append(DoctorCheck(id: "trash", name: "Trash movement", status: "unsupported", required: false, message: "Delete uses supported cancellation, not Trash."))
        checks.append(DoctorCheck(id: "undo-assignments", name: "Undo scheduling and assignments", status: "unsupported", required: false, message: "Schedule, heading, and project moves are not fully undoable. Supported fields and grouped status/tag changes have local undo."))
        checks.append(DoctorCheck(id: "open", name: "Direct open", status: "unsupported", required: false, message: "Direct open is disabled; use the Things app to navigate."))
        let healthy = !checks.contains { $0.required && $0.status != "ok" }
        return DoctorReport(overallStatus: healthy ? "ok" : "needs-attention", checks: checks)
    }

    private static func configCheck() -> DoctorCheck {
        let manager = FileManager.default
        let directory = ClingsConfig.directoryURL
        var isDirectory: ObjCBool = false
        if manager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            let usable = isDirectory.boolValue && manager.isReadableFile(atPath: directory.path) && manager.isWritableFile(atPath: directory.path)
            return DoctorCheck(id: "config", name: "Config directory", status: usable ? "ok" : "error", required: true, message: usable ? "Readable and appears writable; no write test performed" : "Config location is not a readable/writable directory. Check CLINGS_CONFIG_DIR and its permissions.")
        }
        var parent = directory.deletingLastPathComponent()
        while !manager.fileExists(atPath: parent.path), parent.path != "/" {
            parent.deleteLastPathComponent()
        }
        var parentIsDirectory: ObjCBool = false
        let exists = manager.fileExists(atPath: parent.path, isDirectory: &parentIsDirectory)
        let writable = exists && parentIsDirectory.boolValue && manager.isWritableFile(atPath: parent.path)
        return DoctorCheck(id: "config", name: "Config directory", status: writable ? "ok" : "error", required: true, message: writable ? "Not initialized; parent appears writable. Created only when a command needs local storage." : "Config directory cannot be initialized. Check CLINGS_CONFIG_DIR and parent permissions.")
    }
}
