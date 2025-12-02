//! Interactive fuzzy finder for Things 3 items.
//!
//! This module provides an interactive terminal interface for browsing
//! and selecting todos using fuzzy search powered by skim.

mod picker;

pub use picker::{pick_todos, PickAction, PickOptions, PickResult};
