@testable import ClingsCore
import Foundation
import Testing

struct StrictDateTests {
    @Test func completeSchedulingStemsRetainValidTimes() {
        for stem in ["next friday", "tomorrow", "in 2 days", "on friday", "2027-01-15", "dec 15", "this evening", "tomorrow morning"] {
            let parsed = TaskParser().parse("Task \(stem) 3pm")
            #expect(parsed.title == "Task")
            #expect(parsed.whenDate != nil, "Rejected: \(stem) 3pm")
            #expect(parsed.invalidDateExpressions.isEmpty)
        }
    }
    @Test func monthDayExpressionsNeverNormalizeImpossibleDates() throws {
        let parser = NaturalLanguageDateParser()
        let reference = try #require(parser.parse("2027-02-01"))
        #expect(parser.parse("feb 29", referenceDate: reference) == nil)
        #expect(parser.parse("feb 31", referenceDate: reference) == nil)
        #expect(parser.parse("feb 31 2027", referenceDate: reference) == nil)
        #expect(parser.parse("feb 29 2028", referenceDate: reference) != nil)
    }

    @Test func scheduledStartIsAdditiveAndFormatable() throws {
        let date = try #require(NaturalLanguageDateParser().parse("2027-01-15"))
        let todo = Todo(id: "a", name: "A", scheduledDate: date)
        #expect(TodoLineFormatter(template: "{when}/{start}/{due}").format(todo: todo) == "2027-01-15/2027-01-15/")
        #expect(JSONOutputFormatter().format(todo: todo).contains("scheduledDate"))
        #expect(try JSONDecoder().decode(Todo.self, from: Data(#"{"id":"old","name":"Old"}"#.utf8)).scheduledDate == nil)
    }

    @Test func rejectsImpossibleDatesAndTimes() {
        let parser = NaturalLanguageDateParser()
        for expression in ["2027-02-30", "2027-13-01", "today 25:00", "tomorrow 9:99", "today 13pm", "today 0am"] {
            #expect(parser.parse(expression) == nil, "Accepted: \(expression)")
        }
    }

    @Test func rejectsUnknownFieldsAndTrailingInput() {
        #expect(throws: (any Error).self) { try FilterParser.parse("unknown = open") }
        #expect(throws: (any Error).self) { try FilterParser.parse("status = open garbage") }
    }

    @Test func gregorianResolutionHandlesDSTAndLeapDays() throws {
        let zone = try #require(TimeZone(identifier: "America/Chicago"))
        let parser = NaturalLanguageDateParser(timeZone: zone)
        let before = try #require(parser.parse("2026-03-07"))
        let tomorrow = try #require(parser.parse("tomorrow", referenceDate: before))
        let next = try #require(parser.parse("in 2 days", referenceDate: before))
        #expect(next.timeIntervalSince(tomorrow) == 23 * 3600)
        #expect(parser.parse("2026-03-08 2:30") == nil)
        #expect(parser.parse("2028-02-29") != nil)
        #expect(parser.parse("2027-02-29") == nil)
    }
}
