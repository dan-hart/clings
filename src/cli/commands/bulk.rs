//! Bulk operations CLI commands.
//!
//! This module implements the `clings bulk` and `clings filter` commands.
//!
//! # Safety Features
//!
//! Bulk operations include several safety measures to prevent accidental data loss:
//!
//! - **Confirmation prompts**: Operations affecting more than 50 items require confirmation
//! - **Batch size limits**: Default limit of 50 items per operation
//! - **Dry-run mode**: Preview changes before applying them with `--dry-run`
//! - **Explicit override**: Use `--yes` to skip confirmation (for scripting)

use std::fmt::Write as FmtWrite;
use std::io::{self, Write};

use colored::Colorize;
use serde_json::json;

use crate::cli::args::OutputFormat;
use crate::core::{filter_items, parse_filter};
use crate::error::ClingsError;
use crate::features::bulk::{execute_bulk_operation, BulkAction, BulkOperation, BulkSummary};
use crate::output::format_todos;
use crate::things::{ThingsClient, Todo};

/// Options for bulk operation safety checks.
pub struct BulkSafetyOptions {
    /// Skip confirmation prompt
    pub skip_confirmation: bool,
    /// Maximum items to process (0 = unlimited, requires `skip_confirmation`)
    pub limit: usize,
    /// Whether this is a dry run
    pub dry_run: bool,
}

/// Check safety limits and prompt for confirmation if needed.
///
/// Returns the filtered list of todos to process, or an error if the user cancels.
///
/// # Safety Checks
///
/// 1. If `limit > 0` and matches exceed limit, truncates to limit
/// 2. If `skip_confirmation` is false and matches > 5, prompts user
/// 3. Shows preview of affected items before confirmation
fn check_bulk_safety(
    todos: &[Todo],
    action_name: &str,
    options: &BulkSafetyOptions,
) -> Result<Vec<Todo>, ClingsError> {
    let mut filtered = todos.to_vec();
    let total_matched = filtered.len();

    // Apply limit if set (0 means unlimited)
    if options.limit > 0 && filtered.len() > options.limit {
        if !options.skip_confirmation {
            return Err(ClingsError::BulkOperation(format!(
                "Operation would affect {} items, which exceeds the limit of {}.\n\
                 Use --limit {} to increase the limit, or --yes to skip this check.\n\
                 Use --dry-run first to preview what would be affected.",
                total_matched, options.limit, total_matched
            )));
        }
        // With --yes, truncate to limit (unless limit is 0)
        filtered.truncate(options.limit);
    }

    // Skip confirmation for dry runs or if --yes flag is set
    if options.dry_run || options.skip_confirmation {
        return Ok(filtered);
    }

    // Require confirmation for operations affecting more than 5 items
    if filtered.len() > 5 {
        println!();
        println!(
            "{} This will {} {} items:",
            "WARNING:".yellow().bold(),
            action_name.red().bold(),
            filtered.len()
        );
        println!();

        // Show first 10 items as preview
        let preview_count = filtered.len().min(10);
        for todo in filtered.iter().take(preview_count) {
            println!(
                "  {} {} {}",
                "•".dimmed(),
                todo.name,
                format!("({})", todo.id).dimmed()
            );
        }
        if filtered.len() > preview_count {
            println!(
                "  {} ... and {} more",
                "•".dimmed(),
                filtered.len() - preview_count
            );
        }

        println!();
        print!(
            "{} Type 'yes' to confirm, or anything else to cancel: ",
            "CONFIRM:".cyan().bold()
        );
        io::stdout()
            .flush()
            .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;

        let mut input = String::new();
        io::stdin()
            .read_line(&mut input)
            .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;

        if input.trim().to_lowercase() != "yes" {
            return Err(ClingsError::BulkOperation(
                "Operation cancelled by user. No changes were made.".to_string(),
            ));
        }

        println!();
    }

    Ok(filtered)
}

/// Execute search with advanced filter expression.
///
/// Lists todos matching the given SQL-like filter expression.
/// This is used when `--filter` flag is passed to the search command.
///
/// # Errors
///
/// Returns an error if the filter is invalid or the Things 3 API call fails.
pub fn search_with_filter(
    client: &ThingsClient,
    filter_query: &str,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let todos = client.get_all_todos()?;
    let expr = parse_filter(filter_query)?;
    let matching: Vec<_> = filter_items(&todos, &expr).into_iter().cloned().collect();

    format_todos(&matching, &format!("Filter: \"{filter_query}\""), format)
}

/// Execute a bulk complete operation.
///
/// Marks all todos matching the filter as complete.
///
/// # Safety
///
/// - Requires confirmation for operations affecting more than 5 items
/// - Respects the `--limit` flag to prevent accidental mass operations
/// - Use `--dry-run` to preview changes before applying
/// - Use `--yes` to skip confirmation (for scripting)
///
/// # Examples
///
/// ```bash
/// # Preview what would be completed
/// clings bulk complete --where "tags CONTAINS 'done'" --dry-run
///
/// # Complete up to 50 matching items (with confirmation)
/// clings bulk complete --where "tags CONTAINS 'done'"
///
/// # Complete all matching items without confirmation (scripting)
/// clings bulk complete --where "tags CONTAINS 'done'" --yes --limit 0
/// ```
///
/// # Errors
///
/// Returns an error if:
/// - No filter is provided
/// - The filter is invalid
/// - The user cancels the confirmation prompt
/// - The Things 3 API call fails
pub fn bulk_complete(
    client: &ThingsClient,
    filter_query: Option<&str>,
    dry_run: bool,
    skip_confirmation: bool,
    limit: usize,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let filter_query = filter_query.ok_or_else(|| {
        ClingsError::BulkOperation(
            "Filter required for bulk complete.\n\n\
             Usage: clings bulk complete --where \"filter expression\"\n\n\
             Examples:\n  \
             clings bulk complete --where \"tags CONTAINS 'done'\"\n  \
             clings bulk complete --where \"project = 'Completed'\" --dry-run"
                .to_string(),
        )
    })?;

    let all_todos = client.get_all_todos()?;
    let expr = parse_filter(filter_query)?;
    let matching: Vec<_> = filter_items(&all_todos, &expr)
        .into_iter()
        .cloned()
        .collect();

    let safety_options = BulkSafetyOptions {
        skip_confirmation,
        limit,
        dry_run,
    };
    let todos_to_process = check_bulk_safety(&matching, "COMPLETE", &safety_options)?;

    let operation = BulkOperation::new(filter_query, BulkAction::Complete, dry_run)?;
    let summary = execute_bulk_operation(client, &todos_to_process, &operation)?;
    format_bulk_summary(&summary, format)
}

/// Execute a bulk cancel operation.
///
/// Marks all todos matching the filter as canceled.
///
/// # Safety
///
/// - Requires confirmation for operations affecting more than 5 items
/// - Respects the `--limit` flag to prevent accidental mass operations
/// - Use `--dry-run` to preview changes before applying
///
/// # Examples
///
/// ```bash
/// # Preview what would be canceled
/// clings bulk cancel --where "project = 'Old Project'" --dry-run
///
/// # Cancel matching items (with confirmation if >5)
/// clings bulk cancel --where "project = 'Old Project'"
/// ```
///
/// # Errors
///
/// Returns an error if the filter is invalid, user cancels, or API fails.
pub fn bulk_cancel(
    client: &ThingsClient,
    filter_query: Option<&str>,
    dry_run: bool,
    skip_confirmation: bool,
    limit: usize,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let filter_query = filter_query.ok_or_else(|| {
        ClingsError::BulkOperation(
            "Filter required for bulk cancel.\n\n\
             Usage: clings bulk cancel --where \"filter expression\"\n\n\
             Examples:\n  \
             clings bulk cancel --where \"project = 'Old Project'\"\n  \
             clings bulk cancel --where \"status = open AND due < today\" --dry-run"
                .to_string(),
        )
    })?;

    let all_todos = client.get_all_todos()?;
    let expr = parse_filter(filter_query)?;
    let matching: Vec<_> = filter_items(&all_todos, &expr)
        .into_iter()
        .cloned()
        .collect();

    let safety_options = BulkSafetyOptions {
        skip_confirmation,
        limit,
        dry_run,
    };
    let todos_to_process = check_bulk_safety(&matching, "CANCEL", &safety_options)?;

    let operation = BulkOperation::new(filter_query, BulkAction::Cancel, dry_run)?;
    let summary = execute_bulk_operation(client, &todos_to_process, &operation)?;
    format_bulk_summary(&summary, format)
}

/// Execute a bulk tag operation.
///
/// Adds tags to all todos matching the filter.
///
/// # Safety
///
/// - Requires confirmation for operations affecting more than 5 items
/// - Respects the `--limit` flag to prevent accidental mass operations
/// - Use `--dry-run` to preview changes before applying
///
/// # Examples
///
/// ```bash
/// # Preview what would be tagged
/// clings bulk tag --where "project = 'Work'" urgent --dry-run
///
/// # Add multiple tags
/// clings bulk tag --where "project = 'Work'" urgent priority review
/// ```
///
/// # Errors
///
/// Returns an error if no tags provided, filter invalid, user cancels, or API fails.
pub fn bulk_tag(
    client: &ThingsClient,
    filter_query: Option<&str>,
    tags: &[String],
    dry_run: bool,
    skip_confirmation: bool,
    limit: usize,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    if tags.is_empty() {
        return Err(ClingsError::BulkOperation(
            "At least one tag is required.\n\n\
             Usage: clings bulk tag --where \"filter\" tag1 [tag2 ...]\n\n\
             Example: clings bulk tag --where \"project = 'Work'\" urgent priority"
                .to_string(),
        ));
    }

    let filter_query = filter_query.ok_or_else(|| {
        ClingsError::BulkOperation(
            "Filter required for bulk tag.\n\n\
             Usage: clings bulk tag --where \"filter expression\" tag1 [tag2 ...]"
                .to_string(),
        )
    })?;

    let all_todos = client.get_all_todos()?;
    let expr = parse_filter(filter_query)?;
    let matching: Vec<_> = filter_items(&all_todos, &expr)
        .into_iter()
        .cloned()
        .collect();

    let safety_options = BulkSafetyOptions {
        skip_confirmation,
        limit,
        dry_run,
    };
    let todos_to_process = check_bulk_safety(&matching, "TAG", &safety_options)?;

    let action = BulkAction::Tag(tags.to_vec());
    let operation = BulkOperation::new(filter_query, action, dry_run)?;
    let summary = execute_bulk_operation(client, &todos_to_process, &operation)?;
    format_bulk_summary(&summary, format)
}

/// Execute a bulk move operation.
///
/// Moves all matching todos to the specified project.
///
/// # Safety
///
/// - Requires confirmation for operations affecting more than 5 items
/// - Respects the `--limit` flag to prevent accidental mass operations
/// - Use `--dry-run` to preview changes before applying
///
/// # Examples
///
/// ```bash
/// # Preview what would be moved
/// clings bulk move --where "tags CONTAINS 'work'" --to "Work Project" --dry-run
///
/// # Move matching items
/// clings bulk move --where "tags CONTAINS 'work'" --to "Work Project"
/// ```
///
/// # Errors
///
/// Returns an error if filter invalid, project not found, user cancels, or API fails.
pub fn bulk_move(
    client: &ThingsClient,
    filter_query: Option<&str>,
    project: &str,
    dry_run: bool,
    skip_confirmation: bool,
    limit: usize,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let filter_query = filter_query.ok_or_else(|| {
        ClingsError::BulkOperation(
            "Filter required for bulk move.\n\n\
             Usage: clings bulk move --where \"filter expression\" --to \"Project Name\""
                .to_string(),
        )
    })?;

    let all_todos = client.get_all_todos()?;
    let expr = parse_filter(filter_query)?;
    let matching: Vec<_> = filter_items(&all_todos, &expr)
        .into_iter()
        .cloned()
        .collect();

    let safety_options = BulkSafetyOptions {
        skip_confirmation,
        limit,
        dry_run,
    };
    let todos_to_process = check_bulk_safety(&matching, "MOVE", &safety_options)?;

    let action = BulkAction::MoveToProject(project.to_string());
    let operation = BulkOperation::new(filter_query, action, dry_run)?;
    let summary = execute_bulk_operation(client, &todos_to_process, &operation)?;
    format_bulk_summary(&summary, format)
}

/// Format a bulk operation summary for output.
fn format_bulk_summary(summary: &BulkSummary, format: OutputFormat) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Json => {
            let results: Vec<_> = summary
                .results
                .iter()
                .map(|r| {
                    json!({
                        "id": r.id,
                        "name": r.name,
                        "success": r.success,
                        "error": r.error
                    })
                })
                .collect();

            let output = json!({
                "action": summary.action,
                "dry_run": summary.dry_run,
                "matched": summary.matched,
                "succeeded": summary.succeeded,
                "failed": summary.failed,
                "results": results
            });

            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        },
        OutputFormat::Pretty => {
            let mut output = String::new();

            if summary.dry_run {
                writeln!(
                    output,
                    "{} {}\n",
                    "DRY RUN:".yellow().bold(),
                    "No changes will be made".yellow()
                )
                .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;
            }

            writeln!(output, "{} {}", "Action:".cyan().bold(), summary.action)
                .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;
            writeln!(output, "{} {}", "Matched:".cyan(), summary.matched)
                .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;

            if !summary.dry_run {
                writeln!(output, "{} {}", "Succeeded:".green(), summary.succeeded)
                    .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;
                if summary.failed > 0 {
                    writeln!(output, "{} {}", "Failed:".red(), summary.failed)
                        .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;
                }
            }

            if !summary.results.is_empty() {
                writeln!(output, "\n{}", "Items:".cyan().bold())
                    .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;
                for result in &summary.results {
                    let status = if result.success {
                        if summary.dry_run {
                            "would".blue()
                        } else {
                            "done".green()
                        }
                    } else {
                        "fail".red()
                    };

                    writeln!(
                        output,
                        "  [{}] {} ({})",
                        status,
                        result.name,
                        result.id.dimmed()
                    )
                    .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;

                    if let Some(ref error) = result.error {
                        writeln!(output, "       {} {}", "Error:".red(), error)
                            .map_err(|e| ClingsError::BulkOperation(e.to_string()))?;
                    }
                }
            }

            Ok(output)
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::features::bulk::BulkResult;

    fn make_summary(dry_run: bool, succeeded: usize, failed: usize) -> BulkSummary {
        let mut results = Vec::new();
        for i in 0..succeeded {
            results.push(BulkResult {
                id: format!("id-{i}"),
                name: format!("Task {i}"),
                success: true,
                error: None,
            });
        }
        for i in 0..failed {
            results.push(BulkResult {
                id: format!("fail-{i}"),
                name: format!("Failed Task {i}"),
                success: false,
                error: Some("Test error".to_string()),
            });
        }

        BulkSummary {
            matched: succeeded + failed,
            succeeded,
            failed,
            results,
            dry_run,
            action: "complete".to_string(),
        }
    }

    #[test]
    fn test_format_summary_json() {
        let summary = make_summary(false, 2, 1);
        let result = format_bulk_summary(&summary, OutputFormat::Json).unwrap();

        assert!(result.contains("\"action\": \"complete\""));
        assert!(result.contains("\"matched\": 3"));
        assert!(result.contains("\"succeeded\": 2"));
        assert!(result.contains("\"failed\": 1"));
    }

    #[test]
    fn test_format_summary_pretty() {
        let summary = make_summary(false, 2, 0);
        let result = format_bulk_summary(&summary, OutputFormat::Pretty).unwrap();

        assert!(result.contains("complete"));
        assert!(result.contains("Matched: 2"));
        assert!(result.contains("Succeeded: 2"));
    }

    #[test]
    fn test_format_summary_dry_run() {
        let summary = make_summary(true, 3, 0);
        let result = format_bulk_summary(&summary, OutputFormat::Pretty).unwrap();

        assert!(result.contains("DRY RUN"));
        assert!(result.contains("would")); // Status shows "would" instead of "done"
    }

    #[test]
    fn test_format_summary_with_failures() {
        let summary = make_summary(false, 2, 1);
        let result = format_bulk_summary(&summary, OutputFormat::Pretty).unwrap();

        assert!(result.contains("Failed: 1"));
        assert!(result.contains("Test error"));
    }
}
