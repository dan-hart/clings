//! Sync queue command implementation.
//!
//! Handles sync queue management commands.

use chrono::Utc;
use colored::Colorize;

use crate::cli::args::{OutputFormat, SyncCommands};
use crate::error::ClingsError;
use crate::features::sync::{
    format_sync_result, ExecutorConfig, Operation, OperationStatus, OperationType, SyncExecutor,
    SyncQueue,
};
use crate::output::to_json;
use crate::things::ThingsClient;

/// Execute sync subcommands.
pub fn sync(
    client: &ThingsClient,
    cmd: SyncCommands,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let queue = SyncQueue::new()?;

    match cmd {
        SyncCommands::Status => show_status(&queue, format),
        SyncCommands::Run {
            stop_on_error,
            dry_run,
            limit: _,
        } => run_sync(client, &queue, stop_on_error, dry_run, format),
        SyncCommands::List { status, limit } => list_operations(&queue, status, limit, format),
        SyncCommands::Add {
            operation,
            id,
            payload,
        } => add_operation(&queue, &operation, id, payload, format),
        SyncCommands::Retry { all, id } => retry_operations(&queue, all, id, format),
        SyncCommands::Clear {
            all,
            older_than,
            force,
        } => clear_operations(&queue, all, older_than, force, format),
    }
}

/// Show queue status.
fn show_status(queue: &SyncQueue, format: OutputFormat) -> Result<String, ClingsError> {
    let stats = queue.stats()?;

    match format {
        OutputFormat::Json => {
            let data = serde_json::json!({
                "pending": stats.pending,
                "completed": stats.completed,
                "failed": stats.failed,
                "oldest_pending": stats.oldest_pending.map(|t| t.to_rfc3339()),
            });
            to_json(&data)
        }
        OutputFormat::Pretty => {
            let mut lines = Vec::new();

            lines.push("Sync Queue Status".bold().to_string());
            lines.push("─".repeat(40));

            lines.push(format!(
                "  Pending:    {} {}",
                stats.pending,
                if stats.pending > 0 {
                    "operations waiting".dimmed()
                } else {
                    "".dimmed()
                }
            ));

            lines.push(format!(
                "  Completed:  {} {}",
                stats.completed,
                "operations".dimmed()
            ));

            lines.push(format!(
                "  Failed:     {} {}",
                stats.failed,
                if stats.failed > 0 {
                    "operations need attention".red()
                } else {
                    "".normal()
                }
            ));

            if let Some(oldest) = stats.oldest_pending {
                let age = Utc::now().signed_duration_since(oldest);
                let age_str = if age.num_hours() > 0 {
                    format!("{} hours ago", age.num_hours())
                } else if age.num_minutes() > 0 {
                    format!("{} minutes ago", age.num_minutes())
                } else {
                    "just now".to_string()
                };
                lines.push(format!("  Oldest:     {}", age_str.dimmed()));
            }

            if stats.pending > 0 {
                lines.push(String::new());
                lines.push(
                    "Run 'clings sync run' to execute pending operations"
                        .dimmed()
                        .to_string(),
                );
            }

            Ok(lines.join("\n"))
        }
    }
}

/// Run sync operations.
fn run_sync(
    client: &ThingsClient,
    queue: &SyncQueue,
    stop_on_error: bool,
    dry_run: bool,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let config = ExecutorConfig {
        max_attempts: 3,
        stop_on_error,
        dry_run,
    };

    let executor = SyncExecutor::with_config(client, queue, config);
    let result = executor.execute_all()?;

    match format {
        OutputFormat::Json => {
            let data = serde_json::json!({
                "succeeded": result.succeeded,
                "failed": result.failed,
                "skipped": result.skipped,
                "total": result.total(),
            });
            to_json(&data)
        }
        OutputFormat::Pretty => {
            if result.total() == 0 {
                Ok("No pending operations to sync.".to_string())
            } else {
                Ok(format_sync_result(&result))
            }
        }
    }
}

/// List queued operations.
fn list_operations(
    queue: &SyncQueue,
    status_filter: Option<String>,
    limit: usize,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let status = status_filter
        .as_deref()
        .map(OperationStatus::from_str)
        .unwrap_or(OperationStatus::Pending);

    let operations = queue.get_by_status(status)?;

    match format {
        OutputFormat::Json => to_json(&operations),
        OutputFormat::Pretty => {
            if operations.is_empty() {
                return Ok(format!("No {} operations in queue.", status));
            }

            let mut lines = Vec::new();

            lines.push(format!(
                "{} Operations ({})",
                status.to_string().to_uppercase(),
                operations.len()
            ));
            lines.push("─".repeat(60));

            lines.push(format!(
                "{:<6} {:<20} {:<20} {}",
                "ID", "Type", "Created", "Status"
            ));
            lines.push("─".repeat(60));

            for op in operations.iter().take(limit) {
                let id = op.id.map(|i| i.to_string()).unwrap_or_default();
                let created = op.created_at.format("%Y-%m-%d %H:%M").to_string();
                let status_str = match op.status {
                    OperationStatus::Pending => "⏳".to_string(),
                    OperationStatus::InProgress => "▶️".to_string(),
                    OperationStatus::Completed => "✓".green().to_string(),
                    OperationStatus::Failed => "✗".red().to_string(),
                    OperationStatus::Skipped => "○".yellow().to_string(),
                };

                lines.push(format!(
                    "{:<6} {:<20} {:<20} {}",
                    id,
                    op.operation_type.display_name(),
                    created,
                    status_str
                ));

                if let Some(error) = &op.last_error {
                    let short_error = if error.len() > 50 {
                        format!("{}...", &error[..47])
                    } else {
                        error.clone()
                    };
                    lines.push(format!("       {}", short_error.red()));
                }
            }

            Ok(lines.join("\n"))
        }
    }
}

/// Add an operation to the queue.
fn add_operation(
    queue: &SyncQueue,
    operation_type: &str,
    id: Option<String>,
    payload: Option<String>,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let mut operation = match operation_type.to_lowercase().as_str() {
        "complete" => {
            let id = id.ok_or_else(|| ClingsError::Config("ID required for complete".to_string()))?;
            Operation::complete_todo(id)
        }
        "cancel" => {
            let id = id.ok_or_else(|| ClingsError::Config("ID required for cancel".to_string()))?;
            Operation::cancel_todo(id)
        }
        "delete" => {
            let id = id.ok_or_else(|| ClingsError::Config("ID required for delete".to_string()))?;
            Operation::delete_todo(id)
        }
        _ => {
            // Generic operation with custom payload
            let payload_str = payload.unwrap_or_else(|| "{}".to_string());
            let op_type = match operation_type.to_lowercase().as_str() {
                "add-todo" => OperationType::AddTodo,
                "add-tags" => OperationType::AddTags,
                "move" => OperationType::MoveTodo,
                "set-due" => OperationType::SetDueDate,
                "clear-due" => OperationType::ClearDueDate,
                _ => {
                    return Err(ClingsError::Config(format!(
                        "Unknown operation type: {operation_type}"
                    )));
                }
            };
            Operation::new(op_type, payload_str)
        }
    };

    queue.enqueue(&mut operation)?;

    match format {
        OutputFormat::Json => to_json(&operation),
        OutputFormat::Pretty => Ok(format!(
            "Queued {} operation (ID: {})",
            operation.operation_type.display_name(),
            operation.id.unwrap_or(0)
        )),
    }
}

/// Retry failed operations.
fn retry_operations(
    queue: &SyncQueue,
    all: bool,
    id: Option<i64>,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    if let Some(op_id) = id {
        // Retry specific operation
        if let Some(mut operation) = queue.get(op_id)? {
            operation.status = OperationStatus::Pending;
            operation.attempts = 0;
            operation.last_error = None;
            queue.update(&operation)?;

            match format {
                OutputFormat::Json => to_json(&operation),
                OutputFormat::Pretty => Ok(format!("Reset operation {} for retry", op_id)),
            }
        } else {
            Err(ClingsError::NotFound(format!("Operation {op_id}")))
        }
    } else if all {
        // Retry all failed operations
        let failed = queue.get_by_status(OperationStatus::Failed)?;
        let count = failed.len();

        for mut operation in failed {
            operation.status = OperationStatus::Pending;
            operation.attempts = 0;
            operation.last_error = None;
            queue.update(&operation)?;
        }

        match format {
            OutputFormat::Json => {
                let data = serde_json::json!({"reset": count});
                to_json(&data)
            }
            OutputFormat::Pretty => Ok(format!("Reset {} failed operations for retry", count)),
        }
    } else {
        Err(ClingsError::Config(
            "Specify --all or provide an operation ID".to_string(),
        ))
    }
}

/// Clear operations from queue.
fn clear_operations(
    queue: &SyncQueue,
    all: bool,
    older_than: i64,
    force: bool,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    if all {
        if !force {
            return Err(ClingsError::Config(
                "Use --force to clear all operations".to_string(),
            ));
        }
        queue.clear()?;

        match format {
            OutputFormat::Json => {
                let data = serde_json::json!({"cleared": "all"});
                to_json(&data)
            }
            OutputFormat::Pretty => Ok("Cleared all operations from queue".to_string()),
        }
    } else {
        let count = queue.cleanup(older_than)?;

        match format {
            OutputFormat::Json => {
                let data = serde_json::json!({"cleared": count});
                to_json(&data)
            }
            OutputFormat::Pretty => Ok(format!(
                "Cleared {} completed operations older than {} hours",
                count, older_than
            )),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sync_command_exists() {
        let client = ThingsClient::new();
        let _: bool = std::mem::size_of_val(&client) >= 0;
    }
}
