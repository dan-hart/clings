//! Shell and editor integration features.
//!
//! This module provides:
//! - Shell prompt integration (task counts)
//! - Shell completions generation
//! - Editor plugin generation (Vim, VS Code)
//! - Git hooks integration
//! - Pipe support for stdin/stdout workflows

pub mod completions;
pub mod editor;
pub mod git;
pub mod prompt;

pub use completions::generate_completions;
pub use editor::{generate_vim_plugin, vscode_info};
pub use git::{commit_todo_hook, install_git_hooks, GitHookType};
pub use prompt::{prompt_segment, PromptFormat, PromptSegment};
