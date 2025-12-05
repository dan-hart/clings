//! Timer functionality for focus sessions.
//!
//! Provides countdown timers and duration parsing/formatting.

use chrono::Duration;
use serde::{Deserialize, Serialize};

/// Timer state.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TimerState {
    /// Timer is running
    Running,
    /// Timer is paused
    Paused,
    /// Timer has completed
    Completed,
    /// Timer was stopped before completing
    Stopped,
}

/// A countdown timer.
#[derive(Debug, Clone)]
pub struct Timer {
    /// Total duration in seconds
    total_seconds: i64,
    /// Remaining seconds
    remaining_seconds: i64,
    /// Current state
    state: TimerState,
}

impl Timer {
    /// Create a new timer with the given duration.
    #[must_use]
    pub const fn new(duration: Duration) -> Self {
        let seconds = duration.num_seconds();
        Self {
            total_seconds: seconds,
            remaining_seconds: seconds,
            state: TimerState::Paused,
        }
    }

    /// Create a timer from minutes.
    #[must_use]
    pub const fn from_minutes(minutes: i64) -> Self {
        Self::new(Duration::minutes(minutes))
    }

    /// Start or resume the timer.
    pub fn start(&mut self) {
        if self.remaining_seconds > 0 {
            self.state = TimerState::Running;
        }
    }

    /// Pause the timer.
    pub fn pause(&mut self) {
        if self.state == TimerState::Running {
            self.state = TimerState::Paused;
        }
    }

    /// Stop the timer.
    pub fn stop(&mut self) {
        self.state = TimerState::Stopped;
    }

    /// Tick the timer by one second.
    ///
    /// Returns true if the timer just completed.
    pub fn tick(&mut self) -> bool {
        if self.state != TimerState::Running {
            return false;
        }

        if self.remaining_seconds > 0 {
            self.remaining_seconds -= 1;
        }

        if self.remaining_seconds == 0 {
            self.state = TimerState::Completed;
            true
        } else {
            false
        }
    }

    /// Get remaining time as Duration.
    #[must_use]
    pub const fn remaining(&self) -> Duration {
        Duration::seconds(self.remaining_seconds)
    }

    /// Get elapsed time as Duration.
    #[must_use]
    pub const fn elapsed(&self) -> Duration {
        Duration::seconds(self.total_seconds - self.remaining_seconds)
    }

    /// Get progress as a percentage (0.0 - 1.0).
    #[must_use]
    #[allow(clippy::cast_precision_loss)]
    pub fn progress(&self) -> f64 {
        if self.total_seconds == 0 {
            return 1.0;
        }
        1.0 - (self.remaining_seconds as f64 / self.total_seconds as f64)
    }

    /// Check if the timer is running.
    #[must_use]
    pub fn is_running(&self) -> bool {
        self.state == TimerState::Running
    }

    /// Check if the timer is completed.
    #[must_use]
    pub fn is_completed(&self) -> bool {
        self.state == TimerState::Completed
    }

    /// Get the current state.
    #[must_use]
    pub const fn state(&self) -> TimerState {
        self.state
    }

    /// Format remaining time as MM:SS.
    #[must_use]
    pub fn format_remaining(&self) -> String {
        format_duration_mmss(self.remaining())
    }

    /// Format elapsed time as MM:SS.
    #[must_use]
    pub fn format_elapsed(&self) -> String {
        format_duration_mmss(self.elapsed())
    }

    /// Reset the timer to its original duration.
    pub fn reset(&mut self) {
        self.remaining_seconds = self.total_seconds;
        self.state = TimerState::Paused;
    }

    /// Add time to the timer.
    pub fn add_time(&mut self, duration: Duration) {
        self.remaining_seconds += duration.num_seconds();
        self.total_seconds += duration.num_seconds();
    }
}

/// Format a duration as MM:SS.
#[must_use]
pub fn format_duration_mmss(d: Duration) -> String {
    let total_seconds = d.num_seconds().abs();
    let minutes = total_seconds / 60;
    let seconds = total_seconds % 60;
    format!("{minutes:02}:{seconds:02}")
}

/// Format a duration as a human-readable string.
#[must_use]
pub fn format_duration(d: Duration) -> String {
    let total_minutes = d.num_minutes();

    if total_minutes < 1 {
        let seconds = d.num_seconds();
        return format!("{} second{}", seconds, if seconds == 1 { "" } else { "s" });
    }

    let hours = total_minutes / 60;
    let minutes = total_minutes % 60;

    if hours > 0 {
        if minutes > 0 {
            format!(
                "{} hour{}, {} minute{}",
                hours,
                if hours == 1 { "" } else { "s" },
                minutes,
                if minutes == 1 { "" } else { "s" }
            )
        } else {
            format!("{} hour{}", hours, if hours == 1 { "" } else { "s" })
        }
    } else {
        format!("{} minute{}", minutes, if minutes == 1 { "" } else { "s" })
    }
}

/// Parse a duration string like "25m", "1h30m", "90s".
#[must_use]
pub fn parse_duration(s: &str) -> Option<Duration> {
    let s = s.trim().to_lowercase();

    // Try parsing as just a number (assume minutes)
    if let Ok(minutes) = s.parse::<i64>() {
        return Some(Duration::minutes(minutes));
    }

    let mut total_seconds: i64 = 0;
    let mut current_num = String::new();

    for c in s.chars() {
        if c.is_ascii_digit() {
            current_num.push(c);
        } else if !current_num.is_empty() {
            let num: i64 = current_num.parse().ok()?;
            current_num.clear();

            match c {
                'h' => total_seconds += num * 3600,
                'm' => total_seconds += num * 60,
                's' => total_seconds += num,
                _ => return None,
            }
        }
    }

    // Handle trailing number without unit (assume minutes)
    if !current_num.is_empty() {
        let num: i64 = current_num.parse().ok()?;
        total_seconds += num * 60;
    }

    if total_seconds > 0 {
        Some(Duration::seconds(total_seconds))
    } else {
        None
    }
}

/// Render a progress bar.
#[must_use]
#[allow(
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    clippy::cast_precision_loss
)]
pub fn render_progress_bar(progress: f64, width: usize) -> String {
    let filled = (progress * width as f64) as usize;
    let empty = width.saturating_sub(filled);

    format!("[{}{}]", "█".repeat(filled), "░".repeat(empty))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_timer_new() {
        let timer = Timer::from_minutes(25);
        assert_eq!(timer.remaining().num_minutes(), 25);
        assert_eq!(timer.state(), TimerState::Paused);
    }

    #[test]
    fn test_timer_tick() {
        let mut timer = Timer::from_minutes(1);
        timer.start();

        for _ in 0..59 {
            assert!(!timer.tick());
            assert!(timer.is_running());
        }

        assert!(timer.tick());
        assert!(timer.is_completed());
    }

    #[test]
    fn test_timer_pause_resume() {
        let mut timer = Timer::from_minutes(25);
        timer.start();
        assert!(timer.is_running());

        timer.pause();
        assert!(!timer.is_running());
        assert_eq!(timer.state(), TimerState::Paused);

        timer.start();
        assert!(timer.is_running());
    }

    #[test]
    fn test_timer_progress() {
        let mut timer = Timer::new(Duration::seconds(100));
        timer.start();

        assert_eq!(timer.progress(), 0.0);

        for _ in 0..50 {
            timer.tick();
        }

        assert!((timer.progress() - 0.5).abs() < 0.01);
    }

    #[test]
    fn test_parse_duration_minutes() {
        assert_eq!(parse_duration("25"), Some(Duration::minutes(25)));
        assert_eq!(parse_duration("25m"), Some(Duration::minutes(25)));
    }

    #[test]
    fn test_parse_duration_hours() {
        assert_eq!(parse_duration("1h"), Some(Duration::hours(1)));
        assert_eq!(parse_duration("2h30m"), Some(Duration::minutes(150)));
    }

    #[test]
    fn test_parse_duration_seconds() {
        assert_eq!(parse_duration("90s"), Some(Duration::seconds(90)));
        assert_eq!(parse_duration("1m30s"), Some(Duration::seconds(90)));
    }

    #[test]
    fn test_parse_duration_invalid() {
        assert!(parse_duration("").is_none());
        assert!(parse_duration("abc").is_none());
    }

    #[test]
    fn test_format_duration() {
        assert_eq!(format_duration(Duration::minutes(25)), "25 minutes");
        assert_eq!(format_duration(Duration::minutes(1)), "1 minute");
        assert_eq!(format_duration(Duration::hours(2)), "2 hours");
        assert_eq!(format_duration(Duration::minutes(90)), "1 hour, 30 minutes");
    }

    #[test]
    fn test_format_duration_mmss() {
        assert_eq!(format_duration_mmss(Duration::minutes(25)), "25:00");
        assert_eq!(format_duration_mmss(Duration::seconds(90)), "01:30");
        assert_eq!(format_duration_mmss(Duration::seconds(0)), "00:00");
    }

    #[test]
    fn test_render_progress_bar() {
        let bar = render_progress_bar(0.5, 10);
        assert!(bar.contains("█████"));
        assert!(bar.contains("░░░░░"));
    }
}
