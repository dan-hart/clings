//! Sync executor for processing queued operations.
//!
//! Executes operations from the queue with retry logic and conflict handling.

use colored::Colorize;

use super::operation::{
    AddProjectPayload, AddTodoPayload, Operation, OperationType, TagPayload, TodoIdPayload,
};
use super::queue::SyncQueue;
use crate::error::ClingsError;
use crate::things::ThingsClient;

/// Configuration for the sync executor.
#[derive(Debug, Clone)]
pub struct ExecutorConfig {
    /// Maximum number of retry attempts
    pub max_attempts: i32,
    /// Whether to stop on first error
    pub stop_on_error: bool,
    /// Dry run mode (don't actually execute)
    pub dry_run: bool,
}

impl Default for ExecutorConfig {
    fn default() -> Self {
        Self {
            max_attempts: 3,
            stop_on_error: false,
            dry_run: false,
        }
    }
}

/// Result of executing a single operation.
#[derive(Debug)]
pub struct ExecutionResult {
    /// Operation ID
    pub id: i64,
    /// Operation type
    pub operation_type: OperationType,
    /// Whether it succeeded
    pub success: bool,
    /// Error message if failed
    pub error: Option<String>,
    /// Whether it was skipped
    pub skipped: bool,
}

/// Result of executing multiple operations.
#[derive(Debug)]
pub struct SyncResult {
    /// Number of successful operations
    pub succeeded: usize,
    /// Number of failed operations
    pub failed: usize,
    /// Number of skipped operations
    pub skipped: usize,
    /// Individual results
    pub results: Vec<ExecutionResult>,
}

impl SyncResult {
    /// Create an empty result.
    #[must_use]
    pub const fn empty() -> Self {
        Self {
            succeeded: 0,
            failed: 0,
            skipped: 0,
            results: Vec::new(),
        }
    }

    /// Add a result.
    pub fn add(&mut self, result: ExecutionResult) {
        if result.skipped {
            self.skipped += 1;
        } else if result.success {
            self.succeeded += 1;
        } else {
            self.failed += 1;
        }
        self.results.push(result);
    }

    /// Check if all operations succeeded.
    #[must_use]
    pub const fn all_succeeded(&self) -> bool {
        self.failed == 0
    }

    /// Get total operations processed.
    #[must_use]
    pub const fn total(&self) -> usize {
        self.succeeded + self.failed + self.skipped
    }
}

/// Executor for processing sync queue operations.
pub struct SyncExecutor<'a> {
    client: &'a ThingsClient,
    queue: &'a SyncQueue,
    config: ExecutorConfig,
}

impl<'a> SyncExecutor<'a> {
    /// Create a new executor.
    #[must_use]
    pub fn new(client: &'a ThingsClient, queue: &'a SyncQueue) -> Self {
        Self {
            client,
            queue,
            config: ExecutorConfig::default(),
        }
    }

    /// Create an executor with custom config.
    #[must_use]
    pub const fn with_config(
        client: &'a ThingsClient,
        queue: &'a SyncQueue,
        config: ExecutorConfig,
    ) -> Self {
        Self {
            client,
            queue,
            config,
        }
    }

    /// Execute all pending operations.
    ///
    /// # Errors
    ///
    /// Returns an error if database operations fail.
    pub fn execute_all(&self) -> Result<SyncResult, ClingsError> {
        let pending = self.queue.get_pending(100)?;
        let mut result = SyncResult::empty();

        for operation in pending {
            let op_result = self.execute_one(&operation)?;
            let should_stop = !op_result.success && self.config.stop_on_error;
            result.add(op_result);

            if should_stop {
                break;
            }
        }

        Ok(result)
    }

    /// Execute a single operation.
    ///
    /// # Errors
    ///
    /// Returns an error if database operations fail.
    pub fn execute_one(&self, operation: &Operation) -> Result<ExecutionResult, ClingsError> {
        let op_id = operation.id.unwrap_or(0);

        // Check if we've exceeded max attempts
        if operation.attempts >= self.config.max_attempts {
            self.queue.mark_failed(op_id, "Max attempts exceeded")?;
            return Ok(ExecutionResult {
                id: op_id,
                operation_type: operation.operation_type,
                success: false,
                error: Some("Max attempts exceeded".to_string()),
                skipped: false,
            });
        }

        // Dry run mode
        if self.config.dry_run {
            return Ok(ExecutionResult {
                id: op_id,
                operation_type: operation.operation_type,
                success: true,
                error: None,
                skipped: true,
            });
        }

        // Execute the operation
        match self.execute_operation(operation) {
            Ok(()) => {
                self.queue.mark_completed(op_id)?;
                Ok(ExecutionResult {
                    id: op_id,
                    operation_type: operation.operation_type,
                    success: true,
                    error: None,
                    skipped: false,
                })
            },
            Err(e) => {
                let error_msg = e.to_string();
                self.queue.record_attempt(op_id, Some(&error_msg))?;

                // Check if we've now exceeded max attempts
                if operation.attempts + 1 >= self.config.max_attempts {
                    self.queue.mark_failed(op_id, &error_msg)?;
                }

                Ok(ExecutionResult {
                    id: op_id,
                    operation_type: operation.operation_type,
                    success: false,
                    error: Some(error_msg),
                    skipped: false,
                })
            },
        }
    }

    /// Execute the actual operation against Things 3.
    fn execute_operation(&self, operation: &Operation) -> Result<(), ClingsError> {
        match operation.operation_type {
            OperationType::AddTodo => self.execute_add_todo(&operation.payload),
            OperationType::CompleteTodo => self.execute_complete_todo(&operation.payload),
            OperationType::CancelTodo => self.execute_cancel_todo(&operation.payload),
            OperationType::DeleteTodo => self.execute_delete_todo(&operation.payload),
            OperationType::UpdateTodo => Self::execute_update_todo(&operation.payload),
            OperationType::AddProject => self.execute_add_project(&operation.payload),
            OperationType::UpdateProject => Err(ClingsError::NotSupported(
                "Update project not implemented".to_string(),
            )),
            OperationType::AddTags => self.execute_add_tags(&operation.payload),
            OperationType::RemoveTags => Err(ClingsError::NotSupported(
                "Remove tags not implemented".to_string(),
            )),
            OperationType::MoveTodo => Self::execute_move_todo(&operation.payload),
            OperationType::SetDueDate => Self::execute_set_due_date(&operation.payload),
            OperationType::ClearDueDate => Self::execute_clear_due_date(&operation.payload),
        }
    }

    fn execute_add_todo(&self, payload: &str) -> Result<(), ClingsError> {
        let data: AddTodoPayload = serde_json::from_str(payload)
            .map_err(|e| ClingsError::Config(format!("Invalid add todo payload: {e}")))?;

        self.client.add_todo(
            &data.title,
            data.notes.as_deref(),
            data.when.as_deref(),
            data.deadline.as_deref(),
            data.tags.as_deref(),
            data.project.as_deref(),
            data.area.as_deref(),
            data.checklist.as_deref(),
        )?;

        Ok(())
    }

    fn execute_complete_todo(&self, payload: &str) -> Result<(), ClingsError> {
        let data: TodoIdPayload = serde_json::from_str(payload)
            .map_err(|e| ClingsError::Config(format!("Invalid complete payload: {e}")))?;

        self.client.complete_todo(&data.id)?;
        Ok(())
    }

    fn execute_cancel_todo(&self, payload: &str) -> Result<(), ClingsError> {
        let data: TodoIdPayload = serde_json::from_str(payload)
            .map_err(|e| ClingsError::Config(format!("Invalid cancel payload: {e}")))?;

        self.client.cancel_todo(&data.id)?;
        Ok(())
    }

    fn execute_delete_todo(&self, payload: &str) -> Result<(), ClingsError> {
        let data: TodoIdPayload = serde_json::from_str(payload)
            .map_err(|e| ClingsError::Config(format!("Invalid delete payload: {e}")))?;

        self.client.delete_todo(&data.id)?;
        Ok(())
    }

    fn execute_update_todo(_payload: &str) -> Result<(), ClingsError> {
        // Update via URL scheme
        Err(ClingsError::NotSupported(
            "Update todo not yet implemented via sync".to_string(),
        ))
    }

    fn execute_add_project(&self, payload: &str) -> Result<(), ClingsError> {
        let data: AddProjectPayload = serde_json::from_str(payload)
            .map_err(|e| ClingsError::Config(format!("Invalid add project payload: {e}")))?;

        self.client.add_project(
            &data.title,
            data.notes.as_deref(),
            data.area.as_deref(),
            data.tags.as_deref(),
            data.deadline.as_deref(),
        )?;

        Ok(())
    }

    fn execute_add_tags(&self, payload: &str) -> Result<(), ClingsError> {
        let data: TagPayload = serde_json::from_str(payload)
            .map_err(|e| ClingsError::Config(format!("Invalid tag payload: {e}")))?;

        // Add tags by updating the todo
        // This is a simplified version - real implementation would merge tags
        let _todo = self.client.get_todo(&data.id)?;
        // Would need to update via Things URL scheme
        Err(ClingsError::NotSupported(
            "Add tags not yet implemented via sync".to_string(),
        ))
    }

    fn execute_move_todo(_payload: &str) -> Result<(), ClingsError> {
        // Move via Things URL scheme
        // Would need: things:///update?id={id}&list={to_project}
        Err(ClingsError::NotSupported(
            "Move todo not yet implemented via sync".to_string(),
        ))
    }

    fn execute_set_due_date(_payload: &str) -> Result<(), ClingsError> {
        // Set due date via Things URL scheme
        Err(ClingsError::NotSupported(
            "Set due date not yet implemented via sync".to_string(),
        ))
    }

    fn execute_clear_due_date(_payload: &str) -> Result<(), ClingsError> {
        Err(ClingsError::NotSupported(
            "Clear due date not yet implemented via sync".to_string(),
        ))
    }
}

/// Format sync result for display.
#[must_use]
pub fn format_sync_result(result: &SyncResult) -> String {
    let mut lines = Vec::new();

    lines.push(format!("Sync completed: {} operations", result.total()));
    lines.push("─".repeat(40));

    if result.succeeded > 0 {
        lines.push(format!(
            "  {} {}",
            "✓".green(),
            format!("{} succeeded", result.succeeded).green()
        ));
    }

    if result.failed > 0 {
        lines.push(format!(
            "  {} {}",
            "✗".red(),
            format!("{} failed", result.failed).red()
        ));
    }

    if result.skipped > 0 {
        lines.push(format!(
            "  {} {}",
            "○".yellow(),
            format!("{} skipped", result.skipped).yellow()
        ));
    }

    // Show first few errors
    let errors: Vec<_> = result
        .results
        .iter()
        .filter(|r| r.error.is_some())
        .take(3)
        .collect();

    if !errors.is_empty() {
        lines.push(String::new());
        lines.push("Errors:".to_string());
        for err in errors {
            lines.push(format!(
                "  - {}: {}",
                err.operation_type,
                err.error.as_deref().unwrap_or("Unknown error")
            ));
        }
    }

    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sync_result() {
        let mut result = SyncResult::empty();

        result.add(ExecutionResult {
            id: 1,
            operation_type: OperationType::CompleteTodo,
            success: true,
            error: None,
            skipped: false,
        });

        result.add(ExecutionResult {
            id: 2,
            operation_type: OperationType::AddTodo,
            success: false,
            error: Some("Connection failed".to_string()),
            skipped: false,
        });

        assert_eq!(result.succeeded, 1);
        assert_eq!(result.failed, 1);
        assert_eq!(result.total(), 2);
        assert!(!result.all_succeeded());
    }

    #[test]
    fn test_executor_config_default() {
        let config = ExecutorConfig::default();
        assert_eq!(config.max_attempts, 3);
        assert!(!config.stop_on_error);
        assert!(!config.dry_run);
    }
}
