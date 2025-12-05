//! Command implementations for clings.
//!
//! This module contains the implementation of all CLI commands.

mod add;
mod bulk;
mod list;
mod review;
mod shell;
mod stats;

pub use add::quick_add;
pub use bulk::{bulk_cancel, bulk_complete, bulk_move, bulk_tag, search_with_filter};
pub use list::list;
pub use review::review;
pub use shell::shell;
pub use stats::stats;

use crate::cli::args::{AddProjectArgs, OutputFormat, ProjectCommands, TodoCommands};
use crate::error::ClingsError;
use crate::output::{format_projects, format_todo, format_todos, to_json};
use crate::things::{ListView, ThingsClient};

/// Execute todo subcommands
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn todo(
    client: &ThingsClient,
    cmd: TodoCommands,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    match cmd {
        TodoCommands::Show { id } => {
            let todo = client.get_todo(&id)?;
            format_todo(&todo, format)
        },
        TodoCommands::Complete { id } => {
            client.complete_todo(&id)?;
            Ok(format!("Completed todo: {id}"))
        },
        TodoCommands::Cancel { id } => {
            client.cancel_todo(&id)?;
            Ok(format!("Canceled todo: {id}"))
        },
        TodoCommands::Delete { id } => {
            client.delete_todo(&id)?;
            Ok(format!(
                "Canceled todo: {id} (Things API doesn't support true deletion)"
            ))
        },
        TodoCommands::Update {
            id,
            title,
            notes,
            when,
            deadline,
            tags,
            project,
        } => {
            client.update_todo(
                &id,
                title.as_deref(),
                notes.as_deref(),
                when.as_deref(),
                deadline.as_deref(),
                tags.as_deref(),
                project.as_deref(),
            )?;
            Ok(format!("Updated todo: {id}"))
        },
    }
}

/// Execute project subcommands
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn project(
    client: &ThingsClient,
    cmd: ProjectCommands,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    match cmd {
        ProjectCommands::List => {
            let projects = client.get_projects()?;
            format_projects(&projects, format)
        },
        ProjectCommands::Show { id } => {
            // For now, list projects and find by ID
            let projects = client.get_projects()?;
            let project = projects
                .iter()
                .find(|p| p.id == id)
                .ok_or_else(|| ClingsError::NotFound(format!("Project with ID: {id}")))?;
            match format {
                OutputFormat::Json => to_json(project),
                OutputFormat::Pretty => {
                    use std::fmt::Write;
                    let mut output = format!("Project: {}\n", project.name);
                    let _ = writeln!(output, "  ID: {}", project.id);
                    let _ = writeln!(output, "  Status: {}", project.status);
                    if !project.notes.is_empty() {
                        output.push_str("  Notes: ");
                        output.push_str(&project.notes);
                        output.push('\n');
                    }
                    if let Some(area) = &project.area {
                        output.push_str("  Area: ");
                        output.push_str(area);
                        output.push('\n');
                    }
                    if !project.tags.is_empty() {
                        output.push_str("  Tags: ");
                        output.push_str(&project.tags.join(", "));
                        output.push('\n');
                    }
                    if let Some(due) = &project.due_date {
                        output.push_str("  Due: ");
                        output.push_str(&due.to_string());
                        output.push('\n');
                    }
                    Ok(output)
                },
            }
        },
        ProjectCommands::Add(args) => add_project(client, &args, format),
    }
}

fn add_project(
    client: &ThingsClient,
    args: &AddProjectArgs,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let response = client.add_project(
        &args.title,
        args.notes.as_deref(),
        args.area.as_deref(),
        args.tags.as_deref(),
        args.due.as_deref(),
    )?;

    match format {
        OutputFormat::Json => to_json(&response),
        OutputFormat::Pretty => Ok(format!(
            "Created project: {} (ID: {})",
            response.name, response.id
        )),
    }
}

/// Execute search command with optional filters
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn search(
    client: &ThingsClient,
    query: Option<&str>,
    tag: Option<&str>,
    project: Option<&str>,
    due: Option<&str>,
    filter: Option<&str>,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    // If advanced filter is provided, use filter mode
    if let Some(filter_expr) = filter {
        return search_with_filter(client, filter_expr, format);
    }

    // For now, just use simple text search
    // TODO: Add flag-based filtering when ThingsClient supports it
    let todos = if let Some(q) = query {
        client.search(q)?
    } else {
        // If no query but filters exist, get all and filter
        client.get_list(ListView::Anytime)?
    };

    // Apply simple filters (tag, project, due) - this is a basic implementation
    let filtered: Vec<_> = todos
        .into_iter()
        .filter(|t| {
            if let Some(tag_filter) = tag {
                if !t.tags.iter().any(|tt| tt.eq_ignore_ascii_case(tag_filter)) {
                    return false;
                }
            }
            if let Some(project_filter) = project {
                if let Some(ref proj) = t.project {
                    if !proj.eq_ignore_ascii_case(project_filter) {
                        return false;
                    }
                } else {
                    return false;
                }
            }
            if let Some(due_filter) = due {
                let due_date = crate::cli::args::parse_date(due_filter);
                if let Some(ref todo_due) = t.due_date {
                    // Compare the date string format
                    if todo_due.format("%Y-%m-%d").to_string() != due_date {
                        return false;
                    }
                } else {
                    return false;
                }
            }
            true
        })
        .collect();

    let title = query.map_or_else(
        || "Search Results".to_string(),
        |q| format!("Search: \"{q}\""),
    );
    format_todos(&filtered, &title, format)
}

/// Execute open command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails.
pub fn open(client: &ThingsClient, target: &str) -> Result<String, ClingsError> {
    client.open(target)?;
    Ok(format!("Opened: {target}"))
}
