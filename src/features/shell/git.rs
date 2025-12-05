//! Git hooks integration.
//!
//! Provides git hook scripts for Things 3 integration:
//! - Create todos from commit messages
//! - Extract TODOs from code comments
//! - Link commits to projects

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

use crate::error::ClingsError;

/// Types of git hooks that can be installed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GitHookType {
    /// Post-commit hook - runs after a commit
    PostCommit,
    /// Pre-push hook - runs before pushing
    PrePush,
    /// Prepare-commit-msg hook - modify commit message
    PrepareCommitMsg,
    /// Commit-msg hook - validate/process commit message
    CommitMsg,
}

impl GitHookType {
    /// Get the filename for this hook type.
    #[must_use]
    pub const fn filename(&self) -> &'static str {
        match self {
            Self::PostCommit => "post-commit",
            Self::PrePush => "pre-push",
            Self::PrepareCommitMsg => "prepare-commit-msg",
            Self::CommitMsg => "commit-msg",
        }
    }

    /// Parse hook type from string.
    ///
    /// Note: This is not the standard `FromStr` trait to avoid conflicts.
    #[must_use]
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().replace(['-', '_'], "").as_str() {
            "postcommit" => Some(Self::PostCommit),
            "prepush" => Some(Self::PrePush),
            "preparecommitmsg" => Some(Self::PrepareCommitMsg),
            "commitmsg" => Some(Self::CommitMsg),
            _ => None,
        }
    }

    /// Get all hook types.
    #[must_use]
    pub fn all() -> Vec<Self> {
        vec![
            Self::PostCommit,
            Self::PrePush,
            Self::PrepareCommitMsg,
            Self::CommitMsg,
        ]
    }
}

/// Install git hooks in the specified repository.
///
/// # Arguments
///
/// * `repo_path` - Path to the git repository (or None for current dir)
/// * `hooks` - Which hooks to install (or None for all)
/// * `force` - Overwrite existing hooks
///
/// # Returns
///
/// List of installed hook paths.
///
/// # Errors
///
/// Returns an error if the git hooks directory is not found or if writing hooks fails.
pub fn install_git_hooks(
    repo_path: Option<&Path>,
    hooks: Option<&[GitHookType]>,
    force: bool,
) -> Result<Vec<String>, ClingsError> {
    let repo = repo_path.unwrap_or_else(|| Path::new("."));
    let hooks_dir = repo.join(".git/hooks");

    if !hooks_dir.exists() {
        return Err(ClingsError::NotFound(format!(
            "Git hooks directory not found: {}",
            hooks_dir.display()
        )));
    }

    let hooks_to_install = hooks.map_or_else(GitHookType::all, <[GitHookType]>::to_vec);
    let mut installed = Vec::new();

    for hook_type in hooks_to_install {
        let hook_path = hooks_dir.join(hook_type.filename());

        // Check if hook already exists
        if hook_path.exists() && !force {
            // Check if it's our hook or a different one
            let content = fs::read_to_string(&hook_path).unwrap_or_default();
            if !content.contains("# clings git hook") {
                eprintln!(
                    "Warning: {} already exists and was not created by clings. Use --force to overwrite.",
                    hook_path.display()
                );
                continue;
            }
        }

        // Generate and write the hook
        let hook_content = generate_hook_script(hook_type);
        fs::write(&hook_path, hook_content)?;

        // Make executable
        let mut perms = fs::metadata(&hook_path)?.permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&hook_path, perms)?;

        installed.push(hook_path.display().to_string());
    }

    Ok(installed)
}

/// Generate the hook script for a given type.
fn generate_hook_script(hook_type: GitHookType) -> String {
    match hook_type {
        GitHookType::PostCommit => POST_COMMIT_HOOK.to_string(),
        GitHookType::PrePush => PRE_PUSH_HOOK.to_string(),
        GitHookType::PrepareCommitMsg => PREPARE_COMMIT_MSG_HOOK.to_string(),
        GitHookType::CommitMsg => COMMIT_MSG_HOOK.to_string(),
    }
}

/// Process a commit message for todo markers.
///
/// Looks for patterns like:
/// - `TODO:` text -> creates a todo
/// - `DONE:` id -> completes a todo
/// - `Things:` project -> associates with project
///
/// # Arguments
///
/// * `message` - The commit message to process
/// * `project` - Optional project to associate todos with
///
/// # Returns
///
/// List of actions that would be taken.
#[must_use]
pub fn commit_todo_hook(message: &str, project: Option<&str>) -> Vec<CommitTodoAction> {
    let mut actions = Vec::new();

    for line in message.lines() {
        let line = line.trim();

        // Look for TODO: pattern
        if let Some(todo_text) = line
            .strip_prefix("TODO:")
            .or_else(|| line.strip_prefix("todo:"))
        {
            let todo_text = todo_text.trim();
            if !todo_text.is_empty() {
                actions.push(CommitTodoAction::Create {
                    title: todo_text.to_string(),
                    project: project.map(String::from),
                });
            }
        }

        // Look for DONE: pattern with ID
        if let Some(id) = line
            .strip_prefix("DONE:")
            .or_else(|| line.strip_prefix("done:"))
        {
            let id = id.trim();
            if !id.is_empty() {
                actions.push(CommitTodoAction::Complete { id: id.to_string() });
            }
        }

        // Look for FIXME: pattern
        if let Some(fixme_text) = line
            .strip_prefix("FIXME:")
            .or_else(|| line.strip_prefix("fixme:"))
        {
            let fixme_text = fixme_text.trim();
            if !fixme_text.is_empty() {
                actions.push(CommitTodoAction::Create {
                    title: format!("[FIXME] {fixme_text}"),
                    project: project.map(String::from),
                });
            }
        }
    }

    actions
}

/// Actions that can be triggered by commit messages.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CommitTodoAction {
    /// Create a new todo
    Create {
        title: String,
        project: Option<String>,
    },
    /// Complete an existing todo
    Complete { id: String },
}

// Hook scripts
const POST_COMMIT_HOOK: &str = r#"#!/bin/bash
# clings git hook - post-commit
# Created by: clings shell git install-hooks

# Get the commit message
COMMIT_MSG=$(git log -1 --format=%B)

# Process for TODO markers
if echo "$COMMIT_MSG" | grep -qi "TODO:"; then
    echo "$COMMIT_MSG" | grep -i "TODO:" | while read -r line; do
        TODO_TEXT=$(echo "$line" | sed 's/.*TODO:\s*//')
        if [ -n "$TODO_TEXT" ]; then
            clings add "$TODO_TEXT" 2>/dev/null || echo "Note: clings not available"
        fi
    done
fi

# Process for DONE markers
if echo "$COMMIT_MSG" | grep -qi "DONE:"; then
    echo "$COMMIT_MSG" | grep -i "DONE:" | while read -r line; do
        TODO_ID=$(echo "$line" | sed 's/.*DONE:\s*//' | awk '{print $1}')
        if [ -n "$TODO_ID" ]; then
            clings todo complete "$TODO_ID" 2>/dev/null || echo "Note: clings not available"
        fi
    done
fi

exit 0
"#;

const PRE_PUSH_HOOK: &str = r#"#!/bin/bash
# clings git hook - pre-push
# Created by: clings shell git install-hooks

# This hook can be used to check for incomplete todos
# before pushing. Customize as needed.

# Example: Warn about open TODOs in staged changes
# git diff --cached | grep -n "TODO:" && echo "Warning: Found TODOs in changes"

exit 0
"#;

const PREPARE_COMMIT_MSG_HOOK: &str = r##"#!/bin/bash
# clings git hook - prepare-commit-msg
# Created by: clings shell git install-hooks

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2
SHA1=$3

# Skip for merge commits
if [ "$COMMIT_SOURCE" = "merge" ]; then
    exit 0
fi

# Optionally append Things 3 context
# Uncomment to add current today count to commit message:
# echo "" >> "$COMMIT_MSG_FILE"
# THINGS_COUNT=$(clings today -o json 2>/dev/null | jq -r ".count // 0")
# echo "# Things Today: $THINGS_COUNT" >> "$COMMIT_MSG_FILE"

exit 0
"##;

const COMMIT_MSG_HOOK: &str = r#"#!/bin/bash
# clings git hook - commit-msg
# Created by: clings shell git install-hooks

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Validate commit message format if needed
# Example: Require conventional commits format

# Extract and queue todos from commit message
if echo "$COMMIT_MSG" | grep -qi "TODO:\|FIXME:"; then
    echo "Detected TODO/FIXME markers in commit message."
    echo "These will be processed by the post-commit hook."
fi

exit 0
"#;

/// Remove installed git hooks.
///
/// # Errors
///
/// Returns an error if the git hooks directory is not found or if removing hooks fails.
pub fn uninstall_git_hooks(
    repo_path: Option<&Path>,
    hooks: Option<&[GitHookType]>,
) -> Result<Vec<String>, ClingsError> {
    let repo = repo_path.unwrap_or_else(|| Path::new("."));
    let hooks_dir = repo.join(".git/hooks");

    if !hooks_dir.exists() {
        return Err(ClingsError::NotFound(format!(
            "Git hooks directory not found: {}",
            hooks_dir.display()
        )));
    }

    let hooks_to_remove = hooks.map_or_else(GitHookType::all, <[GitHookType]>::to_vec);
    let mut removed = Vec::new();

    for hook_type in hooks_to_remove {
        let hook_path = hooks_dir.join(hook_type.filename());

        if hook_path.exists() {
            // Only remove if it's our hook
            let content = fs::read_to_string(&hook_path).unwrap_or_default();
            if content.contains("# clings git hook") {
                fs::remove_file(&hook_path)?;
                removed.push(hook_path.display().to_string());
            }
        }
    }

    Ok(removed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hook_type_filename() {
        assert_eq!(GitHookType::PostCommit.filename(), "post-commit");
        assert_eq!(GitHookType::PrePush.filename(), "pre-push");
        assert_eq!(
            GitHookType::PrepareCommitMsg.filename(),
            "prepare-commit-msg"
        );
        assert_eq!(GitHookType::CommitMsg.filename(), "commit-msg");
    }

    #[test]
    fn test_hook_type_from_str() {
        assert_eq!(
            GitHookType::from_str("post-commit"),
            Some(GitHookType::PostCommit)
        );
        assert_eq!(
            GitHookType::from_str("postcommit"),
            Some(GitHookType::PostCommit)
        );
        assert_eq!(
            GitHookType::from_str("pre-push"),
            Some(GitHookType::PrePush)
        );
        assert_eq!(GitHookType::from_str("unknown"), None);
    }

    #[test]
    fn test_commit_todo_hook_create() {
        let message = "Fix bug\n\nTODO: Write tests for this fix";
        let actions = commit_todo_hook(message, None);

        assert_eq!(actions.len(), 1);
        assert!(matches!(
            &actions[0],
            CommitTodoAction::Create { title, project: None } if title == "Write tests for this fix"
        ));
    }

    #[test]
    fn test_commit_todo_hook_complete() {
        let message = "Finish feature\n\nDONE: ABC123";
        let actions = commit_todo_hook(message, None);

        assert_eq!(actions.len(), 1);
        assert!(matches!(
            &actions[0],
            CommitTodoAction::Complete { id } if id == "ABC123"
        ));
    }

    #[test]
    fn test_commit_todo_hook_with_project() {
        let message = "TODO: Add documentation";
        let actions = commit_todo_hook(message, Some("MyProject"));

        assert_eq!(actions.len(), 1);
        assert!(matches!(
            &actions[0],
            CommitTodoAction::Create { title, project: Some(p) }
                if title == "Add documentation" && p == "MyProject"
        ));
    }

    #[test]
    fn test_commit_todo_hook_fixme() {
        let message = "FIXME: Memory leak in handler";
        let actions = commit_todo_hook(message, None);

        assert_eq!(actions.len(), 1);
        assert!(matches!(
            &actions[0],
            CommitTodoAction::Create { title, .. } if title.contains("[FIXME]")
        ));
    }

    #[test]
    fn test_commit_todo_hook_multiple() {
        let message = "Big update\n\nTODO: Tests\nTODO: Docs\nDONE: XYZ";
        let actions = commit_todo_hook(message, None);

        assert_eq!(actions.len(), 3);
    }

    #[test]
    fn test_hook_script_contains_marker() {
        assert!(POST_COMMIT_HOOK.contains("# clings git hook"));
        assert!(PRE_PUSH_HOOK.contains("# clings git hook"));
    }
}
