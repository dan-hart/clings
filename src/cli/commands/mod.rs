//! Command implementations for clings.
//!
//! This module contains the implementation of all CLI commands.

mod add;
mod automation;
mod bulk;
mod focus;
mod pick;
mod review;
mod shell;
mod stats;
mod sync;
mod template;

pub use add::quick_add;
pub use automation::automation;
pub use bulk::{
    bulk_cancel, bulk_clear_due, bulk_complete, bulk_move, bulk_set_due, bulk_tag, filter,
};
pub use focus::focus;
pub use pick::pick;
pub use review::review;
pub use shell::{git, pipe, shell};
pub use stats::stats;
pub use sync::sync;
pub use template::template;

use crate::cli::args::{
    AddProjectArgs, AddTodoArgs, OutputFormat, ProjectCommands, TodoCommands,
};
use crate::error::ClingsError;
use crate::output::{format_areas, format_projects, format_tags, format_todo, format_todos, to_json};
use crate::things::{ListView, ThingsClient};

/// Execute inbox command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn inbox(client: &ThingsClient, format: OutputFormat) -> Result<String, ClingsError> {
    let todos = client.get_list(ListView::Inbox)?;
    format_todos(&todos, "Inbox", format)
}

/// Execute today command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn today(client: &ThingsClient, format: OutputFormat) -> Result<String, ClingsError> {
    let todos = client.get_list(ListView::Today)?;
    format_todos(&todos, "Today", format)
}

/// Execute upcoming command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn upcoming(client: &ThingsClient, format: OutputFormat) -> Result<String, ClingsError> {
    let todos = client.get_list(ListView::Upcoming)?;
    format_todos(&todos, "Upcoming", format)
}

/// Execute anytime command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn anytime(client: &ThingsClient, format: OutputFormat) -> Result<String, ClingsError> {
    let todos = client.get_list(ListView::Anytime)?;
    format_todos(&todos, "Anytime", format)
}

/// Execute someday command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn someday(client: &ThingsClient, format: OutputFormat) -> Result<String, ClingsError> {
    let todos = client.get_list(ListView::Someday)?;
    format_todos(&todos, "Someday", format)
}

/// Execute logbook command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn logbook(client: &ThingsClient, format: OutputFormat) -> Result<String, ClingsError> {
    let todos = client.get_list(ListView::Logbook)?;
    format_todos(&todos, "Logbook", format)
}

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
        TodoCommands::List => {
            let todos = client.get_list(ListView::Anytime)?;
            format_todos(&todos, "All Todos", format)
        }
        TodoCommands::Show { id } => {
            let todo = client.get_todo(&id)?;
            format_todo(&todo, format)
        }
        TodoCommands::Add(args) => add_todo(client, args, format),
        TodoCommands::Complete { id } => {
            client.complete_todo(&id)?;
            Ok(format!("Completed todo: {id}"))
        }
        TodoCommands::Cancel { id } => {
            client.cancel_todo(&id)?;
            Ok(format!("Canceled todo: {id}"))
        }
        TodoCommands::Delete { id } => {
            client.delete_todo(&id)?;
            Ok(format!(
                "Canceled todo: {id} (Things API doesn't support true deletion)"
            ))
        }
    }
}

fn add_todo(
    client: &ThingsClient,
    args: AddTodoArgs,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let due_date = args.due.as_ref().map(|d| crate::cli::args::parse_date(d));
    let response = client.add_todo(
        &args.title,
        args.notes.as_deref(),
        due_date.as_deref(),
        args.tags.as_deref(),
        args.list.as_deref(),
        args.checklist.as_deref(),
    )?;

    match format {
        OutputFormat::Json => to_json(&response),
        OutputFormat::Pretty => Ok(format!(
            "Created todo: {} (ID: {})",
            response.name, response.id
        )),
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
        }
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
                    let mut output = format!("Project: {}\n", project.name);
                    output.push_str(&format!("  ID: {}\n", project.id));
                    output.push_str(&format!("  Status: {}\n", project.status));
                    if !project.notes.is_empty() {
                        output.push_str(&format!("  Notes: {}\n", project.notes));
                    }
                    if let Some(area) = &project.area {
                        output.push_str(&format!("  Area: {area}\n"));
                    }
                    if !project.tags.is_empty() {
                        output.push_str(&format!("  Tags: {}\n", project.tags.join(", ")));
                    }
                    if let Some(due) = &project.due_date {
                        output.push_str(&format!("  Due: {due}\n"));
                    }
                    Ok(output)
                }
            }
        }
        ProjectCommands::Add(args) => add_project(client, args, format),
    }
}

fn add_project(
    client: &ThingsClient,
    args: AddProjectArgs,
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

/// Execute areas command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn areas(client: &ThingsClient, format: OutputFormat) -> Result<String, ClingsError> {
    let areas = client.get_areas()?;
    format_areas(&areas, format)
}

/// Execute tags command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn tags(client: &ThingsClient, format: OutputFormat) -> Result<String, ClingsError> {
    let tags = client.get_tags()?;
    format_tags(&tags, format)
}

/// Execute search command
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn search(
    client: &ThingsClient,
    query: &str,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let todos = client.search(query)?;
    format_todos(&todos, &format!("Search: \"{query}\""), format)
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
