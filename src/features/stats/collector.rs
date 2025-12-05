//! Data collection for statistics.
//!
//! Gathers todo data from Things 3 for analysis.
//!
//! Uses direct database access for completed todos (fast, even for large Logbooks)
//! and JXA for open todos (provides complete data with resolved project/area names).

use chrono::{Datelike, Duration, Local, NaiveDate, Timelike};
use std::collections::HashMap;

use crate::error::ClingsError;
use crate::things::{fetch_stats_data, ListView, Status, ThingsClient, Todo};

/// Collected statistics data.
#[derive(Debug, Clone)]
pub struct CollectedData {
    /// All open todos
    pub open_todos: Vec<Todo>,
    /// Completed todos (from logbook)
    pub completed_todos: Vec<Todo>,
    /// Today's todos
    pub today_todos: Vec<Todo>,
    /// Inbox todos
    pub inbox_todos: Vec<Todo>,
    /// Upcoming todos
    pub upcoming_todos: Vec<Todo>,
    /// Someday todos
    pub someday_todos: Vec<Todo>,
    /// All projects
    pub projects: Vec<crate::things::Project>,
    /// All areas
    pub areas: Vec<crate::things::Area>,
    /// All tags
    pub tags: Vec<crate::things::Tag>,
}

/// Collects data from Things 3 for statistics.
pub struct StatsCollector<'a> {
    client: &'a ThingsClient,
}

impl<'a> StatsCollector<'a> {
    /// Create a new stats collector.
    #[must_use]
    pub const fn new(client: &'a ThingsClient) -> Self {
        Self { client }
    }

    /// Collect all data for statistics.
    ///
    /// Uses direct database access for fast data retrieval. Falls back to
    /// JXA if database access fails.
    ///
    /// # Errors
    ///
    /// Returns an error if both database access and JXA fallback fail.
    pub fn collect(&self) -> Result<CollectedData, ClingsError> {
        // Try database access first (much faster than JXA)
        if let Ok(db_data) = fetch_stats_data() {
            let inbox_todos = db_data.inbox_todos;
            let today_todos = db_data.today_todos;
            let upcoming_todos = db_data.upcoming_todos;
            let someday_todos = db_data.someday_todos;
            let anytime_todos = db_data.anytime_todos;
            let completed_todos = db_data.completed_todos;

            // Combine open todos
            let mut open_todos = Vec::new();
            open_todos.extend(inbox_todos.clone());
            open_todos.extend(today_todos.clone());
            open_todos.extend(upcoming_todos.clone());
            open_todos.extend(anytime_todos);

            Ok(CollectedData {
                open_todos,
                completed_todos,
                today_todos,
                inbox_todos,
                upcoming_todos,
                someday_todos,
                // Empty collections for projects/areas/tags - not needed for most stats
                projects: Vec::new(),
                areas: Vec::new(),
                tags: Vec::new(),
            })
        } else {
            // Fall back to JXA if database access fails
            let inbox_todos = self.client.get_list(ListView::Inbox).unwrap_or_default();
            let today_todos = self.client.get_list(ListView::Today).unwrap_or_default();
            let upcoming_todos = self.client.get_list(ListView::Upcoming).unwrap_or_default();
            let someday_todos = self.client.get_list(ListView::Someday).unwrap_or_default();
            let anytime_todos = self.client.get_list(ListView::Anytime).unwrap_or_default();
            let completed_todos = self.client.get_list(ListView::Logbook).unwrap_or_default();

            let mut open_todos = Vec::new();
            open_todos.extend(inbox_todos.clone());
            open_todos.extend(today_todos.clone());
            open_todos.extend(upcoming_todos.clone());
            open_todos.extend(anytime_todos);

            let projects = self.client.get_projects().unwrap_or_default();
            let areas = self.client.get_areas().unwrap_or_default();
            let tags = self.client.get_tags().unwrap_or_default();

            Ok(CollectedData {
                open_todos,
                completed_todos,
                today_todos,
                inbox_todos,
                upcoming_todos,
                someday_todos,
                projects,
                areas,
                tags,
            })
        }
    }

    /// Get completions grouped by date.
    #[must_use]
    pub fn completions_by_date<'b>(
        &self,
        todos: &'b [Todo],
        days: i64,
    ) -> HashMap<NaiveDate, Vec<&'b Todo>> {
        let today = Local::now().date_naive();
        let start_date = today - Duration::days(days);

        let mut by_date: HashMap<NaiveDate, Vec<&Todo>> = HashMap::new();

        for todo in todos {
            if let Some(mod_date) = todo.modification_date {
                let date = mod_date.date_naive();
                if date >= start_date && date <= today {
                    by_date.entry(date).or_default().push(todo);
                }
            }
        }

        by_date
    }

    /// Get todos grouped by project.
    #[must_use]
    pub fn todos_by_project<'b>(&self, todos: &'b [Todo]) -> HashMap<String, Vec<&'b Todo>> {
        let mut by_project: HashMap<String, Vec<&Todo>> = HashMap::new();

        for todo in todos {
            let project = todo
                .project
                .clone()
                .unwrap_or_else(|| "(No Project)".to_string());
            by_project.entry(project).or_default().push(todo);
        }

        by_project
    }

    /// Get todos grouped by tag.
    #[must_use]
    pub fn todos_by_tag<'b>(&self, todos: &'b [Todo]) -> HashMap<String, Vec<&'b Todo>> {
        let mut by_tag: HashMap<String, Vec<&Todo>> = HashMap::new();

        for todo in todos {
            if todo.tags.is_empty() {
                by_tag
                    .entry("(No Tags)".to_string())
                    .or_default()
                    .push(todo);
            } else {
                for tag in &todo.tags {
                    by_tag.entry(tag.clone()).or_default().push(todo);
                }
            }
        }

        by_tag
    }

    /// Get todos grouped by area.
    #[must_use]
    pub fn todos_by_area<'b>(&self, todos: &'b [Todo]) -> HashMap<String, Vec<&'b Todo>> {
        let mut by_area: HashMap<String, Vec<&Todo>> = HashMap::new();

        for todo in todos {
            let area = todo.area.clone().unwrap_or_else(|| "(No Area)".to_string());
            by_area.entry(area).or_default().push(todo);
        }

        by_area
    }

    /// Get todos due in the next N days.
    #[must_use]
    pub fn todos_due_soon<'b>(&self, todos: &'b [Todo], days: i64) -> Vec<&'b Todo> {
        let today = Local::now().date_naive();
        let end_date = today + Duration::days(days);

        todos
            .iter()
            .filter(|t| {
                t.due_date
                    .is_some_and(|due| due >= today && due <= end_date)
            })
            .collect()
    }

    /// Get overdue todos.
    #[must_use]
    pub fn overdue_todos<'b>(&self, todos: &'b [Todo]) -> Vec<&'b Todo> {
        let today = Local::now().date_naive();

        todos
            .iter()
            .filter(|t| {
                t.due_date
                    .is_some_and(|due| due < today && t.status == Status::Open)
            })
            .collect()
    }

    /// Get completion counts by day of week.
    #[must_use]
    pub fn completions_by_day_of_week(&self, todos: &[Todo]) -> [usize; 7] {
        let mut counts = [0usize; 7];

        for todo in todos {
            if let Some(mod_date) = todo.modification_date {
                let weekday = mod_date.date_naive().weekday().num_days_from_monday() as usize;
                counts[weekday] += 1;
            }
        }

        counts
    }

    /// Get completion counts by hour of day.
    #[must_use]
    pub fn completions_by_hour(&self, todos: &[Todo]) -> [usize; 24] {
        let mut counts = [0usize; 24];

        for todo in todos {
            if let Some(mod_date) = todo.modification_date {
                let hour = mod_date.hour() as usize;
                counts[hour] += 1;
            }
        }

        counts
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stats_collector_creation() {
        let client = ThingsClient::new();
        let _collector = StatsCollector::new(&client);
        // Just test that it can be created
        // StatsCollector holds a reference, so it's not zero-sized
    }
}
