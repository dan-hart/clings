//! Weekly review workflow for GTD-style productivity.
//!
//! This module implements an interactive weekly review process that helps
//! users process their inbox, review someday items, check projects, and
//! review upcoming deadlines.

mod prompts;
mod workflow;

pub use prompts::{ReviewPrompt, ReviewPromptResult};
pub use workflow::{ReviewSession, ReviewState, ReviewStep, ReviewSummary};
