// SavedViewStoreTests.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import ClingsCore

@Suite("SavedViewStore", .serialized)
struct SavedViewStoreTests {
    @Test func savesLoadsListsAndDeletesViews() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { _ in
            let view = SavedView(name: "work-today", expression: "area = 'Work' AND due <= today", note: "Daily work queue")
            try SavedViewStore.save(view)

            let loaded = try SavedViewStore.load(name: "work-today")
            #expect(loaded?.name == "work-today")
            #expect(loaded?.expression == "area = 'Work' AND due <= today")

            let listed = try SavedViewStore.list()
            #expect(listed.count == 1)
            #expect(listed.first?.note == "Daily work queue")

            #expect(try SavedViewStore.delete(name: "work-today"))
            #expect((try SavedViewStore.load(name: "work-today")) == nil)
        }
    }

    @Test func saveReplacesExistingViewWithSameName() throws {
        try ConfigTestSupport.withTemporaryConfigDirectory { _ in
            try SavedViewStore.save(SavedView(name: "today", expression: "status = open"))
            try SavedViewStore.save(SavedView(name: "today", expression: "due <= today"))

            let listed = try SavedViewStore.list()
            #expect(listed.count == 1)
            #expect(listed.first?.expression == "due <= today")
        }
    }
}
