//! Shell integration commands.
//!
//! Handles shell completions.

use crate::cli::args::{OutputFormat, ShellCommands};
use crate::error::ClingsError;
use crate::features::shell::completions::{
    completion_install_instructions, generate_completions, shell_from_str,
};
use crate::things::ThingsClient;

/// Execute shell subcommands.
///
/// # Errors
///
/// Returns an error if shell completion generation fails.
pub fn shell(
    _client: &ThingsClient,
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
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_shell_completions_unknown_shell() {
        let client = ThingsClient::new();
        let result = shell(
            &client,
            ShellCommands::Completions {
                shell: "unknown".to_string(),
                install: false,
            },
            OutputFormat::Pretty,
        );

        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(matches!(err, ClingsError::Config(_)));
    }
}
