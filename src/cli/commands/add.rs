//! Quick add command implementation.
//!
//! This module implements the `clings add` command for natural language task entry.

use colored::Colorize;
use serde_json::json;

use crate::cli::args::{OutputFormat, QuickAddArgs};
use crate::core::parse_natural_date;
use crate::error::ClingsError;
use crate::features::nlp::{parse_task, ParsedTask, Priority};
use crate::things::ThingsClient;

/// Execute the quick add command.
///
/// # Errors
///
/// Returns an error if parsing fails or the Things 3 API call fails.
pub fn quick_add(
    client: &ThingsClient,
    args: QuickAddArgs,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    // Parse the natural language input
    let mut task = parse_task(&args.text);

    // Apply overrides from CLI args
    if let Some(project) = args.project {
        task.project = Some(project);
    }
    if let Some(area) = args.area {
        task.area = Some(area);
    }
    if let Some(when_str) = args.when {
        task.when = parse_natural_date(&when_str);
    }
    if let Some(deadline_str) = args.deadline {
        task.deadline = parse_natural_date(&deadline_str).map(|d| d.as_deadline());
    }

    // If parse-only mode, just show what would be created
    if args.parse_only {
        return format_parsed_task(&task, format);
    }

    // Validate we have a title
    if task.title.is_empty() {
        return Err(ClingsError::Parse(serde_json::Error::io(
            std::io::Error::new(std::io::ErrorKind::InvalidInput, "No task title found"),
        )));
    }

    // Create the todo via Things client
    let response = client.add_todo(
        &task.title,
        task.notes.as_deref(),
        task.when_date_iso().as_deref(),
        task.deadline_date_iso().as_deref(),
        if task.tags.is_empty() {
            None
        } else {
            Some(task.tags.as_slice())
        },
        task.project.as_deref(),
        task.area.as_deref(),
        if task.checklist.is_empty() {
            None
        } else {
            Some(task.checklist.as_slice())
        },
    )?;

    // Format output
    match format {
        OutputFormat::Json => {
            let output = json!({
                "created": true,
                "id": response.id,
                "name": response.name,
                "parsed": {
                    "title": task.title,
                    "when": task.when_date_iso(),
                    "deadline": task.deadline_date_iso(),
                    "tags": task.tags,
                    "project": task.project,
                    "area": task.area,
                    "priority": task.priority.to_string(),
                    "notes": task.notes,
                    "checklist": task.checklist,
                }
            });
            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        }
        OutputFormat::Pretty => {
            let mut output = format!(
                "{} {} (ID: {})\n",
                "Created:".green().bold(),
                response.name,
                response.id.dimmed()
            );

            if let Some(when) = task.when_date_iso() {
                output.push_str(&format!("  {} {}\n", "When:".cyan(), when));
            }
            if let Some(deadline) = task.deadline_date_iso() {
                output.push_str(&format!("  {} {}\n", "Deadline:".red(), deadline));
            }
            if !task.tags.is_empty() {
                let tags_str: Vec<String> = task.tags.iter().map(|t| format!("#{}", t)).collect();
                output.push_str(&format!("  {} {}\n", "Tags:".yellow(), tags_str.join(" ")));
            }
            if let Some(project) = &task.project {
                output.push_str(&format!("  {} {}\n", "Project:".magenta(), project));
            }
            if task.priority != Priority::None {
                output.push_str(&format!("  {} {}\n", "Priority:".red().bold(), task.priority));
            }

            Ok(output)
        }
    }
}

/// Format a parsed task for display (parse-only mode).
fn format_parsed_task(task: &ParsedTask, format: OutputFormat) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Json => {
            let output = json!({
                "parsed": true,
                "title": task.title,
                "when": task.when_date_iso(),
                "deadline": task.deadline_date_iso(),
                "tags": task.tags,
                "project": task.project,
                "area": task.area,
                "priority": task.priority.to_string(),
                "notes": task.notes,
                "checklist": task.checklist,
                "has_schedule": task.has_schedule(),
            });
            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        }
        OutputFormat::Pretty => {
            let mut output = format!("{}\n", "Parsed Task (not created)".yellow().bold());
            output.push_str(&format!("  {} {}\n", "Title:".cyan().bold(), task.title));

            if let Some(when) = task.when_date_iso() {
                output.push_str(&format!("  {} {}\n", "When:".cyan(), when));
                if let Some(ref w) = task.when {
                    if let Some(time) = w.time {
                        output.push_str(&format!(
                            "  {} {}\n",
                            "Time:".cyan(),
                            time.format("%H:%M")
                        ));
                    }
                }
            }
            if let Some(deadline) = task.deadline_date_iso() {
                output.push_str(&format!("  {} {}\n", "Deadline:".red(), deadline));
            }
            if !task.tags.is_empty() {
                let tags_str: Vec<String> = task.tags.iter().map(|t| format!("#{}", t)).collect();
                output.push_str(&format!("  {} {}\n", "Tags:".yellow(), tags_str.join(" ")));
            }
            if let Some(project) = &task.project {
                output.push_str(&format!("  {} {}\n", "Project:".magenta(), project));
            }
            if let Some(area) = &task.area {
                output.push_str(&format!("  {} {}\n", "Area:".blue(), area));
            }
            if task.priority != Priority::None {
                output.push_str(&format!("  {} {}\n", "Priority:".red().bold(), task.priority));
            }
            if let Some(notes) = &task.notes {
                output.push_str(&format!("  {} {}\n", "Notes:".dimmed(), notes));
            }
            if !task.checklist.is_empty() {
                output.push_str(&format!("  {}\n", "Checklist:".dimmed()));
                for item in &task.checklist {
                    output.push_str(&format!("    - {}\n", item));
                }
            }

            Ok(output)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_format_parsed_task_json() {
        let task = ParsedTask {
            title: "test task".to_string(),
            tags: vec!["work".to_string()],
            ..Default::default()
        };

        let result = format_parsed_task(&task, OutputFormat::Json).unwrap();
        assert!(result.contains("\"title\": \"test task\""));
        assert!(result.contains("\"tags\""));
    }

    #[test]
    fn test_format_parsed_task_pretty() {
        let task = ParsedTask {
            title: "test task".to_string(),
            tags: vec!["work".to_string()],
            project: Some("MyProject".to_string()),
            ..Default::default()
        };

        let result = format_parsed_task(&task, OutputFormat::Pretty).unwrap();
        assert!(result.contains("test task"));
        assert!(result.contains("#work"));
        assert!(result.contains("MyProject"));
    }
}
