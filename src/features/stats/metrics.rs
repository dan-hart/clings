//! Metric calculations for statistics.
//!
//! Computes various productivity metrics from collected data.

use chrono::{Datelike, Duration, Local, NaiveDate, Timelike};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use super::collector::CollectedData;
use crate::things::{Status, Todo};

/// Completion-related metrics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompletionMetrics {
    /// Total completed todos
    pub total_completed: usize,
    /// Completed in the last 7 days
    pub completed_7d: usize,
    /// Completed in the last 30 days
    pub completed_30d: usize,
    /// Average completions per day (last 30 days)
    pub avg_per_day: f64,
    /// Completion rate (completed / (completed + canceled))
    pub completion_rate: f64,
    /// Best day count
    pub best_day_count: usize,
    /// Best day date
    pub best_day_date: Option<NaiveDate>,
}

impl CompletionMetrics {
    /// Calculate completion metrics from data.
    pub fn calculate(data: &CollectedData) -> Self {
        let today = Local::now().date_naive();
        let week_ago = today - Duration::days(7);
        let month_ago = today - Duration::days(30);

        let completed_todos: Vec<_> = data
            .completed_todos
            .iter()
            .filter(|t| t.status == Status::Completed)
            .collect();

        let canceled_todos: Vec<_> = data
            .completed_todos
            .iter()
            .filter(|t| t.status == Status::Canceled)
            .collect();

        let completed_7d = completed_todos
            .iter()
            .filter(|t| {
                t.modification_date
                    .map(|d| d.date_naive() >= week_ago)
                    .unwrap_or(false)
            })
            .count();

        let completed_30d = completed_todos
            .iter()
            .filter(|t| {
                t.modification_date
                    .map(|d| d.date_naive() >= month_ago)
                    .unwrap_or(false)
            })
            .count();

        let avg_per_day = completed_30d as f64 / 30.0;

        let total_resolved = completed_todos.len() + canceled_todos.len();
        let completion_rate = if total_resolved > 0 {
            completed_todos.len() as f64 / total_resolved as f64
        } else {
            0.0
        };

        // Find best day
        let mut by_date: HashMap<NaiveDate, usize> = HashMap::new();
        for todo in &completed_todos {
            if let Some(mod_date) = todo.modification_date {
                *by_date.entry(mod_date.date_naive()).or_default() += 1;
            }
        }

        let (best_day_date, best_day_count) = by_date
            .into_iter()
            .max_by_key(|(_, count)| *count)
            .map(|(date, count)| (Some(date), count))
            .unwrap_or((None, 0));

        Self {
            total_completed: completed_todos.len(),
            completed_7d,
            completed_30d,
            avg_per_day,
            completion_rate,
            best_day_count,
            best_day_date,
        }
    }
}

/// Streak information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreakInfo {
    /// Current streak (consecutive days with completions)
    pub current: usize,
    /// Longest streak ever
    pub longest: usize,
    /// Last completion date
    pub last_completion: Option<NaiveDate>,
    /// Days since last completion
    pub days_since_completion: usize,
}

impl StreakInfo {
    /// Calculate streak from completed todos.
    pub fn calculate(completed_todos: &[Todo]) -> Self {
        let today = Local::now().date_naive();

        // Get unique completion dates
        let mut dates: Vec<NaiveDate> = completed_todos
            .iter()
            .filter_map(|t| t.modification_date.map(|d| d.date_naive()))
            .collect();
        dates.sort();
        dates.dedup();

        if dates.is_empty() {
            return Self {
                current: 0,
                longest: 0,
                last_completion: None,
                days_since_completion: 0,
            };
        }

        let last_completion = dates.last().copied();
        let days_since = last_completion
            .map(|d| (today - d).num_days().max(0) as usize)
            .unwrap_or(0);

        // Calculate current streak (from today backwards)
        let mut current = 0;
        let mut check_date = today;

        while dates.contains(&check_date) {
            current += 1;
            check_date -= Duration::days(1);
        }

        // If no completion today but yesterday, still count from yesterday
        if current == 0 && dates.contains(&(today - Duration::days(1))) {
            check_date = today - Duration::days(1);
            while dates.contains(&check_date) {
                current += 1;
                check_date -= Duration::days(1);
            }
        }

        // Calculate longest streak
        let mut longest = 0;
        let mut streak = 0;
        let mut prev_date: Option<NaiveDate> = None;

        for date in &dates {
            if let Some(prev) = prev_date {
                if (*date - prev).num_days() == 1 {
                    streak += 1;
                } else {
                    streak = 1;
                }
            } else {
                streak = 1;
            }
            longest = longest.max(streak);
            prev_date = Some(*date);
        }

        Self {
            current,
            longest,
            last_completion,
            days_since_completion: days_since,
        }
    }
}

/// Time-based metrics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimeMetrics {
    /// Completions by day of week (Mon=0, Sun=6)
    pub by_day_of_week: [usize; 7],
    /// Completions by hour of day (0-23)
    pub by_hour: [usize; 24],
    /// Most productive day of week
    pub best_day: String,
    /// Most productive hour
    pub best_hour: usize,
    /// Morning completions (6-12)
    pub morning_completions: usize,
    /// Afternoon completions (12-18)
    pub afternoon_completions: usize,
    /// Evening completions (18-24)
    pub evening_completions: usize,
    /// Night completions (0-6)
    pub night_completions: usize,
}

impl TimeMetrics {
    /// Calculate time metrics from completed todos.
    pub fn calculate(completed_todos: &[Todo]) -> Self {
        let mut by_day_of_week = [0usize; 7];
        let mut by_hour = [0usize; 24];

        for todo in completed_todos {
            if let Some(mod_date) = todo.modification_date {
                let weekday = mod_date.date_naive().weekday().num_days_from_monday() as usize;
                by_day_of_week[weekday] += 1;

                let hour = mod_date.hour() as usize;
                by_hour[hour] += 1;
            }
        }

        let day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
        let best_day_idx = by_day_of_week
            .iter()
            .enumerate()
            .max_by_key(|(_, &count)| count)
            .map(|(i, _)| i)
            .unwrap_or(0);
        let best_day = day_names[best_day_idx].to_string();

        let best_hour = by_hour
            .iter()
            .enumerate()
            .max_by_key(|(_, &count)| count)
            .map(|(i, _)| i)
            .unwrap_or(0);

        let morning_completions = by_hour[6..12].iter().sum();
        let afternoon_completions = by_hour[12..18].iter().sum();
        let evening_completions = by_hour[18..24].iter().sum();
        let night_completions = by_hour[0..6].iter().sum();

        Self {
            by_day_of_week,
            by_hour,
            best_day,
            best_hour,
            morning_completions,
            afternoon_completions,
            evening_completions,
            night_completions,
        }
    }

    /// Format hour as readable time.
    pub fn format_hour(hour: usize) -> String {
        if hour == 0 {
            "12am".to_string()
        } else if hour < 12 {
            format!("{hour}am")
        } else if hour == 12 {
            "12pm".to_string()
        } else {
            format!("{}pm", hour - 12)
        }
    }
}

/// Project-level metrics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectMetrics {
    /// Project name
    pub name: String,
    /// Open todos count
    pub open_count: usize,
    /// Completed todos count
    pub completed_count: usize,
    /// Completion rate
    pub completion_rate: f64,
    /// Average age of open todos (days)
    pub avg_age_days: f64,
    /// Overdue count
    pub overdue_count: usize,
}

impl ProjectMetrics {
    /// Calculate metrics for all projects.
    pub fn calculate_all(data: &CollectedData) -> Vec<Self> {
        let today = Local::now().date_naive();
        let mut project_stats: HashMap<String, (usize, usize, Vec<f64>, usize)> = HashMap::new();

        // Count open todos per project
        for todo in &data.open_todos {
            let project = todo.project.clone().unwrap_or_else(|| "(No Project)".to_string());
            let entry = project_stats.entry(project).or_insert((0, 0, Vec::new(), 0));
            entry.0 += 1;

            // Calculate age
            if let Some(created) = todo.creation_date {
                let age = (today - created.date_naive()).num_days() as f64;
                entry.2.push(age);
            }

            // Check if overdue
            if let Some(due) = todo.due_date {
                if due < today {
                    entry.3 += 1;
                }
            }
        }

        // Count completed todos per project
        for todo in &data.completed_todos {
            if todo.status == Status::Completed {
                let project = todo.project.clone().unwrap_or_else(|| "(No Project)".to_string());
                let entry = project_stats.entry(project).or_insert((0, 0, Vec::new(), 0));
                entry.1 += 1;
            }
        }

        project_stats
            .into_iter()
            .map(|(name, (open, completed, ages, overdue))| {
                let total = open + completed;
                let completion_rate = if total > 0 {
                    completed as f64 / total as f64
                } else {
                    0.0
                };
                let avg_age_days = if ages.is_empty() {
                    0.0
                } else {
                    ages.iter().sum::<f64>() / ages.len() as f64
                };

                ProjectMetrics {
                    name,
                    open_count: open,
                    completed_count: completed,
                    completion_rate,
                    avg_age_days,
                    overdue_count: overdue,
                }
            })
            .collect()
    }
}

/// Tag-level metrics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagMetrics {
    /// Tag name
    pub name: String,
    /// Total todos with this tag
    pub total_count: usize,
    /// Open todos with this tag
    pub open_count: usize,
    /// Completed todos with this tag
    pub completed_count: usize,
}

impl TagMetrics {
    /// Calculate metrics for all tags.
    pub fn calculate_all(data: &CollectedData) -> Vec<Self> {
        let mut tag_stats: HashMap<String, (usize, usize)> = HashMap::new();

        // Count open todos per tag
        for todo in &data.open_todos {
            for tag in &todo.tags {
                let entry = tag_stats.entry(tag.clone()).or_insert((0, 0));
                entry.0 += 1;
            }
        }

        // Count completed todos per tag
        for todo in &data.completed_todos {
            if todo.status == Status::Completed {
                for tag in &todo.tags {
                    let entry = tag_stats.entry(tag.clone()).or_insert((0, 0));
                    entry.1 += 1;
                }
            }
        }

        tag_stats
            .into_iter()
            .map(|(name, (open, completed))| TagMetrics {
                name,
                total_count: open + completed,
                open_count: open,
                completed_count: completed,
            })
            .collect()
    }
}

/// Overall productivity metrics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProductivityMetrics {
    /// Completion metrics
    pub completion: CompletionMetrics,
    /// Streak info
    pub streak: StreakInfo,
    /// Time metrics
    pub time: TimeMetrics,
    /// Total open todos
    pub total_open: usize,
    /// Inbox count
    pub inbox_count: usize,
    /// Today count
    pub today_count: usize,
    /// Upcoming count
    pub upcoming_count: usize,
    /// Someday count
    pub someday_count: usize,
    /// Overdue count
    pub overdue_count: usize,
    /// Due this week count
    pub due_this_week: usize,
    /// Projects count
    pub projects_count: usize,
    /// Areas count
    pub areas_count: usize,
    /// Tags count
    pub tags_count: usize,
}

impl ProductivityMetrics {
    /// Calculate all productivity metrics.
    pub fn calculate(data: &CollectedData) -> Self {
        let today = Local::now().date_naive();
        let week_end = today + Duration::days(7);

        let completion = CompletionMetrics::calculate(data);
        let streak = StreakInfo::calculate(&data.completed_todos);
        let time = TimeMetrics::calculate(&data.completed_todos);

        let overdue_count = data
            .open_todos
            .iter()
            .filter(|t| t.due_date.map(|d| d < today).unwrap_or(false))
            .count();

        let due_this_week = data
            .open_todos
            .iter()
            .filter(|t| {
                t.due_date
                    .map(|d| d >= today && d <= week_end)
                    .unwrap_or(false)
            })
            .count();

        Self {
            completion,
            streak,
            time,
            total_open: data.open_todos.len(),
            inbox_count: data.inbox_todos.len(),
            today_count: data.today_todos.len(),
            upcoming_count: data.upcoming_todos.len(),
            someday_count: data.someday_todos.len(),
            overdue_count,
            due_this_week,
            projects_count: data.projects.len(),
            areas_count: data.areas.len(),
            tags_count: data.tags.len(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_streak_empty() {
        let streak = StreakInfo::calculate(&[]);
        assert_eq!(streak.current, 0);
        assert_eq!(streak.longest, 0);
        assert!(streak.last_completion.is_none());
    }

    #[test]
    fn test_time_metrics_hour_format() {
        assert_eq!(TimeMetrics::format_hour(0), "12am");
        assert_eq!(TimeMetrics::format_hour(9), "9am");
        assert_eq!(TimeMetrics::format_hour(12), "12pm");
        assert_eq!(TimeMetrics::format_hour(15), "3pm");
        assert_eq!(TimeMetrics::format_hour(23), "11pm");
    }
}
