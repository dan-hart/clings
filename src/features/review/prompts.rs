//! Interactive prompts for the weekly review.
//!
//! Provides terminal-based prompts for guiding users through the review process.

use std::io::{self, Write};

use colored::Colorize;

use crate::things::{Project, Todo};

/// Result of a review prompt interaction.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReviewPromptResult {
    /// Continue to next item.
    Next,
    /// Skip this item.
    Skip,
    /// Mark item as complete.
    Complete,
    /// Move item to someday.
    MoveToSomeday,
    /// Schedule the item.
    Schedule(String),
    /// Add a note.
    AddNote(String),
    /// Go back to previous step.
    Back,
    /// Pause and save progress.
    Pause,
    /// Quit the review.
    Quit,
}

/// Prompts for the weekly review process.
pub struct ReviewPrompt;

impl ReviewPrompt {
    /// Display a welcome message for the review.
    pub fn welcome() {
        println!();
        println!("{}", "╔══════════════════════════════════════════════════════════════╗".cyan());
        println!("{}", "║                    Weekly Review                              ║".cyan());
        println!("{}", "╚══════════════════════════════════════════════════════════════╝".cyan());
        println!();
        println!("Let's review your system and make sure everything is up to date.");
        println!();
    }

    /// Display the current step header.
    pub fn step_header(step_name: &str, step_num: u8, total: u8, progress_percent: u8) {
        println!();
        let progress_bar = Self::progress_bar(progress_percent);
        println!(
            "{} Step {}/{}: {}",
            progress_bar,
            step_num,
            total,
            step_name.bold()
        );
        println!("{}", "─".repeat(60).dimmed());
    }

    /// Generate a progress bar string.
    fn progress_bar(percent: u8) -> String {
        let filled = (percent as usize) / 5;
        let empty = 20 - filled;
        format!(
            "[{}{}] {}%",
            "█".repeat(filled).green(),
            "░".repeat(empty).dimmed(),
            percent
        )
    }

    /// Display step instructions.
    pub fn step_instructions(step_name: &str) {
        let instructions = match step_name {
            "Process Inbox" => {
                "Review each item in your inbox and decide:\n\
                 • Is it actionable? If not, delete or move to someday\n\
                 • Does it take less than 2 minutes? Do it now\n\
                 • Should it be delegated? Move to waiting\n\
                 • Otherwise, schedule it or add to a project"
            }
            "Review Someday/Maybe" => {
                "Look through your someday items:\n\
                 • Has anything become more urgent? Schedule it\n\
                 • Is anything no longer relevant? Delete it\n\
                 • Keep items that might be useful later"
            }
            "Check Active Projects" => {
                "For each active project, verify:\n\
                 • Does it have a clear next action?\n\
                 • Is the project still relevant?\n\
                 • Are there any stuck items?"
            }
            "Review Upcoming Deadlines" => {
                "Check items with upcoming deadlines:\n\
                 • Are you on track to meet them?\n\
                 • Do any need to be rescheduled?\n\
                 • Are there dependencies to resolve?"
            }
            "Generate Summary" => {
                "Review complete! Let's see how you did."
            }
            _ => "Follow the prompts below.",
        };

        println!();
        println!("{}", instructions.dimmed());
        println!();
    }

    /// Prompt for processing an inbox item.
    pub fn inbox_item(todo: &Todo, index: usize, total: usize) -> ReviewPromptResult {
        Self::display_todo(todo);
        println!(
            "  {} {} of {}",
            "Item".dimmed(),
            (index + 1).to_string().bold(),
            total
        );
        println!();

        Self::show_options(&[
            ("n", "Next (keep in inbox)"),
            ("c", "Complete"),
            ("s", "Move to Someday"),
            ("d", "Schedule (set date)"),
            ("k", "Skip"),
            ("b", "Back to previous step"),
            ("p", "Pause review"),
            ("q", "Quit"),
        ]);

        Self::get_inbox_action()
    }

    /// Prompt for reviewing a someday item.
    pub fn someday_item(todo: &Todo, index: usize, total: usize) -> ReviewPromptResult {
        Self::display_todo(todo);
        println!(
            "  {} {} of {}",
            "Item".dimmed(),
            (index + 1).to_string().bold(),
            total
        );
        println!();

        Self::show_options(&[
            ("n", "Next (keep in someday)"),
            ("c", "Complete (done!)"),
            ("d", "Schedule (make active)"),
            ("k", "Skip"),
            ("b", "Back"),
            ("p", "Pause"),
            ("q", "Quit"),
        ]);

        Self::get_someday_action()
    }

    /// Prompt for checking a project.
    pub fn project_item(project: &Project, index: usize, total: usize) -> ReviewPromptResult {
        Self::display_project(project);
        println!(
            "  {} {} of {}",
            "Project".dimmed(),
            (index + 1).to_string().bold(),
            total
        );
        println!();

        Self::show_options(&[
            ("n", "Next (project looks good)"),
            ("o", "Open in Things"),
            ("k", "Skip"),
            ("b", "Back"),
            ("p", "Pause"),
            ("q", "Quit"),
        ]);

        Self::get_project_action()
    }

    /// Prompt for reviewing an upcoming deadline.
    pub fn deadline_item(todo: &Todo, index: usize, total: usize) -> ReviewPromptResult {
        Self::display_todo_with_deadline(todo);
        println!(
            "  {} {} of {}",
            "Deadline".dimmed(),
            (index + 1).to_string().bold(),
            total
        );
        println!();

        Self::show_options(&[
            ("n", "Next (on track)"),
            ("c", "Complete"),
            ("d", "Reschedule"),
            ("k", "Skip"),
            ("b", "Back"),
            ("p", "Pause"),
            ("q", "Quit"),
        ]);

        Self::get_deadline_action()
    }

    /// Display a todo item.
    fn display_todo(todo: &Todo) {
        println!();
        println!("  {} {}", "→".cyan(), todo.name.bold());

        if let Some(ref project) = todo.project {
            println!("    {} {}", "Project:".dimmed(), project);
        }

        if !todo.tags.is_empty() {
            let tags: Vec<String> = todo.tags.iter().map(|t| format!("#{}", t)).collect();
            println!("    {} {}", "Tags:".dimmed(), tags.join(" ").magenta());
        }

        if !todo.notes.is_empty() {
            let truncated = if todo.notes.len() > 100 {
                format!("{}...", &todo.notes[..100])
            } else {
                todo.notes.clone()
            };
            println!("    {} {}", "Notes:".dimmed(), truncated.dimmed());
        }
    }

    /// Display a todo with its deadline emphasized.
    fn display_todo_with_deadline(todo: &Todo) {
        Self::display_todo(todo);

        if let Some(due) = todo.due_date {
            let today = chrono::Local::now().date_naive();
            let days_until = (due - today).num_days();

            let due_str = due.format("%Y-%m-%d").to_string();
            let urgency = if days_until < 0 {
                format!("{} (OVERDUE!)", due_str).red().bold()
            } else if days_until == 0 {
                format!("{} (TODAY!)", due_str).yellow().bold()
            } else if days_until <= 3 {
                format!("{} ({} days)", due_str, days_until).yellow()
            } else {
                format!("{} ({} days)", due_str, days_until).normal()
            };

            println!("    {} {}", "Due:".dimmed(), urgency);
        }
    }

    /// Display a project.
    fn display_project(project: &Project) {
        println!();
        println!("  {} {}", "📁".cyan(), project.name.bold());

        if let Some(ref area) = project.area {
            println!("    {} {}", "Area:".dimmed(), area);
        }

        if !project.tags.is_empty() {
            let tags: Vec<String> = project.tags.iter().map(|t| format!("#{}", t)).collect();
            println!("    {} {}", "Tags:".dimmed(), tags.join(" ").magenta());
        }

        if !project.notes.is_empty() {
            let truncated = if project.notes.len() > 100 {
                format!("{}...", &project.notes[..100])
            } else {
                project.notes.clone()
            };
            println!("    {} {}", "Notes:".dimmed(), truncated.dimmed());
        }

        println!(
            "    {} {}",
            "Status:".dimmed(),
            project.status.to_string()
        );
    }

    /// Show available options.
    fn show_options(options: &[(&str, &str)]) {
        print!("  ");
        for (key, desc) in options {
            print!("[{}]{} ", key.cyan().bold(), desc.dimmed());
        }
        println!();
    }

    /// Read a single character input.
    fn read_char() -> Option<char> {
        print!("  {} ", ">".green());
        io::stdout().flush().ok()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input).ok()?;

        input.trim().chars().next()
    }

    /// Read a line of input.
    fn read_line(prompt: &str) -> Option<String> {
        print!("  {} {}: ", ">".green(), prompt);
        io::stdout().flush().ok()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input).ok()?;

        let trimmed = input.trim().to_string();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed)
        }
    }

    /// Get action for inbox item.
    fn get_inbox_action() -> ReviewPromptResult {
        loop {
            if let Some(c) = Self::read_char() {
                match c.to_ascii_lowercase() {
                    'n' => return ReviewPromptResult::Next,
                    'c' => return ReviewPromptResult::Complete,
                    's' => return ReviewPromptResult::MoveToSomeday,
                    'd' => {
                        if let Some(date) = Self::read_line("Enter date (YYYY-MM-DD or 'today', 'tomorrow', etc.)") {
                            return ReviewPromptResult::Schedule(date);
                        }
                        println!("  {}", "Date required, try again.".yellow());
                    }
                    'k' => return ReviewPromptResult::Skip,
                    'b' => return ReviewPromptResult::Back,
                    'p' => return ReviewPromptResult::Pause,
                    'q' => return ReviewPromptResult::Quit,
                    _ => println!("  {}", "Invalid option, try again.".yellow()),
                }
            }
        }
    }

    /// Get action for someday item.
    fn get_someday_action() -> ReviewPromptResult {
        loop {
            if let Some(c) = Self::read_char() {
                match c.to_ascii_lowercase() {
                    'n' => return ReviewPromptResult::Next,
                    'c' => return ReviewPromptResult::Complete,
                    'd' => {
                        if let Some(date) = Self::read_line("Enter date (YYYY-MM-DD or 'today', 'tomorrow', etc.)") {
                            return ReviewPromptResult::Schedule(date);
                        }
                        println!("  {}", "Date required, try again.".yellow());
                    }
                    'k' => return ReviewPromptResult::Skip,
                    'b' => return ReviewPromptResult::Back,
                    'p' => return ReviewPromptResult::Pause,
                    'q' => return ReviewPromptResult::Quit,
                    _ => println!("  {}", "Invalid option, try again.".yellow()),
                }
            }
        }
    }

    /// Get action for project.
    fn get_project_action() -> ReviewPromptResult {
        loop {
            if let Some(c) = Self::read_char() {
                match c.to_ascii_lowercase() {
                    'n' => return ReviewPromptResult::Next,
                    'o' => return ReviewPromptResult::Next, // Will be handled to open
                    'k' => return ReviewPromptResult::Skip,
                    'b' => return ReviewPromptResult::Back,
                    'p' => return ReviewPromptResult::Pause,
                    'q' => return ReviewPromptResult::Quit,
                    _ => println!("  {}", "Invalid option, try again.".yellow()),
                }
            }
        }
    }

    /// Get action for deadline item.
    fn get_deadline_action() -> ReviewPromptResult {
        loop {
            if let Some(c) = Self::read_char() {
                match c.to_ascii_lowercase() {
                    'n' => return ReviewPromptResult::Next,
                    'c' => return ReviewPromptResult::Complete,
                    'd' => {
                        if let Some(date) = Self::read_line("Enter new date (YYYY-MM-DD or 'today', 'tomorrow', etc.)") {
                            return ReviewPromptResult::Schedule(date);
                        }
                        println!("  {}", "Date required, try again.".yellow());
                    }
                    'k' => return ReviewPromptResult::Skip,
                    'b' => return ReviewPromptResult::Back,
                    'p' => return ReviewPromptResult::Pause,
                    'q' => return ReviewPromptResult::Quit,
                    _ => println!("  {}", "Invalid option, try again.".yellow()),
                }
            }
        }
    }

    /// Confirm quitting the review.
    pub fn confirm_quit() -> bool {
        println!();
        println!(
            "  {} {}",
            "⚠".yellow(),
            "Are you sure you want to quit? Progress will be lost.".yellow()
        );
        print!("  [y/n] ");
        io::stdout().flush().ok();

        if let Some(c) = Self::read_char() {
            return c.to_ascii_lowercase() == 'y';
        }
        false
    }

    /// Confirm pausing the review.
    pub fn confirm_pause() -> bool {
        println!();
        println!(
            "  {} {}",
            "💾".cyan(),
            "Save progress and exit? You can resume later with 'clings review --resume'."
        );
        print!("  [y/n] ");
        io::stdout().flush().ok();

        if let Some(c) = Self::read_char() {
            return c.to_ascii_lowercase() == 'y';
        }
        false
    }

    /// Display the review summary.
    pub fn display_summary(
        duration: &str,
        total_processed: usize,
        completed: usize,
        moved_to_someday: usize,
        scheduled: usize,
        projects_reviewed: usize,
        deadlines_reviewed: usize,
    ) {
        println!();
        println!("{}", "╔══════════════════════════════════════════════════════════════╗".green());
        println!("{}", "║                    Review Complete!                           ║".green());
        println!("{}", "╚══════════════════════════════════════════════════════════════╝".green());
        println!();
        println!("  {} {}", "Duration:".bold(), duration);
        println!();
        println!("  {}", "Summary:".bold());
        println!("    {} items processed", total_processed);
        println!("    {} {} completed", completed, "✓".green());
        println!("    {} moved to someday", moved_to_someday);
        println!("    {} scheduled", scheduled);
        println!("    {} projects reviewed", projects_reviewed);
        println!("    {} deadlines reviewed", deadlines_reviewed);
        println!();
        println!(
            "  {}",
            "Great job! Your system is now up to date.".green().bold()
        );
        println!();
    }

    /// Display a message when resuming a review.
    pub fn resume_message(step_name: &str, progress_percent: u8) {
        println!();
        println!(
            "  {} {}",
            "📂".cyan(),
            "Resuming previous review session...".cyan()
        );
        println!(
            "  {} {} at {}% complete",
            "Current step:".dimmed(),
            step_name.bold(),
            progress_percent
        );
        println!();
    }

    /// Display a message when no items to review.
    pub fn no_items(category: &str) {
        println!();
        println!(
            "  {} No {} to review.",
            "✓".green(),
            category
        );
        println!();
    }

    /// Prompt to continue to next step.
    pub fn continue_prompt() -> bool {
        println!();
        print!(
            "  {} Press {} to continue or {} to pause... ",
            "→".cyan(),
            "Enter".bold(),
            "p".bold()
        );
        io::stdout().flush().ok();

        if let Some(c) = Self::read_char() {
            if c.to_ascii_lowercase() == 'p' {
                return false;
            }
        }
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_progress_bar_empty() {
        let bar = ReviewPrompt::progress_bar(0);
        assert!(bar.contains("0%"));
    }

    #[test]
    fn test_progress_bar_half() {
        let bar = ReviewPrompt::progress_bar(50);
        assert!(bar.contains("50%"));
    }

    #[test]
    fn test_progress_bar_full() {
        let bar = ReviewPrompt::progress_bar(100);
        assert!(bar.contains("100%"));
    }

    #[test]
    fn test_review_prompt_result_variants() {
        // Ensure all variants are accessible
        let next = ReviewPromptResult::Next;
        let skip = ReviewPromptResult::Skip;
        let complete = ReviewPromptResult::Complete;
        let someday = ReviewPromptResult::MoveToSomeday;
        let schedule = ReviewPromptResult::Schedule("2024-01-15".to_string());
        let note = ReviewPromptResult::AddNote("Test note".to_string());
        let back = ReviewPromptResult::Back;
        let pause = ReviewPromptResult::Pause;
        let quit = ReviewPromptResult::Quit;

        assert_eq!(next, ReviewPromptResult::Next);
        assert_eq!(skip, ReviewPromptResult::Skip);
        assert_eq!(complete, ReviewPromptResult::Complete);
        assert_eq!(someday, ReviewPromptResult::MoveToSomeday);
        assert!(matches!(schedule, ReviewPromptResult::Schedule(_)));
        assert!(matches!(note, ReviewPromptResult::AddNote(_)));
        assert_eq!(back, ReviewPromptResult::Back);
        assert_eq!(pause, ReviewPromptResult::Pause);
        assert_eq!(quit, ReviewPromptResult::Quit);
    }
}
