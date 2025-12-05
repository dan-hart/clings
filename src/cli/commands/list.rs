//! Consolidated list command implementation.
//!
//! This module provides a single `list` command that handles all list views
//! (inbox, today, upcoming, anytime, someday, logbook, areas, tags, projects).

use crate::cli::args::OutputFormat;
use crate::error::ClingsError;
use crate::output::{format_areas, format_projects, format_tags, format_todos};
use crate::things::{ListView, ThingsClient};

/// Available list views for the `list` command.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum ListTarget {
    /// Today's todos (default)
    #[default]
    Today,
    /// Inbox todos
    Inbox,
    /// Upcoming todos
    Upcoming,
    /// Anytime todos
    Anytime,
    /// Someday todos
    Someday,
    /// Completed todos (logbook)
    Logbook,
    /// All areas
    Areas,
    /// All tags
    Tags,
    /// All projects
    Projects,
}

impl ListTarget {
    /// Parse a string into a `ListTarget`.
    ///
    /// Returns `None` if the string doesn't match any known view.
    #[must_use]
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "today" | "t" => Some(Self::Today),
            "inbox" | "i" => Some(Self::Inbox),
            "upcoming" | "u" => Some(Self::Upcoming),
            "anytime" => Some(Self::Anytime),
            "someday" | "s" => Some(Self::Someday),
            "logbook" | "l" => Some(Self::Logbook),
            "areas" => Some(Self::Areas),
            "tags" => Some(Self::Tags),
            "projects" => Some(Self::Projects),
            _ => None,
        }
    }
}

/// Execute the list command.
///
/// # Arguments
///
/// * `client` - The Things 3 client
/// * `target` - Optional target view (defaults to Today)
/// * `format` - Output format (pretty or JSON)
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or output formatting fails.
pub fn list(
    client: &ThingsClient,
    target: Option<&str>,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let list_target = match target {
        Some(s) => ListTarget::from_str(s).ok_or_else(|| {
            ClingsError::InvalidArgument(format!(
                "Unknown list view: '{s}'. Valid options: today, inbox, upcoming, anytime, someday, logbook, areas, tags, projects"
            ))
        })?,
        None => ListTarget::default(),
    };

    match list_target {
        ListTarget::Today => {
            let todos = client.get_list(ListView::Today)?;
            format_todos(&todos, "Today", format)
        },
        ListTarget::Inbox => {
            let todos = client.get_list(ListView::Inbox)?;
            format_todos(&todos, "Inbox", format)
        },
        ListTarget::Upcoming => {
            let todos = client.get_list(ListView::Upcoming)?;
            format_todos(&todos, "Upcoming", format)
        },
        ListTarget::Anytime => {
            let todos = client.get_list(ListView::Anytime)?;
            format_todos(&todos, "Anytime", format)
        },
        ListTarget::Someday => {
            let todos = client.get_list(ListView::Someday)?;
            format_todos(&todos, "Someday", format)
        },
        ListTarget::Logbook => {
            let todos = client.get_list(ListView::Logbook)?;
            format_todos(&todos, "Logbook", format)
        },
        ListTarget::Areas => {
            let areas = client.get_areas()?;
            format_areas(&areas, format)
        },
        ListTarget::Tags => {
            let tags = client.get_tags()?;
            format_tags(&tags, format)
        },
        ListTarget::Projects => {
            let projects = client.get_projects()?;
            format_projects(&projects, format)
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_list_target_from_str() {
        assert_eq!(ListTarget::from_str("today"), Some(ListTarget::Today));
        assert_eq!(ListTarget::from_str("t"), Some(ListTarget::Today));
        assert_eq!(ListTarget::from_str("inbox"), Some(ListTarget::Inbox));
        assert_eq!(ListTarget::from_str("i"), Some(ListTarget::Inbox));
        assert_eq!(ListTarget::from_str("upcoming"), Some(ListTarget::Upcoming));
        assert_eq!(ListTarget::from_str("u"), Some(ListTarget::Upcoming));
        assert_eq!(ListTarget::from_str("anytime"), Some(ListTarget::Anytime));
        assert_eq!(ListTarget::from_str("someday"), Some(ListTarget::Someday));
        assert_eq!(ListTarget::from_str("s"), Some(ListTarget::Someday));
        assert_eq!(ListTarget::from_str("logbook"), Some(ListTarget::Logbook));
        assert_eq!(ListTarget::from_str("l"), Some(ListTarget::Logbook));
        assert_eq!(ListTarget::from_str("areas"), Some(ListTarget::Areas));
        assert_eq!(ListTarget::from_str("tags"), Some(ListTarget::Tags));
        assert_eq!(ListTarget::from_str("projects"), Some(ListTarget::Projects));
        assert_eq!(ListTarget::from_str("invalid"), None);
    }

    #[test]
    fn test_list_target_case_insensitive() {
        assert_eq!(ListTarget::from_str("TODAY"), Some(ListTarget::Today));
        assert_eq!(ListTarget::from_str("Today"), Some(ListTarget::Today));
        assert_eq!(ListTarget::from_str("INBOX"), Some(ListTarget::Inbox));
    }

    #[test]
    fn test_list_target_default() {
        assert_eq!(ListTarget::default(), ListTarget::Today);
    }
}
