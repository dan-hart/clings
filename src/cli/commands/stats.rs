//! Statistics command implementation.
//!
//! Handles the stats command for productivity analytics.

use colored::Colorize;

use crate::cli::args::{OutputFormat, StatsArgs};
use crate::error::ClingsError;
use crate::features::stats::{
    generate_insights, render_bar_chart, render_heatmap, render_sparkline, InsightLevel,
    ProductivityMetrics, StatsCollector,
};
use crate::output::to_json;
use crate::things::ThingsClient;

/// Execute stats command with optional flags.
///
/// # Errors
///
/// Returns an error if stats collection fails or rendering fails.
pub fn stats(
    client: &ThingsClient,
    args: &StatsArgs,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let collector = StatsCollector::new(client);
    let data = collector.collect()?;
    let metrics = ProductivityMetrics::calculate(&data);

    // Dispatch based on flags
    if args.trends {
        render_trends(&data, args.days, format)
    } else if args.heatmap {
        render_heatmap_cmd(&data, args.weeks, format)
    } else {
        // Default: show dashboard
        render_dashboard(&data, &metrics, format)
    }
}

/// Render the full dashboard.
fn render_dashboard(
    data: &crate::features::stats::collector::CollectedData,
    metrics: &ProductivityMetrics,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Json => to_json(metrics),
        OutputFormat::Pretty => {
            let mut output = Vec::new();

            // Header
            output.push(
                "╔════════════════════════════════════════════════════════════════╗".to_string(),
            );
            output.push(
                "║              📊 PRODUCTIVITY DASHBOARD                         ║".to_string(),
            );
            output.push(
                "╚════════════════════════════════════════════════════════════════╝".to_string(),
            );
            output.push(String::new());

            // Overview section
            output.push("📋 CURRENT STATUS".bold().to_string());
            output.push("─".repeat(50));
            output.push(format!(
                "  Inbox: {}  Today: {}  Upcoming: {}  Someday: {}",
                metrics.inbox_count.to_string().cyan(),
                metrics.today_count.to_string().green(),
                metrics.upcoming_count.to_string().yellow(),
                metrics.someday_count.to_string().blue()
            ));
            output.push(format!(
                "  Total open: {}  Overdue: {}  Due this week: {}",
                metrics.total_open,
                if metrics.overdue_count > 0 {
                    metrics.overdue_count.to_string().red().to_string()
                } else {
                    "0".green().to_string()
                },
                metrics.due_this_week
            ));
            output.push(String::new());

            // Completion section
            output.push("✅ COMPLETIONS".bold().to_string());
            output.push("─".repeat(50));
            output.push(format!(
                "  Last 7 days: {}  Last 30 days: {}  All time: {}",
                metrics.completion.completed_7d.to_string().green(),
                metrics.completion.completed_30d.to_string().green(),
                metrics.completion.total_completed
            ));
            output.push(format!(
                "  Average: {:.1}/day  Completion rate: {:.0}%",
                metrics.completion.avg_per_day,
                metrics.completion.completion_rate * 100.0
            ));
            if let Some(best_date) = metrics.completion.best_day_date {
                output.push(format!(
                    "  Best day: {} ({} tasks)",
                    best_date.format("%b %d"),
                    metrics.completion.best_day_count
                ));
            }
            output.push(String::new());

            // Streak section
            output.push("🔥 STREAK".bold().to_string());
            output.push("─".repeat(50));
            let streak_display = if metrics.streak.current > 0 {
                format!("{} days", metrics.streak.current)
                    .green()
                    .to_string()
            } else {
                "0 days".dimmed().to_string()
            };
            output.push(format!(
                "  Current: {}  Longest: {} days",
                streak_display, metrics.streak.longest
            ));
            if metrics.streak.days_since_completion > 0 {
                output.push(format!(
                    "  Days since last completion: {}",
                    metrics.streak.days_since_completion
                ));
            }
            output.push(String::new());

            // Time patterns section
            output.push("⏰ PRODUCTIVITY PATTERNS".bold().to_string());
            output.push("─".repeat(50));
            output.push(format!(
                "  Most productive day: {}",
                metrics.time.best_day.cyan()
            ));
            output.push(format!(
                "  Peak hour: {}",
                crate::features::stats::metrics::TimeMetrics::format_hour(metrics.time.best_hour)
                    .cyan()
            ));
            output.push(format!(
                "  Morning: {}  Afternoon: {}  Evening: {}  Night: {}",
                metrics.time.morning_completions,
                metrics.time.afternoon_completions,
                metrics.time.evening_completions,
                metrics.time.night_completions
            ));
            output.push(String::new());

            // Weekly sparkline
            let last_7_days: Vec<usize> = (0..7)
                .rev()
                .map(|i| {
                    let day = chrono::Local::now().date_naive() - chrono::Duration::days(i);
                    data.completed_todos
                        .iter()
                        .filter(|t| t.modification_date.is_some_and(|d| d.date_naive() == day))
                        .count()
                })
                .collect();
            output.push(format!("  Last 7 days: {}", render_sparkline(&last_7_days)));
            output.push(String::new());

            // Insights section
            let insights = generate_insights(data, metrics);
            let top_insights: Vec<_> = insights.into_iter().take(3).collect();
            if !top_insights.is_empty() {
                output.push("💡 TOP INSIGHTS".bold().to_string());
                output.push("─".repeat(50));
                for insight in top_insights {
                    let icon = match insight.level {
                        InsightLevel::High => "!".red().to_string(),
                        InsightLevel::Medium => "*".yellow().to_string(),
                        InsightLevel::Low => "-".blue().to_string(),
                    };
                    output.push(format!("  {} {}", icon, insight.message));
                }
            }

            Ok(output.join("\n"))
        },
    }
}

/// Render completion trends.
fn render_trends(
    data: &crate::features::stats::collector::CollectedData,
    days: usize,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let today = chrono::Local::now().date_naive();

    // Calculate daily completions
    let mut daily_counts: Vec<(String, usize)> = Vec::new();
    for i in (0..days).rev() {
        #[allow(clippy::cast_possible_wrap)]
        let day = today - chrono::Duration::days(i as i64);
        let count = data
            .completed_todos
            .iter()
            .filter(|t| t.modification_date.is_some_and(|d| d.date_naive() == day))
            .count();
        daily_counts.push((day.format("%m/%d").to_string(), count));
    }

    match format {
        OutputFormat::Json => to_json(&daily_counts),
        OutputFormat::Pretty => {
            let mut output = Vec::new();

            output.push(
                format!("📈 Completion Trends (Last {days} days)")
                    .bold()
                    .to_string(),
            );
            output.push("═".repeat(50));
            output.push(String::new());

            // Sparkline
            let values: Vec<usize> = daily_counts.iter().map(|(_, c)| *c).collect();
            output.push(format!("Daily completions: {}", render_sparkline(&values)));
            output.push(String::new());

            // Bar chart for last 14 days (or fewer if days < 14)
            let chart_days = days.min(14);
            let recent: Vec<(String, usize)> = daily_counts
                .iter()
                .rev()
                .take(chart_days)
                .rev()
                .cloned()
                .collect();

            output.push("Recent days:".to_string());
            output.push(render_bar_chart(&recent, 5, 30));

            // Summary stats
            let total: usize = values.iter().sum();
            #[allow(clippy::cast_precision_loss)]
            let avg = total as f64 / days as f64;
            let max = values.iter().max().copied().unwrap_or(0);

            output.push(String::new());
            output.push(format!(
                "Total: {total}  Average: {avg:.1}/day  Peak: {max}"
            ));

            Ok(output.join("\n"))
        },
    }
}

/// Render heatmap.
fn render_heatmap_cmd(
    data: &crate::features::stats::collector::CollectedData,
    weeks: usize,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Json => {
            // For JSON, return the raw completion data
            let today = chrono::Local::now().date_naive();
            let days = weeks * 7;
            let mut by_date: std::collections::HashMap<String, usize> =
                std::collections::HashMap::new();

            for todo in &data.completed_todos {
                if let Some(mod_date) = todo.modification_date {
                    let day = mod_date.date_naive();
                    #[allow(clippy::cast_possible_wrap)]
                    if (today - day).num_days() < days as i64 {
                        *by_date.entry(day.to_string()).or_default() += 1;
                    }
                }
            }

            to_json(&by_date)
        },
        OutputFormat::Pretty => {
            let mut output = Vec::new();

            output.push(
                format!("📅 Completion Heatmap (Last {weeks} weeks)")
                    .bold()
                    .to_string(),
            );
            output.push("═".repeat(50));
            output.push(String::new());
            output.push(render_heatmap(&data.completed_todos, weeks));

            Ok(output.join("\n"))
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stats_command_exists() {
        // Just verify the module compiles and types exist
        let _client = ThingsClient::new();
    }
}
