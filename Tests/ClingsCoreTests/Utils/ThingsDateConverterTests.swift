// ThingsDateConverterTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import ClingsCore

final class ThingsDateConverterTests: XCTestCase {

    // MARK: - Known Database Values

    func testDecodeKnownValue_20260227() {
        // Value observed in actual Things 3 database
        let components = ThingsDateConverter.decode(132787584)
        XCTAssertEqual(components?.year, 2026)
        XCTAssertEqual(components?.month, 2)
        XCTAssertEqual(components?.day, 27)
    }

    func testDecodeToDate_20260227() {
        let date = ThingsDateConverter.decodeToDate(132787584)
        XCTAssertNotNil(date)

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: date!), 2026)
        XCTAssertEqual(calendar.component(.month, from: date!), 2)
        XCTAssertEqual(calendar.component(.day, from: date!), 27)
    }

    // MARK: - Encode/Decode Roundtrips

    func testRoundtrip_20260301() {
        let encoded = ThingsDateConverter.encode(year: 2026, month: 3, day: 1)
        let decoded = ThingsDateConverter.decode(encoded)
        XCTAssertEqual(decoded?.year, 2026)
        XCTAssertEqual(decoded?.month, 3)
        XCTAssertEqual(decoded?.day, 1)
    }

    func testRoundtrip_20240101() {
        let encoded = ThingsDateConverter.encode(year: 2024, month: 1, day: 1)
        let decoded = ThingsDateConverter.decode(encoded)
        XCTAssertEqual(decoded?.year, 2024)
        XCTAssertEqual(decoded?.month, 1)
        XCTAssertEqual(decoded?.day, 1)
    }

    func testRoundtrip_20241231() {
        let encoded = ThingsDateConverter.encode(year: 2024, month: 12, day: 31)
        let decoded = ThingsDateConverter.decode(encoded)
        XCTAssertEqual(decoded?.year, 2024)
        XCTAssertEqual(decoded?.month, 12)
        XCTAssertEqual(decoded?.day, 31)
    }

    // MARK: - Edge Cases

    func testLeapDay() {
        let encoded = ThingsDateConverter.encode(year: 2024, month: 2, day: 29)
        let decoded = ThingsDateConverter.decode(encoded)
        XCTAssertEqual(decoded?.year, 2024)
        XCTAssertEqual(decoded?.month, 2)
        XCTAssertEqual(decoded?.day, 29)
    }

    func testYearBoundary_Jan1() {
        let encoded = ThingsDateConverter.encode(year: 2025, month: 1, day: 1)
        let decoded = ThingsDateConverter.decode(encoded)
        XCTAssertEqual(decoded?.year, 2025)
        XCTAssertEqual(decoded?.month, 1)
        XCTAssertEqual(decoded?.day, 1)
    }

    func testYearBoundary_Dec31() {
        let encoded = ThingsDateConverter.encode(year: 2025, month: 12, day: 31)
        let decoded = ThingsDateConverter.decode(encoded)
        XCTAssertEqual(decoded?.year, 2025)
        XCTAssertEqual(decoded?.month, 12)
        XCTAssertEqual(decoded?.day, 31)
    }

    func testDecodeZeroReturnsNil() {
        XCTAssertNil(ThingsDateConverter.decode(0))
    }

    // MARK: - Date Roundtrip

    func testEncodeDateRoundtrip() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 3, day: 15)
        let date = calendar.date(from: components)!

        let encoded = ThingsDateConverter.encodeDate(date)
        let decoded = ThingsDateConverter.decodeToDate(encoded)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(calendar.component(.year, from: decoded!), 2026)
        XCTAssertEqual(calendar.component(.month, from: decoded!), 3)
        XCTAssertEqual(calendar.component(.day, from: decoded!), 15)
    }

    // MARK: - Bit Layout Verification

    func testBitLayout() {
        // Verify the exact bit positions by constructing a known value manually
        // 2026 = 0b11111101010, month 2 = 0b0010, day 27 = 0b11011
        // Expected: 0b11111101010_0010_11011_0000000
        let expected = (2026 << 16) | (2 << 12) | (27 << 7)
        XCTAssertEqual(expected, 132787584)
        XCTAssertEqual(ThingsDateConverter.encode(year: 2026, month: 2, day: 27), 132787584)
    }
}
