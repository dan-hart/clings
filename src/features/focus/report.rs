//! Focus session reports.
//!
//! Generates productivity reports from session history.

use chrono::{DateTime, Datelike, Duration, Local, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use super::session::{FocusSession, SessionState};
use super::storage::FocusStorage;
use super::timer::format_duration;
use crate::error::ClingsError;

/// Report time period.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReportPeriod {
    /// Today only
    Today,
    /// Last 7 days
    Week,
    /// Last 30 days
    Month,
    /// All time
    AllTime,
    /// Custom date range
    Custom(NaiveDate, NaiveDate),
}

impl ReportPeriod {
    /// Get the start and end dates for this period.
    pub fn date_range(&self) -> (DateTime<Utc>, DateTime<Utc>) {
        let now = Utc::now();
        let today = now.date_naive();

        match self {
            Self::Today => {
                let start = today.and_hms_opt(0, 0, 0).unwrap();
                let end = today.and_hms_opt(23, 59, 59).unwrap();
                (
                    DateTime::from_naive_utc_and_offset(start, Utc),
                    DateTime::from_naive_utc_and_offset(end, Utc),
                )
            }
            Self::Week => {
                let start = (today - Duration::days(6)).and_hms_opt(0, 0, 0).unwrap();
                let end = today.and_hms_opt(23, 59, 59).unwrap();
                (
                    DateTime::from_naive_utc_and_offset(start, Utc),
                    DateTime::from_naive_utc_and_offset(end, Utc),
                )
            }
            Self::Month => {
                let start = (today - Duration::days(29)).and_hms_opt(0, 0, 0).unwrap();
                let end = today.and_hms_opt(23, 59, 59).unwrap();
                (
                    DateTime::from_naive_utc_and_offset(start, Utc),
                    DateTime::from_naive_utc_and_offset(end, Utc),
                )
            }
            Self::AllTime => {
                let start = NaiveDate::from_ymd_opt(2000, 1, 1)
                    .unwrap()
                    .and_hms_opt(0, 0, 0)
                    .unwrap();
                let end = today.and_hms_opt(23, 59, 59).unwrap();
                (
                    DateTime::from_naive_utc_and_offset(start, Utc),
                    DateTime::from_naive_utc_and_offset(end, Utc),
                )
            }
            Self::Custom(start_date, end_date) => {
                let start = start_date.and_hms_opt(0, 0, 0).unwrap();
                let end = end_date.and_hms_opt(23, 59, 59).unwrap();
                (
                    DateTime::from_naive_utc_and_offset(start, Utc),
                    DateTime::from_naive_utc_and_offset(end, Utc),
                )
            }
        }
    }

    /// Parse period from string.
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "today" | "t" | "d" => Self::Today,
            "week" | "w" | "7d" => Self::Week,
            "month" | "m" | "30d" => Self::Month,
            "all" | "alltime" | "all-time" => Self::AllTime,
            _ => Self::Week,
        }
    }

    /// Get display name.
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Today => "Today",
            Self::Week => "This Week",
            Self::Month => "This Month",
            Self::AllTime => "All Time",
            Self::Custom(_, _) => "Custom Range",
        }
    }
}

/// Focus report data.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FocusReport {
    /// Report period name
    pub period: String,
    /// Total focus time in minutes
    pub total_minutes: i64,
    /// Number of completed sessions
    pub completed_sessions: i64,
    /// Number of abandoned sessions
    pub abandoned_sessions: i64,
    /// Average session length in minutes
    pub avg_session_minutes: f64,
    /// Longest session in minutes
    pub longest_session_minutes: i64,
    /// Focus time by day of week
    pub by_day_of_week: [i64; 7],
    /// Focus time by task
    pub by_task: Vec<TaskFocusTime>,
    /// Daily breakdown
    pub daily: Vec<DailyFocusTime>,
    /// Current streak (consecutive days with focus time)
    pub streak_days: i64,
}

/// Focus time per task.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskFocusTime {
    /// Task ID
    pub task_id: Option<String>,
    /// Task name
    pub task_name: String,
    /// Total focus minutes
    pub minutes: i64,
    /// Session count
    pub sessions: i64,
}

/// Focus time per day.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DailyFocusTime {
    /// Date
    pub date: String,
    /// Total focus minutes
    pub minutes: i64,
    /// Session count
    pub sessions: i64,
}

impl FocusReport {
    /// Generate a report for the given period.
    pub fn generate(storage: &FocusStorage, period: ReportPeriod) -> Result<Self, ClingsError> {
        let (start, end) = period.date_range();
        let sessions = storage.get_range(start, end)?;

        // Filter to only work sessions (not breaks)
        let work_sessions: Vec<_> = sessions
            .iter()
            .filter(|s| !s.session_type.is_break())
            .collect();

        let completed: Vec<_> = work_sessions
            .iter()
            .filter(|s| s.state == SessionState::Completed)
            .collect();

        let abandoned: Vec<_> = work_sessions
            .iter()
            .filter(|s| s.state == SessionState::Abandoned)
            .collect();

        let total_minutes: i64 = completed.iter().map(|s| s.actual_duration).sum();
        let completed_count = completed.len() as i64;
        let abandoned_count = abandoned.len() as i64;

        let avg_session_minutes = if completed_count > 0 {
            total_minutes as f64 / completed_count as f64
        } else {
            0.0
        };

        let longest_session_minutes = completed
            .iter()
            .map(|s| s.actual_duration)
            .max()
            .unwrap_or(0);

        // By day of week
        let mut by_day_of_week = [0i64; 7];
        for session in &completed {
            let weekday = session.started_at.weekday().num_days_from_monday() as usize;
            by_day_of_week[weekday] += session.actual_duration;
        }

        // By task
        let mut task_map: HashMap<Option<String>, (String, i64, i64)> = HashMap::new();
        for session in &completed {
            let entry = task_map
                .entry(session.task_id.clone())
                .or_insert_with(|| {
                    (
                        session
                            .task_name
                            .clone()
                            .unwrap_or_else(|| "(No Task)".to_string()),
                        0,
                        0,
                    )
                });
            entry.1 += session.actual_duration;
            entry.2 += 1;
        }

        let mut by_task: Vec<TaskFocusTime> = task_map
            .into_iter()
            .map(|(task_id, (task_name, minutes, sessions))| TaskFocusTime {
                task_id,
                task_name,
                minutes,
                sessions,
            })
            .collect();
        by_task.sort_by(|a, b| b.minutes.cmp(&a.minutes));

        // Daily breakdown
        let mut daily_map: HashMap<NaiveDate, (i64, i64)> = HashMap::new();
        for session in &completed {
            let date = session.started_at.date_naive();
            let entry = daily_map.entry(date).or_insert((0, 0));
            entry.0 += session.actual_duration;
            entry.1 += 1;
        }

        let mut daily: Vec<DailyFocusTime> = daily_map
            .into_iter()
            .map(|(date, (minutes, sessions))| DailyFocusTime {
                date: date.to_string(),
                minutes,
                sessions,
            })
            .collect();
        daily.sort_by(|a, b| b.date.cmp(&a.date));

        // Calculate streak
        let streak_days = calculate_streak(&completed);

        Ok(Self {
            period: period.display_name().to_string(),
            total_minutes,
            completed_sessions: completed_count,
            abandoned_sessions: abandoned_count,
            avg_session_minutes,
            longest_session_minutes,
            by_day_of_week,
            by_task,
            daily,
            streak_days,
        })
    }

    /// Format the report for display.
    pub fn format(&self) -> String {
        let mut lines = Vec::new();

        lines.push(format!("📊 Focus Report: {}", self.period));
        lines.push("═".repeat(50));
        lines.push(String::new());

        // Summary
        lines.push("Summary".to_string());
        lines.push("─".repeat(40));
        lines.push(format!(
            "  Total focus time:    {}",
            format_duration(Duration::minutes(self.total_minutes))
        ));
        lines.push(format!(
            "  Completed sessions:  {}",
            self.completed_sessions
        ));
        lines.push(format!(
            "  Abandoned sessions:  {}",
            self.abandoned_sessions
        ));
        lines.push(format!(
            "  Average session:     {:.0} minutes",
            self.avg_session_minutes
        ));
        lines.push(format!(
            "  Longest session:     {} minutes",
            self.longest_session_minutes
        ));
        lines.push(format!("  Current streak:      {} days", self.streak_days));
        lines.push(String::new());

        // By day of week
        if self.total_minutes > 0 {
            lines.push("By Day of Week".to_string());
            lines.push("─".repeat(40));
            let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
            let max_day = self.by_day_of_week.iter().max().copied().unwrap_or(1).max(1);

            for (i, day) in days.iter().enumerate() {
                let minutes = self.by_day_of_week[i];
                let bar_len = (minutes as f64 / max_day as f64 * 20.0) as usize;
                let bar = "█".repeat(bar_len);
                lines.push(format!("  {} {:>4}m {}", day, minutes, bar));
            }
            lines.push(String::new());
        }

        // Top tasks
        if !self.by_task.is_empty() {
            lines.push("Top Tasks".to_string());
            lines.push("─".repeat(40));

            for task in self.by_task.iter().take(5) {
                let name = if task.task_name.len() > 25 {
                    format!("{}...", &task.task_name[..22])
                } else {
                    task.task_name.clone()
                };
                lines.push(format!(
                    "  {:<25} {:>4}m ({} sessions)",
                    name, task.minutes, task.sessions
                ));
            }
            lines.push(String::new());
        }

        // Recent days
        if !self.daily.is_empty() {
            lines.push("Recent Days".to_string());
            lines.push("─".repeat(40));

            for day in self.daily.iter().take(7) {
                lines.push(format!(
                    "  {} {:>4}m ({} sessions)",
                    day.date, day.minutes, day.sessions
                ));
            }
        }

        lines.join("\n")
    }

    /// Get total hours.
    pub fn total_hours(&self) -> f64 {
        self.total_minutes as f64 / 60.0
    }
}

/// Calculate the current focus streak.
fn calculate_streak(sessions: &[&&FocusSession]) -> i64 {
    if sessions.is_empty() {
        return 0;
    }

    let today = Local::now().date_naive();

    // Get unique dates with focus sessions
    let mut dates: Vec<NaiveDate> = sessions
        .iter()
        .map(|s| s.started_at.date_naive())
        .collect();
    dates.sort();
    dates.dedup();

    if dates.is_empty() {
        return 0;
    }

    // Count consecutive days from today backwards
    let mut streak = 0;
    let mut check_date = today;

    // If no session today, start from yesterday
    if !dates.contains(&today) {
        check_date = today - Duration::days(1);
        if !dates.contains(&check_date) {
            return 0;
        }
    }

    while dates.contains(&check_date) {
        streak += 1;
        check_date -= Duration::days(1);
    }

    streak
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_report_period_today() {
        let period = ReportPeriod::Today;
        let (start, end) = period.date_range();

        assert!(start < end);
        assert_eq!(start.date_naive(), Utc::now().date_naive());
    }

    #[test]
    fn test_report_period_from_str() {
        assert_eq!(ReportPeriod::from_str("today"), ReportPeriod::Today);
        assert_eq!(ReportPeriod::from_str("week"), ReportPeriod::Week);
        assert_eq!(ReportPeriod::from_str("month"), ReportPeriod::Month);
        assert_eq!(ReportPeriod::from_str("all"), ReportPeriod::AllTime);
    }

    #[test]
    fn test_focus_report_total_hours() {
        let report = FocusReport {
            period: "Test".to_string(),
            total_minutes: 120,
            completed_sessions: 4,
            abandoned_sessions: 1,
            avg_session_minutes: 30.0,
            longest_session_minutes: 45,
            by_day_of_week: [0; 7],
            by_task: vec![],
            daily: vec![],
            streak_days: 3,
        };

        assert!((report.total_hours() - 2.0).abs() < 0.01);
    }
}
