//! Insights generation from statistics.
//!
//! Provides actionable insights and recommendations based on productivity data.

use serde::{Deserialize, Serialize};

use super::collector::CollectedData;
use super::metrics::{ProductivityMetrics, ProjectMetrics};

/// Insight importance level.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum InsightLevel {
    /// High priority - needs attention
    High,
    /// Medium priority - worth noting
    Medium,
    /// Low priority - informational
    Low,
}

impl InsightLevel {
    /// Get icon for this level.
    pub fn icon(&self) -> &'static str {
        match self {
            Self::High => "!",
            Self::Medium => "*",
            Self::Low => "-",
        }
    }

    /// Get color name for this level.
    pub fn color(&self) -> &'static str {
        match self {
            Self::High => "red",
            Self::Medium => "yellow",
            Self::Low => "blue",
        }
    }
}

/// An actionable insight.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Insight {
    /// The insight message
    pub message: String,
    /// Importance level
    pub level: InsightLevel,
    /// Category of insight
    pub category: String,
    /// Optional suggestion
    pub suggestion: Option<String>,
}

impl Insight {
    fn new(message: &str, level: InsightLevel, category: &str) -> Self {
        Self {
            message: message.to_string(),
            level,
            category: category.to_string(),
            suggestion: None,
        }
    }

    fn with_suggestion(mut self, suggestion: &str) -> Self {
        self.suggestion = Some(suggestion.to_string());
        self
    }
}

/// Generate insights from collected data.
pub fn generate_insights(data: &CollectedData, metrics: &ProductivityMetrics) -> Vec<Insight> {
    let mut insights = Vec::new();

    // Inbox management insights
    insights.extend(inbox_insights(data, metrics));

    // Overdue insights
    insights.extend(overdue_insights(data, metrics));

    // Streak insights
    insights.extend(streak_insights(metrics));

    // Productivity pattern insights
    insights.extend(pattern_insights(metrics));

    // Project insights
    insights.extend(project_insights(data));

    // Workload insights
    insights.extend(workload_insights(metrics));

    // Sort by priority
    insights.sort_by(|a, b| {
        let level_ord = |l: &InsightLevel| match l {
            InsightLevel::High => 0,
            InsightLevel::Medium => 1,
            InsightLevel::Low => 2,
        };
        level_ord(&a.level).cmp(&level_ord(&b.level))
    });

    insights
}

fn inbox_insights(data: &CollectedData, metrics: &ProductivityMetrics) -> Vec<Insight> {
    let mut insights = Vec::new();

    if metrics.inbox_count > 20 {
        insights.push(
            Insight::new(
                &format!(
                    "Your inbox has {} items - it's getting crowded",
                    metrics.inbox_count
                ),
                InsightLevel::High,
                "Inbox",
            )
            .with_suggestion("Consider processing your inbox with 'clings review'"),
        );
    } else if metrics.inbox_count > 10 {
        insights.push(
            Insight::new(
                &format!("You have {} items in your inbox", metrics.inbox_count),
                InsightLevel::Medium,
                "Inbox",
            )
            .with_suggestion("Try to process inbox items daily to stay organized"),
        );
    } else if metrics.inbox_count == 0 {
        insights.push(Insight::new(
            "Inbox zero! Great job keeping things organized",
            InsightLevel::Low,
            "Inbox",
        ));
    }

    // Check for stale inbox items
    let stale_inbox: Vec<_> = data
        .inbox_todos
        .iter()
        .filter(|t| {
            t.creation_date
                .map(|d| {
                    let age = chrono::Local::now().signed_duration_since(d).num_days();
                    age > 7
                })
                .unwrap_or(false)
        })
        .collect();

    if stale_inbox.len() > 3 {
        insights.push(
            Insight::new(
                &format!(
                    "{} inbox items are over a week old",
                    stale_inbox.len()
                ),
                InsightLevel::Medium,
                "Inbox",
            )
            .with_suggestion("Old inbox items may need to be processed or moved to Someday"),
        );
    }

    insights
}

fn overdue_insights(_data: &CollectedData, metrics: &ProductivityMetrics) -> Vec<Insight> {
    let mut insights = Vec::new();

    if metrics.overdue_count > 5 {
        insights.push(
            Insight::new(
                &format!(
                    "You have {} overdue tasks - this needs attention",
                    metrics.overdue_count
                ),
                InsightLevel::High,
                "Deadlines",
            )
            .with_suggestion("Review overdue items and either complete, reschedule, or cancel them"),
        );
    } else if metrics.overdue_count > 0 {
        insights.push(
            Insight::new(
                &format!("You have {} overdue task(s)", metrics.overdue_count),
                InsightLevel::Medium,
                "Deadlines",
            )
            .with_suggestion("Use 'clings filter \"due < today\"' to see overdue items"),
        );
    }

    if metrics.due_this_week > 10 {
        insights.push(
            Insight::new(
                &format!(
                    "{} tasks due this week - busy week ahead!",
                    metrics.due_this_week
                ),
                InsightLevel::Medium,
                "Deadlines",
            )
            .with_suggestion("Consider what can be rescheduled if needed"),
        );
    }

    insights
}

fn streak_insights(metrics: &ProductivityMetrics) -> Vec<Insight> {
    let mut insights = Vec::new();

    if metrics.streak.current >= 7 {
        insights.push(Insight::new(
            &format!(
                "Amazing! {} day completion streak - keep it going!",
                metrics.streak.current
            ),
            InsightLevel::Low,
            "Streak",
        ));
    } else if metrics.streak.current >= 3 {
        insights.push(Insight::new(
            &format!("{} day streak - you're building momentum!", metrics.streak.current),
            InsightLevel::Low,
            "Streak",
        ));
    } else if metrics.streak.days_since_completion > 3 {
        insights.push(
            Insight::new(
                &format!(
                    "No completions in {} days",
                    metrics.streak.days_since_completion
                ),
                InsightLevel::Medium,
                "Streak",
            )
            .with_suggestion("Even one small task completion can help rebuild momentum"),
        );
    }

    if metrics.streak.longest > 0 && metrics.streak.current < metrics.streak.longest {
        let to_beat = metrics.streak.longest - metrics.streak.current;
        if to_beat <= 3 && metrics.streak.current > 0 {
            insights.push(Insight::new(
                &format!(
                    "You're {} days away from matching your best streak of {} days!",
                    to_beat, metrics.streak.longest
                ),
                InsightLevel::Low,
                "Streak",
            ));
        }
    }

    insights
}

fn pattern_insights(metrics: &ProductivityMetrics) -> Vec<Insight> {
    let mut insights = Vec::new();

    // Productivity time insights
    let peak_period = if metrics.time.morning_completions > metrics.time.afternoon_completions
        && metrics.time.morning_completions > metrics.time.evening_completions
    {
        "morning"
    } else if metrics.time.afternoon_completions > metrics.time.evening_completions {
        "afternoon"
    } else {
        "evening"
    };

    if metrics.completion.completed_30d > 10 {
        insights.push(Insight::new(
            &format!(
                "You're most productive in the {} ({} is your peak hour)",
                peak_period,
                super::metrics::TimeMetrics::format_hour(metrics.time.best_hour)
            ),
            InsightLevel::Low,
            "Patterns",
        ));

        insights.push(Insight::new(
            &format!(
                "{} is your most productive day of the week",
                metrics.time.best_day
            ),
            InsightLevel::Low,
            "Patterns",
        ));
    }

    // Completion rate insights
    if metrics.completion.completion_rate < 0.7 && metrics.completion.total_completed > 10 {
        insights.push(
            Insight::new(
                &format!(
                    "Completion rate is {:.0}% - many tasks are being canceled",
                    metrics.completion.completion_rate * 100.0
                ),
                InsightLevel::Medium,
                "Patterns",
            )
            .with_suggestion("Consider if tasks are realistic when you create them"),
        );
    } else if metrics.completion.completion_rate > 0.95 && metrics.completion.total_completed > 20 {
        insights.push(Insight::new(
            &format!(
                "Excellent {:.0}% completion rate!",
                metrics.completion.completion_rate * 100.0
            ),
            InsightLevel::Low,
            "Patterns",
        ));
    }

    insights
}

fn project_insights(data: &CollectedData) -> Vec<Insight> {
    let mut insights = Vec::new();
    let project_metrics = ProjectMetrics::calculate_all(data);

    // Find projects with many overdue items
    for pm in &project_metrics {
        if pm.overdue_count > 3 {
            insights.push(
                Insight::new(
                    &format!(
                        "Project '{}' has {} overdue tasks",
                        pm.name, pm.overdue_count
                    ),
                    InsightLevel::High,
                    "Projects",
                )
                .with_suggestion("Review this project's timeline and priorities"),
            );
        }
    }

    // Find stale projects (old open tasks)
    for pm in &project_metrics {
        if pm.avg_age_days > 30.0 && pm.open_count > 3 {
            insights.push(
                Insight::new(
                    &format!(
                        "Project '{}' has tasks averaging {:.0} days old",
                        pm.name, pm.avg_age_days
                    ),
                    InsightLevel::Medium,
                    "Projects",
                )
                .with_suggestion("Consider if this project is still relevant"),
            );
        }
    }

    // Find highly active projects
    let active_projects: Vec<_> = project_metrics
        .iter()
        .filter(|pm| pm.completed_count > 10 && pm.completion_rate > 0.5)
        .collect();

    if !active_projects.is_empty() && active_projects.len() <= 3 {
        let names: Vec<_> = active_projects.iter().map(|pm| pm.name.as_str()).collect();
        insights.push(Insight::new(
            &format!("Making good progress on: {}", names.join(", ")),
            InsightLevel::Low,
            "Projects",
        ));
    }

    insights
}

fn workload_insights(metrics: &ProductivityMetrics) -> Vec<Insight> {
    let mut insights = Vec::new();

    if metrics.total_open > 100 {
        insights.push(
            Insight::new(
                &format!(
                    "You have {} open tasks - consider consolidating",
                    metrics.total_open
                ),
                InsightLevel::Medium,
                "Workload",
            )
            .with_suggestion("Large task lists can be overwhelming. Review and prune regularly."),
        );
    }

    if metrics.someday_count > 50 {
        insights.push(
            Insight::new(
                &format!(
                    "{} items in Someday - might need a cleanup",
                    metrics.someday_count
                ),
                InsightLevel::Low,
                "Workload",
            )
            .with_suggestion("Review Someday items during your weekly review"),
        );
    }

    if metrics.today_count > 15 {
        insights.push(
            Insight::new(
                &format!(
                    "{} tasks for today might be ambitious",
                    metrics.today_count
                ),
                InsightLevel::Medium,
                "Workload",
            )
            .with_suggestion("Focus on 3-5 key tasks. Move others to upcoming if needed."),
        );
    } else if metrics.today_count == 0 {
        insights.push(
            Insight::new("No tasks scheduled for today", InsightLevel::Low, "Workload")
                .with_suggestion("Check 'clings upcoming' or 'clings inbox' for tasks to do"),
        );
    }

    // Daily average insight
    if metrics.completion.avg_per_day > 0.0 {
        let velocity_msg = if metrics.completion.avg_per_day >= 5.0 {
            format!(
                "High velocity: {:.1} tasks/day average!",
                metrics.completion.avg_per_day
            )
        } else if metrics.completion.avg_per_day >= 2.0 {
            format!(
                "Good pace: {:.1} tasks/day average",
                metrics.completion.avg_per_day
            )
        } else {
            format!(
                "Completing {:.1} tasks/day on average",
                metrics.completion.avg_per_day
            )
        };

        insights.push(Insight::new(&velocity_msg, InsightLevel::Low, "Workload"));
    }

    insights
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_insight_level_icon() {
        assert_eq!(InsightLevel::High.icon(), "!");
        assert_eq!(InsightLevel::Medium.icon(), "*");
        assert_eq!(InsightLevel::Low.icon(), "-");
    }

    #[test]
    fn test_insight_creation() {
        let insight = Insight::new("Test message", InsightLevel::High, "Test")
            .with_suggestion("Test suggestion");

        assert_eq!(insight.message, "Test message");
        assert_eq!(insight.level, InsightLevel::High);
        assert_eq!(insight.category, "Test");
        assert_eq!(insight.suggestion, Some("Test suggestion".to_string()));
    }
}
