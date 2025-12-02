//! Template data types.
//!
//! Defines the structure for project templates, including headings,
//! todos, relative dates, and template variables.

use chrono::{Duration, Local, NaiveDate};
use serde::{Deserialize, Serialize};

/// A relative date specification for template todos.
///
/// Supports expressions like "today", "tomorrow", "+3d", "+1w", etc.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(untagged)]
pub enum RelativeDate {
    /// A named date: "today", "tomorrow", "next_week"
    Named(String),
}

impl RelativeDate {
    /// Resolve the relative date to an absolute date.
    #[must_use]
    pub fn resolve(&self) -> NaiveDate {
        let today = Local::now().date_naive();

        match self {
            Self::Named(s) => Self::parse_relative(s, today),
        }
    }

    /// Parse a relative date string.
    fn parse_relative(s: &str, base: NaiveDate) -> NaiveDate {
        let s = s.trim().to_lowercase();

        match s.as_str() {
            "today" => base,
            "tomorrow" => base + Duration::days(1),
            "next_week" | "nextweek" => base + Duration::weeks(1),
            "next_month" | "nextmonth" => {
                // Add approximately one month
                base + Duration::days(30)
            }
            _ => {
                // Try to parse offset format: +Nd, +Nw, +Nm
                if let Some(offset) = s.strip_prefix('+') {
                    Self::parse_offset(offset, base)
                } else if let Some(offset) = s.strip_prefix('-') {
                    Self::parse_negative_offset(offset, base)
                } else {
                    // Default to today if unparseable
                    base
                }
            }
        }
    }

    /// Parse a positive offset like "3d", "1w", "2m".
    fn parse_offset(offset: &str, base: NaiveDate) -> NaiveDate {
        let offset = offset.trim();
        if offset.is_empty() {
            return base;
        }

        let unit = offset.chars().last().unwrap_or('d');
        let num_str: String = offset.chars().take_while(|c| c.is_ascii_digit()).collect();
        let num: i64 = num_str.parse().unwrap_or(1);

        match unit {
            'd' => base + Duration::days(num),
            'w' => base + Duration::weeks(num),
            'm' => base + Duration::days(num * 30),
            'y' => base + Duration::days(num * 365),
            _ => base + Duration::days(num),
        }
    }

    /// Parse a negative offset.
    fn parse_negative_offset(offset: &str, base: NaiveDate) -> NaiveDate {
        let offset = offset.trim();
        if offset.is_empty() {
            return base;
        }

        let unit = offset.chars().last().unwrap_or('d');
        let num_str: String = offset.chars().take_while(|c| c.is_ascii_digit()).collect();
        let num: i64 = num_str.parse().unwrap_or(1);

        match unit {
            'd' => base - Duration::days(num),
            'w' => base - Duration::weeks(num),
            'm' => base - Duration::days(num * 30),
            'y' => base - Duration::days(num * 365),
            _ => base - Duration::days(num),
        }
    }

    /// Create a new relative date from a string.
    #[must_use]
    pub fn new(s: &str) -> Self {
        Self::Named(s.to_string())
    }
}

impl std::fmt::Display for RelativeDate {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Named(s) => write!(f, "{s}"),
        }
    }
}

/// A template variable that can be substituted when applying.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateVariable {
    /// Variable name (without braces).
    pub name: String,
    /// Default value if not provided.
    #[serde(default)]
    pub default: Option<String>,
    /// Description of the variable.
    #[serde(default)]
    pub description: Option<String>,
}

/// A todo item within a template.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateTodo {
    /// The todo title (may contain {{variables}}).
    pub title: String,
    /// Optional notes.
    #[serde(default)]
    pub notes: Option<String>,
    /// Relative due date.
    #[serde(default)]
    pub due: Option<RelativeDate>,
    /// Tags to apply.
    #[serde(default)]
    pub tags: Vec<String>,
    /// Checklist items.
    #[serde(default)]
    pub checklist: Vec<String>,
}

impl TemplateTodo {
    /// Create a new template todo.
    #[must_use]
    pub fn new(title: &str) -> Self {
        Self {
            title: title.to_string(),
            notes: None,
            due: None,
            tags: Vec::new(),
            checklist: Vec::new(),
        }
    }

    /// Set the notes.
    #[must_use]
    pub fn with_notes(mut self, notes: &str) -> Self {
        self.notes = Some(notes.to_string());
        self
    }

    /// Set the due date.
    #[must_use]
    pub fn with_due(mut self, due: RelativeDate) -> Self {
        self.due = Some(due);
        self
    }

    /// Add tags.
    #[must_use]
    pub fn with_tags(mut self, tags: Vec<String>) -> Self {
        self.tags = tags;
        self
    }
}

/// A heading (section) within a project template.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateHeading {
    /// Heading title.
    pub title: String,
    /// Todos under this heading.
    #[serde(default)]
    pub todos: Vec<TemplateTodo>,
}

impl TemplateHeading {
    /// Create a new heading.
    #[must_use]
    pub fn new(title: &str) -> Self {
        Self {
            title: title.to_string(),
            todos: Vec::new(),
        }
    }

    /// Add todos to the heading.
    #[must_use]
    pub fn with_todos(mut self, todos: Vec<TemplateTodo>) -> Self {
        self.todos = todos;
        self
    }
}

/// A project template.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectTemplate {
    /// Template name (unique identifier).
    pub name: String,
    /// Template description.
    #[serde(default)]
    pub description: Option<String>,
    /// Default project notes.
    #[serde(default)]
    pub notes: Option<String>,
    /// Default area for the project.
    #[serde(default)]
    pub area: Option<String>,
    /// Default tags for the project.
    #[serde(default)]
    pub tags: Vec<String>,
    /// Template variables.
    #[serde(default)]
    pub variables: Vec<TemplateVariable>,
    /// Todos at the project level (no heading).
    #[serde(default)]
    pub todos: Vec<TemplateTodo>,
    /// Headings with their todos.
    #[serde(default)]
    pub headings: Vec<TemplateHeading>,
    /// Source project this template was created from.
    #[serde(default)]
    pub source_project: Option<String>,
    /// When the template was created.
    #[serde(default)]
    pub created_at: Option<chrono::DateTime<chrono::Utc>>,
}

impl ProjectTemplate {
    /// Create a new empty template.
    #[must_use]
    pub fn new(name: &str) -> Self {
        Self {
            name: name.to_string(),
            description: None,
            notes: None,
            area: None,
            tags: Vec::new(),
            variables: Vec::new(),
            todos: Vec::new(),
            headings: Vec::new(),
            source_project: None,
            created_at: Some(chrono::Utc::now()),
        }
    }

    /// Set the description.
    #[must_use]
    pub fn with_description(mut self, description: &str) -> Self {
        self.description = Some(description.to_string());
        self
    }

    /// Set the notes.
    #[must_use]
    pub fn with_notes(mut self, notes: &str) -> Self {
        self.notes = Some(notes.to_string());
        self
    }

    /// Set the area.
    #[must_use]
    pub fn with_area(mut self, area: &str) -> Self {
        self.area = Some(area.to_string());
        self
    }

    /// Set the tags.
    #[must_use]
    pub fn with_tags(mut self, tags: Vec<String>) -> Self {
        self.tags = tags;
        self
    }

    /// Add headings.
    #[must_use]
    pub fn with_headings(mut self, headings: Vec<TemplateHeading>) -> Self {
        self.headings = headings;
        self
    }

    /// Add project-level todos.
    #[must_use]
    pub fn with_todos(mut self, todos: Vec<TemplateTodo>) -> Self {
        self.todos = todos;
        self
    }

    /// Set the source project.
    #[must_use]
    pub fn with_source(mut self, source: &str) -> Self {
        self.source_project = Some(source.to_string());
        self
    }

    /// Get total number of todos in the template.
    #[must_use]
    pub fn todo_count(&self) -> usize {
        self.todos.len() + self.headings.iter().map(|h| h.todos.len()).sum::<usize>()
    }

    /// Substitute variables in a string.
    pub fn substitute(&self, text: &str, vars: &std::collections::HashMap<String, String>) -> String {
        let mut result = text.to_string();

        // First, substitute provided variables
        for (key, value) in vars {
            let pattern = format!("{{{{{key}}}}}");
            result = result.replace(&pattern, value);
        }

        // Then, substitute defaults for any remaining variables
        for var in &self.variables {
            let pattern = format!("{{{{{}}}}}", var.name);
            if result.contains(&pattern) {
                if let Some(default) = &var.default {
                    result = result.replace(&pattern, default);
                }
            }
        }

        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_relative_date_today() {
        let date = RelativeDate::new("today");
        assert_eq!(date.resolve(), Local::now().date_naive());
    }

    #[test]
    fn test_relative_date_tomorrow() {
        let date = RelativeDate::new("tomorrow");
        assert_eq!(
            date.resolve(),
            Local::now().date_naive() + Duration::days(1)
        );
    }

    #[test]
    fn test_relative_date_offset_days() {
        let date = RelativeDate::new("+3d");
        assert_eq!(
            date.resolve(),
            Local::now().date_naive() + Duration::days(3)
        );
    }

    #[test]
    fn test_relative_date_offset_weeks() {
        let date = RelativeDate::new("+2w");
        assert_eq!(
            date.resolve(),
            Local::now().date_naive() + Duration::weeks(2)
        );
    }

    #[test]
    fn test_relative_date_negative_offset() {
        let date = RelativeDate::new("-1d");
        assert_eq!(
            date.resolve(),
            Local::now().date_naive() - Duration::days(1)
        );
    }

    #[test]
    fn test_template_todo_builder() {
        let todo = TemplateTodo::new("Test todo")
            .with_notes("Some notes")
            .with_due(RelativeDate::new("+1w"))
            .with_tags(vec!["tag1".to_string()]);

        assert_eq!(todo.title, "Test todo");
        assert_eq!(todo.notes, Some("Some notes".to_string()));
        assert!(todo.due.is_some());
        assert_eq!(todo.tags, vec!["tag1".to_string()]);
    }

    #[test]
    fn test_template_heading() {
        let heading = TemplateHeading::new("Planning").with_todos(vec![
            TemplateTodo::new("Task 1"),
            TemplateTodo::new("Task 2"),
        ]);

        assert_eq!(heading.title, "Planning");
        assert_eq!(heading.todos.len(), 2);
    }

    #[test]
    fn test_project_template_builder() {
        let template = ProjectTemplate::new("Sprint")
            .with_description("Sprint template")
            .with_notes("Sprint notes")
            .with_area("Work")
            .with_tags(vec!["sprint".to_string()])
            .with_source("Sprint 42");

        assert_eq!(template.name, "Sprint");
        assert_eq!(template.description, Some("Sprint template".to_string()));
        assert_eq!(template.area, Some("Work".to_string()));
        assert_eq!(template.source_project, Some("Sprint 42".to_string()));
    }

    #[test]
    fn test_template_todo_count() {
        let template = ProjectTemplate::new("Test")
            .with_todos(vec![TemplateTodo::new("Root todo")])
            .with_headings(vec![
                TemplateHeading::new("H1").with_todos(vec![
                    TemplateTodo::new("T1"),
                    TemplateTodo::new("T2"),
                ]),
                TemplateHeading::new("H2").with_todos(vec![TemplateTodo::new("T3")]),
            ]);

        assert_eq!(template.todo_count(), 4);
    }

    #[test]
    fn test_variable_substitution() {
        let mut template = ProjectTemplate::new("Sprint {{number}}");
        template.variables.push(TemplateVariable {
            name: "number".to_string(),
            default: Some("1".to_string()),
            description: Some("Sprint number".to_string()),
        });

        let mut vars = std::collections::HashMap::new();
        vars.insert("number".to_string(), "43".to_string());

        let result = template.substitute("Sprint {{number}} - Week {{week}}", &vars);
        assert_eq!(result, "Sprint 43 - Week {{week}}");
    }

    #[test]
    fn test_variable_substitution_with_defaults() {
        let mut template = ProjectTemplate::new("Test");
        template.variables.push(TemplateVariable {
            name: "version".to_string(),
            default: Some("1.0".to_string()),
            description: None,
        });

        let vars = std::collections::HashMap::new();
        let result = template.substitute("Release v{{version}}", &vars);
        assert_eq!(result, "Release v1.0");
    }
}
