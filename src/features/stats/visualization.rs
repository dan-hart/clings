//! Terminal visualization for statistics.
//!
//! Provides ASCII charts, graphs, and visual representations.

use chrono::{Datelike, Duration, Local, NaiveDate};
use std::collections::HashMap;

use crate::things::Todo;

/// Characters for bar chart rendering.
const BAR_CHARS: [char; 8] = [' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇'];
const FULL_BLOCK: char = '█';

/// Render a horizontal bar chart.
///
/// # Arguments
///
/// * `data` - Vec of (label, value) pairs
/// * `max_label_width` - Maximum width for labels
/// * `bar_width` - Width of the bar portion
///
/// # Returns
///
/// A multi-line string with the chart.
pub fn render_bar_chart(data: &[(String, usize)], max_label_width: usize, bar_width: usize) -> String {
    if data.is_empty() {
        return String::new();
    }

    let max_value = data.iter().map(|(_, v)| *v).max().unwrap_or(1).max(1);
    let mut lines = Vec::new();

    for (label, value) in data {
        let truncated_label = if label.len() > max_label_width {
            format!("{}...", &label[..max_label_width - 3])
        } else {
            format!("{:width$}", label, width = max_label_width)
        };

        let bar_length = (*value as f64 / max_value as f64 * bar_width as f64) as usize;
        let bar = FULL_BLOCK.to_string().repeat(bar_length);
        let padding = " ".repeat(bar_width - bar_length);

        lines.push(format!("{} |{}{} {}", truncated_label, bar, padding, value));
    }

    lines.join("\n")
}

/// Render a sparkline (compact inline chart).
///
/// # Arguments
///
/// * `values` - Slice of values to render
///
/// # Returns
///
/// A single-line string with the sparkline.
pub fn render_sparkline(values: &[usize]) -> String {
    if values.is_empty() {
        return String::new();
    }

    let max_value = *values.iter().max().unwrap_or(&1);
    let max_value = max_value.max(1);

    values
        .iter()
        .map(|&v| {
            let normalized = (v as f64 / max_value as f64 * 7.0) as usize;
            if v == 0 {
                BAR_CHARS[0]
            } else {
                BAR_CHARS[normalized.min(7)]
            }
        })
        .collect()
}

/// Render a weekly heatmap.
///
/// Shows 7 columns (days) with intensity based on completions.
///
/// # Arguments
///
/// * `completed_todos` - Slice of completed todos
/// * `weeks` - Number of weeks to show
///
/// # Returns
///
/// Multi-line string with the heatmap.
pub fn render_heatmap(completed_todos: &[Todo], weeks: usize) -> String {
    let today = Local::now().date_naive();
    let days = weeks * 7;
    let start_date = today - Duration::days(days as i64 - 1);

    // Count completions by date
    let mut by_date: HashMap<NaiveDate, usize> = HashMap::new();
    for todo in completed_todos {
        if let Some(mod_date) = todo.modification_date {
            let date = mod_date.date_naive();
            if date >= start_date && date <= today {
                *by_date.entry(date).or_default() += 1;
            }
        }
    }

    let max_count = by_date.values().max().copied().unwrap_or(1).max(1);

    // Build heatmap grid
    let mut lines = Vec::new();
    let day_labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    // Header with week numbers
    let mut header = "     ".to_string();
    for w in 0..weeks {
        header.push_str(&format!("W{:<2}", weeks - w));
    }
    lines.push(header);

    // Each row is a day of the week
    for day_idx in 0..7 {
        let mut row = format!("{} ", day_labels[day_idx]);

        for week in (0..weeks).rev() {
            let days_back = week * 7 + (6 - day_idx);
            let date = today - Duration::days(days_back as i64);

            // Adjust for day of week alignment
            let weekday = date.weekday().num_days_from_monday() as usize;
            if weekday != day_idx {
                row.push_str("   ");
                continue;
            }

            let count = by_date.get(&date).copied().unwrap_or(0);
            let intensity = if count == 0 {
                '·'
            } else {
                let level = (count as f64 / max_count as f64 * 4.0) as usize;
                match level {
                    0 => '░',
                    1 => '▒',
                    2 => '▓',
                    _ => '█',
                }
            };
            row.push_str(&format!(" {} ", intensity));
        }

        lines.push(row);
    }

    // Legend
    lines.push(String::new());
    lines.push("Legend: · = 0  ░ = low  ▒ = medium  ▓ = high  █ = peak".to_string());

    lines.join("\n")
}

/// Render a simple progress bar.
///
/// # Arguments
///
/// * `current` - Current value
/// * `total` - Total value
/// * `width` - Width of the progress bar
///
/// # Returns
///
/// A single-line string with the progress bar.
pub fn render_progress_bar(current: usize, total: usize, width: usize) -> String {
    let total = total.max(1);
    let progress = (current as f64 / total as f64).min(1.0);
    let filled = (progress * width as f64) as usize;
    let empty = width - filled;

    let bar = format!(
        "[{}{}]",
        FULL_BLOCK.to_string().repeat(filled),
        "░".repeat(empty)
    );

    format!("{} {:.0}%", bar, progress * 100.0)
}

/// Render a day-of-week chart.
///
/// # Arguments
///
/// * `counts` - Array of 7 counts (Mon-Sun)
///
/// # Returns
///
/// Multi-line string with the chart.
pub fn render_day_of_week_chart(counts: &[usize; 7]) -> String {
    let day_labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    let data: Vec<(String, usize)> = day_labels
        .iter()
        .zip(counts.iter())
        .map(|(l, &c)| (l.to_string(), c))
        .collect();

    render_bar_chart(&data, 3, 20)
}

/// Render an hour-of-day chart.
///
/// # Arguments
///
/// * `counts` - Array of 24 counts (0-23)
///
/// # Returns
///
/// Multi-line string with a compact hourly chart.
pub fn render_hour_chart(counts: &[usize; 24]) -> String {
    let mut lines = Vec::new();

    // Group into 6 periods of 4 hours each
    let periods = [
        ("12am-4am", &counts[0..4]),
        ("4am-8am", &counts[4..8]),
        ("8am-12pm", &counts[8..12]),
        ("12pm-4pm", &counts[12..16]),
        ("4pm-8pm", &counts[16..20]),
        ("8pm-12am", &counts[20..24]),
    ];

    let data: Vec<(String, usize)> = periods
        .iter()
        .map(|(label, slice)| (label.to_string(), slice.iter().sum()))
        .collect();

    lines.push(render_bar_chart(&data, 9, 20));
    lines.push(String::new());
    lines.push(format!("Hourly: {}", render_sparkline(counts)));

    lines.join("\n")
}

/// Render a summary box with key metrics.
///
/// # Arguments
///
/// * `title` - Box title
/// * `items` - Vec of (label, value) pairs
///
/// # Returns
///
/// Multi-line string with a bordered box.
pub fn render_summary_box(title: &str, items: &[(&str, String)]) -> String {
    let max_label_len = items.iter().map(|(l, _)| l.len()).max().unwrap_or(0);
    let max_value_len = items.iter().map(|(_, v)| v.len()).max().unwrap_or(0);
    let content_width = max_label_len + max_value_len + 3; // " : "
    let box_width = content_width.max(title.len()) + 4;

    let mut lines = Vec::new();

    // Top border
    lines.push(format!("┌{}┐", "─".repeat(box_width)));

    // Title
    let title_padding = (box_width - title.len()) / 2;
    lines.push(format!(
        "│{}{}{}│",
        " ".repeat(title_padding),
        title,
        " ".repeat(box_width - title_padding - title.len())
    ));

    // Separator
    lines.push(format!("├{}┤", "─".repeat(box_width)));

    // Items
    for (label, value) in items {
        let item_str = format!("{:>width$} : {}", label, value, width = max_label_len);
        let padding = box_width - item_str.len();
        lines.push(format!("│ {}{} │", item_str, " ".repeat(padding - 2)));
    }

    // Bottom border
    lines.push(format!("└{}┘", "─".repeat(box_width)));

    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_render_sparkline() {
        let values = [0, 2, 5, 3, 8, 4, 1];
        let sparkline = render_sparkline(&values);
        assert_eq!(sparkline.chars().count(), 7);
    }

    #[test]
    fn test_render_sparkline_empty() {
        let sparkline = render_sparkline(&[]);
        assert!(sparkline.is_empty());
    }

    #[test]
    fn test_render_bar_chart() {
        let data = vec![
            ("A".to_string(), 5),
            ("B".to_string(), 10),
            ("C".to_string(), 3),
        ];
        let chart = render_bar_chart(&data, 5, 10);
        assert!(chart.contains("A"));
        assert!(chart.contains("B"));
        assert!(chart.contains("C"));
    }

    #[test]
    fn test_render_progress_bar() {
        let bar = render_progress_bar(50, 100, 20);
        assert!(bar.contains("50%"));

        let full_bar = render_progress_bar(100, 100, 20);
        assert!(full_bar.contains("100%"));

        let empty_bar = render_progress_bar(0, 100, 20);
        assert!(empty_bar.contains("0%"));
    }

    #[test]
    fn test_render_summary_box() {
        let items = [
            ("Tasks", "42".to_string()),
            ("Completed", "35".to_string()),
        ];
        let box_str = render_summary_box("Summary", &items);
        assert!(box_str.contains("Summary"));
        assert!(box_str.contains("42"));
        assert!(box_str.contains("35"));
    }
}
