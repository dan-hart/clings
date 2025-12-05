//! Database migrations for clings.
//!
//! Each migration is a function that upgrades the schema by one version.
//! Migrations are run automatically when the database is opened.

use rusqlite::Connection;

use crate::error::ClingsError;

/// Current schema version.
const CURRENT_VERSION: i32 = 1;

/// Get the current schema version from the database.
///
/// Returns 0 if no version has been set (new database).
pub fn get_version(conn: &Connection) -> Result<i32, ClingsError> {
    // Try to read from user_version pragma
    let version: i32 = conn
        .query_row("PRAGMA user_version", [], |row| row.get(0))
        .map_err(|e| ClingsError::Database(format!("Failed to get schema version: {e}")))?;

    Ok(version)
}

/// Set the schema version in the database.
fn set_version(conn: &Connection, version: i32) -> Result<(), ClingsError> {
    conn.execute_batch(&format!("PRAGMA user_version = {version};"))
        .map_err(|e| ClingsError::Database(format!("Failed to set schema version: {e}")))
}

/// Run all pending migrations.
pub fn run(conn: &Connection) -> Result<(), ClingsError> {
    let current = get_version(conn)?;

    if current >= CURRENT_VERSION {
        return Ok(());
    }

    // Run migrations in order
    for version in (current + 1)..=CURRENT_VERSION {
        run_migration(conn, version)?;
        set_version(conn, version)?;
    }

    Ok(())
}

/// Run a specific migration.
fn run_migration(conn: &Connection, version: i32) -> Result<(), ClingsError> {
    match version {
        1 => migrate_v1(conn),
        _ => Err(ClingsError::Database(format!(
            "Unknown migration version: {version}"
        ))),
    }
}

/// Migration v1: Initial schema.
///
/// Creates tables for:
/// - `stats_daily`: Daily productivity statistics
/// - `focus_sessions`: Pomodoro/focus session history
/// - `sync_queue`: Offline operation queue
fn migrate_v1(conn: &Connection) -> Result<(), ClingsError> {
    conn.execute_batch(
        r"
        -- Daily statistics
        CREATE TABLE IF NOT EXISTS stats_daily (
            date TEXT PRIMARY KEY,
            completed INTEGER NOT NULL DEFAULT 0,
            created INTEGER NOT NULL DEFAULT 0,
            canceled INTEGER NOT NULL DEFAULT 0,
            focus_minutes INTEGER NOT NULL DEFAULT 0
        );

        -- Focus sessions
        CREATE TABLE IF NOT EXISTS focus_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id TEXT,
            task_name TEXT,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            duration_minutes INTEGER NOT NULL,
            session_type TEXT NOT NULL DEFAULT 'pomodoro',
            completed INTEGER NOT NULL DEFAULT 0,
            notes TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_focus_sessions_started
        ON focus_sessions(started_at);

        CREATE INDEX IF NOT EXISTS idx_focus_sessions_task
        ON focus_sessions(task_id);

        -- Sync queue for offline operations
        CREATE TABLE IF NOT EXISTS sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_attempt TEXT,
            last_error TEXT,
            status TEXT NOT NULL DEFAULT 'pending'
        );

        CREATE INDEX IF NOT EXISTS idx_sync_queue_status
        ON sync_queue(status);

        -- Review sessions
        CREATE TABLE IF NOT EXISTS review_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            review_type TEXT NOT NULL,
            started_at TEXT NOT NULL,
            completed_at TEXT,
            items_processed INTEGER NOT NULL DEFAULT 0,
            notes TEXT
        );
        ",
    )
    .map_err(|e| ClingsError::Database(format!("Migration v1 failed: {e}")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_migration_v1() {
        let conn = Connection::open_in_memory().unwrap();

        // Run migration
        run(&conn).unwrap();

        // Verify version
        assert_eq!(get_version(&conn).unwrap(), CURRENT_VERSION);

        // Verify tables exist by inserting data
        conn.execute(
            "INSERT INTO stats_daily (date, completed) VALUES ('2024-01-01', 5)",
            [],
        )
        .unwrap();

        conn.execute(
            "INSERT INTO focus_sessions (task_id, started_at, duration_minutes, session_type)
             VALUES ('abc123', '2024-01-01T10:00:00', 25, 'pomodoro')",
            [],
        )
        .unwrap();

        conn.execute(
            "INSERT INTO sync_queue (operation_type, payload, created_at)
             VALUES ('complete_todo', '{\"id\":\"abc123\"}', '2024-01-01T10:00:00')",
            [],
        )
        .unwrap();
    }

    #[test]
    fn test_migration_idempotent() {
        let conn = Connection::open_in_memory().unwrap();

        // Run migrations twice
        run(&conn).unwrap();
        run(&conn).unwrap();

        // Should still be at current version
        assert_eq!(get_version(&conn).unwrap(), CURRENT_VERSION);
    }

    #[test]
    fn test_get_version_new_database() {
        let conn = Connection::open_in_memory().unwrap();

        // New database should have version 0
        assert_eq!(get_version(&conn).unwrap(), 0);
    }
}
