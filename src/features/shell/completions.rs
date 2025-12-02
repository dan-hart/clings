//! Shell completions generation.
//!
//! Generates shell completion scripts for bash, zsh, fish, and PowerShell.

use clap::CommandFactory;
use clap_complete::Shell;
use std::io::Write;

use crate::cli::args::Cli;
use crate::error::ClingsError;

/// Generate shell completions for the specified shell.
///
/// # Arguments
///
/// * `shell` - The shell to generate completions for
///
/// # Returns
///
/// The completion script as a string.
pub fn generate_completions(shell: Shell) -> Result<String, ClingsError> {
    let mut cmd = Cli::command();
    let mut buf = Vec::new();
    generate_to(&mut buf, shell, &mut cmd)?;
    String::from_utf8(buf).map_err(|e| ClingsError::Script(format!("UTF-8 error: {e}")))
}

fn generate_to<W: Write>(buf: &mut W, shell: Shell, cmd: &mut clap::Command) -> Result<(), ClingsError> {
    clap_complete::generate(shell, cmd, "clings", buf);
    Ok(())
}

/// Get shell from string name.
pub fn shell_from_str(s: &str) -> Option<Shell> {
    match s.to_lowercase().as_str() {
        "bash" => Some(Shell::Bash),
        "zsh" => Some(Shell::Zsh),
        "fish" => Some(Shell::Fish),
        "powershell" | "ps" | "pwsh" => Some(Shell::PowerShell),
        "elvish" => Some(Shell::Elvish),
        _ => None,
    }
}

/// Get installation instructions for shell completions.
pub fn completion_install_instructions(shell: Shell) -> String {
    match shell {
        Shell::Bash => r#"# Add to ~/.bashrc or ~/.bash_profile:
source <(clings shell completions bash)

# Or save to a file:
clings shell completions bash > /usr/local/etc/bash_completion.d/clings
"#.to_string(),

        Shell::Zsh => r#"# Add to ~/.zshrc (before compinit):
source <(clings shell completions zsh)

# Or save to your fpath:
clings shell completions zsh > ~/.zsh/completions/_clings
# Then add to ~/.zshrc:
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
"#.to_string(),

        Shell::Fish => r#"# Save to fish completions directory:
clings shell completions fish > ~/.config/fish/completions/clings.fish

# Or run directly:
clings shell completions fish | source
"#.to_string(),

        Shell::PowerShell => r#"# Add to your PowerShell profile ($PROFILE):
clings shell completions powershell | Out-String | Invoke-Expression

# Or save to a file and dot-source it:
clings shell completions powershell > ~/clings.ps1
. ~/clings.ps1
"#.to_string(),

        Shell::Elvish => r#"# Save to elvish completions directory:
clings shell completions elvish > ~/.elvish/lib/clings.elv

# Then add to ~/.elvish/rc.elv:
use clings
"#.to_string(),

        _ => "Unknown shell".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_shell_from_str() {
        assert_eq!(shell_from_str("bash"), Some(Shell::Bash));
        assert_eq!(shell_from_str("zsh"), Some(Shell::Zsh));
        assert_eq!(shell_from_str("fish"), Some(Shell::Fish));
        assert_eq!(shell_from_str("powershell"), Some(Shell::PowerShell));
        assert_eq!(shell_from_str("pwsh"), Some(Shell::PowerShell));
        assert_eq!(shell_from_str("unknown"), None);
    }

    #[test]
    fn test_generate_bash_completions() {
        let result = generate_completions(Shell::Bash);
        assert!(result.is_ok());
        let script = result.unwrap();
        assert!(script.contains("clings"));
        assert!(script.contains("complete"));
    }

    #[test]
    fn test_generate_zsh_completions() {
        let result = generate_completions(Shell::Zsh);
        assert!(result.is_ok());
        let script = result.unwrap();
        assert!(script.contains("clings"));
    }

    #[test]
    fn test_generate_fish_completions() {
        let result = generate_completions(Shell::Fish);
        assert!(result.is_ok());
        let script = result.unwrap();
        assert!(script.contains("clings"));
    }

    #[test]
    fn test_completion_instructions_not_empty() {
        assert!(!completion_install_instructions(Shell::Bash).is_empty());
        assert!(!completion_install_instructions(Shell::Zsh).is_empty());
        assert!(!completion_install_instructions(Shell::Fish).is_empty());
    }
}
