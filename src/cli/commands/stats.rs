//! Statistics command implementation.
//!
//! Handles the stats subcommands for productivity analytics.

use colored::Colorize;

use crate::cli::args::{OutputFormat, StatsCommands};
use crate::error::ClingsError;
use crate::features::stats::{
    generate_insights, render_bar_chart, render_heatmap, render_sparkline,
    InsightLevel, ProductivityMetrics, ProjectMetrics, StatsCollector, TagMetrics,
};
use crate::output::to_json;
use crate::things::ThingsClient;

/// Execute stats subcommands.
pub fn stats(
    client: &ThingsClient,
    cmd: Option<StatsCommands>,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let collector = StatsCollector::new(client);
    let data = collector.collect()?;
    let metrics = ProductivityMetrics::calculate(&data);

    match cmd {
        None | Some(StatsCommands::Dashboard) => render_dashboard(&data, &metrics, format),
        Some(StatsCommands::Summary) => render_summary(&metrics, format),
        Some(StatsCommands::Insights) => render_insights(&data, &metrics, format),
        Some(StatsCommands::Trends { days }) => render_trends(&data, &metrics, days, format),
        Some(StatsCommands::Projects) => render_projects(&data, format),
        Some(StatsCommands::Tags) => render_tags(&data, format),
        Some(StatsCommands::Patterns) => render_patterns(&metrics, format),
        Some(StatsCommands::Heatmap { weeks }) => render_heatmap_cmd(&data, weeks, format),
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
            output.push("╔════════════════════════════════════════════════════════════════╗".to_string());
            output.push("║              📊 PRODUCTIVITY DASHBOARD                         ║".to_string());
            output.push("╚════════════════════════════════════════════════════════════════╝".to_string());
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
                format!("{} days", metrics.streak.current).green().to_string()
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
                crate::features::stats::metrics::TimeMetrics::format_hour(metrics.time.best_hour).cyan()
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
                    let date = chrono::Local::now().date_naive() - chrono::Duration::days(i);
                    data.completed_todos
                        .iter()
                        .filter(|t| {
                            t.modification_date
                                .map(|d| d.date_naive() == date)
                                .unwrap_or(false)
                        })
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
        }
    }
}

/// Render a quick summary.
fn render_summary(metrics: &ProductivityMetrics, format: OutputFormat) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Json => to_json(metrics),
        OutputFormat::Pretty => {
            let mut output = Vec::new();

            output.push("📊 Quick Summary".bold().to_string());
            output.push("─".repeat(40));
            output.push(format!("Open tasks:      {}", metrics.total_open));
            output.push(format!("Inbox:           {}", metrics.inbox_count));
            output.push(format!("Today:           {}", metrics.today_count));
            output.push(format!(
                "Overdue:         {}",
                if metrics.overdue_count > 0 {
                    metrics.overdue_count.to_string().red().to_string()
                } else {
                    "0".green().to_string()
                }
            ));
            output.push(String::new());
            output.push(format!(
                "Completed (7d):  {}",
                metrics.completion.completed_7d
            ));
            output.push(format!(
                "Current streak:  {} days",
                metrics.streak.current
            ));
            output.push(format!(
                "Completion rate: {:.0}%",
                metrics.completion.completion_rate * 100.0
            ));

            Ok(output.join("\n"))
        }
    }
}

/// Render insights.
fn render_insights(
    data: &crate::features::stats::collector::CollectedData,
    metrics: &ProductivityMetrics,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let insights = generate_insights(data, metrics);

    match format {
        OutputFormat::Json => to_json(&insights),
        OutputFormat::Pretty => {
            if insights.is_empty() {
                return Ok("No insights available. Complete more tasks to generate insights.".to_string());
            }

            let mut output = Vec::new();
            output.push("💡 Productivity Insights".bold().to_string());
            output.push("═".repeat(50));

            let mut current_category = String::new();
            for insight in insights {
                if insight.category != current_category {
                    if !current_category.is_empty() {
                        output.push(String::new());
                    }
                    output.push(format!("\n{}", insight.category.bold()));
                    output.push("─".repeat(40));
                    current_category = insight.category.clone();
                }

                let icon = match insight.level {
                    InsightLevel::High => "❗".to_string(),
                    InsightLevel::Medium => "⚠️ ".to_string(),
                    InsightLevel::Low => "💡".to_string(),
                };

                output.push(format!("{} {}", icon, insight.message));
                if let Some(suggestion) = insight.suggestion {
                    output.push(format!("   → {}", suggestion.dimmed()));
                }
            }

            Ok(output.join("\n"))
        }
    }
}

/// Render completion trends.
fn render_trends(
    data: &crate::features::stats::collector::CollectedData,
    _metrics: &ProductivityMetrics,
    days: usize,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let today = chrono::Local::now().date_naive();

    // Calculate daily completions
    let mut daily_counts: Vec<(String, usize)> = Vec::new();
    for i in (0..days).rev() {
        let date = today - chrono::Duration::days(i as i64);
        let count = data
            .completed_todos
            .iter()
            .filter(|t| {
                t.modification_date
                    .map(|d| d.date_naive() == date)
                    .unwrap_or(false)
            })
            .count();
        daily_counts.push((date.format("%m/%d").to_string(), count));
    }

    match format {
        OutputFormat::Json => to_json(&daily_counts),
        OutputFormat::Pretty => {
            let mut output = Vec::new();

            output.push(format!("📈 Completion Trends (Last {} days)", days).bold().to_string());
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
            let avg = total as f64 / days as f64;
            let max = values.iter().max().copied().unwrap_or(0);

            output.push(String::new());
            output.push(format!("Total: {}  Average: {:.1}/day  Peak: {}", total, avg, max));

            Ok(output.join("\n"))
        }
    }
}

/// Render project statistics.
fn render_projects(
    data: &crate::features::stats::collector::CollectedData,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let mut project_metrics = ProjectMetrics::calculate_all(data);
    project_metrics.sort_by(|a, b| b.open_count.cmp(&a.open_count));

    match format {
        OutputFormat::Json => to_json(&project_metrics),
        OutputFormat::Pretty => {
            let mut output = Vec::new();

            output.push("📁 Project Statistics".bold().to_string());
            output.push("═".repeat(60));
            output.push(String::new());

            // Header
            output.push(format!(
                "{:<25} {:>6} {:>6} {:>8} {:>7}",
                "Project", "Open", "Done", "Rate", "Overdue"
            ));
            output.push("─".repeat(60));

            for pm in project_metrics.iter().take(15) {
                let name = if pm.name.len() > 24 {
                    format!("{}...", &pm.name[..21])
                } else {
                    pm.name.clone()
                };

                let rate = format!("{:.0}%", pm.completion_rate * 100.0);
                let overdue = if pm.overdue_count > 0 {
                    pm.overdue_count.to_string().red().to_string()
                } else {
                    "0".to_string()
                };

                output.push(format!(
                    "{:<25} {:>6} {:>6} {:>8} {:>7}",
                    name, pm.open_count, pm.completed_count, rate, overdue
                ));
            }

            if project_metrics.len() > 15 {
                output.push(format!("... and {} more projects", project_metrics.len() - 15));
            }

            Ok(output.join("\n"))
        }
    }
}

/// Render tag statistics.
fn render_tags(
    data: &crate::features::stats::collector::CollectedData,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let mut tag_metrics = TagMetrics::calculate_all(data);
    tag_metrics.sort_by(|a, b| b.total_count.cmp(&a.total_count));

    match format {
        OutputFormat::Json => to_json(&tag_metrics),
        OutputFormat::Pretty => {
            let mut output = Vec::new();

            output.push("🏷️  Tag Statistics".bold().to_string());
            output.push("═".repeat(50));
            output.push(String::new());

            if tag_metrics.is_empty() {
                output.push("No tags found.".dimmed().to_string());
                return Ok(output.join("\n"));
            }

            // Bar chart of top tags
            let chart_data: Vec<(String, usize)> = tag_metrics
                .iter()
                .take(10)
                .map(|tm| (format!("#{}", tm.name), tm.total_count))
                .collect();

            output.push(render_bar_chart(&chart_data, 15, 25));
            output.push(String::new());

            // Detailed table
            output.push(format!("{:<20} {:>8} {:>8} {:>8}", "Tag", "Total", "Open", "Done"));
            output.push("─".repeat(50));

            for tm in tag_metrics.iter().take(15) {
                output.push(format!(
                    "{:<20} {:>8} {:>8} {:>8}",
                    format!("#{}", tm.name),
                    tm.total_count,
                    tm.open_count,
                    tm.completed_count
                ));
            }

            Ok(output.join("\n"))
        }
    }
}

/// Render time patterns.
fn render_patterns(metrics: &ProductivityMetrics, format: OutputFormat) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Json => to_json(&metrics.time),
        OutputFormat::Pretty => {
            let mut output = Vec::new();

            output.push("⏰ Time Patterns".bold().to_string());
            output.push("═".repeat(50));
            output.push(String::new());

            // Day of week chart
            output.push("Completions by Day of Week:".to_string());
            let day_data: Vec<(String, usize)> = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                .iter()
                .enumerate()
                .map(|(i, day)| (day.to_string(), metrics.time.by_day_of_week[i]))
                .collect();
            output.push(render_bar_chart(&day_data, 3, 30));
            output.push(String::new());

            // Time of day distribution
            output.push("Completions by Time of Day:".to_string());
            let time_data = vec![
                ("Night (12-6am)".to_string(), metrics.time.night_completions),
                ("Morning (6-12pm)".to_string(), metrics.time.morning_completions),
                ("Afternoon (12-6pm)".to_string(), metrics.time.afternoon_completions),
                ("Evening (6-12am)".to_string(), metrics.time.evening_completions),
            ];
            output.push(render_bar_chart(&time_data, 18, 25));
            output.push(String::new());

            // Hourly sparkline
            output.push(format!(
                "Hourly distribution: {}",
                render_sparkline(&metrics.time.by_hour)
            ));
            output.push("                     0h        6h        12h       18h       23h".dimmed().to_string());
            output.push(String::new());

            // Summary
            output.push(format!(
                "Peak productivity: {} at {}",
                metrics.time.best_day.green(),
                crate::features::stats::metrics::TimeMetrics::format_hour(metrics.time.best_hour).green()
            ));

            Ok(output.join("\n"))
        }
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
            let mut by_date: std::collections::HashMap<String, usize> = std::collections::HashMap::new();

            for todo in &data.completed_todos {
                if let Some(mod_date) = todo.modification_date {
                    let date = mod_date.date_naive();
                    if (today - date).num_days() < days as i64 {
                        *by_date.entry(date.to_string()).or_default() += 1;
                    }
                }
            }

            to_json(&by_date)
        }
        OutputFormat::Pretty => {
            let mut output = Vec::new();

            output.push(format!("📅 Completion Heatmap (Last {} weeks)", weeks).bold().to_string());
            output.push("═".repeat(50));
            output.push(String::new());
            output.push(render_heatmap(&data.completed_todos, weeks));

            Ok(output.join("\n"))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stats_command_exists() {
        // Just verify the module compiles and types exist
        let _client = ThingsClient::new();
        // We can't test the actual command without Things 3 running
        // ThingsClient is a ZST (zero-sized type) so we just verify it can be created
    }
}
