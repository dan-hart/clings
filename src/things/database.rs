//! Direct database access for Things 3.
//!
//! This module provides read-only access to the Things 3 `SQLite` database
//! for fast data retrieval. All read operations should use this module
//! for best performance.
//!
//! NOTE: This is read-only access. All mutations should go through the
//! JXA client to ensure Things 3 stays in sync.
//!
//! ## Database Schema
//!
//! Things 3 uses the following tables:
//! - `TMTask` - Tasks, projects, and headings (type: 0=task, 1=project, 2=heading)
//! - `TMTag` - Tag definitions
//! - `TMTaskTag` - Junction table linking tasks to tags
//! - `TMChecklistItem` - Checklist items within tasks
//! - `TMArea` - Areas
//! - `TMAreaTag` - Junction table linking areas to tags

use std::path::PathBuf;

use chrono::{DateTime, Local, NaiveDate, TimeZone, Utc};
use rusqlite::{params, Connection, OpenFlags, OptionalExtension};

use crate::error::ClingsError;
use crate::things::types::{Area, ChecklistItem, ListView, Project, Status, Tag, Todo};

/// Find the Things 3 database path.
///
/// Things 3 stores its database in a Group Container with a variable suffix.
#[must_use]
pub fn find_database_path() -> Option<PathBuf> {
    let home = std::env::var("HOME").ok()?;
    let container_path =
        PathBuf::from(&home).join("Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac");

    // Look for ThingsData-* directories
    let entries = std::fs::read_dir(&container_path).ok()?;

    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            let name = path.file_name()?.to_str()?;
            if name.starts_with("ThingsData-") {
                let db_path = path.join("Things Database.thingsdatabase/main.sqlite");
                if db_path.exists() {
                    return Some(db_path);
                }
            }
        }
    }

    None
}

/// Open a read-only connection to the Things database.
fn open_connection() -> Result<Connection, ClingsError> {
    let path = find_database_path()
        .ok_or_else(|| ClingsError::Config("Could not find Things 3 database".to_string()))?;

    Connection::open_with_flags(&path, OpenFlags::SQLITE_OPEN_READ_ONLY)
        .map_err(|e| ClingsError::Database(e.to_string()))
}

/// Convert a Things timestamp (seconds since reference date) to `DateTime<Utc>`.
fn things_timestamp_to_datetime(timestamp: f64) -> Option<DateTime<Utc>> {
    // Things uses Core Data timestamps (seconds since 2001-01-01)
    // We need to convert to Unix timestamp (seconds since 1970-01-01)
    const CORE_DATA_EPOCH_OFFSET: i64 = 978_307_200; // seconds between 1970 and 2001

    #[allow(clippy::cast_possible_truncation)]
    let unix_timestamp = timestamp as i64 + CORE_DATA_EPOCH_OFFSET;
    Utc.timestamp_opt(unix_timestamp, 0).single()
}

/// Convert a Things date integer (days since reference date) to `NaiveDate`.
fn things_date_to_naive_date(days: i64) -> Option<NaiveDate> {
    // Things date integers are days since 2001-01-01
    let base_date = NaiveDate::from_ymd_opt(2001, 1, 1)?;
    base_date.checked_add_signed(chrono::Duration::days(days))
}

/// Statistics data fetched directly from the database.
#[derive(Debug, Clone, Default)]
pub struct DbStatsData {
    /// Completed todos with their completion dates
    pub completed_todos: Vec<Todo>,
    /// Open todos by list
    pub inbox_todos: Vec<Todo>,
    pub today_todos: Vec<Todo>,
    pub upcoming_todos: Vec<Todo>,
    pub anytime_todos: Vec<Todo>,
    pub someday_todos: Vec<Todo>,
    /// Count of projects
    pub project_count: usize,
    /// Count of areas
    pub area_count: usize,
}

/// Fetch statistics data directly from the Things database.
///
/// This is much faster than JXA for large datasets.
///
/// # Errors
///
/// Returns an error if the database cannot be opened or queried.
pub fn fetch_stats_data() -> Result<DbStatsData, ClingsError> {
    let conn = open_connection()?;

    let mut data = DbStatsData::default();

    // Calculate today's date in Things format (days since 2001-01-01)
    let today_days = (Local::now().date_naive()
        - NaiveDate::from_ymd_opt(2001, 1, 1).unwrap_or_default())
    .num_days();

    // Fetch completed todos from the last 90 days
    let ninety_days_ago = Local::now() - chrono::Duration::days(90);
    let cutoff_timestamp = ninety_days_ago.timestamp() - 978_307_200; // Convert to Core Data timestamp

    #[allow(clippy::cast_precision_loss)]
    let cutoff_f64 = cutoff_timestamp as f64;
    data.completed_todos = fetch_todos_with_filter(
        &conn,
        "status = 3 AND trashed = 0 AND type = 0 AND stopDate >= ?",
        &[&cutoff_f64],
    )?;

    // Fetch open todos by list
    // Today: start=1 (Today bucket) OR has today's startDate
    data.today_todos = fetch_todos_with_filter(
        &conn,
        "status = 0 AND trashed = 0 AND type = 0 AND (start = 1 OR startDate = ?)",
        &[&today_days],
    )?;

    // Upcoming: has future startDate
    data.upcoming_todos = fetch_todos_with_filter(
        &conn,
        "status = 0 AND trashed = 0 AND type = 0 AND startDate > ?",
        &[&today_days],
    )?;

    // Inbox: start=0 (Inbox bucket), no project
    data.inbox_todos = fetch_todos_with_filter(
        &conn,
        "status = 0 AND trashed = 0 AND type = 0 AND start = 0 AND project IS NULL AND startDate IS NULL",
        &[],
    )?;

    // Anytime: start=0 with project OR has past/null startDate and project
    data.anytime_todos = fetch_todos_with_filter(
        &conn,
        "status = 0 AND trashed = 0 AND type = 0 AND start = 0 AND project IS NOT NULL",
        &[],
    )?;

    // Someday: start=2
    data.someday_todos = fetch_todos_with_filter(
        &conn,
        "status = 0 AND trashed = 0 AND type = 0 AND start = 2",
        &[],
    )?;

    // Project count (type=1 for projects)
    data.project_count = conn
        .query_row(
            "SELECT COUNT(*) FROM TMTask WHERE type = 1 AND trashed = 0 AND status = 0",
            [],
            |row| row.get(0),
        )
        .unwrap_or(0);

    // Area count
    data.area_count = conn
        .query_row("SELECT COUNT(*) FROM TMArea", [], |row| row.get(0))
        .unwrap_or(0);

    Ok(data)
}

/// Fetch todos for a specific list view.
///
/// This is the primary function for fetching todos, replacing JXA-based
/// `ThingsClient::get_list()` for better performance.
///
/// # Errors
///
/// Returns an error if the database cannot be opened or queried.
pub fn fetch_list(view: ListView) -> Result<Vec<Todo>, ClingsError> {
    let conn = open_connection()?;
    let today_days = days_since_reference_date(Local::now().date_naive());

    let todos = match view {
        ListView::Inbox => fetch_todos_full(
            &conn,
            "status = 0 AND trashed = 0 AND type = 0 AND start = 0 AND project IS NULL AND startDate IS NULL",
            &[],
        )?,
        ListView::Today => fetch_todos_full(
            &conn,
            "status = 0 AND trashed = 0 AND type = 0 AND (start = 1 OR startDate = ?)",
            &[&today_days],
        )?,
        ListView::Upcoming => fetch_todos_full(
            &conn,
            "status = 0 AND trashed = 0 AND type = 0 AND startDate > ?",
            &[&today_days],
        )?,
        ListView::Anytime => fetch_todos_full(
            &conn,
            "status = 0 AND trashed = 0 AND type = 0 AND start = 1 AND (startDate IS NULL OR startDate <= ?)",
            &[&today_days],
        )?,
        ListView::Someday => fetch_todos_full(
            &conn,
            "status = 0 AND trashed = 0 AND type = 0 AND start = 2",
            &[],
        )?,
        ListView::Logbook => {
            // Logbook shows completed todos, order by completion date descending
            let sql = "SELECT uuid, title, notes, status, stopDate, deadline, creationDate, \
                       userModificationDate, project, area \
                       FROM TMTask \
                       WHERE status = 3 AND trashed = 0 AND type = 0 \
                       ORDER BY stopDate DESC \
                       LIMIT 500";
            fetch_todos_from_sql(&conn, sql, &[])?
        }
        ListView::Trash => fetch_todos_full(
            &conn,
            "trashed = 1 AND type = 0",
            &[],
        )?,
    };

    Ok(todos)
}

/// Fetch a single todo by ID with full details including tags and checklist items.
///
/// # Errors
///
/// Returns an error if the database cannot be opened, queried, or if the todo is not found.
pub fn fetch_todo(id: &str) -> Result<Todo, ClingsError> {
    let conn = open_connection()?;

    let sql = "SELECT uuid, title, notes, status, stopDate, deadline, creationDate, \
               userModificationDate, project, area \
               FROM TMTask \
               WHERE uuid = ? AND type = 0";

    let mut stmt = conn
        .prepare(sql)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let todo = stmt
        .query_row(params![id], row_to_todo_tuple)
        .map_err(|e| match e {
            rusqlite::Error::QueryReturnedNoRows => {
                ClingsError::NotFound(format!("Todo with id '{id}' not found"))
            },
            _ => ClingsError::Database(e.to_string()),
        })?;

    let mut todo = tuple_to_todo(&conn, todo)?;

    // Fetch tags for this todo
    todo.tags = fetch_tags_for_task(&conn, id)?;

    // Fetch checklist items
    todo.checklist_items = fetch_checklist_items(&conn, id)?;

    Ok(todo)
}

/// Fetch all projects.
///
/// # Errors
///
/// Returns an error if the database cannot be opened or queried.
pub fn fetch_projects() -> Result<Vec<Project>, ClingsError> {
    let conn = open_connection()?;

    let sql = "SELECT uuid, title, notes, status, stopDate, deadline, creationDate, area \
               FROM TMTask \
               WHERE type = 1 AND trashed = 0 AND status = 0 \
               ORDER BY \"index\"";

    let mut stmt = conn
        .prepare(sql)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let projects = stmt
        .query_map([], |row| {
            let uuid: String = row.get(0)?;
            let title: String = row.get(1)?;
            let notes: Option<String> = row.get(2)?;
            let status_int: i32 = row.get(3)?;
            let _stop_date: Option<f64> = row.get(4)?;
            let deadline: Option<i64> = row.get(5)?;
            let creation_date: Option<f64> = row.get(6)?;
            let area_uuid: Option<String> = row.get(7)?;

            Ok((
                uuid,
                title,
                notes,
                status_int,
                deadline,
                creation_date,
                area_uuid,
            ))
        })
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let mut result = Vec::new();
    for project_result in projects {
        let (uuid, title, notes, status_int, deadline, creation_date, area_uuid) =
            project_result.map_err(|e| ClingsError::Database(e.to_string()))?;

        let status = int_to_status(status_int);
        let due_date = deadline.and_then(things_date_to_naive_date);
        let creation_dt = creation_date.and_then(things_timestamp_to_datetime);

        // Look up area name
        let area_name = area_uuid
            .as_ref()
            .and_then(|uuid| lookup_area_name(&conn, uuid).ok())
            .flatten();

        // Fetch tags for this project
        let tags = fetch_tags_for_task(&conn, &uuid).unwrap_or_default();

        result.push(Project {
            id: uuid,
            name: title,
            notes: notes.unwrap_or_default(),
            status,
            area: area_name,
            tags,
            due_date,
            creation_date: creation_dt,
        });
    }

    Ok(result)
}

/// Fetch all areas.
///
/// # Errors
///
/// Returns an error if the database cannot be opened or queried.
pub fn fetch_areas() -> Result<Vec<Area>, ClingsError> {
    let conn = open_connection()?;

    let sql = "SELECT uuid, title FROM TMArea ORDER BY \"index\"";

    let mut stmt = conn
        .prepare(sql)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let areas = stmt
        .query_map([], |row| {
            let uuid: String = row.get(0)?;
            let title: String = row.get(1)?;
            Ok((uuid, title))
        })
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let mut result = Vec::new();
    for area_result in areas {
        let (uuid, title) = area_result.map_err(|e| ClingsError::Database(e.to_string()))?;

        // Fetch tags for this area
        let tags = fetch_tags_for_area(&conn, &uuid).unwrap_or_default();

        result.push(Area {
            id: uuid,
            name: title,
            tags,
        });
    }

    Ok(result)
}

/// Fetch all tags.
///
/// # Errors
///
/// Returns an error if the database cannot be opened or queried.
pub fn fetch_tags() -> Result<Vec<Tag>, ClingsError> {
    let conn = open_connection()?;

    let sql = "SELECT uuid, title FROM TMTag ORDER BY title";

    let mut stmt = conn
        .prepare(sql)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let tags = stmt
        .query_map([], |row| {
            let uuid: String = row.get(0)?;
            let title: String = row.get(1)?;
            Ok(Tag {
                id: uuid,
                name: title,
            })
        })
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    tags.collect::<Result<Vec<_>, _>>()
        .map_err(|e| ClingsError::Database(e.to_string()))
}

/// Search todos by title or notes.
///
/// # Errors
///
/// Returns an error if the database cannot be opened or queried.
pub fn search_todos(query: &str) -> Result<Vec<Todo>, ClingsError> {
    let conn = open_connection()?;

    let search_pattern = format!("%{query}%");

    let sql = "SELECT uuid, title, notes, status, stopDate, deadline, creationDate, \
               userModificationDate, project, area \
               FROM TMTask \
               WHERE type = 0 AND trashed = 0 AND (title LIKE ? OR notes LIKE ?) \
               ORDER BY todayIndex, \"index\" \
               LIMIT 100";

    fetch_todos_from_sql(&conn, sql, &[&search_pattern, &search_pattern])
}

/// Fetch all open todos (no filtering by list).
///
/// # Errors
///
/// Returns an error if the database cannot be opened or queried.
pub fn fetch_all_todos() -> Result<Vec<Todo>, ClingsError> {
    let conn = open_connection()?;

    let sql = "SELECT uuid, title, notes, status, stopDate, deadline, creationDate, \
               userModificationDate, project, area \
               FROM TMTask \
               WHERE type = 0 AND trashed = 0 AND status = 0 \
               ORDER BY todayIndex, \"index\"";

    fetch_todos_from_sql(&conn, sql, &[])
}

/// Fetch todos for a specific project.
///
/// # Errors
///
/// Returns an error if the database cannot be opened or queried.
pub fn fetch_project_todos(project_id: &str) -> Result<Vec<Todo>, ClingsError> {
    let conn = open_connection()?;

    let sql = "SELECT uuid, title, notes, status, stopDate, deadline, creationDate, \
               userModificationDate, project, area \
               FROM TMTask \
               WHERE type = 0 AND trashed = 0 AND project = ? \
               ORDER BY \"index\"";

    fetch_todos_from_sql(&conn, sql, &[&project_id])
}

// ============================================================================
// Helper functions
// ============================================================================

/// Calculate days since the Things reference date (2001-01-01).
fn days_since_reference_date(date: NaiveDate) -> i64 {
    let base = NaiveDate::from_ymd_opt(2001, 1, 1).unwrap_or_default();
    (date - base).num_days()
}

/// Convert status integer to Status enum.
const fn int_to_status(status_int: i32) -> Status {
    match status_int {
        2 => Status::Canceled,
        3 => Status::Completed,
        _ => Status::Open,
    }
}

/// Fetch tags for a task by its UUID.
fn fetch_tags_for_task(conn: &Connection, task_uuid: &str) -> Result<Vec<String>, ClingsError> {
    let sql = "SELECT tag.title \
               FROM TMTaskTag AS tt \
               JOIN TMTag AS tag ON tt.tags = tag.uuid \
               WHERE tt.tasks = ?";

    let mut stmt = conn
        .prepare(sql)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let tags = stmt
        .query_map(params![task_uuid], |row| row.get(0))
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    tags.collect::<Result<Vec<String>, _>>()
        .map_err(|e| ClingsError::Database(e.to_string()))
}

/// Fetch tags for an area by its UUID.
fn fetch_tags_for_area(conn: &Connection, area_uuid: &str) -> Result<Vec<String>, ClingsError> {
    let sql = "SELECT tag.title \
               FROM TMAreaTag AS at \
               JOIN TMTag AS tag ON at.tags = tag.uuid \
               WHERE at.areas = ?";

    let mut stmt = conn
        .prepare(sql)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let tags = stmt
        .query_map(params![area_uuid], |row| row.get(0))
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    tags.collect::<Result<Vec<String>, _>>()
        .map_err(|e| ClingsError::Database(e.to_string()))
}

/// Fetch checklist items for a task.
fn fetch_checklist_items(
    conn: &Connection,
    task_uuid: &str,
) -> Result<Vec<ChecklistItem>, ClingsError> {
    let sql = "SELECT title, status FROM TMChecklistItem WHERE task = ? ORDER BY \"index\"";

    let mut stmt = conn
        .prepare(sql)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let items = stmt
        .query_map(params![task_uuid], |row| {
            let title: String = row.get(0)?;
            let status: i32 = row.get(1)?;
            Ok(ChecklistItem {
                name: title,
                completed: status == 3,
            })
        })
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    items
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| ClingsError::Database(e.to_string()))
}

/// Look up project name by UUID.
fn lookup_project_name(
    conn: &Connection,
    project_uuid: &str,
) -> Result<Option<String>, ClingsError> {
    let sql = "SELECT title FROM TMTask WHERE uuid = ? AND type = 1";

    conn.query_row(sql, params![project_uuid], |row| row.get(0))
        .optional()
        .map_err(|e| ClingsError::Database(e.to_string()))
}

/// Look up project UUID by name.
///
/// # Errors
///
/// Returns an error if the database cannot be opened or queried.
pub fn lookup_project_id_by_name(name: &str) -> Result<Option<String>, ClingsError> {
    let conn = open_connection()?;
    let sql = "SELECT uuid FROM TMTask WHERE title = ? AND type = 1 AND trashed = 0 AND status = 0";

    conn.query_row(sql, params![name], |row| row.get(0))
        .optional()
        .map_err(|e| ClingsError::Database(e.to_string()))
}

/// Look up area name by UUID.
fn lookup_area_name(conn: &Connection, area_uuid: &str) -> Result<Option<String>, ClingsError> {
    let sql = "SELECT title FROM TMArea WHERE uuid = ?";

    conn.query_row(sql, params![area_uuid], |row| row.get(0))
        .optional()
        .map_err(|e| ClingsError::Database(e.to_string()))
}

/// Type alias for todo row data.
type TodoRowTuple = (
    String,
    String,
    Option<String>,
    i32,
    Option<f64>,
    Option<i64>,
    Option<f64>,
    Option<f64>,
    Option<String>,
    Option<String>,
);

/// Extract todo data from a row.
fn row_to_todo_tuple(row: &rusqlite::Row<'_>) -> rusqlite::Result<TodoRowTuple> {
    Ok((
        row.get(0)?, // uuid
        row.get(1)?, // title
        row.get(2)?, // notes
        row.get(3)?, // status
        row.get(4)?, // stopDate
        row.get(5)?, // deadline
        row.get(6)?, // creationDate
        row.get(7)?, // userModificationDate
        row.get(8)?, // project
        row.get(9)?, // area
    ))
}

/// Convert a todo tuple to a Todo struct.
#[allow(clippy::unnecessary_wraps)]
fn tuple_to_todo(conn: &Connection, tuple: TodoRowTuple) -> Result<Todo, ClingsError> {
    let (
        uuid,
        title,
        notes,
        status_int,
        stop_date,
        deadline,
        creation_date,
        modification_date,
        project_uuid,
        area_uuid,
    ) = tuple;

    let status = int_to_status(status_int);
    let due_date = deadline.and_then(things_date_to_naive_date);
    let creation_dt = creation_date.and_then(things_timestamp_to_datetime);
    let modification_dt = modification_date
        .or(stop_date)
        .and_then(things_timestamp_to_datetime);

    // Look up project and area names
    let project_name = project_uuid
        .as_ref()
        .and_then(|uuid| lookup_project_name(conn, uuid).ok())
        .flatten();
    let area_name = area_uuid
        .as_ref()
        .and_then(|uuid| lookup_area_name(conn, uuid).ok())
        .flatten();

    Ok(Todo {
        id: uuid,
        name: title,
        notes: notes.unwrap_or_default(),
        status,
        due_date,
        tags: Vec::new(), // Tags are fetched separately when needed
        project: project_name,
        area: area_name,
        checklist_items: Vec::new(), // Checklist items fetched separately
        creation_date: creation_dt,
        modification_date: modification_dt,
    })
}

/// Fetch todos using a custom SQL query with full enrichment (tags, project/area names).
fn fetch_todos_from_sql(
    conn: &Connection,
    sql: &str,
    params: &[&dyn rusqlite::ToSql],
) -> Result<Vec<Todo>, ClingsError> {
    let mut stmt = conn
        .prepare(sql)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let rows = stmt
        .query_map(params, row_to_todo_tuple)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let mut result = Vec::new();
    for row_result in rows {
        let tuple = row_result.map_err(|e| ClingsError::Database(e.to_string()))?;
        let mut todo = tuple_to_todo(conn, tuple)?;

        // Fetch tags for this todo
        todo.tags = fetch_tags_for_task(conn, &todo.id).unwrap_or_default();

        result.push(todo);
    }

    Ok(result)
}

/// Fetch todos with a WHERE clause filter and full enrichment.
fn fetch_todos_full(
    conn: &Connection,
    where_clause: &str,
    params: &[&dyn rusqlite::ToSql],
) -> Result<Vec<Todo>, ClingsError> {
    let sql = format!(
        "SELECT uuid, title, notes, status, stopDate, deadline, creationDate, \
         userModificationDate, project, area \
         FROM TMTask \
         WHERE {where_clause} \
         ORDER BY todayIndex, \"index\""
    );

    fetch_todos_from_sql(conn, &sql, params)
}

/// Fetch todos with a custom WHERE filter.
fn fetch_todos_with_filter(
    conn: &Connection,
    where_clause: &str,
    params: &[&dyn rusqlite::ToSql],
) -> Result<Vec<Todo>, ClingsError> {
    let sql = format!(
        "SELECT uuid, title, notes, status, stopDate, deadline, creationDate, userModificationDate
         FROM TMTask
         WHERE {where_clause}
         ORDER BY todayIndex, \"index\""
    );

    let mut stmt = conn
        .prepare(&sql)
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let todos = stmt
        .query_map(params, |row| {
            let uuid: String = row.get(0)?;
            let title: String = row.get(1)?;
            let notes: Option<String> = row.get(2)?;
            let status_int: i32 = row.get(3)?;
            let stop_date: Option<f64> = row.get(4)?;
            let deadline: Option<i64> = row.get(5)?;
            let creation_date: Option<f64> = row.get(6)?;
            let modification_date: Option<f64> = row.get(7)?;

            Ok((
                uuid,
                title,
                notes,
                status_int,
                stop_date,
                deadline,
                creation_date,
                modification_date,
            ))
        })
        .map_err(|e| ClingsError::Database(e.to_string()))?;

    let mut result = Vec::new();
    for todo_result in todos {
        let (uuid, title, notes, status_int, stop_date, deadline, creation_date, modification_date) =
            todo_result.map_err(|e| ClingsError::Database(e.to_string()))?;

        let status = int_to_status(status_int);

        let due_date = deadline.and_then(things_date_to_naive_date);
        let creation_dt = creation_date.and_then(things_timestamp_to_datetime);
        let modification_dt = modification_date
            .or(stop_date)
            .and_then(things_timestamp_to_datetime);

        result.push(Todo {
            id: uuid,
            name: title,
            notes: notes.unwrap_or_default(),
            status,
            due_date,
            tags: Vec::new(),
            project: None,
            area: None,
            checklist_items: Vec::new(),
            creation_date: creation_dt,
            modification_date: modification_dt,
        });
    }

    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Datelike;

    #[test]
    fn test_things_timestamp_conversion() {
        // 2024-01-01 00:00:00 UTC in Core Data timestamp
        // Core Data epoch is 2001-01-01
        // 23 years = ~725760000 seconds
        let timestamp = 725760000.0;
        let dt = things_timestamp_to_datetime(timestamp);
        assert!(dt.is_some());
        let dt = dt.unwrap();
        assert_eq!(dt.year(), 2024);
        assert_eq!(dt.month(), 1);
        assert_eq!(dt.day(), 1);
    }

    #[test]
    fn test_things_date_conversion() {
        // 2024-01-01 is 8400 days after 2001-01-01 (8401 gives Jan 2)
        let days = 8400;
        let date = things_date_to_naive_date(days);
        assert!(date.is_some());
        let date = date.unwrap();
        assert_eq!(date.year(), 2024);
        assert_eq!(date.month(), 1);
        assert_eq!(date.day(), 1);
    }

    #[test]
    fn test_find_database_path_format() {
        // Just verify the function doesn't panic
        let _ = find_database_path();
    }
}
