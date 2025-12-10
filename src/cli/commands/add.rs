//! Quick add command implementation.
//!
//! This module implements the `clings add` command for natural language task entry.

use std::fmt::Write;

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
        task.deadline =
            parse_natural_date(&deadline_str).map(crate::core::DateParseResult::as_deadline);
    }

    // Merge CLI tags with NLP-parsed tags (deduplicated)
    if let Some(cli_tags) = args.tags {
        for tag in cli_tags {
            let trimmed = tag.trim().to_string();
            if !trimmed.is_empty() && !task.tags.contains(&trimmed) {
                task.tags.push(trimmed);
            }
        }
    }

    // Override NLP notes with CLI notes if provided
    if let Some(cli_notes) = args.notes {
        task.notes = Some(cli_notes);
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
        },
        OutputFormat::Pretty => {
            let mut output = format!(
                "{} {} (ID: {})\n",
                "Created:".green().bold(),
                response.name,
                response.id.dimmed()
            );

            if let Some(when) = task.when_date_iso() {
                writeln!(output, "  {} {when}", "When:".cyan()).ok();
            }
            if let Some(deadline) = task.deadline_date_iso() {
                writeln!(output, "  {} {deadline}", "Deadline:".red()).ok();
            }
            if !task.tags.is_empty() {
                let tags_str: Vec<String> = task.tags.iter().map(|t| format!("#{t}")).collect();
                writeln!(output, "  {} {}", "Tags:".yellow(), tags_str.join(" ")).ok();
            }
            if let Some(project) = &task.project {
                writeln!(output, "  {} {project}", "Project:".magenta()).ok();
            }
            if task.priority != Priority::None {
                writeln!(output, "  {} {}", "Priority:".red().bold(), task.priority).ok();
            }

            Ok(output)
        },
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
        },
        OutputFormat::Pretty => {
            let mut output = format!("{}\n", "Parsed Task (not created)".yellow().bold());
            writeln!(output, "  {} {}", "Title:".cyan().bold(), task.title).ok();

            if let Some(when) = task.when_date_iso() {
                writeln!(output, "  {} {when}", "When:".cyan()).ok();
                if let Some(ref w) = task.when {
                    if let Some(time) = w.time {
                        writeln!(output, "  {} {}", "Time:".cyan(), time.format("%H:%M")).ok();
                    }
                }
            }
            if let Some(deadline) = task.deadline_date_iso() {
                writeln!(output, "  {} {deadline}", "Deadline:".red()).ok();
            }
            if !task.tags.is_empty() {
                let tags_str: Vec<String> = task.tags.iter().map(|t| format!("#{t}")).collect();
                writeln!(output, "  {} {}", "Tags:".yellow(), tags_str.join(" ")).ok();
            }
            if let Some(project) = &task.project {
                writeln!(output, "  {} {project}", "Project:".magenta()).ok();
            }
            if let Some(area) = &task.area {
                writeln!(output, "  {} {area}", "Area:".blue()).ok();
            }
            if task.priority != Priority::None {
                writeln!(output, "  {} {}", "Priority:".red().bold(), task.priority).ok();
            }
            if let Some(notes) = &task.notes {
                writeln!(output, "  {} {notes}", "Notes:".dimmed()).ok();
            }
            if !task.checklist.is_empty() {
                writeln!(output, "  {}", "Checklist:".dimmed()).ok();
                for item in &task.checklist {
                    writeln!(output, "    - {item}").ok();
                }
            }

            Ok(output)
        },
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
