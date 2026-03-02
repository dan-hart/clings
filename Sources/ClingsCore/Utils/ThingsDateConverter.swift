// ThingsDateConverter.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Converts between Things 3's bitwise-packed date INTEGER and Swift Date/DateComponents.
///
/// Things 3 stores `deadline` and `startDate` as packed integers with this bit layout:
///
///     Bits 26..16: year  (11 bits, supports up to 2047)
///     Bits 15..12: month (4 bits, 1-12)
///     Bits 11..7:  day   (5 bits, 1-31)
///     Bits 6..0:   padding (always zero)
///
/// This is NOT a timestamp. Other date fields (`creationDate`, `userModificationDate`,
/// `stopDate`) use standard Unix timestamps (seconds since 1970-01-01).
public enum ThingsDateConverter {

    // MARK: - Bit Masks & Shifts

    private static let yearMask:  Int = 0x07FF_0000  // bits 26..16
    private static let monthMask: Int = 0x0000_F000  // bits 15..12
    private static let dayMask:   Int = 0x0000_0F80  // bits 11..7

    private static let yearShift  = 16
    private static let monthShift = 12
    private static let dayShift   = 7

    // MARK: - Decoding

    /// Unpack a Things 3 packed date integer into DateComponents.
    public static func decode(_ packedDate: Int) -> DateComponents? {
        let year  = (packedDate & yearMask)  >> yearShift
        let month = (packedDate & monthMask) >> monthShift
        let day   = (packedDate & dayMask)   >> dayShift

        guard year > 0, (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }

        return DateComponents(year: year, month: month, day: day)
    }

    /// Unpack a Things 3 packed date integer into a Date (midnight, current calendar).
    public static func decodeToDate(_ packedDate: Int) -> Date? {
        guard let components = decode(packedDate) else { return nil }
        return Calendar.current.date(from: components)
    }

    // MARK: - Encoding

    /// Pack year/month/day into a Things 3 date integer.
    public static func encode(year: Int, month: Int, day: Int) -> Int {
        (year << yearShift) | (month << monthShift) | (day << dayShift)
    }

    /// Pack a Date into a Things 3 date integer.
    public static func encodeDate(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            assertionFailure("Failed to extract date components from \(date)")
            return 0
        }
        return encode(year: year, month: month, day: day)
    }
}
