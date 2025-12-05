//! Weekly review CLI command.
//!
//! This module implements the `clings review` command for interactive weekly reviews.

use std::fmt::Write;

use colored::Colorize;
use serde_json::json;

use crate::cli::args::{OutputFormat, ReviewArgs};
use crate::error::ClingsError;
use crate::features::review::{ReviewPrompt, ReviewPromptResult, ReviewSession, ReviewStep};
use crate::things::ThingsClient;

/// Execute the review command.
///
/// # Errors
///
/// Returns an error if the Things 3 API call fails or the review cannot be started.
pub fn review(
    client: ThingsClient,
    args: &ReviewArgs,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    // Handle status request
    if args.status {
        return show_status(format);
    }

    // Handle clear request
    if args.clear {
        let session = ReviewSession::new(client);
        session.clear_saved_state()?;
        return Ok("Cleared saved review state.".to_string());
    }

    // Start or resume review
    let mut session = if args.resume {
        ReviewSession::resume(client.clone()).map_or_else(
            |_| {
                println!("No saved review to resume. Starting new review.");
                let s = ReviewSession::new(client);
                ReviewPrompt::welcome();
                s
            },
            |s| {
                ReviewPrompt::resume_message(s.current_step().name(), s.state().progress_percent());
                s
            },
        )
    } else {
        let s = ReviewSession::new(client);
        ReviewPrompt::welcome();
        s
    };

    // Run the review loop
    run_review_loop(&mut session, args.deadline_days)?;

    // Generate output
    if session.is_complete() {
        let summary = session.get_summary();
        session.clear_saved_state()?;

        match format {
            OutputFormat::Json => {
                let output = json!({
                    "status": "complete",
                    "duration_seconds": summary.duration_seconds,
                    "duration_formatted": summary.format_duration(),
                    "total_processed": summary.total_processed,
                    "completed": summary.completed,
                    "moved_to_someday": summary.moved_to_someday,
                    "scheduled": summary.scheduled,
                    "projects_reviewed": summary.projects_reviewed,
                    "deadlines_reviewed": summary.deadlines_reviewed,
                    "notes": summary.notes,
                });
                serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
            },
            OutputFormat::Pretty => {
                ReviewPrompt::display_summary(
                    &summary.format_duration(),
                    summary.total_processed,
                    summary.completed,
                    summary.moved_to_someday,
                    summary.scheduled,
                    summary.projects_reviewed,
                    summary.deadlines_reviewed,
                );
                Ok(String::new())
            },
        }
    } else {
        // Review was paused
        session.save()?;
        Ok("Review paused. Use 'clings review --resume' to continue.".to_string())
    }
}

/// Show the current review status.
#[allow(clippy::too_many_lines)]
fn show_status(format: OutputFormat) -> Result<String, ClingsError> {
    let paths = crate::config::Paths::default();
    let state_path = paths.root.join("review_state.yaml");

    if !state_path.exists() {
        return match format {
            OutputFormat::Json => {
                let output = json!({
                    "active_review": false,
                });
                serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
            },
            OutputFormat::Pretty => Ok("No active review session.".to_string()),
        };
    }

    let content = std::fs::read_to_string(&state_path).map_err(ClingsError::Io)?;
    let state: crate::features::review::ReviewState =
        serde_yaml::from_str(&content).map_err(|e| ClingsError::Config(e.to_string()))?;

    match format {
        OutputFormat::Json => {
            let output = json!({
                "active_review": true,
                "current_step": state.current_step.name(),
                "step_number": state.current_step.number(),
                "total_steps": ReviewStep::total_steps(),
                "progress_percent": state.progress_percent(),
                "started_at": state.started_at.to_rfc3339(),
                "updated_at": state.updated_at.to_rfc3339(),
                "inbox_processed": state.inbox_processed,
                "someday_reviewed": state.someday_reviewed,
                "projects_checked": state.projects_checked,
                "deadlines_reviewed": state.deadlines_reviewed,
                "items_completed": state.items_completed.len(),
                "items_moved_to_someday": state.items_moved_to_someday.len(),
                "items_scheduled": state.items_scheduled.len(),
            });
            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        },
        OutputFormat::Pretty => {
            let mut output = String::new();
            let _ = writeln!(output, "{}", "Active Review Session".cyan().bold());
            let _ = writeln!(output, "{}", "─".repeat(40).dimmed());
            let _ = writeln!(
                output,
                "  {} Step {}/{}: {}",
                "Current:".bold(),
                state.current_step.number(),
                ReviewStep::total_steps(),
                state.current_step.name()
            );
            let _ = writeln!(
                output,
                "  {} {}%",
                "Progress:".bold(),
                state.progress_percent()
            );
            let _ = writeln!(
                output,
                "  {} {}",
                "Started:".bold(),
                state.started_at.format("%Y-%m-%d %H:%M")
            );
            let _ = writeln!(
                output,
                "  {} {}",
                "Updated:".bold(),
                state.updated_at.format("%Y-%m-%d %H:%M")
            );
            output.push('\n');
            let _ = writeln!(output, "{}", "Statistics:".cyan().bold());
            let _ = writeln!(output, "  {} inbox items processed", state.inbox_processed);
            let _ = writeln!(
                output,
                "  {} someday items reviewed",
                state.someday_reviewed
            );
            let _ = writeln!(output, "  {} projects checked", state.projects_checked);
            let _ = writeln!(output, "  {} deadlines reviewed", state.deadlines_reviewed);
            let _ = writeln!(output, "  {} items completed", state.items_completed.len());
            let _ = writeln!(
                output,
                "  {} items moved to someday",
                state.items_moved_to_someday.len()
            );
            let _ = writeln!(output, "  {} items scheduled", state.items_scheduled.len());
            output.push('\n');
            output.push_str("Use 'clings review --resume' to continue.\n");
            Ok(output)
        },
    }
}

/// Run the main review loop.
fn run_review_loop(session: &mut ReviewSession, deadline_days: i64) -> Result<(), ClingsError> {
    loop {
        let step = session.current_step();

        // Display step header and instructions
        ReviewPrompt::step_header(
            step.name(),
            step.number(),
            ReviewStep::total_steps(),
            session.state().progress_percent(),
        );
        ReviewPrompt::step_instructions(step.name());

        // Execute the current step
        let should_continue = match step {
            ReviewStep::ProcessInbox => process_inbox(session)?,
            ReviewStep::ReviewSomeday => review_someday(session)?,
            ReviewStep::CheckProjects => check_projects(session)?,
            ReviewStep::ReviewDeadlines => review_deadlines(session, deadline_days)?,
            ReviewStep::GenerateSummary => {
                // Summary is displayed after the loop
                session.advance();
                true
            },
            ReviewStep::Complete => break,
        };

        if !should_continue {
            // User requested pause or quit
            break;
        }
    }

    Ok(())
}

/// Process inbox items.
fn process_inbox(session: &mut ReviewSession) -> Result<bool, ClingsError> {
    let inbox = session.get_inbox()?;

    if inbox.is_empty() {
        ReviewPrompt::no_items("inbox items");
        if !ReviewPrompt::continue_prompt() {
            return Ok(false);
        }
        session.advance();
        return Ok(true);
    }

    for (i, todo) in inbox.iter().enumerate() {
        let result = ReviewPrompt::inbox_item(todo, i, inbox.len());

        match result {
            ReviewPromptResult::Next | ReviewPromptResult::Skip => {
                if !matches!(result, ReviewPromptResult::Skip) {
                    session.state_mut().inbox_processed += 1;
                }
            },
            ReviewPromptResult::Complete => {
                session.complete_todo(&todo.id)?;
                session.state_mut().inbox_processed += 1;
            },
            ReviewPromptResult::MoveToSomeday => {
                // Move to someday via Things
                session.client().move_to_someday(&todo.id)?;
                session
                    .state_mut()
                    .items_moved_to_someday
                    .push(todo.id.clone());
                session.state_mut().inbox_processed += 1;
            },
            ReviewPromptResult::Schedule(date) => {
                let parsed_date = crate::cli::args::parse_date(&date);
                session.client().update_todo_due(&todo.id, &parsed_date)?;
                session.state_mut().items_scheduled.push(todo.id.clone());
                session.state_mut().inbox_processed += 1;
            },
            ReviewPromptResult::Back => {
                session.go_back();
                return Ok(true);
            },
            ReviewPromptResult::Pause => {
                if ReviewPrompt::confirm_pause() {
                    return Ok(false);
                }
            },
            ReviewPromptResult::Quit => {
                if ReviewPrompt::confirm_quit() {
                    // Don't save state on quit
                    session.clear_saved_state()?;
                    std::process::exit(0);
                }
            },
            ReviewPromptResult::AddNote(_) => {
                // Not used in inbox processing
            },
        }
    }

    if !ReviewPrompt::continue_prompt() {
        return Ok(false);
    }

    session.advance();
    Ok(true)
}

/// Review someday items.
fn review_someday(session: &mut ReviewSession) -> Result<bool, ClingsError> {
    let someday = session.get_someday()?;

    if someday.is_empty() {
        ReviewPrompt::no_items("someday items");
        if !ReviewPrompt::continue_prompt() {
            return Ok(false);
        }
        session.advance();
        return Ok(true);
    }

    for (i, todo) in someday.iter().enumerate() {
        let result = ReviewPrompt::someday_item(todo, i, someday.len());

        match result {
            ReviewPromptResult::Next | ReviewPromptResult::Skip => {
                if !matches!(result, ReviewPromptResult::Skip) {
                    session.state_mut().someday_reviewed += 1;
                }
            },
            ReviewPromptResult::Complete => {
                session.complete_todo(&todo.id)?;
                session.state_mut().someday_reviewed += 1;
            },
            ReviewPromptResult::Schedule(date) => {
                let parsed_date = crate::cli::args::parse_date(&date);
                session.client().update_todo_due(&todo.id, &parsed_date)?;
                session.state_mut().items_scheduled.push(todo.id.clone());
                session.state_mut().someday_reviewed += 1;
            },
            ReviewPromptResult::Back => {
                session.go_back();
                return Ok(true);
            },
            ReviewPromptResult::Pause => {
                if ReviewPrompt::confirm_pause() {
                    return Ok(false);
                }
            },
            ReviewPromptResult::Quit => {
                if ReviewPrompt::confirm_quit() {
                    session.clear_saved_state()?;
                    std::process::exit(0);
                }
            },
            _ => {},
        }
    }

    if !ReviewPrompt::continue_prompt() {
        return Ok(false);
    }

    session.advance();
    Ok(true)
}

/// Check active projects.
fn check_projects(session: &mut ReviewSession) -> Result<bool, ClingsError> {
    let projects = session.get_projects()?;
    let active_projects: Vec<_> = projects
        .into_iter()
        .filter(|p| p.status == crate::things::types::Status::Open)
        .collect();

    if active_projects.is_empty() {
        ReviewPrompt::no_items("active projects");
        if !ReviewPrompt::continue_prompt() {
            return Ok(false);
        }
        session.advance();
        return Ok(true);
    }

    for (i, project) in active_projects.iter().enumerate() {
        let result = ReviewPrompt::project_item(project, i, active_projects.len());

        match result {
            ReviewPromptResult::Next | ReviewPromptResult::Skip => {
                if !matches!(result, ReviewPromptResult::Skip) {
                    session.state_mut().projects_checked += 1;
                }
            },
            ReviewPromptResult::Back => {
                session.go_back();
                return Ok(true);
            },
            ReviewPromptResult::Pause => {
                if ReviewPrompt::confirm_pause() {
                    return Ok(false);
                }
            },
            ReviewPromptResult::Quit => {
                if ReviewPrompt::confirm_quit() {
                    session.clear_saved_state()?;
                    std::process::exit(0);
                }
            },
            _ => {},
        }
    }

    if !ReviewPrompt::continue_prompt() {
        return Ok(false);
    }

    session.advance();
    Ok(true)
}

/// Review upcoming deadlines.
fn review_deadlines(session: &mut ReviewSession, days: i64) -> Result<bool, ClingsError> {
    let deadlines = session.get_upcoming_deadlines(days)?;

    if deadlines.is_empty() {
        ReviewPrompt::no_items(&format!("deadlines in the next {days} days"));
        if !ReviewPrompt::continue_prompt() {
            return Ok(false);
        }
        session.advance();
        return Ok(true);
    }

    for (i, todo) in deadlines.iter().enumerate() {
        let result = ReviewPrompt::deadline_item(todo, i, deadlines.len());

        match result {
            ReviewPromptResult::Next | ReviewPromptResult::Skip => {
                if !matches!(result, ReviewPromptResult::Skip) {
                    session.state_mut().deadlines_reviewed += 1;
                }
            },
            ReviewPromptResult::Complete => {
                session.complete_todo(&todo.id)?;
                session.state_mut().deadlines_reviewed += 1;
            },
            ReviewPromptResult::Schedule(date) => {
                let parsed_date = crate::cli::args::parse_date(&date);
                session.client().update_todo_due(&todo.id, &parsed_date)?;
                session.state_mut().items_scheduled.push(todo.id.clone());
                session.state_mut().deadlines_reviewed += 1;
            },
            ReviewPromptResult::Back => {
                session.go_back();
                return Ok(true);
            },
            ReviewPromptResult::Pause => {
                if ReviewPrompt::confirm_pause() {
                    return Ok(false);
                }
            },
            ReviewPromptResult::Quit => {
                if ReviewPrompt::confirm_quit() {
                    session.clear_saved_state()?;
                    std::process::exit(0);
                }
            },
            _ => {},
        }
    }

    if !ReviewPrompt::continue_prompt() {
        return Ok(false);
    }

    session.advance();
    Ok(true)
}

#[cfg(test)]
mod tests {
    use crate::cli::args::ReviewArgs;

    #[test]
    fn test_review_args_defaults() {
        let args = ReviewArgs {
            resume: false,
            status: false,
            clear: false,
            deadline_days: 7,
        };
        assert!(!args.resume);
        assert!(!args.status);
        assert!(!args.clear);
        assert_eq!(args.deadline_days, 7);
    }
}
