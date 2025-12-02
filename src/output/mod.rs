//! Output formatting for clings.
//!
//! This module provides formatters for displaying Things 3 data in various formats.

mod json;
mod pretty;

use crate::cli::args::OutputFormat;
use crate::error::ClingsError;
use crate::things::{Area, Project, Tag, Todo};

pub use json::*;
pub use pretty::*;

/// Format todos based on output format
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_todos(
    todos: &[Todo],
    title: &str,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Pretty => Ok(format_todos_pretty(todos, title)),
        OutputFormat::Json => format_todos_json(todos, title),
    }
}

/// Format a single todo based on output format
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_todo(todo: &Todo, format: OutputFormat) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Pretty => Ok(format_todo_pretty(todo)),
        OutputFormat::Json => format_todo_json(todo),
    }
}

/// Format projects based on output format
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_projects(projects: &[Project], format: OutputFormat) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Pretty => Ok(format_projects_pretty(projects)),
        OutputFormat::Json => format_projects_json(projects),
    }
}

/// Format areas based on output format
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_areas(areas: &[Area], format: OutputFormat) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Pretty => Ok(format_areas_pretty(areas)),
        OutputFormat::Json => format_areas_json(areas),
    }
}

/// Format tags based on output format
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_tags(tags: &[Tag], format: OutputFormat) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Pretty => Ok(format_tags_pretty(tags)),
        OutputFormat::Json => format_tags_json(tags),
    }
}
