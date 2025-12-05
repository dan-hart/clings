//! Focus session management.
//!
//! Handles starting, stopping, pausing, and resuming focus sessions.

use chrono::{DateTime, Duration, Local, Utc};
use serde::{Deserialize, Serialize};

/// Type of focus session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SessionType {
    /// Standard Pomodoro (25 minutes)
    Pomodoro,
    /// Short break (5 minutes)
    ShortBreak,
    /// Long break (15 minutes)
    LongBreak,
    /// Custom duration focus
    Focus,
    /// Open-ended session (no timer)
    OpenEnded,
}

impl SessionType {
    /// Get the default duration for this session type.
    #[must_use]
    pub const fn default_duration(&self) -> Duration {
        match self {
            Self::Pomodoro => Duration::minutes(25),
            Self::ShortBreak => Duration::minutes(5),
            Self::LongBreak => Duration::minutes(15),
            Self::Focus => Duration::minutes(50),
            Self::OpenEnded => Duration::zero(),
        }
    }

    /// Parse session type from string.
    #[must_use]
    pub fn parse(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "pomodoro" | "pomo" | "p" => Self::Pomodoro,
            "short" | "short-break" | "sb" => Self::ShortBreak,
            "long" | "long-break" | "lb" => Self::LongBreak,
            "focus" | "f" => Self::Focus,
            "open" | "open-ended" | "o" | _ => Self::OpenEnded,
        }
    }

    /// Get display name.
    #[must_use]
    pub const fn display_name(&self) -> &'static str {
        match self {
            Self::Pomodoro => "Pomodoro",
            Self::ShortBreak => "Short Break",
            Self::LongBreak => "Long Break",
            Self::Focus => "Focus",
            Self::OpenEnded => "Open-Ended",
        }
    }

    /// Check if this is a break type.
    #[must_use]
    pub const fn is_break(&self) -> bool {
        matches!(self, Self::ShortBreak | Self::LongBreak)
    }
}

impl std::fmt::Display for SessionType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.display_name())
    }
}

/// State of a focus session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SessionState {
    /// Session is actively running
    Running,
    /// Session is paused
    Paused,
    /// Session completed successfully
    Completed,
    /// Session was abandoned/canceled
    Abandoned,
}

impl std::fmt::Display for SessionState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Running => write!(f, "Running"),
            Self::Paused => write!(f, "Paused"),
            Self::Completed => write!(f, "Completed"),
            Self::Abandoned => write!(f, "Abandoned"),
        }
    }
}

/// A focus session.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FocusSession {
    /// Database ID (None if not persisted)
    pub id: Option<i64>,
    /// Associated task ID from Things
    pub task_id: Option<String>,
    /// Task name (for display)
    pub task_name: Option<String>,
    /// Session type
    pub session_type: SessionType,
    /// When the session started
    pub started_at: DateTime<Utc>,
    /// When the session ended (None if still running)
    pub ended_at: Option<DateTime<Utc>>,
    /// Planned duration in minutes
    pub planned_duration: i64,
    /// Actual duration worked in minutes (accounts for pauses)
    pub actual_duration: i64,
    /// Current state
    pub state: SessionState,
    /// When the session was paused (for calculating pause time)
    pub paused_at: Option<DateTime<Utc>>,
    /// Total time spent paused in minutes
    pub pause_duration: i64,
    /// Optional notes
    pub notes: Option<String>,
}

impl FocusSession {
    /// Create a new focus session.
    #[must_use]
    pub fn new(
        task_id: Option<String>,
        task_name: Option<String>,
        session_type: SessionType,
        duration_minutes: Option<i64>,
    ) -> Self {
        let planned_duration =
            duration_minutes.unwrap_or_else(|| session_type.default_duration().num_minutes());

        Self {
            id: None,
            task_id,
            task_name,
            session_type,
            started_at: Utc::now(),
            ended_at: None,
            planned_duration,
            actual_duration: 0,
            state: SessionState::Running,
            paused_at: None,
            pause_duration: 0,
            notes: None,
        }
    }

    /// Start a Pomodoro session.
    #[must_use]
    pub fn pomodoro(task_id: Option<String>, task_name: Option<String>) -> Self {
        Self::new(task_id, task_name, SessionType::Pomodoro, None)
    }

    /// Start a short break.
    #[must_use]
    pub fn short_break() -> Self {
        Self::new(None, None, SessionType::ShortBreak, None)
    }

    /// Start a long break.
    #[must_use]
    pub fn long_break() -> Self {
        Self::new(None, None, SessionType::LongBreak, None)
    }

    /// Start an open-ended focus session.
    #[must_use]
    pub fn open_ended(task_id: Option<String>, task_name: Option<String>) -> Self {
        Self::new(task_id, task_name, SessionType::OpenEnded, Some(0))
    }

    /// Pause the session.
    pub fn pause(&mut self) {
        if self.state == SessionState::Running {
            self.state = SessionState::Paused;
            self.paused_at = Some(Utc::now());
        }
    }

    /// Resume a paused session.
    pub fn resume(&mut self) {
        if self.state == SessionState::Paused {
            if let Some(paused_at) = self.paused_at {
                let pause_time = Utc::now().signed_duration_since(paused_at).num_minutes();
                self.pause_duration += pause_time;
            }
            self.state = SessionState::Running;
            self.paused_at = None;
        }
    }

    /// Complete the session.
    pub fn complete(&mut self) {
        self.state = SessionState::Completed;
        self.ended_at = Some(Utc::now());
        self.calculate_actual_duration();
    }

    /// Abandon/cancel the session.
    pub fn abandon(&mut self) {
        self.state = SessionState::Abandoned;
        self.ended_at = Some(Utc::now());
        self.calculate_actual_duration();
    }

    /// Calculate the actual duration worked.
    fn calculate_actual_duration(&mut self) {
        let end = self.ended_at.unwrap_or_else(Utc::now);
        let total = end.signed_duration_since(self.started_at).num_minutes();
        self.actual_duration = (total - self.pause_duration).max(0);
    }

    /// Get elapsed time since session started (excluding pauses).
    #[must_use]
    pub fn elapsed(&self) -> Duration {
        let now = Utc::now();
        let total = now.signed_duration_since(self.started_at);

        // Account for current pause
        let current_pause = self.paused_at.map_or_else(Duration::zero, |paused_at| {
            now.signed_duration_since(paused_at)
        });

        total - Duration::minutes(self.pause_duration) - current_pause
    }

    /// Get remaining time (for timed sessions).
    #[must_use]
    pub fn remaining(&self) -> Duration {
        if self.planned_duration == 0 {
            return Duration::zero();
        }

        let elapsed = self.elapsed();
        let planned = Duration::minutes(self.planned_duration);

        if elapsed >= planned {
            Duration::zero()
        } else {
            planned - elapsed
        }
    }

    /// Check if the session timer has completed.
    #[must_use]
    pub fn is_timer_complete(&self) -> bool {
        if self.planned_duration == 0 {
            false // Open-ended sessions don't complete automatically
        } else {
            self.remaining() == Duration::zero()
        }
    }

    /// Check if the session is active (running or paused).
    #[must_use]
    pub const fn is_active(&self) -> bool {
        matches!(self.state, SessionState::Running | SessionState::Paused)
    }

    /// Get progress as a percentage (0.0 - 1.0).
    #[must_use]
    pub fn progress(&self) -> f64 {
        if self.planned_duration == 0 {
            return 0.0;
        }

        #[allow(clippy::cast_precision_loss)]
        let elapsed = self.elapsed().num_seconds() as f64;
        #[allow(clippy::cast_precision_loss)]
        let planned = (self.planned_duration * 60) as f64;

        (elapsed / planned).min(1.0)
    }

    /// Format the session for display.
    #[must_use]
    pub fn format_status(&self) -> String {
        let elapsed = self.elapsed();
        let elapsed_str = format_duration_short(elapsed);

        let task_info = self
            .task_name
            .as_ref()
            .map_or_else(String::new, |n| format!(" on \"{n}\""));

        if self.session_type == SessionType::OpenEnded {
            let session_type = self.session_type;
            let state = self.state;
            format!("{session_type} session{task_info} - {elapsed_str} elapsed ({state})")
        } else {
            let remaining = self.remaining();
            let remaining_str = format_duration_short(remaining);
            #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
            let progress = (self.progress() * 100.0) as u8;
            let session_type = self.session_type;
            let state = self.state;

            format!("{session_type} session{task_info} - {remaining_str} remaining ({elapsed_str}/{progress}%) [{state}]")
        }
    }

    /// Get start time in local timezone.
    #[must_use]
    pub fn started_at_local(&self) -> DateTime<Local> {
        self.started_at.with_timezone(&Local)
    }

    /// Get end time in local timezone.
    #[must_use]
    pub fn ended_at_local(&self) -> Option<DateTime<Local>> {
        self.ended_at.map(|t| t.with_timezone(&Local))
    }
}

/// Format a duration as a short string (e.g., "25m", "1h 30m").
fn format_duration_short(d: Duration) -> String {
    let total_minutes = d.num_minutes();
    let hours = total_minutes / 60;
    let minutes = total_minutes % 60;

    if hours > 0 {
        format!("{hours}h {minutes}m")
    } else {
        format!("{minutes}m")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_session_type_default_duration() {
        assert_eq!(SessionType::Pomodoro.default_duration().num_minutes(), 25);
        assert_eq!(SessionType::ShortBreak.default_duration().num_minutes(), 5);
        assert_eq!(SessionType::LongBreak.default_duration().num_minutes(), 15);
        assert_eq!(SessionType::Focus.default_duration().num_minutes(), 50);
        assert_eq!(SessionType::OpenEnded.default_duration().num_minutes(), 0);
    }

    #[test]
    fn test_session_type_parse() {
        assert_eq!(SessionType::parse("pomodoro"), SessionType::Pomodoro);
        assert_eq!(SessionType::parse("pomo"), SessionType::Pomodoro);
        assert_eq!(SessionType::parse("short"), SessionType::ShortBreak);
        assert_eq!(SessionType::parse("long"), SessionType::LongBreak);
        assert_eq!(SessionType::parse("open"), SessionType::OpenEnded);
    }

    #[test]
    fn test_session_new() {
        let session = FocusSession::new(
            Some("task123".to_string()),
            Some("Test Task".to_string()),
            SessionType::Pomodoro,
            None,
        );

        assert_eq!(session.task_id, Some("task123".to_string()));
        assert_eq!(session.task_name, Some("Test Task".to_string()));
        assert_eq!(session.session_type, SessionType::Pomodoro);
        assert_eq!(session.planned_duration, 25);
        assert_eq!(session.state, SessionState::Running);
    }

    #[test]
    fn test_session_pause_resume() {
        let mut session = FocusSession::pomodoro(None, None);

        assert_eq!(session.state, SessionState::Running);

        session.pause();
        assert_eq!(session.state, SessionState::Paused);
        assert!(session.paused_at.is_some());

        session.resume();
        assert_eq!(session.state, SessionState::Running);
        assert!(session.paused_at.is_none());
    }

    #[test]
    fn test_session_complete() {
        let mut session = FocusSession::pomodoro(None, None);
        session.complete();

        assert_eq!(session.state, SessionState::Completed);
        assert!(session.ended_at.is_some());
    }

    #[test]
    fn test_session_is_active() {
        let mut session = FocusSession::pomodoro(None, None);
        assert!(session.is_active());

        session.pause();
        assert!(session.is_active());

        session.complete();
        assert!(!session.is_active());
    }

    #[test]
    fn test_session_is_break() {
        assert!(!SessionType::Pomodoro.is_break());
        assert!(SessionType::ShortBreak.is_break());
        assert!(SessionType::LongBreak.is_break());
    }

    #[test]
    fn test_format_duration_short() {
        assert_eq!(format_duration_short(Duration::minutes(25)), "25m");
        assert_eq!(format_duration_short(Duration::minutes(90)), "1h 30m");
        assert_eq!(format_duration_short(Duration::minutes(0)), "0m");
    }
}
