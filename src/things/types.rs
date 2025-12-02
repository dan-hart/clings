use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

use crate::core::{FieldValue, Filterable, Schedulable};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Todo {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub notes: String,
    pub status: Status,
    #[serde(default)]
    pub due_date: Option<NaiveDate>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub project: Option<String>,
    #[serde(default)]
    pub area: Option<String>,
    #[serde(default)]
    pub checklist_items: Vec<ChecklistItem>,
    #[serde(default)]
    pub creation_date: Option<DateTime<Utc>>,
    #[serde(default)]
    pub modification_date: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChecklistItem {
    pub name: String,
    pub completed: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Status {
    Open,
    Completed,
    Canceled,
}

impl std::fmt::Display for Status {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Status::Open => write!(f, "open"),
            Status::Completed => write!(f, "completed"),
            Status::Canceled => write!(f, "canceled"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Project {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub notes: String,
    pub status: Status,
    #[serde(default)]
    pub area: Option<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub due_date: Option<NaiveDate>,
    #[serde(default)]
    pub creation_date: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Area {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub tags: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Tag {
    pub id: String,
    pub name: String,
}

/// Response from creating a new item
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateResponse {
    pub id: String,
    pub name: String,
}

/// Result of a batch operation (e.g., complete_todos_batch)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BatchResult {
    /// Number of items successfully processed
    pub succeeded: usize,
    /// Number of items that failed
    pub failed: usize,
    /// Details of failures
    #[serde(default)]
    pub errors: Vec<BatchError>,
}

/// Error details for a batch operation failure
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BatchError {
    /// ID of the item that failed
    pub id: String,
    /// Error message
    pub error: String,
}

/// Result of get_all_lists - todos from all list views
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AllListsResult {
    #[serde(default)]
    pub inbox: Vec<Todo>,
    #[serde(default)]
    pub today: Vec<Todo>,
    #[serde(default)]
    pub upcoming: Vec<Todo>,
    #[serde(default)]
    pub anytime: Vec<Todo>,
    #[serde(default)]
    pub someday: Vec<Todo>,
    #[serde(default)]
    pub logbook: Vec<Todo>,
}

/// Result of get_open_lists - todos from open list views (excludes Logbook)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OpenListsResult {
    #[serde(default)]
    pub inbox: Vec<Todo>,
    #[serde(default)]
    pub today: Vec<Todo>,
    #[serde(default)]
    pub upcoming: Vec<Todo>,
    #[serde(default)]
    pub anytime: Vec<Todo>,
    #[serde(default)]
    pub someday: Vec<Todo>,
}

/// A list view (Today, Inbox, etc.)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ListView {
    Inbox,
    Today,
    Upcoming,
    Anytime,
    Someday,
    Logbook,
    Trash,
}

impl ListView {
    pub fn as_str(&self) -> &'static str {
        match self {
            ListView::Inbox => "Inbox",
            ListView::Today => "Today",
            ListView::Upcoming => "Upcoming",
            ListView::Anytime => "Anytime",
            ListView::Someday => "Someday",
            ListView::Logbook => "Logbook",
            ListView::Trash => "Trash",
        }
    }

    pub fn jxa_list_name(&self) -> &'static str {
        match self {
            ListView::Inbox => "inbox",
            ListView::Today => "today",
            ListView::Upcoming => "upcoming",
            ListView::Anytime => "anytime",
            ListView::Someday => "someday",
            ListView::Logbook => "logbook",
            ListView::Trash => "trash",
        }
    }
}

impl std::fmt::Display for ListView {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

// Implement Filterable for Todo
impl Filterable for Todo {
    fn field_value(&self, field: &str) -> Option<FieldValue> {
        match field.to_lowercase().as_str() {
            "id" => Some(FieldValue::String(self.id.clone())),
            "name" | "title" => Some(FieldValue::String(self.name.clone())),
            "notes" => Some(FieldValue::String(self.notes.clone())),
            "status" => Some(FieldValue::String(self.status.to_string())),
            "due" | "due_date" | "duedate" => Some(FieldValue::OptionalDate(self.due_date)),
            "tags" => Some(FieldValue::StringList(self.tags.clone())),
            "project" => Some(FieldValue::OptionalString(self.project.clone())),
            "area" => Some(FieldValue::OptionalString(self.area.clone())),
            "created" | "creation_date" | "creationdate" => {
                self.creation_date.map(|dt| FieldValue::Date(dt.date_naive()))
            }
            "modified" | "modification_date" | "modificationdate" => {
                self.modification_date.map(|dt| FieldValue::Date(dt.date_naive()))
            }
            _ => None,
        }
    }

    fn id(&self) -> &str {
        &self.id
    }

    fn name(&self) -> &str {
        &self.name
    }
}

// Implement Schedulable for Todo
impl Schedulable for Todo {
    fn when_date(&self) -> Option<NaiveDate> {
        self.due_date
    }

    fn deadline(&self) -> Option<NaiveDate> {
        // Things 3 treats due_date as both "when" and "deadline"
        // In the future, we might want to distinguish these
        self.due_date
    }
}

// Implement Filterable for Project
impl Filterable for Project {
    fn field_value(&self, field: &str) -> Option<FieldValue> {
        match field.to_lowercase().as_str() {
            "id" => Some(FieldValue::String(self.id.clone())),
            "name" | "title" => Some(FieldValue::String(self.name.clone())),
            "notes" => Some(FieldValue::String(self.notes.clone())),
            "status" => Some(FieldValue::String(self.status.to_string())),
            "due" | "due_date" | "duedate" => Some(FieldValue::OptionalDate(self.due_date)),
            "tags" => Some(FieldValue::StringList(self.tags.clone())),
            "area" => Some(FieldValue::OptionalString(self.area.clone())),
            "created" | "creation_date" | "creationdate" => {
                self.creation_date.map(|dt| FieldValue::Date(dt.date_naive()))
            }
            _ => None,
        }
    }

    fn id(&self) -> &str {
        &self.id
    }

    fn name(&self) -> &str {
        &self.name
    }
}

// Implement Schedulable for Project
impl Schedulable for Project {
    fn when_date(&self) -> Option<NaiveDate> {
        self.due_date
    }

    fn deadline(&self) -> Option<NaiveDate> {
        self.due_date
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Helper to create a test todo
    fn make_todo(name: &str, status: Status) -> Todo {
        Todo {
            id: "test-id".to_string(),
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

    // ==================== Status Tests ====================

    #[test]
    fn test_status_display_open() {
        assert_eq!(Status::Open.to_string(), "open");
    }

    #[test]
    fn test_status_display_completed() {
        assert_eq!(Status::Completed.to_string(), "completed");
    }

    #[test]
    fn test_status_display_canceled() {
        assert_eq!(Status::Canceled.to_string(), "canceled");
    }

    #[test]
    fn test_status_equality() {
        assert_eq!(Status::Open, Status::Open);
        assert_ne!(Status::Open, Status::Completed);
        assert_ne!(Status::Completed, Status::Canceled);
    }

    // ==================== ListView Tests ====================

    #[test]
    fn test_listview_as_str() {
        assert_eq!(ListView::Inbox.as_str(), "Inbox");
        assert_eq!(ListView::Today.as_str(), "Today");
        assert_eq!(ListView::Upcoming.as_str(), "Upcoming");
        assert_eq!(ListView::Anytime.as_str(), "Anytime");
        assert_eq!(ListView::Someday.as_str(), "Someday");
        assert_eq!(ListView::Logbook.as_str(), "Logbook");
        assert_eq!(ListView::Trash.as_str(), "Trash");
    }

    #[test]
    fn test_listview_jxa_list_name() {
        assert_eq!(ListView::Inbox.jxa_list_name(), "inbox");
        assert_eq!(ListView::Today.jxa_list_name(), "today");
        assert_eq!(ListView::Upcoming.jxa_list_name(), "upcoming");
        assert_eq!(ListView::Anytime.jxa_list_name(), "anytime");
        assert_eq!(ListView::Someday.jxa_list_name(), "someday");
        assert_eq!(ListView::Logbook.jxa_list_name(), "logbook");
        assert_eq!(ListView::Trash.jxa_list_name(), "trash");
    }

    #[test]
    fn test_listview_display() {
        assert_eq!(format!("{}", ListView::Today), "Today");
        assert_eq!(format!("{}", ListView::Inbox), "Inbox");
    }

    // ==================== Todo Serialization Tests ====================

    #[test]
    fn test_todo_deserialize_minimal() {
        let json = r#"{
            "id": "abc123",
            "name": "Test Task",
            "status": "open"
        }"#;

        let todo: Todo = serde_json::from_str(json).unwrap();
        assert_eq!(todo.id, "abc123");
        assert_eq!(todo.name, "Test Task");
        assert_eq!(todo.status, Status::Open);
        assert!(todo.notes.is_empty());
        assert!(todo.tags.is_empty());
        assert!(todo.due_date.is_none());
    }

    #[test]
    fn test_todo_deserialize_full() {
        let json = r#"{
            "id": "xyz789",
            "name": "Full Task",
            "notes": "Some notes here",
            "status": "completed",
            "dueDate": "2024-12-15",
            "tags": ["work", "urgent"],
            "project": "Project A",
            "area": "Work",
            "checklistItems": [
                {"name": "Step 1", "completed": true},
                {"name": "Step 2", "completed": false}
            ]
        }"#;

        let todo: Todo = serde_json::from_str(json).unwrap();
        assert_eq!(todo.id, "xyz789");
        assert_eq!(todo.name, "Full Task");
        assert_eq!(todo.notes, "Some notes here");
        assert_eq!(todo.status, Status::Completed);
        assert_eq!(todo.due_date, Some(NaiveDate::from_ymd_opt(2024, 12, 15).unwrap()));
        assert_eq!(todo.tags, vec!["work", "urgent"]);
        assert_eq!(todo.project, Some("Project A".to_string()));
        assert_eq!(todo.area, Some("Work".to_string()));
        assert_eq!(todo.checklist_items.len(), 2);
        assert!(todo.checklist_items[0].completed);
        assert!(!todo.checklist_items[1].completed);
    }

    #[test]
    fn test_todo_serialize_roundtrip() {
        let todo = Todo {
            id: "test-123".to_string(),
            name: "Roundtrip Test".to_string(),
            notes: "Notes".to_string(),
            status: Status::Open,
            due_date: Some(NaiveDate::from_ymd_opt(2024, 6, 15).unwrap()),
            tags: vec!["tag1".to_string()],
            project: Some("Project".to_string()),
            area: None,
            checklist_items: vec![],
            creation_date: None,
            modification_date: None,
        };

        let json = serde_json::to_string(&todo).unwrap();
        let deserialized: Todo = serde_json::from_str(&json).unwrap();

        assert_eq!(todo.id, deserialized.id);
        assert_eq!(todo.name, deserialized.name);
        assert_eq!(todo.status, deserialized.status);
        assert_eq!(todo.due_date, deserialized.due_date);
    }

    // ==================== BatchResult Tests ====================

    #[test]
    fn test_batch_result_default() {
        let result = BatchResult::default();
        assert_eq!(result.succeeded, 0);
        assert_eq!(result.failed, 0);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn test_batch_result_deserialize() {
        let json = r#"{
            "succeeded": 5,
            "failed": 2,
            "errors": [
                {"id": "abc", "error": "Not found"},
                {"id": "xyz", "error": "Permission denied"}
            ]
        }"#;

        let result: BatchResult = serde_json::from_str(json).unwrap();
        assert_eq!(result.succeeded, 5);
        assert_eq!(result.failed, 2);
        assert_eq!(result.errors.len(), 2);
        assert_eq!(result.errors[0].id, "abc");
        assert_eq!(result.errors[0].error, "Not found");
    }

    // ==================== AllListsResult Tests ====================

    #[test]
    fn test_all_lists_result_default() {
        let result = AllListsResult::default();
        assert!(result.inbox.is_empty());
        assert!(result.today.is_empty());
        assert!(result.upcoming.is_empty());
        assert!(result.anytime.is_empty());
        assert!(result.someday.is_empty());
        assert!(result.logbook.is_empty());
    }

    #[test]
    fn test_all_lists_result_deserialize() {
        let json = r#"{
            "inbox": [{"id": "1", "name": "Task 1", "status": "open"}],
            "today": [{"id": "2", "name": "Task 2", "status": "open"}],
            "upcoming": [],
            "anytime": [],
            "someday": [],
            "logbook": []
        }"#;

        let result: AllListsResult = serde_json::from_str(json).unwrap();
        assert_eq!(result.inbox.len(), 1);
        assert_eq!(result.today.len(), 1);
        assert_eq!(result.inbox[0].name, "Task 1");
        assert_eq!(result.today[0].name, "Task 2");
    }

    // ==================== Filterable Trait Tests ====================

    #[test]
    fn test_todo_filterable_id() {
        let todo = make_todo("Test", Status::Open);
        assert_eq!(todo.id(), "test-id");
    }

    #[test]
    fn test_todo_filterable_name() {
        let todo = make_todo("My Task", Status::Open);
        assert_eq!(todo.name(), "My Task");
    }

    #[test]
    fn test_todo_filterable_field_value_name() {
        let todo = make_todo("Task Name", Status::Open);
        if let Some(FieldValue::String(name)) = todo.field_value("name") {
            assert_eq!(name, "Task Name");
        } else {
            panic!("Expected String field value");
        }
    }

    #[test]
    fn test_todo_filterable_field_value_title_alias() {
        let todo = make_todo("Task Name", Status::Open);
        if let Some(FieldValue::String(name)) = todo.field_value("title") {
            assert_eq!(name, "Task Name");
        } else {
            panic!("Expected String field value for title alias");
        }
    }

    #[test]
    fn test_todo_filterable_field_value_status() {
        let todo = make_todo("Task", Status::Completed);
        if let Some(FieldValue::String(status)) = todo.field_value("status") {
            assert_eq!(status, "completed");
        } else {
            panic!("Expected String field value for status");
        }
    }

    #[test]
    fn test_todo_filterable_field_value_tags() {
        let mut todo = make_todo("Task", Status::Open);
        todo.tags = vec!["work".to_string(), "urgent".to_string()];

        if let Some(FieldValue::StringList(tags)) = todo.field_value("tags") {
            assert_eq!(tags, vec!["work", "urgent"]);
        } else {
            panic!("Expected StringList field value for tags");
        }
    }

    #[test]
    fn test_todo_filterable_field_value_due_date() {
        let mut todo = make_todo("Task", Status::Open);
        todo.due_date = Some(NaiveDate::from_ymd_opt(2024, 12, 25).unwrap());

        if let Some(FieldValue::OptionalDate(date)) = todo.field_value("due") {
            assert_eq!(date, Some(NaiveDate::from_ymd_opt(2024, 12, 25).unwrap()));
        } else {
            panic!("Expected OptionalDate field value");
        }
    }

    #[test]
    fn test_todo_filterable_field_value_unknown() {
        let todo = make_todo("Task", Status::Open);
        assert!(todo.field_value("unknown_field").is_none());
    }

    // ==================== Schedulable Trait Tests ====================

    #[test]
    fn test_todo_schedulable_when_date() {
        let mut todo = make_todo("Task", Status::Open);
        todo.due_date = Some(NaiveDate::from_ymd_opt(2024, 12, 25).unwrap());

        assert_eq!(todo.when_date(), Some(NaiveDate::from_ymd_opt(2024, 12, 25).unwrap()));
    }

    #[test]
    fn test_todo_schedulable_when_date_none() {
        let todo = make_todo("Task", Status::Open);
        assert!(todo.when_date().is_none());
    }

    #[test]
    fn test_todo_schedulable_deadline() {
        let mut todo = make_todo("Task", Status::Open);
        todo.due_date = Some(NaiveDate::from_ymd_opt(2024, 12, 25).unwrap());

        assert_eq!(todo.deadline(), Some(NaiveDate::from_ymd_opt(2024, 12, 25).unwrap()));
    }

    // ==================== Project Tests ====================

    #[test]
    fn test_project_deserialize() {
        let json = r#"{
            "id": "proj-1",
            "name": "My Project",
            "notes": "Project notes",
            "status": "open",
            "area": "Work",
            "tags": ["important"]
        }"#;

        let project: Project = serde_json::from_str(json).unwrap();
        assert_eq!(project.id, "proj-1");
        assert_eq!(project.name, "My Project");
        assert_eq!(project.area, Some("Work".to_string()));
    }

    #[test]
    fn test_project_filterable() {
        let project = Project {
            id: "proj-1".to_string(),
            name: "Test Project".to_string(),
            notes: String::new(),
            status: Status::Open,
            area: Some("Work".to_string()),
            tags: vec!["urgent".to_string()],
            due_date: None,
            creation_date: None,
        };

        assert_eq!(project.id(), "proj-1");
        assert_eq!(project.name(), "Test Project");

        if let Some(FieldValue::OptionalString(area)) = project.field_value("area") {
            assert_eq!(area, Some("Work".to_string()));
        } else {
            panic!("Expected OptionalString field value");
        }
    }

    // ==================== Area and Tag Tests ====================

    #[test]
    fn test_area_deserialize() {
        let json = r#"{"id": "area-1", "name": "Home", "tags": ["personal"]}"#;
        let area: Area = serde_json::from_str(json).unwrap();
        assert_eq!(area.id, "area-1");
        assert_eq!(area.name, "Home");
        assert_eq!(area.tags, vec!["personal"]);
    }

    #[test]
    fn test_tag_deserialize() {
        let json = r#"{"id": "tag-1", "name": "urgent"}"#;
        let tag: Tag = serde_json::from_str(json).unwrap();
        assert_eq!(tag.id, "tag-1");
        assert_eq!(tag.name, "urgent");
    }

    // ==================== CreateResponse Tests ====================

    #[test]
    fn test_create_response_deserialize() {
        let json = r#"{"id": "new-123", "name": "New Item"}"#;
        let response: CreateResponse = serde_json::from_str(json).unwrap();
        assert_eq!(response.id, "new-123");
        assert_eq!(response.name, "New Item");
    }
}
