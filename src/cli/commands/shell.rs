//! Shell integration commands.
//!
//! Handles shell completions, prompt segments, and editor plugins.

use std::io::{self, BufRead};
use std::path::Path;

use crate::cli::args::{GitCommands, OutputFormat, PipeCommands, ShellCommands};
use crate::error::ClingsError;
use crate::features::nlp::parse_task;
use crate::features::shell::completions::{
    completion_install_instructions, generate_completions, shell_from_str,
};
use crate::features::shell::editor::{generate_emacs_config, generate_vim_plugin, sublime_info, vscode_info};
use crate::features::shell::git::{
    commit_todo_hook, install_git_hooks, uninstall_git_hooks, CommitTodoAction, GitHookType,
};
use crate::features::shell::prompt::{prompt_segment, PromptFormat, PromptSegment};
use crate::things::{ListView, ThingsClient};

/// Execute shell subcommands.
pub fn shell(
    client: &ThingsClient,
    cmd: ShellCommands,
    _format: OutputFormat,
) -> Result<String, ClingsError> {
    match cmd {
        ShellCommands::Completions { shell, install } => {
            let shell_type = shell_from_str(&shell).ok_or_else(|| {
                ClingsError::Config(format!(
                    "Unknown shell: {shell}. Supported: bash, zsh, fish, powershell, elvish"
                ))
            })?;

            if install {
                Ok(completion_install_instructions(shell_type))
            } else {
                generate_completions(shell_type)
            }
        }

        ShellCommands::Prompt {
            format,
            segment,
            custom,
        } => {
            let fmt = if custom.is_some() {
                PromptFormat::Custom
            } else {
                PromptFormat::from_str(&format)
            };
            let seg = PromptSegment::from_str(&segment);
            prompt_segment(client, seg, fmt, custom.as_deref())
        }

        ShellCommands::Editor { editor } => match editor.to_lowercase().as_str() {
            "vim" | "neovim" | "nvim" => Ok(generate_vim_plugin()),
            "emacs" => Ok(generate_emacs_config()),
            "vscode" | "code" => Ok(vscode_info()),
            "sublime" | "subl" => Ok(sublime_info()),
            _ => Err(ClingsError::Config(format!(
                "Unknown editor: {editor}. Supported: vim, emacs, vscode, sublime"
            ))),
        },
    }
}

/// Execute pipe subcommands.
pub fn pipe(
    client: &ThingsClient,
    cmd: PipeCommands,
    _format: OutputFormat,
) -> Result<String, ClingsError> {
    match cmd {
        PipeCommands::Add {
            project,
            tags,
            dry_run,
        } => pipe_add(client, project.as_deref(), tags.as_deref(), dry_run),

        PipeCommands::Complete { dry_run } => pipe_complete(client, dry_run),

        PipeCommands::List {
            list,
            with_id,
            delimiter,
        } => pipe_list(client, &list, with_id, &delimiter),
    }
}

/// Add todos from stdin.
fn pipe_add(
    client: &ThingsClient,
    project: Option<&str>,
    tags: Option<&[String]>,
    dry_run: bool,
) -> Result<String, ClingsError> {
    let stdin = io::stdin();
    let mut added = Vec::new();

    for line in stdin.lock().lines() {
        let line = line?;
        let line = line.trim();

        if line.is_empty() {
            continue;
        }

        // Parse with NLP
        let mut parsed = parse_task(line);

        // Override project if specified
        let list = if let Some(p) = project {
            Some(p.to_string())
        } else {
            parsed.project.clone()
        };

        // Add tags if specified
        if let Some(t) = tags {
            parsed.tags.extend(t.iter().cloned());
        }

        // Get deadline as ISO string
        let deadline_iso = parsed.deadline_date_iso();

        if dry_run {
            added.push(format!("Would add: {}", parsed.title));
        } else {
            let response = client.add_todo(
                &parsed.title,
                parsed.notes.as_deref(),
                deadline_iso.as_deref(),
                if parsed.tags.is_empty() {
                    None
                } else {
                    Some(&parsed.tags)
                },
                list.as_deref(),
                None, // checklist
            )?;
            added.push(format!("Added: {} ({})", response.name, response.id));
        }
    }

    if added.is_empty() {
        Ok("No todos to add (stdin was empty)".to_string())
    } else {
        Ok(added.join("\n"))
    }
}

/// Complete todos from stdin IDs.
fn pipe_complete(client: &ThingsClient, dry_run: bool) -> Result<String, ClingsError> {
    let stdin = io::stdin();
    let mut completed = Vec::new();

    for line in stdin.lock().lines() {
        let line = line?;
        let id = line.trim();

        if id.is_empty() {
            continue;
        }

        if dry_run {
            completed.push(format!("Would complete: {id}"));
        } else {
            client.complete_todo(id)?;
            completed.push(format!("Completed: {id}"));
        }
    }

    if completed.is_empty() {
        Ok("No todos to complete (stdin was empty)".to_string())
    } else {
        Ok(completed.join("\n"))
    }
}

/// List todos in pipe-friendly format.
fn pipe_list(
    client: &ThingsClient,
    list: &str,
    with_id: bool,
    delimiter: &str,
) -> Result<String, ClingsError> {
    let view = match list.to_lowercase().as_str() {
        "inbox" | "i" => ListView::Inbox,
        "today" | "t" => ListView::Today,
        "upcoming" | "u" => ListView::Upcoming,
        "anytime" | "a" => ListView::Anytime,
        "someday" | "s" => ListView::Someday,
        "logbook" | "l" => ListView::Logbook,
        _ => {
            return Err(ClingsError::Config(format!(
                "Unknown list: {list}. Supported: inbox, today, upcoming, anytime, someday, logbook"
            )))
        }
    };

    let todos = client.get_list(view)?;
    let lines: Vec<String> = todos
        .iter()
        .map(|t| {
            if with_id {
                format!("{}{}{}", t.id, delimiter, t.name)
            } else {
                t.name.clone()
            }
        })
        .collect();

    Ok(lines.join("\n"))
}

/// Execute git subcommands.
pub fn git(
    client: &ThingsClient,
    cmd: GitCommands,
    _format: OutputFormat,
) -> Result<String, ClingsError> {
    match cmd {
        GitCommands::InstallHooks { hook, force, repo } => {
            let repo_path = repo.as_ref().map(Path::new);
            let hooks = hook.as_ref().and_then(|h| {
                GitHookType::from_str(h).map(|ht| vec![ht])
            });

            let installed = install_git_hooks(repo_path, hooks.as_deref(), force)?;

            if installed.is_empty() {
                Ok("No hooks were installed".to_string())
            } else {
                Ok(format!(
                    "Installed hooks:\n{}",
                    installed
                        .iter()
                        .map(|p| format!("  - {p}"))
                        .collect::<Vec<_>>()
                        .join("\n")
                ))
            }
        }

        GitCommands::UninstallHooks { hook, repo } => {
            let repo_path = repo.as_ref().map(Path::new);
            let hooks = hook.as_ref().and_then(|h| {
                GitHookType::from_str(h).map(|ht| vec![ht])
            });

            let removed = uninstall_git_hooks(repo_path, hooks.as_deref())?;

            if removed.is_empty() {
                Ok("No clings hooks found to remove".to_string())
            } else {
                Ok(format!(
                    "Removed hooks:\n{}",
                    removed
                        .iter()
                        .map(|p| format!("  - {p}"))
                        .collect::<Vec<_>>()
                        .join("\n")
                ))
            }
        }

        GitCommands::ProcessMessage {
            message,
            project,
            execute,
        } => {
            let actions = commit_todo_hook(&message, project.as_deref());

            if actions.is_empty() {
                return Ok("No TODO/DONE markers found in message".to_string());
            }

            let mut output = Vec::new();

            for action in actions {
                match action {
                    CommitTodoAction::Create { title, project } => {
                        if execute {
                            let response = client.add_todo(
                                &title,
                                None,
                                None,
                                None,
                                project.as_deref(),
                                None,
                            )?;
                            output.push(format!("Created: {} ({})", response.name, response.id));
                        } else {
                            output.push(format!(
                                "Would create: \"{}\"{}",
                                title,
                                project.map(|p| format!(" in {p}")).unwrap_or_default()
                            ));
                        }
                    }
                    CommitTodoAction::Complete { id } => {
                        if execute {
                            client.complete_todo(&id)?;
                            output.push(format!("Completed: {id}"));
                        } else {
                            output.push(format!("Would complete: {id}"));
                        }
                    }
                }
            }

            if !execute {
                output.insert(0, "(Dry run - use --execute to apply)".to_string());
            }

            Ok(output.join("\n"))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pipe_list_view_mapping() {
        // Test that all list names are recognized
        let client = ThingsClient::new();

        // These should parse without error (though they'll fail to connect to Things)
        // We're just testing the view mapping logic
        assert!(matches!(
            pipe_list(&client, "today", false, "\t"),
            Ok(_) | Err(ClingsError::ThingsNotRunning) | Err(ClingsError::PermissionDenied)
        ));
    }

    #[test]
    fn test_git_process_message_dry_run() {
        let client = ThingsClient::new();
        let result = git(
            &client,
            GitCommands::ProcessMessage {
                message: "TODO: Write tests".to_string(),
                project: None,
                execute: false,
            },
            OutputFormat::Pretty,
        );

        // Should succeed in dry run mode without connecting to Things
        assert!(result.is_ok());
        let output = result.unwrap();
        assert!(output.contains("Would create"));
        assert!(output.contains("Write tests"));
    }

    #[test]
    fn test_git_process_message_no_markers() {
        let client = ThingsClient::new();
        let result = git(
            &client,
            GitCommands::ProcessMessage {
                message: "Regular commit message".to_string(),
                project: None,
                execute: false,
            },
            OutputFormat::Pretty,
        );

        assert!(result.is_ok());
        assert!(result.unwrap().contains("No TODO/DONE markers"));
    }
}
