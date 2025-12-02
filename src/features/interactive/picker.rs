//! Fuzzy picker implementation using skim.
//!
//! Provides an interactive terminal interface for selecting todos.

use std::sync::Arc;

use skim::prelude::*;

use crate::things::Todo;

/// Action to perform on selected item(s).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum PickAction {
    /// Show the item details (default).
    #[default]
    Show,
    /// Mark the item as complete.
    Complete,
    /// Mark the item as canceled.
    Cancel,
    /// Open the item in Things.
    Open,
    /// Edit the item (future).
    Edit,
}

impl std::fmt::Display for PickAction {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Show => write!(f, "show"),
            Self::Complete => write!(f, "complete"),
            Self::Cancel => write!(f, "cancel"),
            Self::Open => write!(f, "open"),
            Self::Edit => write!(f, "edit"),
        }
    }
}

impl std::str::FromStr for PickAction {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "show" => Ok(Self::Show),
            "complete" => Ok(Self::Complete),
            "cancel" => Ok(Self::Cancel),
            "open" => Ok(Self::Open),
            "edit" => Ok(Self::Edit),
            _ => Err(format!("Unknown action: {s}")),
        }
    }
}

/// Options for the picker.
#[derive(Debug, Clone, Default)]
pub struct PickOptions {
    /// Action to perform on selection.
    pub action: PickAction,
    /// Allow multiple selections.
    pub multi: bool,
    /// Initial query string.
    pub query: Option<String>,
    /// Prompt text.
    pub prompt: Option<String>,
    /// Preview command (if any).
    pub preview: bool,
}

/// Result of the picker interaction.
#[derive(Debug, Clone)]
pub struct PickResult {
    /// Selected todo IDs.
    pub selected_ids: Vec<String>,
    /// Selected todo names.
    pub selected_names: Vec<String>,
    /// The action to perform.
    pub action: PickAction,
    /// Whether the user aborted.
    pub aborted: bool,
}

/// A wrapper around Todo that implements SkimItem.
struct TodoItem {
    todo: Todo,
    display: String,
}

impl TodoItem {
    fn new(todo: Todo) -> Self {
        let status_icon = match todo.status {
            crate::things::types::Status::Open => "[ ]",
            crate::things::types::Status::Completed => "[x]",
            crate::things::types::Status::Canceled => "[-]",
        };

        let due = todo
            .due_date
            .map(|d| format!(" ({})", d.format("%Y-%m-%d")))
            .unwrap_or_default();

        let tags = if todo.tags.is_empty() {
            String::new()
        } else {
            format!(" #{}", todo.tags.join(" #"))
        };

        let project = todo
            .project
            .as_ref()
            .map(|p| format!(" [{}]", p))
            .unwrap_or_default();

        let display = format!(
            "{} {}{}{}{}",
            status_icon, todo.name, due, project, tags
        );

        Self { todo, display }
    }
}

impl SkimItem for TodoItem {
    fn text(&self) -> Cow<'_, str> {
        Cow::Borrowed(&self.display)
    }

    fn preview(&self, _context: PreviewContext<'_>) -> ItemPreview {
        let mut preview = String::new();

        preview.push_str(&format!("Title: {}\n", self.todo.name));
        preview.push_str(&format!("ID: {}\n", self.todo.id));
        preview.push_str(&format!("Status: {}\n", self.todo.status));

        if let Some(ref project) = self.todo.project {
            preview.push_str(&format!("Project: {}\n", project));
        }

        if let Some(ref area) = self.todo.area {
            preview.push_str(&format!("Area: {}\n", area));
        }

        if let Some(due) = self.todo.due_date {
            preview.push_str(&format!("Due: {}\n", due.format("%Y-%m-%d")));
        }

        if !self.todo.tags.is_empty() {
            preview.push_str(&format!("Tags: {}\n", self.todo.tags.join(", ")));
        }

        if !self.todo.notes.is_empty() {
            preview.push_str(&format!("\nNotes:\n{}\n", self.todo.notes));
        }

        if !self.todo.checklist_items.is_empty() {
            preview.push_str("\nChecklist:\n");
            for item in &self.todo.checklist_items {
                let check = if item.completed { "[x]" } else { "[ ]" };
                preview.push_str(&format!("  {} {}\n", check, item.name));
            }
        }

        ItemPreview::Text(preview)
    }

    fn output(&self) -> Cow<'_, str> {
        // Return the ID for easy processing
        Cow::Borrowed(&self.todo.id)
    }
}

/// Run the interactive picker on a list of todos.
///
/// Returns the selected items and action, or None if aborted.
pub fn pick_todos(todos: Vec<Todo>, options: PickOptions) -> Option<PickResult> {
    if todos.is_empty() {
        return None;
    }

    // Prepare header string (must be stored in a variable to live long enough)
    let header = format!(
        "Action: {} | Enter: select | Ctrl-C: cancel{}",
        options.action,
        if options.multi { " | Tab: toggle" } else { "" }
    );

    // Create skim options
    let skim_options = SkimOptionsBuilder::default()
        .height(Some("50%"))
        .multi(options.multi)
        .prompt(Some(
            options
                .prompt
                .as_deref()
                .unwrap_or("Select todo > "),
        ))
        .query(options.query.as_deref())
        .preview(if options.preview {
            Some("")
        } else {
            None
        })
        .preview_window(if options.preview {
            Some("right:50%:wrap")
        } else {
            None
        })
        .bind(vec![
            // Keybindings for actions
            "ctrl-o:accept", // Open in Things
            "ctrl-c:abort",  // Abort
            "enter:accept",  // Accept selection
            "tab:toggle",    // Toggle selection in multi mode
        ])
        .header(Some(&header))
        .build()
        .ok()?;

    // Create items
    let items: Vec<Arc<dyn SkimItem>> = todos
        .into_iter()
        .map(|t| {
            let item: Arc<dyn SkimItem> = Arc::new(TodoItem::new(t));
            item
        })
        .collect();

    // Create receiver
    let (tx, rx): (SkimItemSender, SkimItemReceiver) = unbounded();

    // Send items
    for item in items {
        let _ = tx.send(item);
    }
    drop(tx); // Close sender

    // Run skim
    let output = Skim::run_with(&skim_options, Some(rx))?;

    if output.is_abort {
        return Some(PickResult {
            selected_ids: vec![],
            selected_names: vec![],
            action: options.action,
            aborted: true,
        });
    }

    // Extract selected items
    let selected: Vec<_> = output
        .selected_items
        .iter()
        .map(|item| {
            // The output() method returns the ID
            let id = item.output().to_string();
            let name = item.text().to_string();
            (id, name)
        })
        .collect();

    let selected_ids: Vec<String> = selected.iter().map(|(id, _)| id.clone()).collect();
    let selected_names: Vec<String> = selected.iter().map(|(_, name)| name.clone()).collect();

    Some(PickResult {
        selected_ids,
        selected_names,
        action: options.action,
        aborted: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pick_action_display() {
        assert_eq!(PickAction::Show.to_string(), "show");
        assert_eq!(PickAction::Complete.to_string(), "complete");
        assert_eq!(PickAction::Cancel.to_string(), "cancel");
        assert_eq!(PickAction::Open.to_string(), "open");
    }

    #[test]
    fn test_pick_action_from_str() {
        assert_eq!("show".parse::<PickAction>().unwrap(), PickAction::Show);
        assert_eq!(
            "complete".parse::<PickAction>().unwrap(),
            PickAction::Complete
        );
        assert_eq!("CANCEL".parse::<PickAction>().unwrap(), PickAction::Cancel);
        assert!("invalid".parse::<PickAction>().is_err());
    }

    #[test]
    fn test_pick_options_default() {
        let opts = PickOptions::default();
        assert_eq!(opts.action, PickAction::Show);
        assert!(!opts.multi);
        assert!(opts.query.is_none());
    }

    #[test]
    fn test_todo_item_display() {
        use crate::things::types::Status;

        let todo = Todo {
            id: "test-123".to_string(),
            name: "Buy milk".to_string(),
            notes: String::new(),
            status: Status::Open,
            due_date: None,
            tags: vec!["errands".to_string()],
            project: Some("Home".to_string()),
            area: None,
            checklist_items: vec![],
            creation_date: None,
            modification_date: None,
        };

        let item = TodoItem::new(todo);
        assert!(item.display.contains("Buy milk"));
        assert!(item.display.contains("[Home]"));
        assert!(item.display.contains("#errands"));
    }

    #[test]
    fn test_pick_todos_empty() {
        let result = pick_todos(vec![], PickOptions::default());
        assert!(result.is_none());
    }
}
