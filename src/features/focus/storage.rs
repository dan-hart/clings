//! Focus session storage.
//!
//! Persists focus sessions to the local database.

use chrono::{DateTime, Utc};
use rusqlite::{params, Row};

use super::session::{FocusSession, SessionState, SessionType};
use crate::error::ClingsError;
use crate::storage::Database;

/// Storage for focus sessions.
pub struct FocusStorage {
    db: Database,
}

impl FocusStorage {
    /// Create a new focus storage.
    pub fn new() -> Result<Self, ClingsError> {
        let db = Database::open()?;
        Ok(Self { db })
    }

    /// Create storage with an existing database connection.
    pub fn with_database(db: Database) -> Self {
        Self { db }
    }

    /// Save a focus session.
    ///
    /// If the session has an ID, it will be updated. Otherwise, it will be inserted.
    pub fn save(&self, session: &mut FocusSession) -> Result<(), ClingsError> {
        if session.id.is_some() {
            self.update(session)
        } else {
            self.insert(session)
        }
    }

    /// Insert a new session.
    fn insert(&self, session: &mut FocusSession) -> Result<(), ClingsError> {
        let conn = self.db.connection();

        conn.execute(
            r"INSERT INTO focus_sessions
              (task_id, task_name, started_at, ended_at, duration_minutes, session_type, completed, notes)
              VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                session.task_id,
                session.task_name,
                session.started_at.to_rfc3339(),
                session.ended_at.map(|t| t.to_rfc3339()),
                session.actual_duration,
                session_type_to_string(session.session_type),
                session.state == SessionState::Completed,
                session.notes,
            ],
        )
        .map_err(|e| ClingsError::Database(format!("Failed to insert session: {}", e)))?;

        session.id = Some(conn.last_insert_rowid());
        Ok(())
    }

    /// Update an existing session.
    fn update(&self, session: &FocusSession) -> Result<(), ClingsError> {
        let conn = self.db.connection();

        conn.execute(
            r"UPDATE focus_sessions SET
              task_id = ?1,
              task_name = ?2,
              started_at = ?3,
              ended_at = ?4,
              duration_minutes = ?5,
              session_type = ?6,
              completed = ?7,
              notes = ?8
              WHERE id = ?9",
            params![
                session.task_id,
                session.task_name,
                session.started_at.to_rfc3339(),
                session.ended_at.map(|t| t.to_rfc3339()),
                session.actual_duration,
                session_type_to_string(session.session_type),
                session.state == SessionState::Completed,
                session.notes,
                session.id,
            ],
        )
        .map_err(|e| ClingsError::Database(format!("Failed to update session: {}", e)))?;

        Ok(())
    }

    /// Get a session by ID.
    pub fn get(&self, id: i64) -> Result<Option<FocusSession>, ClingsError> {
        let conn = self.db.connection();

        let mut stmt = conn
            .prepare(
                r"SELECT id, task_id, task_name, started_at, ended_at,
                         duration_minutes, session_type, completed, notes
                  FROM focus_sessions WHERE id = ?1",
            )
            .map_err(|e| ClingsError::Database(format!("Failed to prepare query: {}", e)))?;

        let result = stmt
            .query_row([id], |row| row_to_session(row))
            .optional()
            .map_err(|e| ClingsError::Database(format!("Failed to query session: {}", e)))?;

        Ok(result)
    }

    /// Get the current active session (if any).
    pub fn get_active(&self) -> Result<Option<FocusSession>, ClingsError> {
        let conn = self.db.connection();

        let mut stmt = conn
            .prepare(
                r"SELECT id, task_id, task_name, started_at, ended_at,
                         duration_minutes, session_type, completed, notes
                  FROM focus_sessions
                  WHERE ended_at IS NULL
                  ORDER BY started_at DESC
                  LIMIT 1",
            )
            .map_err(|e| ClingsError::Database(format!("Failed to prepare query: {}", e)))?;

        let result = stmt
            .query_row([], |row| row_to_session(row))
            .optional()
            .map_err(|e| ClingsError::Database(format!("Failed to query active session: {}", e)))?;

        Ok(result)
    }

    /// Get recent sessions.
    pub fn get_recent(&self, limit: usize) -> Result<Vec<FocusSession>, ClingsError> {
        let conn = self.db.connection();

        let mut stmt = conn
            .prepare(
                r"SELECT id, task_id, task_name, started_at, ended_at,
                         duration_minutes, session_type, completed, notes
                  FROM focus_sessions
                  ORDER BY started_at DESC
                  LIMIT ?1",
            )
            .map_err(|e| ClingsError::Database(format!("Failed to prepare query: {}", e)))?;

        let rows = stmt
            .query_map([limit], |row| row_to_session(row))
            .map_err(|e| ClingsError::Database(format!("Failed to query sessions: {}", e)))?;

        let mut sessions = Vec::new();
        for row in rows {
            sessions.push(row.map_err(|e| ClingsError::Database(e.to_string()))?);
        }

        Ok(sessions)
    }

    /// Get sessions for a date range.
    pub fn get_range(
        &self,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<Vec<FocusSession>, ClingsError> {
        let conn = self.db.connection();

        let mut stmt = conn
            .prepare(
                r"SELECT id, task_id, task_name, started_at, ended_at,
                         duration_minutes, session_type, completed, notes
                  FROM focus_sessions
                  WHERE started_at >= ?1 AND started_at < ?2
                  ORDER BY started_at DESC",
            )
            .map_err(|e| ClingsError::Database(format!("Failed to prepare query: {}", e)))?;

        let rows = stmt
            .query_map([start.to_rfc3339(), end.to_rfc3339()], |row| {
                row_to_session(row)
            })
            .map_err(|e| ClingsError::Database(format!("Failed to query sessions: {}", e)))?;

        let mut sessions = Vec::new();
        for row in rows {
            sessions.push(row.map_err(|e| ClingsError::Database(e.to_string()))?);
        }

        Ok(sessions)
    }

    /// Get sessions for a specific task.
    pub fn get_by_task(&self, task_id: &str) -> Result<Vec<FocusSession>, ClingsError> {
        let conn = self.db.connection();

        let mut stmt = conn
            .prepare(
                r"SELECT id, task_id, task_name, started_at, ended_at,
                         duration_minutes, session_type, completed, notes
                  FROM focus_sessions
                  WHERE task_id = ?1
                  ORDER BY started_at DESC",
            )
            .map_err(|e| ClingsError::Database(format!("Failed to prepare query: {}", e)))?;

        let rows = stmt
            .query_map([task_id], |row| row_to_session(row))
            .map_err(|e| ClingsError::Database(format!("Failed to query sessions: {}", e)))?;

        let mut sessions = Vec::new();
        for row in rows {
            sessions.push(row.map_err(|e| ClingsError::Database(e.to_string()))?);
        }

        Ok(sessions)
    }

    /// Get total focus time for a date range.
    pub fn get_total_time(
        &self,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<i64, ClingsError> {
        let conn = self.db.connection();

        let total: i64 = conn
            .query_row(
                r"SELECT COALESCE(SUM(duration_minutes), 0)
                  FROM focus_sessions
                  WHERE started_at >= ?1 AND started_at < ?2
                    AND completed = 1
                    AND session_type NOT IN ('short_break', 'long_break')",
                [start.to_rfc3339(), end.to_rfc3339()],
                |row| row.get(0),
            )
            .map_err(|e| ClingsError::Database(format!("Failed to query total time: {}", e)))?;

        Ok(total)
    }

    /// Get session count for a date range.
    pub fn get_session_count(
        &self,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<i64, ClingsError> {
        let conn = self.db.connection();

        let count: i64 = conn
            .query_row(
                r"SELECT COUNT(*)
                  FROM focus_sessions
                  WHERE started_at >= ?1 AND started_at < ?2
                    AND completed = 1
                    AND session_type NOT IN ('short_break', 'long_break')",
                [start.to_rfc3339(), end.to_rfc3339()],
                |row| row.get(0),
            )
            .map_err(|e| ClingsError::Database(format!("Failed to query session count: {}", e)))?;

        Ok(count)
    }

    /// Delete a session.
    pub fn delete(&self, id: i64) -> Result<bool, ClingsError> {
        let conn = self.db.connection();

        let rows = conn
            .execute("DELETE FROM focus_sessions WHERE id = ?1", [id])
            .map_err(|e| ClingsError::Database(format!("Failed to delete session: {}", e)))?;

        Ok(rows > 0)
    }

    /// Delete all sessions (for testing).
    #[cfg(test)]
    pub fn delete_all(&self) -> Result<(), ClingsError> {
        let conn = self.db.connection();

        conn.execute("DELETE FROM focus_sessions", [])
            .map_err(|e| ClingsError::Database(format!("Failed to delete sessions: {}", e)))?;

        Ok(())
    }
}

/// Convert a database row to a FocusSession.
fn row_to_session(row: &Row<'_>) -> Result<FocusSession, rusqlite::Error> {
    let id: i64 = row.get(0)?;
    let task_id: Option<String> = row.get(1)?;
    let task_name: Option<String> = row.get(2)?;
    let started_at_str: String = row.get(3)?;
    let ended_at_str: Option<String> = row.get(4)?;
    let duration: i64 = row.get(5)?;
    let session_type_str: String = row.get(6)?;
    let completed: bool = row.get(7)?;
    let notes: Option<String> = row.get(8)?;

    let started_at = DateTime::parse_from_rfc3339(&started_at_str)
        .map(|t| t.with_timezone(&Utc))
        .unwrap_or_else(|_| Utc::now());

    let ended_at = ended_at_str.and_then(|s| {
        DateTime::parse_from_rfc3339(&s)
            .map(|t| t.with_timezone(&Utc))
            .ok()
    });

    let session_type = string_to_session_type(&session_type_str);
    let state = if ended_at.is_none() {
        SessionState::Running
    } else if completed {
        SessionState::Completed
    } else {
        SessionState::Abandoned
    };

    Ok(FocusSession {
        id: Some(id),
        task_id,
        task_name,
        session_type,
        started_at,
        ended_at,
        planned_duration: duration,
        actual_duration: duration,
        state,
        paused_at: None,
        pause_duration: 0,
        notes,
    })
}

fn session_type_to_string(st: SessionType) -> &'static str {
    match st {
        SessionType::Pomodoro => "pomodoro",
        SessionType::ShortBreak => "short_break",
        SessionType::LongBreak => "long_break",
        SessionType::Focus => "focus",
        SessionType::OpenEnded => "open_ended",
    }
}

fn string_to_session_type(s: &str) -> SessionType {
    match s {
        "pomodoro" => SessionType::Pomodoro,
        "short_break" => SessionType::ShortBreak,
        "long_break" => SessionType::LongBreak,
        "focus" => SessionType::Focus,
        "open_ended" => SessionType::OpenEnded,
        _ => SessionType::Pomodoro,
    }
}

// Add optional() extension for rusqlite
trait OptionalExt<T> {
    fn optional(self) -> Result<Option<T>, rusqlite::Error>;
}

impl<T> OptionalExt<T> for Result<T, rusqlite::Error> {
    fn optional(self) -> Result<Option<T>, rusqlite::Error> {
        match self {
            Ok(value) => Ok(Some(value)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_storage() -> FocusStorage {
        let db = Database::open_in_memory().unwrap();
        FocusStorage::with_database(db)
    }

    #[test]
    fn test_save_and_get() {
        let storage = create_test_storage();

        let mut session = FocusSession::pomodoro(
            Some("task123".to_string()),
            Some("Test Task".to_string()),
        );
        session.complete();

        storage.save(&mut session).unwrap();
        assert!(session.id.is_some());

        let loaded = storage.get(session.id.unwrap()).unwrap().unwrap();
        assert_eq!(loaded.task_id, session.task_id);
        assert_eq!(loaded.task_name, session.task_name);
    }

    #[test]
    fn test_get_active() {
        let storage = create_test_storage();

        // No active session
        assert!(storage.get_active().unwrap().is_none());

        // Create an active session (no ended_at)
        let mut session = FocusSession::pomodoro(None, None);
        storage.save(&mut session).unwrap();

        let active = storage.get_active().unwrap();
        assert!(active.is_some());
    }

    #[test]
    fn test_get_recent() {
        let storage = create_test_storage();

        for i in 0..5 {
            let mut session = FocusSession::new(
                Some(format!("task{}", i)),
                Some(format!("Task {}", i)),
                SessionType::Pomodoro,
                None,
            );
            session.complete();
            storage.save(&mut session).unwrap();
        }

        let recent = storage.get_recent(3).unwrap();
        assert_eq!(recent.len(), 3);
    }

    #[test]
    fn test_delete() {
        let storage = create_test_storage();

        let mut session = FocusSession::pomodoro(None, None);
        session.complete();
        storage.save(&mut session).unwrap();

        let id = session.id.unwrap();
        assert!(storage.delete(id).unwrap());
        assert!(storage.get(id).unwrap().is_none());
    }
}
