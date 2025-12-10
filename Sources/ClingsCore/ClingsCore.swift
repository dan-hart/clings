// ClingsCore.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

/// Core library for clings - Things 3 CLI.
///
/// This module provides:
/// - Models: Todo, Project, Area, Tag, Status, Priority, ListView
/// - ThingsClient: Interface to Things 3 via JXA
/// - NLP: Natural language parsing for task creation
/// - Filter: SQL-like filtering DSL
/// - Output: Formatters for text and JSON output

// Re-export all public types
@_exported import Foundation
