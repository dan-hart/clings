//! Actions for automation rules.
//!
//! Actions define what happens when a rule fires.

use serde::{Deserialize, Serialize};

use super::rule::RuleContext;

/// An action to perform.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Action {
    /// Action type
    pub action_type: ActionType,
    /// Action parameters
    pub params: ActionParams,
}

impl Action {
    /// Create a new action.
    #[must_use]
    pub fn new(action_type: ActionType, params: ActionParams) -> Self {
        Self { action_type, params }
    }

    /// Create an add todo action.
    #[must_use]
    pub fn add_todo(title: impl Into<String>) -> Self {
        Self::new(
            ActionType::AddTodo,
            ActionParams::AddTodo {
                title: title.into(),
                notes: None,
                project: None,
                tags: None,
                when: None,
                deadline: None,
            },
        )
    }

    /// Create a complete todo action.
    #[must_use]
    pub fn complete_todo(id: impl Into<String>) -> Self {
        Self::new(
            ActionType::CompleteTodo,
            ActionParams::TodoId { id: id.into() },
        )
    }

    /// Create an add tags action.
    #[must_use]
    pub fn add_tags(id: impl Into<String>, tags: Vec<String>) -> Self {
        Self::new(
            ActionType::AddTags,
            ActionParams::Tags {
                id: id.into(),
                tags,
            },
        )
    }

    /// Create a move todo action.
    #[must_use]
    pub fn move_todo(id: impl Into<String>, project: impl Into<String>) -> Self {
        Self::new(
            ActionType::MoveTodo,
            ActionParams::Move {
                id: id.into(),
                project: project.into(),
            },
        )
    }

    /// Create a log message action.
    #[must_use]
    pub fn log(message: impl Into<String>) -> Self {
        Self::new(
            ActionType::Log,
            ActionParams::Message {
                message: message.into(),
            },
        )
    }

    /// Create a notify action.
    #[must_use]
    pub fn notify(title: impl Into<String>, message: impl Into<String>) -> Self {
        Self::new(
            ActionType::Notify,
            ActionParams::Notification {
                title: title.into(),
                message: message.into(),
            },
        )
    }

    /// Create a shell command action.
    #[must_use]
    pub fn shell(command: impl Into<String>) -> Self {
        Self::new(
            ActionType::Shell,
            ActionParams::Command {
                command: command.into(),
            },
        )
    }

    /// Apply variable substitution to parameters.
    #[must_use]
    pub fn with_substitution(&self, context: &RuleContext) -> Self {
        let params = match &self.params {
            ActionParams::AddTodo {
                title,
                notes,
                project,
                tags,
                when,
                deadline,
            } => ActionParams::AddTodo {
                title: context.substitute(title),
                notes: notes.as_ref().map(|n| context.substitute(n)),
                project: project.as_ref().map(|p| context.substitute(p)),
                tags: tags.clone(),
                when: when.as_ref().map(|w| context.substitute(w)),
                deadline: deadline.as_ref().map(|d| context.substitute(d)),
            },
            ActionParams::TodoId { id } => ActionParams::TodoId {
                id: context.substitute(id),
            },
            ActionParams::Tags { id, tags } => ActionParams::Tags {
                id: context.substitute(id),
                tags: tags.clone(),
            },
            ActionParams::Move { id, project } => ActionParams::Move {
                id: context.substitute(id),
                project: context.substitute(project),
            },
            ActionParams::Message { message } => ActionParams::Message {
                message: context.substitute(message),
            },
            ActionParams::Notification { title, message } => ActionParams::Notification {
                title: context.substitute(title),
                message: context.substitute(message),
            },
            ActionParams::Command { command } => ActionParams::Command {
                command: context.substitute(command),
            },
            ActionParams::SetDue { id, date } => ActionParams::SetDue {
                id: context.substitute(id),
                date: context.substitute(date),
            },
            ActionParams::None => ActionParams::None,
        };

        Self {
            action_type: self.action_type,
            params,
        }
    }
}

/// Types of actions.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActionType {
    /// Add a new todo
    AddTodo,
    /// Complete a todo
    CompleteTodo,
    /// Cancel a todo
    CancelTodo,
    /// Add tags to a todo
    AddTags,
    /// Remove tags from a todo
    RemoveTags,
    /// Move a todo to a project
    MoveTodo,
    /// Set due date
    SetDue,
    /// Clear due date
    ClearDue,
    /// Log a message
    Log,
    /// Send a notification
    Notify,
    /// Execute a shell command
    Shell,
    /// Open a URL
    OpenUrl,
    /// Start a focus session
    StartFocus,
    /// Queue for sync
    QueueSync,
}

impl ActionType {
    /// Get display name.
    #[must_use]
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::AddTodo => "Add Todo",
            Self::CompleteTodo => "Complete Todo",
            Self::CancelTodo => "Cancel Todo",
            Self::AddTags => "Add Tags",
            Self::RemoveTags => "Remove Tags",
            Self::MoveTodo => "Move Todo",
            Self::SetDue => "Set Due Date",
            Self::ClearDue => "Clear Due Date",
            Self::Log => "Log Message",
            Self::Notify => "Send Notification",
            Self::Shell => "Run Command",
            Self::OpenUrl => "Open URL",
            Self::StartFocus => "Start Focus",
            Self::QueueSync => "Queue for Sync",
        }
    }
}

/// Parameters for actions.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ActionParams {
    /// Add todo parameters
    #[serde(rename = "add_todo")]
    AddTodo {
        title: String,
        notes: Option<String>,
        project: Option<String>,
        tags: Option<Vec<String>>,
        when: Option<String>,
        deadline: Option<String>,
    },
    /// Todo ID for simple operations
    #[serde(rename = "todo_id")]
    TodoId { id: String },
    /// Tag operation parameters
    #[serde(rename = "tags")]
    Tags { id: String, tags: Vec<String> },
    /// Move operation parameters
    #[serde(rename = "move")]
    Move { id: String, project: String },
    /// Set due date parameters
    #[serde(rename = "set_due")]
    SetDue { id: String, date: String },
    /// Message for logging
    #[serde(rename = "message")]
    Message { message: String },
    /// Notification parameters
    #[serde(rename = "notification")]
    Notification { title: String, message: String },
    /// Shell command
    #[serde(rename = "command")]
    Command { command: String },
    /// No parameters
    #[serde(rename = "none")]
    None,
}

/// Result of executing an action.
#[derive(Debug, Clone)]
pub struct ActionResult {
    /// Whether the action succeeded
    pub success: bool,
    /// Output message
    pub message: Option<String>,
    /// Error if failed
    pub error: Option<String>,
    /// Any created IDs
    pub created_id: Option<String>,
}

impl ActionResult {
    /// Create a success result.
    #[must_use]
    pub fn success() -> Self {
        Self {
            success: true,
            message: None,
            error: None,
            created_id: None,
        }
    }

    /// Create a success result with message.
    #[must_use]
    pub fn success_with_message(message: impl Into<String>) -> Self {
        Self {
            success: true,
            message: Some(message.into()),
            error: None,
            created_id: None,
        }
    }

    /// Create a success result with created ID.
    #[must_use]
    pub fn success_with_id(id: impl Into<String>) -> Self {
        Self {
            success: true,
            message: None,
            error: None,
            created_id: Some(id.into()),
        }
    }

    /// Create a failure result.
    #[must_use]
    pub fn failure(error: impl Into<String>) -> Self {
        Self {
            success: false,
            message: None,
            error: Some(error.into()),
            created_id: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add_todo_action() {
        let action = Action::add_todo("Buy groceries");

        assert_eq!(action.action_type, ActionType::AddTodo);
        if let ActionParams::AddTodo { title, .. } = &action.params {
            assert_eq!(title, "Buy groceries");
        } else {
            panic!("Wrong params type");
        }
    }

    #[test]
    fn test_substitution() {
        let action = Action::add_todo("Task for {today}: {todo_name}");
        let ctx = RuleContext::now()
            .with_todo("ABC".to_string(), "Test".to_string());

        let substituted = action.with_substitution(&ctx);

        if let ActionParams::AddTodo { title, .. } = &substituted.params {
            assert!(title.contains(&chrono::Utc::now().format("%Y-%m-%d").to_string()));
            assert!(title.contains("Test"));
        } else {
            panic!("Wrong params type");
        }
    }

    #[test]
    fn test_action_result() {
        let success = ActionResult::success();
        assert!(success.success);

        let failure = ActionResult::failure("Something went wrong");
        assert!(!failure.success);
        assert_eq!(failure.error, Some("Something went wrong".to_string()));
    }
}
