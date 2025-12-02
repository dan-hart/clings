//! Path resolution for clings configuration and data files.
//!
//! All clings data is stored in `~/.clings/`:
//! - `config.yaml` - Main configuration file
//! - `clings.db` - SQLite database for stats, sessions, queue
//! - `templates/` - Project templates (YAML files)
//! - `scripts/` - Lua automation scripts
//! - `sessions/` - Focus session logs
//! - `cache/` - Cached data (completions, etc.)

use std::path::PathBuf;

use crate::error::ClingsError;

/// Paths to clings configuration and data directories.
#[derive(Debug, Clone)]
pub struct Paths {
    /// Root directory: `~/.clings/`
    pub root: PathBuf,
    /// Config file: `~/.clings/config.yaml`
    pub config_file: PathBuf,
    /// Database file: `~/.clings/clings.db`
    pub database: PathBuf,
    /// Templates directory: `~/.clings/templates/`
    pub templates: PathBuf,
    /// Scripts directory: `~/.clings/scripts/`
    pub scripts: PathBuf,
    /// Sessions directory: `~/.clings/sessions/`
    pub sessions: PathBuf,
    /// Cache directory: `~/.clings/cache/`
    pub cache: PathBuf,
}

impl Paths {
    /// Create paths based on the user's home directory.
    ///
    /// # Errors
    ///
    /// Returns an error if the home directory cannot be determined.
    pub fn new() -> Result<Self, ClingsError> {
        let home = std::env::var("HOME").map_err(|_| {
            ClingsError::Config("Could not determine home directory".to_string())
        })?;

        let root = PathBuf::from(home).join(".clings");

        Ok(Self {
            config_file: root.join("config.yaml"),
            database: root.join("clings.db"),
            templates: root.join("templates"),
            scripts: root.join("scripts"),
            sessions: root.join("sessions"),
            cache: root.join("cache"),
            root,
        })
    }

    /// Create paths with a custom root directory (useful for testing).
    #[must_use]
    pub fn with_root(root: PathBuf) -> Self {
        Self {
            config_file: root.join("config.yaml"),
            database: root.join("clings.db"),
            templates: root.join("templates"),
            scripts: root.join("scripts"),
            sessions: root.join("sessions"),
            cache: root.join("cache"),
            root,
        }
    }

    /// Ensure all directories exist, creating them if necessary.
    ///
    /// # Errors
    ///
    /// Returns an error if directory creation fails.
    pub fn ensure_dirs(&self) -> Result<(), ClingsError> {
        let dirs = [
            &self.root,
            &self.templates,
            &self.scripts,
            &self.sessions,
            &self.cache,
        ];

        for dir in dirs {
            if !dir.exists() {
                std::fs::create_dir_all(dir).map_err(|e| {
                    ClingsError::Config(format!("Failed to create directory {:?}: {}", dir, e))
                })?;
            }
        }

        Ok(())
    }
}

impl Default for Paths {
    fn default() -> Self {
        Self::new().unwrap_or_else(|_| {
            // Fallback to current directory if home cannot be determined
            Self::with_root(PathBuf::from(".clings"))
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_paths_with_root() {
        let root = PathBuf::from("/tmp/test-clings");
        let paths = Paths::with_root(root.clone());

        assert_eq!(paths.root, root);
        assert_eq!(paths.config_file, root.join("config.yaml"));
        assert_eq!(paths.database, root.join("clings.db"));
        assert_eq!(paths.templates, root.join("templates"));
        assert_eq!(paths.scripts, root.join("scripts"));
        assert_eq!(paths.sessions, root.join("sessions"));
        assert_eq!(paths.cache, root.join("cache"));
    }

    #[test]
    fn test_ensure_dirs() {
        let temp_dir = TempDir::new().unwrap();
        let paths = Paths::with_root(temp_dir.path().to_path_buf());

        paths.ensure_dirs().unwrap();

        assert!(paths.root.exists());
        assert!(paths.templates.exists());
        assert!(paths.scripts.exists());
        assert!(paths.sessions.exists());
        assert!(paths.cache.exists());
    }
}
