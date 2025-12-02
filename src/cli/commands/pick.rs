//! Interactive picker CLI command.
//!
//! This module implements the `clings pick` command for interactive todo selection.

use colored::Colorize;
use serde_json::json;

use crate::cli::args::OutputFormat;
use crate::error::ClingsError;
use crate::features::interactive::{pick_todos, PickAction, PickOptions, PickResult};
use crate::things::{ListView, ThingsClient, Todo};

/// Execute the pick command.
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails.
pub fn pick(
    client: &ThingsClient,
    list: Option<&str>,
    action: PickAction,
    multi: bool,
    query: Option<&str>,
    preview: bool,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    // Get todos from specified list or all
    let todos = get_todos_for_list(client, list)?;

    if todos.is_empty() {
        return Ok("No todos found.".to_string());
    }

    let options = PickOptions {
        action,
        multi,
        query: query.map(String::from),
        prompt: list.map(|l| format!("{} > ", l)),
        preview,
    };

    // Run the picker
    let result = pick_todos(todos, options);

    match result {
        None => Ok("No todos to select from.".to_string()),
        Some(pick_result) if pick_result.aborted => Ok("Selection cancelled.".to_string()),
        Some(pick_result) if pick_result.selected_ids.is_empty() => {
            Ok("No items selected.".to_string())
        }
        Some(pick_result) => {
            // Execute the action
            execute_pick_action(client, &pick_result, format)
        }
    }
}

/// Get todos from a specific list or all todos.
fn get_todos_for_list(client: &ThingsClient, list: Option<&str>) -> Result<Vec<Todo>, ClingsError> {
    match list {
        Some(list_name) => {
            let view = match list_name.to_lowercase().as_str() {
                "inbox" => ListView::Inbox,
                "today" => ListView::Today,
                "upcoming" => ListView::Upcoming,
                "anytime" => ListView::Anytime,
                "someday" => ListView::Someday,
                "logbook" => ListView::Logbook,
                _ => {
                    // Try to get all todos and filter by project name
                    let all_todos = client.get_all_todos()?;
                    return Ok(all_todos
                        .into_iter()
                        .filter(|t| {
                            t.project
                                .as_ref()
                                .map_or(false, |p| p.eq_ignore_ascii_case(list_name))
                        })
                        .collect());
                }
            };
            client.get_list(view)
        }
        None => client.get_all_todos(),
    }
}

/// Execute the selected action on picked items.
fn execute_pick_action(
    client: &ThingsClient,
    result: &PickResult,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let mut successes = Vec::new();
    let mut failures = Vec::new();

    for (id, name) in result
        .selected_ids
        .iter()
        .zip(result.selected_names.iter())
    {
        let action_result = match result.action {
            PickAction::Show => {
                // Show is handled differently - just return the info
                match client.get_todo(id) {
                    Ok(todo) => {
                        successes.push((id.clone(), name.clone(), Some(todo)));
                        continue;
                    }
                    Err(e) => Err(e),
                }
            }
            PickAction::Complete => client.complete_todo(id),
            PickAction::Cancel => client.cancel_todo(id),
            PickAction::Open => client.open(id),
            PickAction::Edit => {
                // Edit not yet implemented
                Err(ClingsError::BulkOperation(
                    "Edit action not yet implemented".to_string(),
                ))
            }
        };

        match action_result {
            Ok(()) => successes.push((id.clone(), name.clone(), None)),
            Err(e) => failures.push((id.clone(), name.clone(), e.to_string())),
        }
    }

    format_pick_result(result, &successes, &failures, format)
}

/// Format the pick result for output.
fn format_pick_result(
    result: &PickResult,
    successes: &[(String, String, Option<Todo>)],
    failures: &[(String, String, String)],
    format: OutputFormat,
) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Json => {
            let success_json: Vec<_> = successes
                .iter()
                .map(|(id, name, todo)| {
                    if let Some(t) = todo {
                        json!({
                            "id": id,
                            "name": t.name,
                            "status": t.status.to_string(),
                            "notes": t.notes,
                            "due_date": t.due_date.map(|d| d.to_string()),
                            "tags": t.tags,
                            "project": t.project,
                            "area": t.area,
                        })
                    } else {
                        json!({
                            "id": id,
                            "name": name,
                            "success": true
                        })
                    }
                })
                .collect();

            let failure_json: Vec<_> = failures
                .iter()
                .map(|(id, name, error)| {
                    json!({
                        "id": id,
                        "name": name,
                        "success": false,
                        "error": error
                    })
                })
                .collect();

            let output = json!({
                "action": result.action.to_string(),
                "selected": success_json,
                "failed": failure_json,
                "total_selected": successes.len() + failures.len(),
                "succeeded": successes.len(),
                "failed_count": failures.len()
            });

            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        }
        OutputFormat::Pretty => {
            let mut output = String::new();

            if result.action == PickAction::Show {
                // Show detailed info for each todo
                for (_, _, todo_opt) in successes {
                    if let Some(todo) = todo_opt {
                        output.push_str(&format_todo_detail(todo));
                        output.push('\n');
                    }
                }
            } else {
                // Show action results
                output.push_str(&format!(
                    "{} {} item(s)\n\n",
                    "Action:".cyan().bold(),
                    result.action
                ));

                if !successes.is_empty() {
                    output.push_str(&format!("{}\n", "Succeeded:".green().bold()));
                    for (_, name, _) in successes {
                        output.push_str(&format!("  {} {}\n", "✓".green(), name));
                    }
                }

                if !failures.is_empty() {
                    output.push_str(&format!("\n{}\n", "Failed:".red().bold()));
                    for (_, name, error) in failures {
                        output.push_str(&format!("  {} {} - {}\n", "✗".red(), name, error));
                    }
                }
            }

            Ok(output)
        }
    }
}

/// Format a single todo for detailed display.
fn format_todo_detail(todo: &Todo) -> String {
    let mut output = String::new();

    let status_icon = match todo.status {
        crate::things::types::Status::Open => "[ ]".blue(),
        crate::things::types::Status::Completed => "[x]".green(),
        crate::things::types::Status::Canceled => "[-]".red(),
    };

    output.push_str(&format!(
        "{} {}\n",
        status_icon,
        todo.name.bold()
    ));
    output.push_str(&format!("   {} {}\n", "ID:".dimmed(), todo.id.dimmed()));

    if let Some(ref project) = todo.project {
        output.push_str(&format!("   {} {}\n", "Project:".cyan(), project));
    }

    if let Some(ref area) = todo.area {
        output.push_str(&format!("   {} {}\n", "Area:".blue(), area));
    }

    if let Some(due) = todo.due_date {
        output.push_str(&format!(
            "   {} {}\n",
            "Due:".yellow(),
            due.format("%Y-%m-%d")
        ));
    }

    if !todo.tags.is_empty() {
        let tags_str: Vec<String> = todo.tags.iter().map(|t| format!("#{}", t)).collect();
        output.push_str(&format!("   {} {}\n", "Tags:".magenta(), tags_str.join(" ")));
    }

    if !todo.notes.is_empty() {
        output.push_str(&format!("   {} {}\n", "Notes:".dimmed(), todo.notes));
    }

    if !todo.checklist_items.is_empty() {
        output.push_str(&format!("   {}\n", "Checklist:".dimmed()));
        for item in &todo.checklist_items {
            let check = if item.completed {
                "[x]".green()
            } else {
                "[ ]".normal()
            };
            output.push_str(&format!("     {} {}\n", check, item.name));
        }
    }

    output
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::things::types::Status;

    fn make_todo(id: &str, name: &str, status: Status) -> Todo {
        Todo {
            id: id.to_string(),
            name: name.to_string(),
            notes: String::new(),
            status,
            due_date: None,
            tags: vec![],
            project: None,
            area: None,
            checklist_items: vec![],
            creation_date: None,
            modification_date: None,
        }
    }

    #[test]
    fn test_format_todo_detail() {
        let todo = make_todo("123", "Test Task", Status::Open);
        let output = format_todo_detail(&todo);
        assert!(output.contains("Test Task"));
        assert!(output.contains("123"));
    }

    #[test]
    fn test_format_pick_result_json() {
        let result = PickResult {
            selected_ids: vec!["id1".to_string()],
            selected_names: vec!["Task 1".to_string()],
            action: PickAction::Complete,
            aborted: false,
        };

        let successes = vec![("id1".to_string(), "Task 1".to_string(), None)];
        let failures: Vec<(String, String, String)> = vec![];

        let output = format_pick_result(&result, &successes, &failures, OutputFormat::Json).unwrap();
        assert!(output.contains("\"action\": \"complete\""));
        assert!(output.contains("\"succeeded\": 1"));
    }

    #[test]
    fn test_format_pick_result_pretty() {
        let result = PickResult {
            selected_ids: vec!["id1".to_string()],
            selected_names: vec!["Task 1".to_string()],
            action: PickAction::Complete,
            aborted: false,
        };

        let successes = vec![("id1".to_string(), "Task 1".to_string(), None)];
        let failures: Vec<(String, String, String)> = vec![];

        let output =
            format_pick_result(&result, &successes, &failures, OutputFormat::Pretty).unwrap();
        assert!(output.contains("complete"));
        assert!(output.contains("Task 1"));
    }
}
