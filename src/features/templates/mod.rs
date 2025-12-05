//! Project templates for clings.
//!
//! This module provides functionality for creating and applying project templates.
//! Templates are reusable project structures that can be saved and applied to
//! create new projects with predefined headings, todos, tags, and relative dates.

mod storage;
mod types;

pub use storage::TemplateStorage;
pub use types::{ProjectTemplate, RelativeDate, TemplateHeading, TemplateTodo, TemplateVariable};
