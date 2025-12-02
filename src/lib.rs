//! clings - A Things 3 CLI for macOS
//!
//! This crate provides a command-line interface for interacting with Things 3
//! via JavaScript for Automation (JXA).

#![deny(unsafe_code)]
#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]
#![warn(clippy::pedantic)]
#![warn(clippy::nursery)]
#![allow(clippy::module_name_repetitions)]

pub mod cli;
pub mod config;
pub mod core;
pub mod error;
pub mod features;
pub mod output;
pub mod storage;
pub mod things;
pub mod tui;

pub use cli::args::{Cli, Commands, OutputFormat};
pub use error::ClingsError;
pub use things::ThingsClient;
