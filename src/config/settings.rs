//! Configuration settings for clings.
//!
//! Settings are loaded from `~/.clings/config.yaml`.

use serde::{Deserialize, Serialize};

use crate::cli::args::OutputFormat;
use crate::config::Paths;
use crate::error::ClingsError;

/// Main configuration structure.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(default)]
pub struct Config {
    /// General settings.
    pub general: GeneralConfig,
    /// Focus mode settings.
    pub focus: FocusConfig,
    /// Review workflow settings.
    pub review: ReviewConfig,
    /// Statistics settings.
    pub stats: StatsConfig,
}

/// General application settings.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct GeneralConfig {
    /// Default output format.
    #[serde(default = "default_output_format")]
    pub default_output: OutputFormat,
    /// Color output setting.
    #[serde(default = "default_color")]
    pub color: ColorSetting,
    /// Default editor for scripts and templates.
    #[serde(default)]
    pub editor: Option<String>,
}

/// Color output setting.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, Default, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum ColorSetting {
    /// Auto-detect based on terminal.
    #[default]
    Auto,
    /// Always use colors.
    Always,
    /// Never use colors.
    Never,
}

/// Focus mode settings.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct FocusConfig {
    /// Default pomodoro duration in minutes.
    #[serde(default = "default_pomodoro_duration")]
    pub pomodoro_duration_minutes: u32,
    /// Short break duration in minutes.
    #[serde(default = "default_short_break")]
    pub short_break_minutes: u32,
    /// Long break duration in minutes.
    #[serde(default = "default_long_break")]
    pub long_break_minutes: u32,
    /// Number of pomodoros before a long break.
    #[serde(default = "default_pomodoros_until_long_break")]
    pub pomodoros_until_long_break: u32,
    /// Enable desktop notifications.
    #[serde(default = "default_true")]
    pub notifications: bool,
    /// Play notification sound.
    #[serde(default = "default_true")]
    pub notification_sound: bool,
}

/// Review workflow settings.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct ReviewConfig {
    /// Day of week for weekly review (0 = Sunday, 6 = Saturday).
    #[serde(default = "default_review_day")]
    pub weekly_review_day: u8,
    /// Auto-archive completed items older than this many days.
    #[serde(default = "default_archive_days")]
    pub auto_archive_completed_days: u32,
}

/// Statistics settings.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct StatsConfig {
    /// Number of days to retain statistics data.
    #[serde(default = "default_retention_days")]
    pub retention_days: u32,
    /// Default dashboard time range.
    #[serde(default = "default_dashboard_range")]
    pub dashboard_default_range: String,
}

// Default value functions for serde
const fn default_output_format() -> OutputFormat {
    OutputFormat::Pretty
}

const fn default_color() -> ColorSetting {
    ColorSetting::Auto
}

const fn default_pomodoro_duration() -> u32 {
    25
}

const fn default_short_break() -> u32 {
    5
}

const fn default_long_break() -> u32 {
    15
}

const fn default_pomodoros_until_long_break() -> u32 {
    4
}

const fn default_true() -> bool {
    true
}

const fn default_review_day() -> u8 {
    0 // Sunday
}

const fn default_archive_days() -> u32 {
    30
}

const fn default_retention_days() -> u32 {
    365
}

fn default_dashboard_range() -> String {
    "week".to_string()
}

impl Default for GeneralConfig {
    fn default() -> Self {
        Self {
            default_output: default_output_format(),
            color: default_color(),
            editor: None,
        }
    }
}

impl Default for FocusConfig {
    fn default() -> Self {
        Self {
            pomodoro_duration_minutes: default_pomodoro_duration(),
            short_break_minutes: default_short_break(),
            long_break_minutes: default_long_break(),
            pomodoros_until_long_break: default_pomodoros_until_long_break(),
            notifications: default_true(),
            notification_sound: default_true(),
        }
    }
}

impl Default for ReviewConfig {
    fn default() -> Self {
        Self {
            weekly_review_day: default_review_day(),
            auto_archive_completed_days: default_archive_days(),
        }
    }
}

impl Default for StatsConfig {
    fn default() -> Self {
        Self {
            retention_days: default_retention_days(),
            dashboard_default_range: default_dashboard_range(),
        }
    }
}

impl Config {
    /// Load configuration from the default path.
    ///
    /// If the config file doesn't exist, returns default configuration.
    ///
    /// # Errors
    ///
    /// Returns an error if the config file exists but cannot be parsed.
    pub fn load() -> Result<Self, ClingsError> {
        let paths = Paths::new()?;
        Self::load_from_path(&paths.config_file)
    }

    /// Load configuration from a specific path.
    ///
    /// If the config file doesn't exist, returns default configuration.
    ///
    /// # Errors
    ///
    /// Returns an error if the config file exists but cannot be parsed.
    pub fn load_from_path(path: &std::path::Path) -> Result<Self, ClingsError> {
        if !path.exists() {
            return Ok(Self::default());
        }

        let contents = std::fs::read_to_string(path).map_err(|e| {
            ClingsError::Config(format!(
                "Failed to read config file {}: {e}",
                path.display()
            ))
        })?;

        serde_yaml::from_str(&contents).map_err(|e| {
            ClingsError::Config(format!(
                "Failed to parse config file {}: {e}",
                path.display()
            ))
        })
    }

    /// Save configuration to the default path.
    ///
    /// # Errors
    ///
    /// Returns an error if the config file cannot be written.
    pub fn save(&self) -> Result<(), ClingsError> {
        let paths = Paths::new()?;
        paths.ensure_dirs()?;
        self.save_to_path(&paths.config_file)
    }

    /// Save configuration to a specific path.
    ///
    /// # Errors
    ///
    /// Returns an error if the config file cannot be written.
    pub fn save_to_path(&self, path: &std::path::Path) -> Result<(), ClingsError> {
        let contents = serde_yaml::to_string(self)
            .map_err(|e| ClingsError::Config(format!("Failed to serialize config: {e}")))?;

        std::fs::write(path, contents).map_err(|e| {
            ClingsError::Config(format!(
                "Failed to write config file {}: {e}",
                path.display()
            ))
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_default_config() {
        let config = Config::default();

        assert_eq!(config.general.default_output, OutputFormat::Pretty);
        assert_eq!(config.general.color, ColorSetting::Auto);
        assert_eq!(config.focus.pomodoro_duration_minutes, 25);
        assert_eq!(config.focus.short_break_minutes, 5);
        assert_eq!(config.review.weekly_review_day, 0);
        assert_eq!(config.stats.retention_days, 365);
    }

    #[test]
    fn test_load_missing_config() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.yaml");

        let config = Config::load_from_path(&config_path).unwrap();

        // Should return defaults when file doesn't exist
        assert_eq!(config.general.default_output, OutputFormat::Pretty);
    }

    #[test]
    fn test_save_and_load_config() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.yaml");

        let mut config = Config::default();
        config.focus.pomodoro_duration_minutes = 30;
        config.stats.retention_days = 90;

        config.save_to_path(&config_path).unwrap();

        let loaded = Config::load_from_path(&config_path).unwrap();

        assert_eq!(loaded.focus.pomodoro_duration_minutes, 30);
        assert_eq!(loaded.stats.retention_days, 90);
    }

    #[test]
    fn test_partial_config() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.yaml");

        // Write a partial config (only some fields)
        let partial_yaml = r#"
focus:
  pomodoro_duration_minutes: 45
"#;
        std::fs::write(&config_path, partial_yaml).unwrap();

        let config = Config::load_from_path(&config_path).unwrap();

        // Custom value should be loaded
        assert_eq!(config.focus.pomodoro_duration_minutes, 45);
        // Defaults should be used for missing fields
        assert_eq!(config.focus.short_break_minutes, 5);
        assert_eq!(config.general.default_output, OutputFormat::Pretty);
    }
}
