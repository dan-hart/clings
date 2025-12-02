//! Bulk operation implementations.
//!
//! Provides operations that can be applied to multiple items matching a filter.

use crate::core::{filter_items, parse_filter, FilterExpr};
use crate::error::ClingsError;
use crate::things::{ThingsClient, Todo};

/// A bulk action to perform on items.
#[derive(Debug, Clone)]
pub enum BulkAction {
    /// Mark items as complete.
    Complete,
    /// Mark items as canceled.
    Cancel,
    /// Add tags to items.
    Tag(Vec<String>),
    /// Remove tags from items.
    Untag(Vec<String>),
    /// Move items to a project.
    MoveToProject(String),
    /// Move items to an area.
    MoveToArea(String),
    /// Set due date for items.
    SetDue(String),
    /// Clear due date for items.
    ClearDue,
    /// Open items in Things (one at a time).
    Open,
}

impl std::fmt::Display for BulkAction {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Complete => write!(f, "complete"),
            Self::Cancel => write!(f, "cancel"),
            Self::Tag(tags) => write!(f, "tag with {}", tags.join(", ")),
            Self::Untag(tags) => write!(f, "remove tags {}", tags.join(", ")),
            Self::MoveToProject(p) => write!(f, "move to project '{p}'"),
            Self::MoveToArea(a) => write!(f, "move to area '{a}'"),
            Self::SetDue(d) => write!(f, "set due date to {d}"),
            Self::ClearDue => write!(f, "clear due date"),
            Self::Open => write!(f, "open in Things"),
        }
    }
}

/// A bulk operation specification.
#[derive(Debug, Clone)]
pub struct BulkOperation {
    /// The filter expression to select items.
    pub filter: FilterExpr,
    /// The action to perform on matching items.
    pub action: BulkAction,
    /// Whether to run in dry-run mode (no actual changes).
    pub dry_run: bool,
}

impl BulkOperation {
    /// Create a new bulk operation from a filter query and action.
    ///
    /// # Errors
    ///
    /// Returns an error if the filter query is invalid.
    pub fn new(filter_query: &str, action: BulkAction, dry_run: bool) -> Result<Self, ClingsError> {
        let filter = parse_filter(filter_query)?;
        Ok(Self {
            filter,
            action,
            dry_run,
        })
    }

    /// Create a bulk operation with no filter (matches all items).
    ///
    /// # Panics
    ///
    /// This function will not panic as it constructs a valid filter directly.
    #[must_use]
    pub fn all(action: BulkAction, dry_run: bool) -> Self {
        // Construct a filter that matches everything directly (no parsing needed)
        // This avoids potential panics from parsing
        use crate::core::filter::{Condition, FilterValue, Operator};

        // Filter: status IN ('open', 'completed', 'canceled')
        let filter = FilterExpr::Condition(Condition {
            field: "status".to_string(),
            operator: Operator::In,
            value: FilterValue::StringList(vec![
                "open".to_string(),
                "completed".to_string(),
                "canceled".to_string(),
            ]),
        });

        Self {
            filter,
            action,
            dry_run,
        }
    }
}

/// Result of a bulk operation on a single item.
#[derive(Debug, Clone)]
pub struct BulkResult {
    /// The item ID.
    pub id: String,
    /// The item name.
    pub name: String,
    /// Whether the operation succeeded.
    pub success: bool,
    /// Error message if failed.
    pub error: Option<String>,
}

/// Summary of a bulk operation.
#[derive(Debug, Clone)]
pub struct BulkSummary {
    /// Total items that matched the filter.
    pub matched: usize,
    /// Number of successful operations.
    pub succeeded: usize,
    /// Number of failed operations.
    pub failed: usize,
    /// Individual results.
    pub results: Vec<BulkResult>,
    /// Whether this was a dry run.
    pub dry_run: bool,
    /// The action that was performed.
    pub action: String,
}

impl BulkSummary {
    /// Create a new summary.
    fn new(action: &BulkAction, dry_run: bool) -> Self {
        Self {
            matched: 0,
            succeeded: 0,
            failed: 0,
            results: Vec::new(),
            dry_run,
            action: action.to_string(),
        }
    }

    /// Add a successful result.
    fn add_success(&mut self, id: String, name: String) {
        self.succeeded += 1;
        self.results.push(BulkResult {
            id,
            name,
            success: true,
            error: None,
        });
    }

    /// Add a failed result.
    fn add_failure(&mut self, id: String, name: String, error: String) {
        self.failed += 1;
        self.results.push(BulkResult {
            id,
            name,
            success: false,
            error: Some(error),
        });
    }
}

/// Execute a bulk operation on todos.
///
/// Uses batch JXA operations for performance when possible.
///
/// # Errors
///
/// Returns an error if the operation fails to execute.
pub fn execute_bulk_operation(
    client: &ThingsClient,
    todos: &[Todo],
    operation: &BulkOperation,
) -> Result<BulkSummary, ClingsError> {
    let matching: Vec<&Todo> = filter_items(todos, &operation.filter);
    let mut summary = BulkSummary::new(&operation.action, operation.dry_run);
    summary.matched = matching.len();

    if operation.dry_run {
        // In dry-run mode, just report what would happen
        for todo in matching {
            summary.add_success(todo.id.clone(), todo.name.clone());
        }
        return Ok(summary);
    }

    // Build a map of id -> name for result reporting
    let id_to_name: std::collections::HashMap<String, String> = matching
        .iter()
        .map(|t| (t.id.clone(), t.name.clone()))
        .collect();

    // Try to use batch operations for supported actions
    match &operation.action {
        BulkAction::Complete => {
            let ids: Vec<String> = matching.iter().map(|t| t.id.clone()).collect();
            let batch_result = client.complete_todos_batch(&ids)?;
            apply_batch_result_to_summary(&mut summary, &batch_result, &id_to_name);
        }
        BulkAction::Cancel => {
            let ids: Vec<String> = matching.iter().map(|t| t.id.clone()).collect();
            let batch_result = client.cancel_todos_batch(&ids)?;
            apply_batch_result_to_summary(&mut summary, &batch_result, &id_to_name);
        }
        BulkAction::Tag(tags) => {
            let ids: Vec<String> = matching.iter().map(|t| t.id.clone()).collect();
            let batch_result = client.add_tags_batch(&ids, tags)?;
            apply_batch_result_to_summary(&mut summary, &batch_result, &id_to_name);
        }
        BulkAction::MoveToProject(project) => {
            let ids: Vec<String> = matching.iter().map(|t| t.id.clone()).collect();
            let batch_result = client.move_todos_batch(&ids, project)?;
            apply_batch_result_to_summary(&mut summary, &batch_result, &id_to_name);
        }
        BulkAction::SetDue(date) => {
            let ids: Vec<String> = matching.iter().map(|t| t.id.clone()).collect();
            let batch_result = client.update_todos_due_batch(&ids, date)?;
            apply_batch_result_to_summary(&mut summary, &batch_result, &id_to_name);
        }
        BulkAction::ClearDue => {
            let ids: Vec<String> = matching.iter().map(|t| t.id.clone()).collect();
            let batch_result = client.clear_todos_due_batch(&ids)?;
            apply_batch_result_to_summary(&mut summary, &batch_result, &id_to_name);
        }
        // Fallback to sequential execution for unsupported batch operations
        _ => {
            for todo in matching {
                let result = execute_action(client, todo, &operation.action);
                match result {
                    Ok(()) => summary.add_success(todo.id.clone(), todo.name.clone()),
                    Err(e) => summary.add_failure(todo.id.clone(), todo.name.clone(), e.to_string()),
                }
            }
        }
    }

    Ok(summary)
}

/// Apply batch operation results to the summary.
fn apply_batch_result_to_summary(
    summary: &mut BulkSummary,
    batch_result: &crate::things::BatchResult,
    id_to_name: &std::collections::HashMap<String, String>,
) {
    // Record successes
    // Note: batch results don't return individual success IDs, so we calculate them
    let failed_ids: std::collections::HashSet<String> =
        batch_result.errors.iter().map(|e| e.id.clone()).collect();

    for (id, name) in id_to_name {
        if failed_ids.contains(id) {
            // Find the error for this ID
            if let Some(err) = batch_result.errors.iter().find(|e| &e.id == id) {
                summary.add_failure(id.clone(), name.clone(), err.error.clone());
            }
        } else {
            summary.add_success(id.clone(), name.clone());
        }
    }
}

/// Execute a single action on a todo.
fn execute_action(
    client: &ThingsClient,
    todo: &Todo,
    action: &BulkAction,
) -> Result<(), ClingsError> {
    match action {
        BulkAction::Complete => client.complete_todo(&todo.id),
        BulkAction::Cancel => client.cancel_todo(&todo.id),
        BulkAction::Tag(tags) => {
            // Things 3 URL scheme supports adding tags
            let tag_str = tags.join(",");
            client.update_todo_tags(&todo.id, &tag_str)
        }
        BulkAction::Untag(_tags) => {
            // Note: Things 3 API doesn't have direct tag removal
            // This would require reading current tags, removing, then setting
            Err(ClingsError::BulkOperation(
                "Tag removal not yet supported".to_string(),
            ))
        }
        BulkAction::MoveToProject(project) => client.move_todo_to_list(&todo.id, project),
        BulkAction::MoveToArea(_area) => {
            // Things 3 API doesn't support moving directly to an area
            Err(ClingsError::BulkOperation(
                "Moving to area not yet supported".to_string(),
            ))
        }
        BulkAction::SetDue(date) => client.update_todo_due(&todo.id, date),
        BulkAction::ClearDue => client.clear_todo_due(&todo.id),
        BulkAction::Open => client.open(&todo.id),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::things::types::Status;
    use chrono::NaiveDate;

    fn make_todo(name: &str, status: Status, due: Option<&str>, tags: &[&str]) -> Todo {
        Todo {
            id: format!("test-{}", name.replace(' ', "-")),
            name: name.to_string(),
            notes: String::new(),
            status,
            due_date: due.and_then(|d| NaiveDate::parse_from_str(d, "%Y-%m-%d").ok()),
            tags: tags.iter().map(|s| (*s).to_string()).collect(),
            project: None,
            area: None,
            checklist_items: vec![],
            creation_date: None,
            modification_date: None,
        }
    }

    #[test]
    fn test_bulk_operation_new() {
        let op = BulkOperation::new("status = open", BulkAction::Complete, false);
        assert!(op.is_ok());

        let op = BulkOperation::new("invalid ?? query", BulkAction::Complete, false);
        assert!(op.is_err());
    }

    #[test]
    fn test_bulk_action_display() {
        assert_eq!(BulkAction::Complete.to_string(), "complete");
        assert_eq!(BulkAction::Cancel.to_string(), "cancel");
        assert_eq!(
            BulkAction::Tag(vec!["work".to_string(), "urgent".to_string()]).to_string(),
            "tag with work, urgent"
        );
        assert_eq!(
            BulkAction::MoveToProject("Work".to_string()).to_string(),
            "move to project 'Work'"
        );
    }

    #[test]
    fn test_bulk_summary_creation() {
        let summary = BulkSummary::new(&BulkAction::Complete, false);
        assert_eq!(summary.matched, 0);
        assert_eq!(summary.succeeded, 0);
        assert_eq!(summary.failed, 0);
        assert!(!summary.dry_run);
    }

    #[test]
    fn test_bulk_summary_add_results() {
        let mut summary = BulkSummary::new(&BulkAction::Complete, true);
        summary.add_success("id1".to_string(), "Task 1".to_string());
        summary.add_success("id2".to_string(), "Task 2".to_string());
        summary.add_failure("id3".to_string(), "Task 3".to_string(), "Error".to_string());

        assert_eq!(summary.succeeded, 2);
        assert_eq!(summary.failed, 1);
        assert_eq!(summary.results.len(), 3);
        assert!(summary.results[0].success);
        assert!(!summary.results[2].success);
        assert_eq!(summary.results[2].error, Some("Error".to_string()));
    }

    #[test]
    fn test_filter_matching() {
        let todos = vec![
            make_todo("Task 1", Status::Open, None, &["work"]),
            make_todo("Task 2", Status::Completed, None, &["work"]),
            make_todo("Task 3", Status::Open, None, &["personal"]),
            make_todo("Task 4", Status::Open, Some("2024-12-15"), &["work"]),
        ];

        let expr = parse_filter("status = open AND tags CONTAINS 'work'").unwrap();
        let matching: Vec<&Todo> = filter_items(&todos, &expr);

        assert_eq!(matching.len(), 2);
        assert!(matching.iter().any(|t| t.name == "Task 1"));
        assert!(matching.iter().any(|t| t.name == "Task 4"));
    }

    #[test]
    fn test_bulk_operation_all() {
        let op = BulkOperation::all(BulkAction::Complete, true);
        assert!(op.dry_run);

        let todos = vec![
            make_todo("Task 1", Status::Open, None, &[]),
            make_todo("Task 2", Status::Completed, None, &[]),
            make_todo("Task 3", Status::Canceled, None, &[]),
        ];

        let matching: Vec<&Todo> = filter_items(&todos, &op.filter);
        assert_eq!(matching.len(), 3); // Should match all
    }
}
