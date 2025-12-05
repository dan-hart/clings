//! JSON output formatting for clings.
//!
//! This module provides functions for formatting Things 3 data as JSON.

use serde::Serialize;
use serde_json::json;

use crate::error::ClingsError;
use crate::things::{Area, Project, Tag, Todo};

/// Format todos as JSON
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_todos_json(todos: &[Todo], list_name: &str) -> Result<String, ClingsError> {
    let output = json!({
        "list": list_name,
        "count": todos.len(),
        "items": todos
    });
    Ok(serde_json::to_string_pretty(&output)?)
}

/// Format a single todo as JSON
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_todo_json(todo: &Todo) -> Result<String, ClingsError> {
    Ok(serde_json::to_string_pretty(todo)?)
}

/// Format projects as JSON
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_projects_json(projects: &[Project]) -> Result<String, ClingsError> {
    let output = json!({
        "count": projects.len(),
        "items": projects
    });
    Ok(serde_json::to_string_pretty(&output)?)
}

/// Format areas as JSON
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_areas_json(areas: &[Area]) -> Result<String, ClingsError> {
    let output = json!({
        "count": areas.len(),
        "items": areas
    });
    Ok(serde_json::to_string_pretty(&output)?)
}

/// Format tags as JSON
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn format_tags_json(tags: &[Tag]) -> Result<String, ClingsError> {
    let output = json!({
        "count": tags.len(),
        "items": tags
    });
    Ok(serde_json::to_string_pretty(&output)?)
}

/// Generic JSON formatter for any serializable type
///
/// # Errors
///
/// Returns `ClingsError::Parse` if JSON serialization fails.
pub fn to_json<T: Serialize>(value: &T) -> Result<String, ClingsError> {
    Ok(serde_json::to_string_pretty(value)?)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::things::{ChecklistItem, Status};
    use chrono::{NaiveDate, Utc};

    fn make_todo(name: &str, status: Status) -> Todo {
        Todo {
            id: "test-id-123".to_string(),
            name: name.to_string(),
            notes: String::new(),
            status,
            due_date: None,
            tags: vec![],
            project: None,
            area: None,
            checklist_items: vec![],
            creation_date: None,
            modification_date: None,
        }
    }

    fn make_project(name: &str, status: Status) -> Project {
        Project {
            id: "project-id-456".to_string(),
            name: name.to_string(),
            notes: String::new(),
            status,
            area: None,
            tags: vec![],
            due_date: None,
            creation_date: None,
        }
    }

    fn make_area(name: &str) -> Area {
        Area {
            id: "area-id-789".to_string(),
            name: name.to_string(),
            tags: vec![],
        }
    }

    fn make_tag(name: &str) -> Tag {
        Tag {
            id: "tag-id-012".to_string(),
            name: name.to_string(),
        }
    }

    #[test]
    fn test_format_todos_json_empty_list() {
        let todos: Vec<Todo> = vec![];
        let result = format_todos_json(&todos, "Today").unwrap();

        assert!(result.contains("\"list\": \"Today\""));
        assert!(result.contains("\"count\": 0"));
        assert!(result.contains("\"items\": []"));
    }

    #[test]
    fn test_format_todos_json_single_todo() {
        let todos = vec![make_todo("Buy milk", Status::Open)];
        let result = format_todos_json(&todos, "Inbox").unwrap();

        assert!(result.contains("\"list\": \"Inbox\""));
        assert!(result.contains("\"count\": 1"));
        assert!(result.contains("\"name\": \"Buy milk\""));
        assert!(result.contains("\"id\": \"test-id-123\""));
        assert!(result.contains("\"status\": \"open\""));
    }

    #[test]
    fn test_format_todos_json_multiple_todos() {
        let todos = vec![
            make_todo("Task 1", Status::Open),
            make_todo("Task 2", Status::Completed),
            make_todo("Task 3", Status::Canceled),
        ];
        let result = format_todos_json(&todos, "Today").unwrap();

        assert!(result.contains("\"count\": 3"));
        assert!(result.contains("\"Task 1\""));
        assert!(result.contains("\"Task 2\""));
        assert!(result.contains("\"Task 3\""));
    }

    #[test]
    fn test_format_todos_json_with_tags() {
        let mut todo = make_todo("Tagged task", Status::Open);
        todo.tags = vec!["work".to_string(), "urgent".to_string()];
        let todos = vec![todo];
        let result = format_todos_json(&todos, "Today").unwrap();

        assert!(result.contains("\"tags\""));
        assert!(result.contains("\"work\""));
        assert!(result.contains("\"urgent\""));
    }

    #[test]
    fn test_format_todos_json_with_due_date() {
        let mut todo = make_todo("Due task", Status::Open);
        todo.due_date = Some(NaiveDate::from_ymd_opt(2025, 12, 15).unwrap());
        let todos = vec![todo];
        let result = format_todos_json(&todos, "Today").unwrap();

        assert!(result.contains("\"dueDate\": \"2025-12-15\""));
    }

    #[test]
    fn test_format_todos_json_with_project_and_area() {
        let mut todo = make_todo("Project task", Status::Open);
        todo.project = Some("My Project".to_string());
        todo.area = Some("Work".to_string());
        let todos = vec![todo];
        let result = format_todos_json(&todos, "Today").unwrap();

        assert!(result.contains("\"project\": \"My Project\""));
        assert!(result.contains("\"area\": \"Work\""));
    }

    #[test]
    fn test_format_todos_json_with_notes() {
        let mut todo = make_todo("Task with notes", Status::Open);
        todo.notes = "Important details here".to_string();
        let todos = vec![todo];
        let result = format_todos_json(&todos, "Today").unwrap();

        assert!(result.contains("\"notes\": \"Important details here\""));
    }

    #[test]
    fn test_format_todos_json_with_checklist() {
        let mut todo = make_todo("Task with checklist", Status::Open);
        todo.checklist_items = vec![
            ChecklistItem {
                name: "Subtask 1".to_string(),
                completed: true,
            },
            ChecklistItem {
                name: "Subtask 2".to_string(),
                completed: false,
            },
        ];
        let todos = vec![todo];
        let result = format_todos_json(&todos, "Today").unwrap();

        assert!(result.contains("\"checklistItems\""));
        assert!(result.contains("\"Subtask 1\""));
        assert!(result.contains("\"Subtask 2\""));
    }

    #[test]
    fn test_format_todo_json_single() {
        let todo = make_todo("Single task", Status::Completed);
        let result = format_todo_json(&todo).unwrap();

        assert!(result.contains("\"name\": \"Single task\""));
        assert!(result.contains("\"status\": \"completed\""));
        assert!(result.contains("\"id\": \"test-id-123\""));
    }

    #[test]
    fn test_format_projects_json_empty_list() {
        let projects: Vec<Project> = vec![];
        let result = format_projects_json(&projects).unwrap();

        assert!(result.contains("\"count\": 0"));
        assert!(result.contains("\"items\": []"));
    }

    #[test]
    fn test_format_projects_json_single_project() {
        let projects = vec![make_project("Website Redesign", Status::Open)];
        let result = format_projects_json(&projects).unwrap();

        assert!(result.contains("\"count\": 1"));
        assert!(result.contains("\"name\": \"Website Redesign\""));
        assert!(result.contains("\"id\": \"project-id-456\""));
    }

    #[test]
    fn test_format_projects_json_with_area_and_tags() {
        let mut project = make_project("Marketing Campaign", Status::Open);
        project.area = Some("Business".to_string());
        project.tags = vec!["q4".to_string(), "marketing".to_string()];
        let projects = vec![project];
        let result = format_projects_json(&projects).unwrap();

        assert!(result.contains("\"area\": \"Business\""));
        assert!(result.contains("\"q4\""));
        assert!(result.contains("\"marketing\""));
    }

    #[test]
    fn test_format_areas_json_empty_list() {
        let areas: Vec<Area> = vec![];
        let result = format_areas_json(&areas).unwrap();

        assert!(result.contains("\"count\": 0"));
        assert!(result.contains("\"items\": []"));
    }

    #[test]
    fn test_format_areas_json_multiple_areas() {
        let areas = vec![
            make_area("Work"),
            make_area("Personal"),
            make_area("Health"),
        ];
        let result = format_areas_json(&areas).unwrap();

        assert!(result.contains("\"count\": 3"));
        assert!(result.contains("\"Work\""));
        assert!(result.contains("\"Personal\""));
        assert!(result.contains("\"Health\""));
    }

    #[test]
    fn test_format_tags_json_empty_list() {
        let tags: Vec<Tag> = vec![];
        let result = format_tags_json(&tags).unwrap();

        assert!(result.contains("\"count\": 0"));
        assert!(result.contains("\"items\": []"));
    }

    #[test]
    fn test_format_tags_json_multiple_tags() {
        let tags = vec![make_tag("urgent"), make_tag("work"), make_tag("home")];
        let result = format_tags_json(&tags).unwrap();

        assert!(result.contains("\"count\": 3"));
        assert!(result.contains("\"urgent\""));
        assert!(result.contains("\"work\""));
        assert!(result.contains("\"home\""));
    }

    #[test]
    fn test_to_json_generic() {
        let todo = make_todo("Generic test", Status::Open);
        let result = to_json(&todo).unwrap();

        assert!(result.contains("\"name\": \"Generic test\""));
        assert!(result.contains("\"status\": \"open\""));
    }

    #[test]
    fn test_json_preserves_special_characters() {
        let mut todo = make_todo("Task with \"quotes\" and \\ backslashes", Status::Open);
        todo.notes = "Line 1\nLine 2\tTabbed".to_string();
        let result = format_todo_json(&todo).unwrap();

        // JSON should properly escape special characters
        assert!(result.contains("\\\"quotes\\\""));
        assert!(result.contains("\\\\"));
        assert!(result.contains("\\n"));
        assert!(result.contains("\\t"));
    }

    #[test]
    fn test_json_with_creation_date() {
        let mut todo = make_todo("Created task", Status::Open);
        todo.creation_date = Some(Utc::now());
        let result = format_todo_json(&todo).unwrap();

        assert!(result.contains("\"creationDate\""));
    }

    #[test]
    fn test_format_todos_json_all_statuses() {
        let todos = vec![
            make_todo("Open task", Status::Open),
            make_todo("Completed task", Status::Completed),
            make_todo("Canceled task", Status::Canceled),
        ];
        let result = format_todos_json(&todos, "All").unwrap();

        assert!(result.contains("\"status\": \"open\""));
        assert!(result.contains("\"status\": \"completed\""));
        assert!(result.contains("\"status\": \"canceled\""));
    }
}
