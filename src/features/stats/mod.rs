//! Statistics and insights module.
//!
//! Provides task statistics, productivity metrics, and insights:
//! - Completion rates and trends
//! - Productivity streaks
//! - Tag and project analytics
//! - Time-based patterns
//! - Actionable insights

pub mod collector;
pub mod insights;
pub mod metrics;
pub mod visualization;

pub use collector::StatsCollector;
pub use insights::{generate_insights, Insight, InsightLevel};
pub use metrics::{
    CompletionMetrics, ProductivityMetrics, ProjectMetrics, StreakInfo, TagMetrics, TimeMetrics,
};
pub use visualization::{render_bar_chart, render_heatmap, render_sparkline};
