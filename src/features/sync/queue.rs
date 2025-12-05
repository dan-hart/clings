//! Sync queue storage and management.
//!
//! Provides persistence and querying of queued operations.

use chrono::{DateTime, Utc};
use rusqlite::{params, Row};

use super::operation::{Operation, OperationStatus, OperationType};
use crate::error::ClingsError;
use crate::storage::Database;

/// Sync queue for managing offline operations.
pub struct SyncQueue {
    db: Database,
}

impl SyncQueue {
    /// Create a new sync queue.
    ///
    /// # Errors
    ///
    /// Returns an error if the database cannot be opened.
    pub fn new() -> Result<Self, ClingsError> {
        let db = Database::open()?;
        Ok(Self { db })
    }

    /// Create a sync queue with an existing database connection.
    #[must_use]
    pub const fn with_database(db: Database) -> Self {
        Self { db }
    }

    /// Add an operation to the queue.
    ///
    /// # Errors
    ///
    /// Returns an error if the operation cannot be saved.
    pub fn enqueue(&self, operation: &mut Operation) -> Result<(), ClingsError> {
        let conn = self.db.connection();

        conn.execute(
            r"INSERT INTO sync_queue (operation_type, payload, created_at, attempts, status)
              VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                operation_type_to_string(operation.operation_type),
                operation.payload,
                operation.created_at.to_rfc3339(),
                operation.attempts,
                operation.status.to_string(),
            ],
        )
        .map_err(|e| ClingsError::Database(format!("Failed to enqueue operation: {e}")))?;

        operation.id = Some(conn.last_insert_rowid());
        Ok(())
    }

    /// Get pending operations, ordered by priority and creation time.
    ///
    /// # Errors
    ///
    /// Returns an error if the query fails.
    pub fn get_pending(&self, limit: usize) -> Result<Vec<Operation>, ClingsError> {
        let conn = self.db.connection();

        let mut stmt = conn
            .prepare(
                r"SELECT id, operation_type, payload, created_at, attempts,
                         last_attempt, last_error, status
                  FROM sync_queue
                  WHERE status = 'pending'
                  ORDER BY created_at ASC
                  LIMIT ?1",
            )
            .map_err(|e| ClingsError::Database(format!("Failed to prepare query: {e}")))?;

        let rows = stmt.query_map([limit], row_to_operation).map_err(|e| {
            ClingsError::Database(format!("Failed to query pending operations: {e}"))
        })?;

        let mut operations = Vec::new();
        for row in rows {
            operations.push(row.map_err(|e| ClingsError::Database(e.to_string()))?);
        }

        // Sort by priority
        operations.sort_by_key(|op| op.operation_type.priority());

        Ok(operations)
    }

    /// Get all operations with a given status.
    ///
    /// # Errors
    ///
    /// Returns an error if the query fails.
    pub fn get_by_status(&self, status: OperationStatus) -> Result<Vec<Operation>, ClingsError> {
        let conn = self.db.connection();

        let mut stmt = conn
            .prepare(
                r"SELECT id, operation_type, payload, created_at, attempts,
                         last_attempt, last_error, status
                  FROM sync_queue
                  WHERE status = ?1
                  ORDER BY created_at DESC",
            )
            .map_err(|e| ClingsError::Database(format!("Failed to prepare query: {e}")))?;

        let rows = stmt
            .query_map([status.to_string()], row_to_operation)
            .map_err(|e| ClingsError::Database(format!("Failed to query operations: {e}")))?;

        let mut operations = Vec::new();
        for row in rows {
            operations.push(row.map_err(|e| ClingsError::Database(e.to_string()))?);
        }

        Ok(operations)
    }

    /// Get a specific operation by ID.
    ///
    /// # Errors
    ///
    /// Returns an error if the query fails.
    pub fn get(&self, id: i64) -> Result<Option<Operation>, ClingsError> {
        let conn = self.db.connection();

        let mut stmt = conn
            .prepare(
                r"SELECT id, operation_type, payload, created_at, attempts,
                         last_attempt, last_error, status
                  FROM sync_queue
                  WHERE id = ?1",
            )
            .map_err(|e| ClingsError::Database(format!("Failed to prepare query: {e}")))?;

        let result = stmt
            .query_row([id], row_to_operation)
            .optional()
            .map_err(|e| ClingsError::Database(format!("Failed to query operation: {e}")))?;

        Ok(result)
    }

    /// Update an operation.
    ///
    /// # Errors
    ///
    /// Returns an error if the update fails.
    pub fn update(&self, operation: &Operation) -> Result<(), ClingsError> {
        let conn = self.db.connection();

        conn.execute(
            r"UPDATE sync_queue SET
              operation_type = ?1,
              payload = ?2,
              attempts = ?3,
              last_attempt = ?4,
              last_error = ?5,
              status = ?6
              WHERE id = ?7",
            params![
                operation_type_to_string(operation.operation_type),
                operation.payload,
                operation.attempts,
                operation.last_attempt.map(|t| t.to_rfc3339()),
                operation.last_error,
                operation.status.to_string(),
                operation.id,
            ],
        )
        .map_err(|e| ClingsError::Database(format!("Failed to update operation: {e}")))?;

        Ok(())
    }

    /// Mark an operation as completed.
    ///
    /// # Errors
    ///
    /// Returns an error if the update fails.
    pub fn mark_completed(&self, id: i64) -> Result<(), ClingsError> {
        let conn = self.db.connection();

        conn.execute(
            "UPDATE sync_queue SET status = 'completed', last_attempt = ?1 WHERE id = ?2",
            params![Utc::now().to_rfc3339(), id],
        )
        .map_err(|e| ClingsError::Database(format!("Failed to mark operation completed: {e}")))?;

        Ok(())
    }

    /// Mark an operation as failed with error.
    ///
    /// # Errors
    ///
    /// Returns an error if the update fails.
    pub fn mark_failed(&self, id: i64, error: &str) -> Result<(), ClingsError> {
        let conn = self.db.connection();

        conn.execute(
            r"UPDATE sync_queue SET
              status = 'failed',
              last_attempt = ?1,
              last_error = ?2,
              attempts = attempts + 1
              WHERE id = ?3",
            params![Utc::now().to_rfc3339(), error, id],
        )
        .map_err(|e| ClingsError::Database(format!("Failed to mark operation failed: {e}")))?;

        Ok(())
    }

    /// Increment attempt count and record error for retry.
    ///
    /// # Errors
    ///
    /// Returns an error if the update fails.
    pub fn record_attempt(&self, id: i64, error: Option<&str>) -> Result<(), ClingsError> {
        let conn = self.db.connection();

        conn.execute(
            r"UPDATE sync_queue SET
              last_attempt = ?1,
              last_error = ?2,
              attempts = attempts + 1
              WHERE id = ?3",
            params![Utc::now().to_rfc3339(), error, id],
        )
        .map_err(|e| ClingsError::Database(format!("Failed to record attempt: {e}")))?;

        Ok(())
    }

    /// Delete an operation.
    ///
    /// # Errors
    ///
    /// Returns an error if the delete fails.
    pub fn delete(&self, id: i64) -> Result<bool, ClingsError> {
        let conn = self.db.connection();

        let rows = conn
            .execute("DELETE FROM sync_queue WHERE id = ?1", [id])
            .map_err(|e| ClingsError::Database(format!("Failed to delete operation: {e}")))?;

        Ok(rows > 0)
    }

    /// Delete completed operations older than the specified age.
    ///
    /// # Errors
    ///
    /// Returns an error if the delete fails.
    pub fn cleanup(&self, max_age_hours: i64) -> Result<usize, ClingsError> {
        let conn = self.db.connection();
        let cutoff = Utc::now() - chrono::Duration::hours(max_age_hours);

        let rows = conn
            .execute(
                "DELETE FROM sync_queue WHERE status = 'completed' AND created_at < ?1",
                [cutoff.to_rfc3339()],
            )
            .map_err(|e| ClingsError::Database(format!("Failed to cleanup operations: {e}")))?;

        Ok(rows)
    }

    /// Get queue statistics.
    ///
    /// # Errors
    ///
    /// Returns an error if the query fails.
    pub fn stats(&self) -> Result<QueueStats, ClingsError> {
        let conn = self.db.connection();

        let pending: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sync_queue WHERE status = 'pending'",
                [],
                |row| row.get(0),
            )
            .map_err(|e| ClingsError::Database(format!("Failed to count pending: {e}")))?;

        let completed: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sync_queue WHERE status = 'completed'",
                [],
                |row| row.get(0),
            )
            .map_err(|e| ClingsError::Database(format!("Failed to count completed: {e}")))?;

        let failed: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sync_queue WHERE status = 'failed'",
                [],
                |row| row.get(0),
            )
            .map_err(|e| ClingsError::Database(format!("Failed to count failed: {e}")))?;

        let oldest_pending: Option<String> = conn
            .query_row(
                "SELECT created_at FROM sync_queue WHERE status = 'pending' ORDER BY created_at ASC LIMIT 1",
                [],
                |row| row.get(0),
            )
            .optional()
            .map_err(|e| ClingsError::Database(format!("Failed to get oldest pending: {e}")))?;

        Ok(QueueStats {
            pending,
            completed,
            failed,
            oldest_pending: oldest_pending
                .and_then(|s| DateTime::parse_from_rfc3339(&s).ok())
                .map(|t| t.with_timezone(&Utc)),
        })
    }

    /// Clear all operations (for testing/reset).
    ///
    /// # Errors
    ///
    /// Returns an error if the delete fails.
    pub fn clear(&self) -> Result<(), ClingsError> {
        let conn = self.db.connection();

        conn.execute("DELETE FROM sync_queue", [])
            .map_err(|e| ClingsError::Database(format!("Failed to clear queue: {e}")))?;

        Ok(())
    }

    /// Check if there are any pending operations.
    ///
    /// # Errors
    ///
    /// Returns an error if the query fails.
    pub fn has_pending(&self) -> Result<bool, ClingsError> {
        let conn = self.db.connection();

        let count: i64 = conn
            .query_row(
                "SELECT COUNT(*) FROM sync_queue WHERE status = 'pending'",
                [],
                |row| row.get(0),
            )
            .map_err(|e| ClingsError::Database(format!("Failed to check pending: {e}")))?;

        Ok(count > 0)
    }
}

/// Queue statistics.
#[derive(Debug, Clone)]
pub struct QueueStats {
    /// Number of pending operations
    pub pending: i64,
    /// Number of completed operations
    pub completed: i64,
    /// Number of failed operations
    pub failed: i64,
    /// Oldest pending operation timestamp
    pub oldest_pending: Option<DateTime<Utc>>,
}

const fn operation_type_to_string(ot: OperationType) -> &'static str {
    match ot {
        OperationType::AddTodo => "add_todo",
        OperationType::CompleteTodo => "complete_todo",
        OperationType::CancelTodo => "cancel_todo",
        OperationType::DeleteTodo => "delete_todo",
        OperationType::UpdateTodo => "update_todo",
        OperationType::AddProject => "add_project",
        OperationType::UpdateProject => "update_project",
        OperationType::AddTags => "add_tags",
        OperationType::RemoveTags => "remove_tags",
        OperationType::MoveTodo => "move_todo",
        OperationType::SetDueDate => "set_due_date",
        OperationType::ClearDueDate => "clear_due_date",
    }
}

fn string_to_operation_type(s: &str) -> OperationType {
    match s {
        "complete_todo" => OperationType::CompleteTodo,
        "cancel_todo" => OperationType::CancelTodo,
        "delete_todo" => OperationType::DeleteTodo,
        "update_todo" => OperationType::UpdateTodo,
        "add_project" => OperationType::AddProject,
        "update_project" => OperationType::UpdateProject,
        "add_tags" => OperationType::AddTags,
        "remove_tags" => OperationType::RemoveTags,
        "move_todo" => OperationType::MoveTodo,
        "set_due_date" => OperationType::SetDueDate,
        "clear_due_date" => OperationType::ClearDueDate,
        "add_todo" | _ => OperationType::AddTodo,
    }
}

fn row_to_operation(row: &Row<'_>) -> Result<Operation, rusqlite::Error> {
    let id: i64 = row.get(0)?;
    let operation_type_str: String = row.get(1)?;
    let payload: String = row.get(2)?;
    let created_at_str: String = row.get(3)?;
    let attempts: i32 = row.get(4)?;
    let last_attempt_str: Option<String> = row.get(5)?;
    let last_error: Option<String> = row.get(6)?;
    let status_str: String = row.get(7)?;

    let created_at = DateTime::parse_from_rfc3339(&created_at_str)
        .map_or_else(|_| Utc::now(), |t| t.with_timezone(&Utc));

    let last_attempt = last_attempt_str.and_then(|s| {
        DateTime::parse_from_rfc3339(&s)
            .map(|t| t.with_timezone(&Utc))
            .ok()
    });

    Ok(Operation {
        id: Some(id),
        operation_type: string_to_operation_type(&operation_type_str),
        payload,
        created_at,
        attempts,
        last_attempt,
        last_error,
        status: OperationStatus::from_string(&status_str),
    })
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

    fn create_test_queue() -> SyncQueue {
        let db = Database::open_in_memory().unwrap();
        SyncQueue::with_database(db)
    }

    #[test]
    fn test_enqueue_and_get() {
        let queue = create_test_queue();

        let mut op = Operation::complete_todo("ABC123".to_string());
        queue.enqueue(&mut op).unwrap();
        assert!(op.id.is_some());

        let loaded = queue.get(op.id.unwrap()).unwrap().unwrap();
        assert_eq!(loaded.operation_type, OperationType::CompleteTodo);
        assert_eq!(loaded.status, OperationStatus::Pending);
    }

    #[test]
    fn test_get_pending() {
        let queue = create_test_queue();

        // Add operations in different order
        let mut add = Operation::add_todo(&super::super::operation::AddTodoPayload {
            title: "Test".to_string(),
            notes: None,
            when: None,
            deadline: None,
            tags: None,
            project: None,
            area: None,
            checklist: None,
        });
        queue.enqueue(&mut add).unwrap();

        let mut complete = Operation::complete_todo("XYZ".to_string());
        queue.enqueue(&mut complete).unwrap();

        let pending = queue.get_pending(10).unwrap();
        assert_eq!(pending.len(), 2);

        // Complete should come first (higher priority)
        assert_eq!(pending[0].operation_type, OperationType::CompleteTodo);
        assert_eq!(pending[1].operation_type, OperationType::AddTodo);
    }

    #[test]
    fn test_mark_completed() {
        let queue = create_test_queue();

        let mut op = Operation::complete_todo("ABC".to_string());
        queue.enqueue(&mut op).unwrap();

        queue.mark_completed(op.id.unwrap()).unwrap();

        let loaded = queue.get(op.id.unwrap()).unwrap().unwrap();
        assert_eq!(loaded.status, OperationStatus::Completed);
    }

    #[test]
    fn test_mark_failed() {
        let queue = create_test_queue();

        let mut op = Operation::complete_todo("ABC".to_string());
        queue.enqueue(&mut op).unwrap();

        queue
            .mark_failed(op.id.unwrap(), "Connection error")
            .unwrap();

        let loaded = queue.get(op.id.unwrap()).unwrap().unwrap();
        assert_eq!(loaded.status, OperationStatus::Failed);
        assert_eq!(loaded.last_error, Some("Connection error".to_string()));
    }

    #[test]
    fn test_stats() {
        let queue = create_test_queue();

        let mut op1 = Operation::complete_todo("A".to_string());
        queue.enqueue(&mut op1).unwrap();

        let mut op2 = Operation::complete_todo("B".to_string());
        queue.enqueue(&mut op2).unwrap();
        queue.mark_completed(op2.id.unwrap()).unwrap();

        let stats = queue.stats().unwrap();
        assert_eq!(stats.pending, 1);
        assert_eq!(stats.completed, 1);
        assert_eq!(stats.failed, 0);
    }

    #[test]
    fn test_delete() {
        let queue = create_test_queue();

        let mut op = Operation::complete_todo("ABC".to_string());
        queue.enqueue(&mut op).unwrap();

        assert!(queue.delete(op.id.unwrap()).unwrap());
        assert!(queue.get(op.id.unwrap()).unwrap().is_none());
    }
}
