//! Review workflow state machine.
//!
//! Implements the GTD weekly review process as a state machine that can be
//! paused and resumed.

use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};

use crate::config::Paths;
use crate::error::ClingsError;
use crate::things::{ListView, Project, ThingsClient, Todo};

/// Steps in the weekly review process.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ReviewStep {
    /// Process items in inbox.
    ProcessInbox,
    /// Review someday/maybe items.
    ReviewSomeday,
    /// Check active projects.
    CheckProjects,
    /// Review upcoming deadlines.
    ReviewDeadlines,
    /// Generate and display summary.
    GenerateSummary,
    /// Review is complete.
    Complete,
}

impl ReviewStep {
    /// Get the human-readable name for this step.
    #[must_use]
    pub const fn name(&self) -> &'static str {
        match self {
            Self::ProcessInbox => "Process Inbox",
            Self::ReviewSomeday => "Review Someday/Maybe",
            Self::CheckProjects => "Check Active Projects",
            Self::ReviewDeadlines => "Review Upcoming Deadlines",
            Self::GenerateSummary => "Generate Summary",
            Self::Complete => "Review Complete",
        }
    }

    /// Get the step number (1-indexed).
    #[must_use]
    pub const fn number(&self) -> u8 {
        match self {
            Self::ProcessInbox => 1,
            Self::ReviewSomeday => 2,
            Self::CheckProjects => 3,
            Self::ReviewDeadlines => 4,
            Self::GenerateSummary => 5,
            Self::Complete => 6,
        }
    }

    /// Get the total number of steps (excluding Complete).
    #[must_use]
    pub const fn total_steps() -> u8 {
        5
    }

    /// Get the next step in the sequence.
    #[must_use]
    pub const fn next(self) -> Self {
        match self {
            Self::ProcessInbox => Self::ReviewSomeday,
            Self::ReviewSomeday => Self::CheckProjects,
            Self::CheckProjects => Self::ReviewDeadlines,
            Self::ReviewDeadlines => Self::GenerateSummary,
            Self::GenerateSummary | Self::Complete => Self::Complete,
        }
    }

    /// Get the previous step.
    #[must_use]
    pub const fn previous(self) -> Self {
        match self {
            Self::ProcessInbox | Self::ReviewSomeday => Self::ProcessInbox,
            Self::CheckProjects => Self::ReviewSomeday,
            Self::ReviewDeadlines => Self::CheckProjects,
            Self::GenerateSummary => Self::ReviewDeadlines,
            Self::Complete => Self::GenerateSummary,
        }
    }
}

impl std::fmt::Display for ReviewStep {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.name())
    }
}

/// Current state of a review session.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReviewState {
    /// Current step in the review.
    pub current_step: ReviewStep,
    /// When the review was started.
    pub started_at: DateTime<Local>,
    /// When the review was last updated.
    pub updated_at: DateTime<Local>,
    /// Number of inbox items processed.
    pub inbox_processed: usize,
    /// Number of someday items reviewed.
    pub someday_reviewed: usize,
    /// Number of projects checked.
    pub projects_checked: usize,
    /// Number of upcoming deadlines reviewed.
    pub deadlines_reviewed: usize,
    /// Items that were completed during the review.
    pub items_completed: Vec<String>,
    /// Items that were moved to someday.
    pub items_moved_to_someday: Vec<String>,
    /// Items that were scheduled.
    pub items_scheduled: Vec<String>,
    /// Notes added during the review.
    pub notes: Vec<String>,
}

impl Default for ReviewState {
    fn default() -> Self {
        let now = Local::now();
        Self {
            current_step: ReviewStep::ProcessInbox,
            started_at: now,
            updated_at: now,
            inbox_processed: 0,
            someday_reviewed: 0,
            projects_checked: 0,
            deadlines_reviewed: 0,
            items_completed: Vec::new(),
            items_moved_to_someday: Vec::new(),
            items_scheduled: Vec::new(),
            notes: Vec::new(),
        }
    }
}

impl ReviewState {
    /// Advance to the next step.
    pub fn advance(&mut self) {
        self.current_step = self.current_step.next();
        self.updated_at = Local::now();
    }

    /// Go back to the previous step.
    pub fn go_back(&mut self) {
        self.current_step = self.current_step.previous();
        self.updated_at = Local::now();
    }

    /// Check if the review is complete.
    #[must_use]
    pub fn is_complete(&self) -> bool {
        self.current_step == ReviewStep::Complete
    }

    /// Get progress as a percentage (0-100).
    #[must_use]
    pub fn progress_percent(&self) -> u8 {
        let current = u16::from(self.current_step.number());
        let total = u16::from(ReviewStep::total_steps());
        if current > total {
            100
        } else {
            #[allow(clippy::cast_possible_truncation)]
            let percent = ((current - 1) * 100 / total) as u8;
            percent
        }
    }
}

/// Summary of a completed review.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReviewSummary {
    /// Duration of the review in seconds.
    pub duration_seconds: i64,
    /// Total items processed.
    pub total_processed: usize,
    /// Items completed.
    pub completed: usize,
    /// Items moved to someday.
    pub moved_to_someday: usize,
    /// Items scheduled.
    pub scheduled: usize,
    /// Projects reviewed.
    pub projects_reviewed: usize,
    /// Deadlines reviewed.
    pub deadlines_reviewed: usize,
    /// Notes from the review.
    pub notes: Vec<String>,
}

impl ReviewSummary {
    /// Create a summary from a completed review state.
    #[must_use]
    pub fn from_state(state: &ReviewState) -> Self {
        let duration = Local::now() - state.started_at;
        Self {
            duration_seconds: duration.num_seconds(),
            total_processed: state.inbox_processed
                + state.someday_reviewed
                + state.projects_checked
                + state.deadlines_reviewed,
            completed: state.items_completed.len(),
            moved_to_someday: state.items_moved_to_someday.len(),
            scheduled: state.items_scheduled.len(),
            projects_reviewed: state.projects_checked,
            deadlines_reviewed: state.deadlines_reviewed,
            notes: state.notes.clone(),
        }
    }

    /// Format duration as human-readable string.
    #[must_use]
    pub fn format_duration(&self) -> String {
        let minutes = self.duration_seconds / 60;
        let seconds = self.duration_seconds % 60;
        if minutes > 0 {
            format!("{minutes}m {seconds}s")
        } else {
            format!("{seconds}s")
        }
    }
}

/// A review session that manages the review workflow.
pub struct ReviewSession {
    /// The Things client.
    client: ThingsClient,
    /// Current state of the review.
    state: ReviewState,
    /// Path configuration.
    paths: Paths,
}

impl ReviewSession {
    /// Create a new review session.
    #[must_use]
    pub fn new(client: ThingsClient) -> Self {
        Self {
            client,
            state: ReviewState::default(),
            paths: Paths::default(),
        }
    }

    /// Resume an existing review session.
    ///
    /// # Errors
    ///
    /// Returns an error if the saved state cannot be loaded.
    pub fn resume(client: ThingsClient) -> Result<Self, ClingsError> {
        let paths = Paths::default();
        let state_path = paths.root.join("review_state.yaml");

        if !state_path.exists() {
            return Err(ClingsError::NotFound(
                "No review session to resume".to_string(),
            ));
        }

        let content = std::fs::read_to_string(&state_path).map_err(ClingsError::Io)?;
        let state: ReviewState =
            serde_yaml::from_str(&content).map_err(|e| ClingsError::Config(e.to_string()))?;

        Ok(Self {
            client,
            state,
            paths,
        })
    }

    /// Save the current review state.
    ///
    /// # Errors
    ///
    /// Returns an error if the state cannot be saved.
    pub fn save(&self) -> Result<(), ClingsError> {
        let state_path = self.paths.root.join("review_state.yaml");
        let content =
            serde_yaml::to_string(&self.state).map_err(|e| ClingsError::Config(e.to_string()))?;
        std::fs::write(&state_path, content).map_err(ClingsError::Io)?;
        Ok(())
    }

    /// Clear any saved review state.
    ///
    /// # Errors
    ///
    /// Returns an error if the state file cannot be deleted.
    pub fn clear_saved_state(&self) -> Result<(), ClingsError> {
        let state_path = self.paths.root.join("review_state.yaml");
        if state_path.exists() {
            std::fs::remove_file(&state_path).map_err(ClingsError::Io)?;
        }
        Ok(())
    }

    /// Get the current state.
    #[must_use]
    pub const fn state(&self) -> &ReviewState {
        &self.state
    }

    /// Get mutable access to the state.
    #[must_use]
    pub fn state_mut(&mut self) -> &mut ReviewState {
        &mut self.state
    }

    /// Get the current step.
    #[must_use]
    pub const fn current_step(&self) -> ReviewStep {
        self.state.current_step
    }

    /// Advance to the next step.
    pub fn advance(&mut self) {
        self.state.advance();
    }

    /// Go back to the previous step.
    pub fn go_back(&mut self) {
        self.state.go_back();
    }

    /// Check if the review is complete.
    #[must_use]
    pub fn is_complete(&self) -> bool {
        self.state.is_complete()
    }

    /// Get inbox items.
    ///
    /// # Errors
    ///
    /// Returns an error if the Things 3 API call fails.
    pub fn get_inbox(&self) -> Result<Vec<Todo>, ClingsError> {
        self.client.get_list(ListView::Inbox)
    }

    /// Get someday items.
    ///
    /// # Errors
    ///
    /// Returns an error if the Things 3 API call fails.
    pub fn get_someday(&self) -> Result<Vec<Todo>, ClingsError> {
        self.client.get_list(ListView::Someday)
    }

    /// Get active projects.
    ///
    /// # Errors
    ///
    /// Returns an error if the Things 3 API call fails.
    pub fn get_projects(&self) -> Result<Vec<Project>, ClingsError> {
        self.client.get_projects()
    }

    /// Get upcoming items with deadlines.
    ///
    /// # Errors
    ///
    /// Returns an error if the Things 3 API call fails.
    pub fn get_upcoming_deadlines(&self, days: i64) -> Result<Vec<Todo>, ClingsError> {
        let todos = self.client.get_all_todos()?;
        let today = Local::now().date_naive();
        let deadline = today + chrono::Duration::days(days);

        Ok(todos
            .into_iter()
            .filter(|t| t.due_date.is_some_and(|d| d >= today && d <= deadline))
            .collect())
    }

    /// Complete a todo.
    ///
    /// # Errors
    ///
    /// Returns an error if the Things 3 API call fails.
    pub fn complete_todo(&mut self, id: &str) -> Result<(), ClingsError> {
        self.client.complete_todo(id)?;
        self.state.items_completed.push(id.to_string());
        Ok(())
    }

    /// Get the summary for a completed review.
    #[must_use]
    pub fn get_summary(&self) -> ReviewSummary {
        ReviewSummary::from_state(&self.state)
    }

    /// Get the Things client.
    #[must_use]
    pub const fn client(&self) -> &ThingsClient {
        &self.client
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_review_step_sequence() {
        let step = ReviewStep::ProcessInbox;
        assert_eq!(step.next(), ReviewStep::ReviewSomeday);
        assert_eq!(step.next().next(), ReviewStep::CheckProjects);
        assert_eq!(step.next().next().next(), ReviewStep::ReviewDeadlines);
        assert_eq!(
            step.next().next().next().next(),
            ReviewStep::GenerateSummary
        );
        assert_eq!(
            step.next().next().next().next().next(),
            ReviewStep::Complete
        );
    }

    #[test]
    fn test_review_step_previous() {
        let step = ReviewStep::GenerateSummary;
        assert_eq!(step.previous(), ReviewStep::ReviewDeadlines);
        assert_eq!(step.previous().previous(), ReviewStep::CheckProjects);
    }

    #[test]
    fn test_review_step_number() {
        assert_eq!(ReviewStep::ProcessInbox.number(), 1);
        assert_eq!(ReviewStep::ReviewSomeday.number(), 2);
        assert_eq!(ReviewStep::CheckProjects.number(), 3);
        assert_eq!(ReviewStep::ReviewDeadlines.number(), 4);
        assert_eq!(ReviewStep::GenerateSummary.number(), 5);
        assert_eq!(ReviewStep::Complete.number(), 6);
    }

    #[test]
    fn test_review_state_default() {
        let state = ReviewState::default();
        assert_eq!(state.current_step, ReviewStep::ProcessInbox);
        assert_eq!(state.inbox_processed, 0);
        assert!(!state.is_complete());
    }

    #[test]
    fn test_review_state_advance() {
        let mut state = ReviewState::default();
        state.advance();
        assert_eq!(state.current_step, ReviewStep::ReviewSomeday);
        state.advance();
        assert_eq!(state.current_step, ReviewStep::CheckProjects);
    }

    #[test]
    fn test_review_state_progress() {
        let mut state = ReviewState::default();
        assert_eq!(state.progress_percent(), 0);

        state.advance(); // Step 2
        assert_eq!(state.progress_percent(), 20);

        state.advance(); // Step 3
        assert_eq!(state.progress_percent(), 40);

        state.advance(); // Step 4
        assert_eq!(state.progress_percent(), 60);

        state.advance(); // Step 5
        assert_eq!(state.progress_percent(), 80);

        state.advance(); // Complete
        assert_eq!(state.progress_percent(), 100);
    }

    #[test]
    fn test_review_summary_duration() {
        let summary = ReviewSummary {
            duration_seconds: 125,
            total_processed: 10,
            completed: 3,
            moved_to_someday: 2,
            scheduled: 5,
            projects_reviewed: 4,
            deadlines_reviewed: 6,
            notes: vec![],
        };

        assert_eq!(summary.format_duration(), "2m 5s");
    }

    #[test]
    fn test_review_summary_short_duration() {
        let summary = ReviewSummary {
            duration_seconds: 45,
            total_processed: 0,
            completed: 0,
            moved_to_someday: 0,
            scheduled: 0,
            projects_reviewed: 0,
            deadlines_reviewed: 0,
            notes: vec![],
        };

        assert_eq!(summary.format_duration(), "45s");
    }
}
