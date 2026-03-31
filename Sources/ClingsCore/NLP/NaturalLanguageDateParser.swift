// NaturalLanguageDateParser.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Parses lightweight natural-language scheduling phrases into dates.
public struct NaturalLanguageDateParser: Sendable {
    public init() {}

    public func parse(_ input: String, referenceDate: Date = Date()) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)

        let extractedTime = extractTime(from: lower)
        var datePhrase = extractedTime.remaining

        let implicitHour: Int?
        if datePhrase == "this evening" || datePhrase == "evening" || datePhrase == "tonight" {
            implicitHour = 18
            datePhrase = "today"
        } else if datePhrase == "tomorrow morning" {
            implicitHour = 9
            datePhrase = "tomorrow"
        } else if datePhrase == "tomorrow evening" || datePhrase == "tomorrow night" {
            implicitHour = 18
            datePhrase = "tomorrow"
        } else if datePhrase == "morning" {
            implicitHour = 9
            datePhrase = "today"
        } else {
            implicitHour = nil
        }

        let baseDate: Date?
        if datePhrase == "today" {
            baseDate = startOfDay
        } else if datePhrase == "tomorrow" {
            baseDate = calendar.date(byAdding: .day, value: 1, to: startOfDay)
        } else if datePhrase == "next week" {
            baseDate = calendar.date(byAdding: .day, value: 7, to: startOfDay)
        } else if let inDays = parseRelativeDays(datePhrase, calendar: calendar, startOfDay: startOfDay) {
            baseDate = inDays
        } else if let weekday = weekdayFromName(datePhrase.replacingOccurrences(of: "next ", with: "")) {
            baseDate = nextOccurrence(of: weekday, from: referenceDate, forceNextWeek: datePhrase.hasPrefix("next "))
        } else if let absolute = parseAbsoluteDate(datePhrase, referenceDate: referenceDate) {
            baseDate = absolute
        } else {
            baseDate = nil
        }

        guard let baseDate else { return nil }
        let hour = extractedTime.hour ?? implicitHour
        let minute = extractedTime.minute ?? 0
        guard let hour else { return calendar.startOfDay(for: baseDate) }

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: calendar.startOfDay(for: baseDate)
        )
    }

    private func parseRelativeDays(_ input: String, calendar: Calendar, startOfDay: Date) -> Date? {
        let pattern = #"^in\s+(\d+)\s+days?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let range = Range(match.range(at: 1), in: input),
              let days = Int(input[range]) else {
            return nil
        }
        return calendar.date(byAdding: .day, value: days, to: startOfDay)
    }

    private func parseAbsoluteDate(_ input: String, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let lower = input.lowercased()

        let isoFormatter = DateFormatter()
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoFormatter.timeZone = TimeZone.current
        isoFormatter.dateFormat = "yyyy-MM-dd"
        if let date = isoFormatter.date(from: lower) {
            return calendar.startOfDay(for: date)
        }

        for format in ["MMM d yyyy", "MMMM d yyyy", "MMM d", "MMMM d"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format

            if format.contains("yyyy"), let date = formatter.date(from: lower) {
                return calendar.startOfDay(for: date)
            }

            if let date = formatter.date(from: lower) {
                let components = calendar.dateComponents([.month, .day], from: date)
                var merged = calendar.dateComponents([.year], from: referenceDate)
                merged.month = components.month
                merged.day = components.day
                if let candidate = calendar.date(from: merged) {
                    let candidateStart = calendar.startOfDay(for: candidate)
                    if candidateStart < calendar.startOfDay(for: referenceDate),
                       let nextYear = calendar.date(byAdding: .year, value: 1, to: candidateStart) {
                        return nextYear
                    }
                    return candidateStart
                }
            }
        }

        return nil
    }

    private func weekdayFromName(_ name: String) -> Int? {
        let mapping: [String: Int] = [
            "sunday": 1, "sun": 1,
            "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3,
            "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5,
            "friday": 6, "fri": 6,
            "saturday": 7, "sat": 7,
        ]
        return mapping[name]
    }

    private func nextOccurrence(of weekday: Int, from date: Date, forceNextWeek: Bool) -> Date? {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: date)
        var daysToAdd = weekday - todayWeekday
        if daysToAdd < 0 || (daysToAdd == 0 && forceNextWeek) {
            daysToAdd += 7
        }
        if forceNextWeek, daysToAdd == 0 {
            daysToAdd = 7
        }
        return calendar.date(byAdding: .day, value: daysToAdd == 0 ? 7 : daysToAdd, to: calendar.startOfDay(for: date))
    }

    private func extractTime(from input: String) -> (remaining: String, hour: Int?, minute: Int?) {
        let patterns = [
            #"(?:\s|^)(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#,
            #"(?:\s|^)(\d{1,2}):(\d{2})\b"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
                  let fullRange = Range(match.range, in: input),
                  let hourRange = Range(match.range(at: 1), in: input) else {
                continue
            }

            let rawHour = Int(input[hourRange]) ?? 0
            let rawMinute: Int
            if let minuteRange = Range(match.range(at: 2), in: input) {
                rawMinute = Int(input[minuteRange]) ?? 0
            } else {
                rawMinute = 0
            }

            let meridiem: String?
            if match.numberOfRanges > 3, let meridiemRange = Range(match.range(at: 3), in: input) {
                meridiem = String(input[meridiemRange]).lowercased()
            } else {
                meridiem = nil
            }

            var hour = rawHour
            if let meridiem {
                if meridiem == "pm", hour < 12 {
                    hour += 12
                }
                if meridiem == "am", hour == 12 {
                    hour = 0
                }
            }

            let remaining = input.replacingCharacters(in: fullRange, with: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return (remaining, hour, rawMinute)
        }

        return (input.trimmingCharacters(in: .whitespacesAndNewlines), nil, nil)
    }
}
