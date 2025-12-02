//! Configuration management for clings.
//!
//! This module handles loading and saving configuration from `~/.clings/`.

mod paths;
mod settings;

pub use paths::Paths;
pub use settings::{Config, FocusConfig, GeneralConfig, ReviewConfig, StatsConfig};
