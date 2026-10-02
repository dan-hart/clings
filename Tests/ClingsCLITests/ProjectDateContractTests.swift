@testable import ClingsCLI
import ClingsCore
import Foundation
import Testing

@Suite("Project date validation", .serialized)
struct ProjectDateContractTests {
    @Test func validLeapDayRemainsARealLocalGregorianDate() async throws {
        let client = RecordingThingsClient()
        try await CommandTestSupport.withRuntime(client: client) {
            try await ProjectAddCommand.parse(["Documentation", "--when", "2028-02-29", "--deadline", "2028-02-29"]).run()
            let project = try #require(client.createdProjects.first)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            for value in [project.2, project.3] {
                let date = try #require(value)
                let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
                #expect(parts.year == 2028 && parts.month == 2 && parts.day == 29 && parts.hour == 0)
            }
        }
    }

    @Test func impossibleDatesAreRejectedBeforeProjectCreation() async throws {
        for option in ["--when", "--deadline"] {
            for expression in ["2026-02-30", "2026-02-29", "2026-04-31", "not-a-date", "next monday", "evening", "2026-01-01T12:00:00Z"] {
                let client = RecordingThingsClient()
                try await CommandTestSupport.withRuntime(client: client) {
                    await #expect(throws: (any Error).self) {
                        try await ProjectAddCommand.parse(["Documentation", option, expression]).run()
                    }
                    #expect(client.createdProjects.isEmpty)
                }
            }
        }
    }
}
