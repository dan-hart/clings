//! Storage layer for clings.
//!
//! This module provides SQLite-based persistence for:
//! - Statistics (completed tasks, productivity metrics)
//! - Focus sessions (pomodoro tracking)
//! - Sync queue (offline operations)

mod database;
mod migrations;

pub use database::Database;
