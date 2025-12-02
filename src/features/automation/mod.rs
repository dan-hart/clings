//! Scriptable automation engine.
//!
//! This module provides rule-based automation for Things 3 workflows.
//!
//! Features:
//! - Rule definitions with conditions and actions
//! - Time-based triggers (daily, weekly, on schedule)
//! - Event triggers (on create, on complete, etc.)
//! - Variable substitution in templates
//! - Dry-run mode for testing

pub mod action;
pub mod condition;
pub mod engine;
pub mod rule;
pub mod storage;

pub use action::{Action, ActionType};
pub use condition::{Condition, ConditionOperator};
pub use engine::{format_engine_result, AutomationEngine, EngineConfig, EngineResult};
pub use rule::{EventType, Rule, RuleContext, Trigger, TriggerType};
pub use storage::RuleStorage;
