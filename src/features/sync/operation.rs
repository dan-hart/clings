//! Operation types for the sync queue.
//!
//! Defines the various operations that can be queued and their payloads.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Operation types that can be queued.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OperationType {
    /// Add a new todo
    AddTodo,
    /// Complete a todo
    CompleteTodo,
    /// Cancel a todo
    CancelTodo,
    /// Delete a todo
    DeleteTodo,
    /// Update a todo
    UpdateTodo,
    /// Add a project
    AddProject,
    /// Update a project
    UpdateProject,
    /// Add tags to a todo
    AddTags,
    /// Remove tags from a todo
    RemoveTags,
    /// Move a todo to a project
    MoveTodo,
    /// Set due date
    SetDueDate,
    /// Clear due date
    ClearDueDate,
}

impl OperationType {
    /// Get the display name for this operation type.
    #[must_use]
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::AddTodo => "Add Todo",
            Self::CompleteTodo => "Complete Todo",
            Self::CancelTodo => "Cancel Todo",
            Self::DeleteTodo => "Delete Todo",
            Self::UpdateTodo => "Update Todo",
            Self::AddProject => "Add Project",
            Self::UpdateProject => "Update Project",
            Self::AddTags => "Add Tags",
            Self::RemoveTags => "Remove Tags",
            Self::MoveTodo => "Move Todo",
            Self::SetDueDate => "Set Due Date",
            Self::ClearDueDate => "Clear Due Date",
        }
    }

    /// Check if this operation is idempotent (safe to retry).
    #[must_use]
    pub fn is_idempotent(&self) -> bool {
        matches!(
            self,
            Self::CompleteTodo
                | Self::CancelTodo
                | Self::AddTags
                | Self::RemoveTags
                | Self::SetDueDate
                | Self::ClearDueDate
        )
    }

    /// Get the priority of this operation (lower = higher priority).
    #[must_use]
    pub fn priority(&self) -> i32 {
        match self {
            // Deletions and completions are high priority
            Self::DeleteTodo | Self::CompleteTodo | Self::CancelTodo => 1,
            // Updates are medium priority
            Self::UpdateTodo | Self::UpdateProject | Self::MoveTodo => 2,
            Self::AddTags | Self::RemoveTags | Self::SetDueDate | Self::ClearDueDate => 2,
            // Creations are lower priority
            Self::AddTodo | Self::AddProject => 3,
        }
    }
}

impl std::fmt::Display for OperationType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.display_name())
    }
}

/// Status of a queued operation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OperationStatus {
    /// Waiting to be executed
    Pending,
    /// Currently being executed
    InProgress,
    /// Successfully executed
    Completed,
    /// Failed after max retries
    Failed,
    /// Skipped due to conflict
    Skipped,
}

impl OperationStatus {
    /// Check if this status is terminal (no more action needed).
    #[must_use]
    pub fn is_terminal(&self) -> bool {
        matches!(self, Self::Completed | Self::Failed | Self::Skipped)
    }

    /// Convert from string.
    #[must_use]
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "pending" => Self::Pending,
            "in_progress" | "inprogress" => Self::InProgress,
            "completed" => Self::Completed,
            "failed" => Self::Failed,
            "skipped" => Self::Skipped,
            _ => Self::Pending,
        }
    }
}

impl std::fmt::Display for OperationStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            Self::Pending => "pending",
            Self::InProgress => "in_progress",
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Skipped => "skipped",
        };
        write!(f, "{s}")
    }
}

/// Payload for add todo operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddTodoPayload {
    pub title: String,
    pub notes: Option<String>,
    pub when: Option<String>,
    pub deadline: Option<String>,
    pub tags: Option<Vec<String>>,
    pub project: Option<String>,
    pub area: Option<String>,
    pub checklist: Option<Vec<String>>,
}

/// Payload for complete/cancel/delete operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TodoIdPayload {
    pub id: String,
}

/// Payload for update todo operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateTodoPayload {
    pub id: String,
    pub title: Option<String>,
    pub notes: Option<String>,
    pub when: Option<String>,
    pub deadline: Option<String>,
    pub tags: Option<Vec<String>>,
}

/// Payload for add project operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddProjectPayload {
    pub title: String,
    pub notes: Option<String>,
    pub area: Option<String>,
    pub tags: Option<Vec<String>>,
    pub deadline: Option<String>,
}

/// Payload for tag operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagPayload {
    pub id: String,
    pub tags: Vec<String>,
}

/// Payload for move operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MovePayload {
    pub id: String,
    pub to_project: String,
}

/// Payload for set due date operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DueDatePayload {
    pub id: String,
    pub date: Option<String>,
}

/// A queued operation with metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Operation {
    /// Unique ID
    pub id: Option<i64>,
    /// Operation type
    pub operation_type: OperationType,
    /// JSON payload
    pub payload: String,
    /// When the operation was queued
    pub created_at: DateTime<Utc>,
    /// Number of execution attempts
    pub attempts: i32,
    /// Last attempt timestamp
    pub last_attempt: Option<DateTime<Utc>>,
    /// Last error message
    pub last_error: Option<String>,
    /// Current status
    pub status: OperationStatus,
}

impl Operation {
    /// Create a new pending operation.
    #[must_use]
    pub fn new(operation_type: OperationType, payload: String) -> Self {
        Self {
            id: None,
            operation_type,
            payload,
            created_at: Utc::now(),
            attempts: 0,
            last_attempt: None,
            last_error: None,
            status: OperationStatus::Pending,
        }
    }

    /// Create an add todo operation.
    #[must_use]
    pub fn add_todo(payload: AddTodoPayload) -> Self {
        let json = serde_json::to_string(&payload).unwrap_or_default();
        Self::new(OperationType::AddTodo, json)
    }

    /// Create a complete todo operation.
    #[must_use]
    pub fn complete_todo(id: String) -> Self {
        let payload = TodoIdPayload { id };
        let json = serde_json::to_string(&payload).unwrap_or_default();
        Self::new(OperationType::CompleteTodo, json)
    }

    /// Create a cancel todo operation.
    #[must_use]
    pub fn cancel_todo(id: String) -> Self {
        let payload = TodoIdPayload { id };
        let json = serde_json::to_string(&payload).unwrap_or_default();
        Self::new(OperationType::CancelTodo, json)
    }

    /// Create a delete todo operation.
    #[must_use]
    pub fn delete_todo(id: String) -> Self {
        let payload = TodoIdPayload { id };
        let json = serde_json::to_string(&payload).unwrap_or_default();
        Self::new(OperationType::DeleteTodo, json)
    }

    /// Create an add project operation.
    #[must_use]
    pub fn add_project(payload: AddProjectPayload) -> Self {
        let json = serde_json::to_string(&payload).unwrap_or_default();
        Self::new(OperationType::AddProject, json)
    }

    /// Create an add tags operation.
    #[must_use]
    pub fn add_tags(id: String, tags: Vec<String>) -> Self {
        let payload = TagPayload { id, tags };
        let json = serde_json::to_string(&payload).unwrap_or_default();
        Self::new(OperationType::AddTags, json)
    }

    /// Create a move todo operation.
    #[must_use]
    pub fn move_todo(id: String, to_project: String) -> Self {
        let payload = MovePayload { id, to_project };
        let json = serde_json::to_string(&payload).unwrap_or_default();
        Self::new(OperationType::MoveTodo, json)
    }

    /// Create a set due date operation.
    #[must_use]
    pub fn set_due_date(id: String, date: String) -> Self {
        let payload = DueDatePayload { id, date: Some(date) };
        let json = serde_json::to_string(&payload).unwrap_or_default();
        Self::new(OperationType::SetDueDate, json)
    }

    /// Create a clear due date operation.
    #[must_use]
    pub fn clear_due_date(id: String) -> Self {
        let payload = DueDatePayload { id, date: None };
        let json = serde_json::to_string(&payload).unwrap_or_default();
        Self::new(OperationType::ClearDueDate, json)
    }

    /// Check if operation should be retried.
    #[must_use]
    pub fn should_retry(&self, max_attempts: i32) -> bool {
        self.status == OperationStatus::Pending && self.attempts < max_attempts
    }

    /// Calculate next retry delay using exponential backoff.
    #[must_use]
    pub fn retry_delay_seconds(&self) -> i64 {
        // Base delay of 5 seconds, doubling each attempt up to 5 minutes
        let delay = 5 * (2_i64.pow(self.attempts as u32));
        delay.min(300) // Cap at 5 minutes
    }

    /// Get the target ID from the payload (if applicable).
    #[must_use]
    pub fn target_id(&self) -> Option<String> {
        match self.operation_type {
            OperationType::AddTodo | OperationType::AddProject => None,
            _ => {
                // Try to extract "id" field from JSON
                if let Ok(v) = serde_json::from_str::<serde_json::Value>(&self.payload) {
                    v.get("id").and_then(|id| id.as_str()).map(String::from)
                } else {
                    None
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_operation_type_display() {
        assert_eq!(OperationType::AddTodo.display_name(), "Add Todo");
        assert_eq!(OperationType::CompleteTodo.display_name(), "Complete Todo");
    }

    #[test]
    fn test_operation_type_priority() {
        assert!(OperationType::CompleteTodo.priority() < OperationType::AddTodo.priority());
    }

    #[test]
    fn test_operation_type_idempotent() {
        assert!(OperationType::CompleteTodo.is_idempotent());
        assert!(!OperationType::AddTodo.is_idempotent());
    }

    #[test]
    fn test_operation_status_terminal() {
        assert!(OperationStatus::Completed.is_terminal());
        assert!(OperationStatus::Failed.is_terminal());
        assert!(!OperationStatus::Pending.is_terminal());
    }

    #[test]
    fn test_create_operations() {
        let add = Operation::add_todo(AddTodoPayload {
            title: "Test".to_string(),
            notes: None,
            when: None,
            deadline: None,
            tags: None,
            project: None,
            area: None,
            checklist: None,
        });
        assert_eq!(add.operation_type, OperationType::AddTodo);
        assert_eq!(add.status, OperationStatus::Pending);

        let complete = Operation::complete_todo("ABC123".to_string());
        assert_eq!(complete.operation_type, OperationType::CompleteTodo);
        assert_eq!(complete.target_id(), Some("ABC123".to_string()));
    }

    #[test]
    fn test_retry_delay() {
        let mut op = Operation::complete_todo("ABC".to_string());
        assert_eq!(op.retry_delay_seconds(), 5);

        op.attempts = 1;
        assert_eq!(op.retry_delay_seconds(), 10);

        op.attempts = 5;
        assert_eq!(op.retry_delay_seconds(), 160);

        op.attempts = 10;
        assert_eq!(op.retry_delay_seconds(), 300); // Capped at 5 minutes
    }

    #[test]
    fn test_add_todo_payload_with_area() {
        let payload = AddTodoPayload {
            title: "Test task".to_string(),
            notes: None,
            when: Some("2024-12-15".to_string()),
            deadline: Some("2024-12-20".to_string()),
            tags: None,
            project: None,
            area: Some("Work".to_string()),
            checklist: None,
        };

        assert_eq!(payload.title, "Test task");
        assert_eq!(payload.area, Some("Work".to_string()));
        assert_eq!(payload.when, Some("2024-12-15".to_string()));
        assert_eq!(payload.deadline, Some("2024-12-20".to_string()));
    }

    #[test]
    fn test_add_todo_payload_serialization() {
        let payload = AddTodoPayload {
            title: "Task".to_string(),
            notes: Some("Notes".to_string()),
            when: Some("2024-12-15".to_string()),
            deadline: Some("2024-12-20".to_string()),
            tags: Some(vec!["work".to_string()]),
            project: Some("Project".to_string()),
            area: Some("Work".to_string()),
            checklist: Some(vec!["Step 1".to_string()]),
        };

        let json = serde_json::to_string(&payload).expect("should serialize");
        assert!(json.contains("\"title\":\"Task\""));
        assert!(json.contains("\"area\":\"Work\""));
        assert!(json.contains("\"when\":\"2024-12-15\""));
        assert!(json.contains("\"deadline\":\"2024-12-20\""));
    }

    #[test]
    fn test_add_todo_payload_deserialization() {
        let json = r#"{
            "title": "Test task",
            "area": "Personal",
            "when": "2024-12-15",
            "deadline": "2024-12-20"
        }"#;

        let payload: AddTodoPayload = serde_json::from_str(json).expect("should deserialize");
        assert_eq!(payload.title, "Test task");
        assert_eq!(payload.area, Some("Personal".to_string()));
        assert_eq!(payload.when, Some("2024-12-15".to_string()));
        assert_eq!(payload.deadline, Some("2024-12-20".to_string()));
        assert!(payload.project.is_none());
    }

    #[test]
    fn test_add_todo_payload_deserialization_minimal() {
        let json = r#"{"title": "Simple task"}"#;

        let payload: AddTodoPayload = serde_json::from_str(json).expect("should deserialize");
        assert_eq!(payload.title, "Simple task");
        assert!(payload.area.is_none());
        assert!(payload.when.is_none());
        assert!(payload.deadline.is_none());
    }
}
