//! Natural language parsing for task entry.
//!
//! This module provides parsing for natural language task input like:
//! - "buy milk tomorrow 3pm #errands"
//! - "call mom friday for Family !high"
//! - "finish report by dec 15 #work #urgent"

mod parser;

pub use parser::{parse_task, ParsedTask, Priority};
