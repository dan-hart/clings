// JSONFileStore.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Lightweight JSON persistence for user-local clings state.
public enum JSONFileStore {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static func load<T: Decodable>(_ type: T.Type, from fileName: String, default defaultValue: @autoclosure () -> T) throws -> T {
        let url = try ClingsConfig.fileURL(named: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return defaultValue()
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    public static func save<T: Encodable>(_ value: T, to fileName: String) throws {
        let url = try ClingsConfig.fileURL(named: fileName)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    public static func delete(fileName: String) throws {
        let url = try ClingsConfig.fileURL(named: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try FileManager.default.removeItem(at: url)
    }
}
