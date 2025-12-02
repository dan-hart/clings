use colored::Colorize;

use crate::things::{Area, Project, Status, Tag, Todo};

/// Format a list of todos as a pretty table
pub fn format_todos_pretty(todos: &[Todo], title: &str) -> String {
    if todos.is_empty() {
        return format!("{} (0 items)\n  No items", title);
    }

    let mut output = format!("{} ({} items)\n", title, todos.len());
    output.push_str(&"─".repeat(60));
    output.push('\n');

    for todo in todos {
        let status_icon = match todo.status {
            Status::Open => "[ ]".white(),
            Status::Completed => "[x]".green(),
            Status::Canceled => "[-]".red(),
        };

        let name = match todo.status {
            Status::Canceled => todo.name.strikethrough().to_string(),
            _ => todo.name.clone(),
        };

        let mut line = format!("{} {}", status_icon, name.bold());

        // Add project if present
        if let Some(project) = &todo.project {
            line.push_str(&format!("  {}", project.dimmed()));
        }

        // Add due date if present
        if let Some(due) = &todo.due_date {
            line.push_str(&format!("  {}", due.to_string().yellow()));
        }

        // Add tags if present
        if !todo.tags.is_empty() {
            let tags_str = todo
                .tags
                .iter()
                .map(|t| format!("#{}", t))
                .collect::<Vec<_>>()
                .join(" ");
            line.push_str(&format!("  {}", tags_str.cyan()));
        }

        output.push_str(&line);
        output.push('\n');
    }

    output
}

/// Format a single todo as pretty output
pub fn format_todo_pretty(todo: &Todo) -> String {
    let status_icon = match todo.status {
        Status::Open => "[ ]".white(),
        Status::Completed => "[x]".green(),
        Status::Canceled => "[-]".red(),
    };

    let mut output = format!("{} {}\n", status_icon, todo.name.bold());
    output.push_str(&format!("  {}: {}\n", "ID".dimmed(), todo.id));
    output.push_str(&format!("  {}: {}\n", "Status".dimmed(), todo.status));

    if !todo.notes.is_empty() {
        output.push_str(&format!("  {}: {}\n", "Notes".dimmed(), todo.notes));
    }

    if let Some(project) = &todo.project {
        output.push_str(&format!("  {}: {}\n", "Project".dimmed(), project));
    }

    if let Some(area) = &todo.area {
        output.push_str(&format!("  {}: {}\n", "Area".dimmed(), area));
    }

    if let Some(due) = &todo.due_date {
        output.push_str(&format!("  {}: {}\n", "Due".dimmed(), due));
    }

    if !todo.tags.is_empty() {
        output.push_str(&format!(
            "  {}: {}\n",
            "Tags".dimmed(),
            todo.tags.join(", ")
        ));
    }

    if !todo.checklist_items.is_empty() {
        output.push_str(&format!("  {}:\n", "Checklist".dimmed()));
        for item in &todo.checklist_items {
            let icon = if item.completed { "[x]" } else { "[ ]" };
            output.push_str(&format!("    {} {}\n", icon, item.name));
        }
    }

    if let Some(created) = &todo.creation_date {
        output.push_str(&format!(
            "  {}: {}\n",
            "Created".dimmed(),
            created.format("%Y-%m-%d %H:%M")
        ));
    }

    output
}

/// Format a list of projects as pretty output
pub fn format_projects_pretty(projects: &[Project]) -> String {
    if projects.is_empty() {
        return "Projects (0)\n  No projects".to_string();
    }

    let mut output = format!("Projects ({})\n", projects.len());
    output.push_str(&"─".repeat(60));
    output.push('\n');

    for project in projects {
        let status_icon = match project.status {
            Status::Open => "▸".white(),
            Status::Completed => "✓".green(),
            Status::Canceled => "✗".red(),
        };

        let mut line = format!("{} {}", status_icon, project.name.bold());

        if let Some(area) = &project.area {
            line.push_str(&format!("  {}", area.dimmed()));
        }

        if let Some(due) = &project.due_date {
            line.push_str(&format!("  {}", due.to_string().yellow()));
        }

        output.push_str(&line);
        output.push('\n');
    }

    output
}

/// Format a list of areas as pretty output
pub fn format_areas_pretty(areas: &[Area]) -> String {
    if areas.is_empty() {
        return "Areas (0)\n  No areas".to_string();
    }

    let mut output = format!("Areas ({})\n", areas.len());
    output.push_str(&"─".repeat(40));
    output.push('\n');

    for area in areas {
        output.push_str(&format!("  {}\n", area.name.bold()));
    }

    output
}

/// Format a list of tags as pretty output
pub fn format_tags_pretty(tags: &[Tag]) -> String {
    if tags.is_empty() {
        return "Tags (0)\n  No tags".to_string();
    }

    let mut output = format!("Tags ({})\n", tags.len());
    output.push_str(&"─".repeat(40));
    output.push('\n');

    for tag in tags {
        output.push_str(&format!("  #{}\n", tag.name.cyan()));
    }

    output
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{NaiveDate, Utc};
    use crate::things::ChecklistItem;

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

    // Tests for format_todos_pretty
    #[test]
    fn test_format_todos_pretty_empty_list() {
        let todos: Vec<Todo> = vec![];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains("Today (0 items)"));
        assert!(output.contains("No items"));
    }

    #[test]
    fn test_format_todos_pretty_single_open_todo() {
        let todos = vec![make_todo("Buy groceries", Status::Open)];
        let output = format_todos_pretty(&todos, "Inbox");

        assert!(output.contains("Inbox (1 items)"));
        assert!(output.contains("[ ]"));
        assert!(output.contains("Buy groceries"));
    }

    #[test]
    fn test_format_todos_pretty_completed_todo() {
        let todos = vec![make_todo("Finished task", Status::Completed)];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains("[x]"));
        assert!(output.contains("Finished task"));
    }

    #[test]
    fn test_format_todos_pretty_canceled_todo() {
        let todos = vec![make_todo("Canceled task", Status::Canceled)];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains("[-]"));
        // Note: strikethrough may not be visible in plain text but the name should be there
        assert!(output.contains("Canceled task"));
    }

    #[test]
    fn test_format_todos_pretty_with_project() {
        let mut todo = make_todo("Project task", Status::Open);
        todo.project = Some("Website Redesign".to_string());
        let todos = vec![todo];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains("Project task"));
        assert!(output.contains("Website Redesign"));
    }

    #[test]
    fn test_format_todos_pretty_with_due_date() {
        let mut todo = make_todo("Due task", Status::Open);
        todo.due_date = Some(NaiveDate::from_ymd_opt(2025, 12, 15).unwrap());
        let todos = vec![todo];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains("Due task"));
        assert!(output.contains("2025-12-15"));
    }

    #[test]
    fn test_format_todos_pretty_with_tags() {
        let mut todo = make_todo("Tagged task", Status::Open);
        todo.tags = vec!["work".to_string(), "urgent".to_string()];
        let todos = vec![todo];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains("Tagged task"));
        assert!(output.contains("#work"));
        assert!(output.contains("#urgent"));
    }

    #[test]
    fn test_format_todos_pretty_with_all_metadata() {
        let mut todo = make_todo("Complex task", Status::Open);
        todo.project = Some("Big Project".to_string());
        todo.due_date = Some(NaiveDate::from_ymd_opt(2025, 12, 31).unwrap());
        todo.tags = vec!["important".to_string(), "review".to_string()];
        let todos = vec![todo];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains("Complex task"));
        assert!(output.contains("Big Project"));
        assert!(output.contains("2025-12-31"));
        assert!(output.contains("#important"));
        assert!(output.contains("#review"));
    }

    #[test]
    fn test_format_todos_pretty_multiple_todos() {
        let todos = vec![
            make_todo("First task", Status::Open),
            make_todo("Second task", Status::Completed),
            make_todo("Third task", Status::Canceled),
        ];
        let output = format_todos_pretty(&todos, "All");

        assert!(output.contains("All (3 items)"));
        assert!(output.contains("First task"));
        assert!(output.contains("Second task"));
        assert!(output.contains("Third task"));
    }

    #[test]
    fn test_format_todos_pretty_separator_line() {
        let todos = vec![make_todo("Test", Status::Open)];
        let output = format_todos_pretty(&todos, "Today");

        // Should contain a separator line
        assert!(output.contains("─"));
    }

    // Tests for format_todo_pretty (single todo detail view)
    #[test]
    fn test_format_todo_pretty_basic() {
        let todo = make_todo("Simple task", Status::Open);
        let output = format_todo_pretty(&todo);

        assert!(output.contains("[ ]"));
        assert!(output.contains("Simple task"));
        assert!(output.contains("ID: test-id-123"));
        assert!(output.contains("Status: open"));
    }

    #[test]
    fn test_format_todo_pretty_with_notes() {
        let mut todo = make_todo("Task with notes", Status::Open);
        todo.notes = "These are important notes".to_string();
        let output = format_todo_pretty(&todo);

        assert!(output.contains("Notes:"));
        assert!(output.contains("These are important notes"));
    }

    #[test]
    fn test_format_todo_pretty_with_project_and_area() {
        let mut todo = make_todo("Detailed task", Status::Open);
        todo.project = Some("My Project".to_string());
        todo.area = Some("Work".to_string());
        let output = format_todo_pretty(&todo);

        assert!(output.contains("Project: My Project"));
        assert!(output.contains("Area: Work"));
    }

    #[test]
    fn test_format_todo_pretty_with_checklist() {
        let mut todo = make_todo("Task with subtasks", Status::Open);
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
        let output = format_todo_pretty(&todo);

        assert!(output.contains("Checklist:"));
        assert!(output.contains("[x] Subtask 1"));
        assert!(output.contains("[ ] Subtask 2"));
    }

    #[test]
    fn test_format_todo_pretty_with_creation_date() {
        let mut todo = make_todo("Created task", Status::Open);
        todo.creation_date = Some(Utc::now());
        let output = format_todo_pretty(&todo);

        assert!(output.contains("Created:"));
    }

    #[test]
    fn test_format_todo_pretty_completed_status() {
        let todo = make_todo("Done task", Status::Completed);
        let output = format_todo_pretty(&todo);

        assert!(output.contains("[x]"));
        assert!(output.contains("Status: completed"));
    }

    #[test]
    fn test_format_todo_pretty_canceled_status() {
        let todo = make_todo("Cancelled task", Status::Canceled);
        let output = format_todo_pretty(&todo);

        assert!(output.contains("[-]"));
        assert!(output.contains("Status: canceled"));
    }

    // Tests for format_projects_pretty
    #[test]
    fn test_format_projects_pretty_empty_list() {
        let projects: Vec<Project> = vec![];
        let output = format_projects_pretty(&projects);

        assert!(output.contains("Projects (0)"));
        assert!(output.contains("No projects"));
    }

    #[test]
    fn test_format_projects_pretty_single_project() {
        let projects = vec![make_project("Website Redesign", Status::Open)];
        let output = format_projects_pretty(&projects);

        assert!(output.contains("Projects (1)"));
        assert!(output.contains("▸"));
        assert!(output.contains("Website Redesign"));
    }

    #[test]
    fn test_format_projects_pretty_completed_project() {
        let projects = vec![make_project("Completed Project", Status::Completed)];
        let output = format_projects_pretty(&projects);

        assert!(output.contains("✓"));
        assert!(output.contains("Completed Project"));
    }

    #[test]
    fn test_format_projects_pretty_canceled_project() {
        let projects = vec![make_project("Canceled Project", Status::Canceled)];
        let output = format_projects_pretty(&projects);

        assert!(output.contains("✗"));
        assert!(output.contains("Canceled Project"));
    }

    #[test]
    fn test_format_projects_pretty_with_area() {
        let mut project = make_project("Project with area", Status::Open);
        project.area = Some("Work".to_string());
        let projects = vec![project];
        let output = format_projects_pretty(&projects);

        assert!(output.contains("Project with area"));
        assert!(output.contains("Work"));
    }

    #[test]
    fn test_format_projects_pretty_with_due_date() {
        let mut project = make_project("Due project", Status::Open);
        project.due_date = Some(NaiveDate::from_ymd_opt(2025, 12, 31).unwrap());
        let projects = vec![project];
        let output = format_projects_pretty(&projects);

        assert!(output.contains("Due project"));
        assert!(output.contains("2025-12-31"));
    }

    #[test]
    fn test_format_projects_pretty_multiple_projects() {
        let projects = vec![
            make_project("Project A", Status::Open),
            make_project("Project B", Status::Completed),
            make_project("Project C", Status::Canceled),
        ];
        let output = format_projects_pretty(&projects);

        assert!(output.contains("Projects (3)"));
        assert!(output.contains("Project A"));
        assert!(output.contains("Project B"));
        assert!(output.contains("Project C"));
    }

    // Tests for format_areas_pretty
    #[test]
    fn test_format_areas_pretty_empty_list() {
        let areas: Vec<Area> = vec![];
        let output = format_areas_pretty(&areas);

        assert!(output.contains("Areas (0)"));
        assert!(output.contains("No areas"));
    }

    #[test]
    fn test_format_areas_pretty_single_area() {
        let areas = vec![make_area("Work")];
        let output = format_areas_pretty(&areas);

        assert!(output.contains("Areas (1)"));
        assert!(output.contains("Work"));
    }

    #[test]
    fn test_format_areas_pretty_multiple_areas() {
        let areas = vec![
            make_area("Personal"),
            make_area("Work"),
            make_area("Health"),
        ];
        let output = format_areas_pretty(&areas);

        assert!(output.contains("Areas (3)"));
        assert!(output.contains("Personal"));
        assert!(output.contains("Work"));
        assert!(output.contains("Health"));
    }

    #[test]
    fn test_format_areas_pretty_separator() {
        let areas = vec![make_area("Test Area")];
        let output = format_areas_pretty(&areas);

        assert!(output.contains("─"));
    }

    // Tests for format_tags_pretty
    #[test]
    fn test_format_tags_pretty_empty_list() {
        let tags: Vec<Tag> = vec![];
        let output = format_tags_pretty(&tags);

        assert!(output.contains("Tags (0)"));
        assert!(output.contains("No tags"));
    }

    #[test]
    fn test_format_tags_pretty_single_tag() {
        let tags = vec![make_tag("urgent")];
        let output = format_tags_pretty(&tags);

        assert!(output.contains("Tags (1)"));
        assert!(output.contains("#urgent"));
    }

    #[test]
    fn test_format_tags_pretty_multiple_tags() {
        let tags = vec![
            make_tag("work"),
            make_tag("personal"),
            make_tag("important"),
        ];
        let output = format_tags_pretty(&tags);

        assert!(output.contains("Tags (3)"));
        assert!(output.contains("#work"));
        assert!(output.contains("#personal"));
        assert!(output.contains("#important"));
    }

    // Edge case tests
    #[test]
    fn test_format_todos_pretty_special_characters() {
        let mut todo = make_todo("Task with \"quotes\" & symbols", Status::Open);
        todo.notes = "Special chars: @#$%^&*()".to_string();
        let todos = vec![todo];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains("Task with \"quotes\" & symbols"));
    }

    #[test]
    fn test_format_todos_pretty_long_name() {
        let long_name = "This is a very long task name that should still be displayed correctly without breaking the formatting of the output";
        let todos = vec![make_todo(long_name, Status::Open)];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains(long_name));
    }

    #[test]
    fn test_format_projects_pretty_long_name() {
        let long_name = "A very long project name that contains lots of text and should still render properly in the terminal output";
        let projects = vec![make_project(long_name, Status::Open)];
        let output = format_projects_pretty(&projects);

        assert!(output.contains(long_name));
    }

    #[test]
    fn test_format_todos_pretty_unicode_characters() {
        let todos = vec![make_todo("Task with emoji 🚀 and unicode ™", Status::Open)];
        let output = format_todos_pretty(&todos, "Today");

        assert!(output.contains("Task with emoji 🚀 and unicode ™"));
    }

    #[test]
    fn test_format_tags_pretty_with_spaces() {
        let tags = vec![make_tag("multi word tag")];
        let output = format_tags_pretty(&tags);

        assert!(output.contains("#multi word tag"));
    }

    #[test]
    fn test_format_todo_pretty_empty_notes_not_shown() {
        let todo = make_todo("Task without notes", Status::Open);
        let output = format_todo_pretty(&todo);

        // Notes field should not appear if notes are empty
        assert!(!output.contains("Notes:") || !output.contains("Notes: \n"));
    }

    #[test]
    fn test_format_todo_pretty_empty_checklist_not_shown() {
        let todo = make_todo("Task without checklist", Status::Open);
        let output = format_todo_pretty(&todo);

        // Checklist section should not appear if empty
        assert!(!output.contains("Checklist:"));
    }
}
