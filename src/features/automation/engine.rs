//! Automation engine for executing rules.
//!
//! The engine evaluates rules and executes their actions.

use colored::Colorize;

use super::action::{ActionParams, ActionResult, ActionType};
use super::rule::{EventType, Rule, RuleContext};
use super::storage::RuleStorage;
use crate::error::ClingsError;
use crate::features::sync::{Operation, SyncQueue};
use crate::things::ThingsClient;

/// Configuration for the automation engine.
#[derive(Debug, Clone)]
pub struct EngineConfig {
    /// Dry run mode (don't execute actions)
    pub dry_run: bool,
    /// Maximum actions per rule
    pub max_actions: usize,
    /// Whether to queue failed actions for sync
    pub queue_on_failure: bool,
}

impl Default for EngineConfig {
    fn default() -> Self {
        Self {
            dry_run: false,
            max_actions: 10,
            queue_on_failure: true,
        }
    }
}

/// Result of running the engine.
#[derive(Debug)]
pub struct EngineResult {
    /// Rules evaluated
    pub rules_evaluated: usize,
    /// Rules triggered
    pub rules_triggered: usize,
    /// Actions executed
    pub actions_executed: usize,
    /// Actions failed
    pub actions_failed: usize,
    /// Individual rule results
    pub rule_results: Vec<RuleResult>,
}

impl EngineResult {
    /// Create an empty result.
    #[must_use]
    pub fn empty() -> Self {
        Self {
            rules_evaluated: 0,
            rules_triggered: 0,
            actions_executed: 0,
            actions_failed: 0,
            rule_results: Vec::new(),
        }
    }
}

/// Result of running a single rule.
#[derive(Debug)]
pub struct RuleResult {
    /// Rule name
    pub rule_name: String,
    /// Whether it triggered
    pub triggered: bool,
    /// Action results
    pub action_results: Vec<ActionResult>,
}

/// The automation engine.
pub struct AutomationEngine<'a> {
    client: &'a ThingsClient,
    storage: RuleStorage,
    sync_queue: Option<SyncQueue>,
    config: EngineConfig,
}

impl<'a> AutomationEngine<'a> {
    /// Create a new automation engine.
    ///
    /// # Errors
    ///
    /// Returns an error if storage cannot be initialized.
    pub fn new(client: &'a ThingsClient) -> Result<Self, ClingsError> {
        let storage = RuleStorage::new()?;
        let sync_queue = SyncQueue::new().ok();

        Ok(Self {
            client,
            storage,
            sync_queue,
            config: EngineConfig::default(),
        })
    }

    /// Create engine with custom config.
    ///
    /// # Errors
    ///
    /// Returns an error if storage cannot be initialized.
    pub fn with_config(client: &'a ThingsClient, config: EngineConfig) -> Result<Self, ClingsError> {
        let storage = RuleStorage::new()?;
        let sync_queue = SyncQueue::new().ok();

        Ok(Self {
            client,
            storage,
            sync_queue,
            config,
        })
    }

    /// Run all matching rules for the given context.
    ///
    /// # Errors
    ///
    /// Returns an error if rules cannot be loaded.
    pub fn run(&self, context: &RuleContext) -> Result<EngineResult, ClingsError> {
        let rules = self.storage.list()?;
        let mut result = EngineResult::empty();

        for rule in rules {
            result.rules_evaluated += 1;

            if !rule.should_trigger(context) {
                continue;
            }

            if !rule.conditions_met(context) {
                continue;
            }

            result.rules_triggered += 1;

            let rule_result = self.execute_rule(&rule, context)?;

            for action_result in &rule_result.action_results {
                if action_result.success {
                    result.actions_executed += 1;
                } else {
                    result.actions_failed += 1;
                }
            }

            result.rule_results.push(rule_result);
        }

        Ok(result)
    }

    /// Run a specific rule by name.
    ///
    /// # Errors
    ///
    /// Returns an error if the rule cannot be found or executed.
    pub fn run_rule(&self, name: &str, context: &RuleContext) -> Result<RuleResult, ClingsError> {
        let rule = self
            .storage
            .load(name)?
            .ok_or_else(|| ClingsError::NotFound(format!("Rule not found: {name}")))?;

        self.execute_rule(&rule, context)
    }

    /// Execute a rule's actions.
    fn execute_rule(&self, rule: &Rule, context: &RuleContext) -> Result<RuleResult, ClingsError> {
        let mut action_results = Vec::new();

        for action in rule.actions.iter().take(self.config.max_actions) {
            let substituted = action.with_substitution(context);

            let result = if self.config.dry_run {
                ActionResult::success_with_message("Dry run - action skipped")
            } else {
                self.execute_action(&substituted.action_type, &substituted.params)
            };

            // Queue failed actions for sync if configured
            if !result.success && self.config.queue_on_failure {
                if let Some(queue) = &self.sync_queue {
                    if let Some(mut op) = self.action_to_operation(&substituted.action_type, &substituted.params) {
                        let _ = queue.enqueue(&mut op);
                    }
                }
            }

            action_results.push(result);
        }

        Ok(RuleResult {
            rule_name: rule.name.clone(),
            triggered: true,
            action_results,
        })
    }

    /// Execute a single action.
    fn execute_action(&self, action_type: &ActionType, params: &ActionParams) -> ActionResult {
        match action_type {
            ActionType::AddTodo => self.execute_add_todo(params),
            ActionType::CompleteTodo => self.execute_complete_todo(params),
            ActionType::CancelTodo => self.execute_cancel_todo(params),
            ActionType::AddTags => self.execute_add_tags(params),
            ActionType::RemoveTags => ActionResult::failure("Remove tags not implemented"),
            ActionType::MoveTodo => ActionResult::failure("Move todo not implemented"),
            ActionType::SetDue => ActionResult::failure("Set due not implemented"),
            ActionType::ClearDue => ActionResult::failure("Clear due not implemented"),
            ActionType::Log => self.execute_log(params),
            ActionType::Notify => self.execute_notify(params),
            ActionType::Shell => self.execute_shell(params),
            ActionType::OpenUrl => ActionResult::failure("Open URL not implemented"),
            ActionType::StartFocus => ActionResult::failure("Start focus not implemented"),
            ActionType::QueueSync => self.execute_queue_sync(params),
        }
    }

    fn execute_add_todo(&self, params: &ActionParams) -> ActionResult {
        if let ActionParams::AddTodo {
            title,
            notes,
            project,
            tags,
            when,
            deadline: _,
        } = params
        {
            match self.client.add_todo(
                title,
                notes.as_deref(),
                when.as_deref(),
                tags.as_deref(),
                project.as_deref(),
                None, // checklist
            ) {
                Ok(response) => ActionResult::success_with_id(&response.id),
                Err(e) => ActionResult::failure(e.to_string()),
            }
        } else {
            ActionResult::failure("Invalid add todo parameters")
        }
    }

    fn execute_complete_todo(&self, params: &ActionParams) -> ActionResult {
        if let ActionParams::TodoId { id } = params {
            match self.client.complete_todo(id) {
                Ok(()) => ActionResult::success(),
                Err(e) => ActionResult::failure(e.to_string()),
            }
        } else {
            ActionResult::failure("Invalid complete parameters")
        }
    }

    fn execute_cancel_todo(&self, params: &ActionParams) -> ActionResult {
        if let ActionParams::TodoId { id } = params {
            match self.client.cancel_todo(id) {
                Ok(()) => ActionResult::success(),
                Err(e) => ActionResult::failure(e.to_string()),
            }
        } else {
            ActionResult::failure("Invalid cancel parameters")
        }
    }

    fn execute_add_tags(&self, params: &ActionParams) -> ActionResult {
        if let ActionParams::Tags { id, tags } = params {
            // Tags are added via update, which isn't fully implemented
            ActionResult::failure(format!(
                "Add tags not fully implemented: {} tags to {}",
                tags.len(),
                id
            ))
        } else {
            ActionResult::failure("Invalid tag parameters")
        }
    }

    fn execute_log(&self, params: &ActionParams) -> ActionResult {
        if let ActionParams::Message { message } = params {
            println!("[automation] {message}");
            ActionResult::success()
        } else {
            ActionResult::failure("Invalid log parameters")
        }
    }

    fn execute_notify(&self, params: &ActionParams) -> ActionResult {
        if let ActionParams::Notification { title, message } = params {
            // Use osascript to show notification
            let script = format!(
                r#"display notification "{}" with title "{}""#,
                message.replace('"', r#"\""#),
                title.replace('"', r#"\""#)
            );

            match std::process::Command::new("osascript")
                .arg("-e")
                .arg(&script)
                .output()
            {
                Ok(_) => ActionResult::success(),
                Err(e) => ActionResult::failure(e.to_string()),
            }
        } else {
            ActionResult::failure("Invalid notification parameters")
        }
    }

    fn execute_shell(&self, params: &ActionParams) -> ActionResult {
        if let ActionParams::Command { command } = params {
            match std::process::Command::new("sh")
                .arg("-c")
                .arg(command)
                .output()
            {
                Ok(output) => {
                    if output.status.success() {
                        let stdout = String::from_utf8_lossy(&output.stdout);
                        ActionResult::success_with_message(stdout.trim().to_string())
                    } else {
                        let stderr = String::from_utf8_lossy(&output.stderr);
                        ActionResult::failure(stderr.trim().to_string())
                    }
                }
                Err(e) => ActionResult::failure(e.to_string()),
            }
        } else {
            ActionResult::failure("Invalid shell parameters")
        }
    }

    fn execute_queue_sync(&self, params: &ActionParams) -> ActionResult {
        if let Some(queue) = &self.sync_queue {
            // Queue a generic operation based on params
            if let ActionParams::TodoId { id } = params {
                let mut op = Operation::complete_todo(id.clone());
                match queue.enqueue(&mut op) {
                    Ok(()) => ActionResult::success_with_message(format!("Queued: {id}")),
                    Err(e) => ActionResult::failure(e.to_string()),
                }
            } else {
                ActionResult::failure("Invalid queue parameters")
            }
        } else {
            ActionResult::failure("Sync queue not available")
        }
    }

    /// Convert an action to a sync operation.
    fn action_to_operation(&self, action_type: &ActionType, params: &ActionParams) -> Option<Operation> {
        match (action_type, params) {
            (ActionType::CompleteTodo, ActionParams::TodoId { id }) => {
                Some(Operation::complete_todo(id.clone()))
            }
            (ActionType::CancelTodo, ActionParams::TodoId { id }) => {
                Some(Operation::cancel_todo(id.clone()))
            }
            _ => None,
        }
    }

    /// Trigger event-based rules.
    ///
    /// # Errors
    ///
    /// Returns an error if rules cannot be run.
    pub fn trigger_event(&self, event: EventType) -> Result<EngineResult, ClingsError> {
        let context = RuleContext::with_event(event);
        self.run(&context)
    }

    /// Get all rules.
    ///
    /// # Errors
    ///
    /// Returns an error if rules cannot be loaded.
    pub fn list_rules(&self) -> Result<Vec<Rule>, ClingsError> {
        self.storage.list()
    }

    /// Save a rule.
    ///
    /// # Errors
    ///
    /// Returns an error if the rule cannot be saved.
    pub fn save_rule(&self, rule: &Rule) -> Result<(), ClingsError> {
        self.storage.save(rule)
    }

    /// Delete a rule.
    ///
    /// # Errors
    ///
    /// Returns an error if the rule cannot be deleted.
    pub fn delete_rule(&self, name: &str) -> Result<bool, ClingsError> {
        self.storage.delete(name)
    }
}

/// Format engine result for display.
pub fn format_engine_result(result: &EngineResult) -> String {
    let mut lines = Vec::new();

    lines.push(format!(
        "Automation run complete: {}/{} rules triggered",
        result.rules_triggered, result.rules_evaluated
    ));
    lines.push("─".repeat(50));

    if result.rules_triggered == 0 {
        lines.push("  No rules triggered".dimmed().to_string());
        return lines.join("\n");
    }

    for rule_result in &result.rule_results {
        let status = if rule_result
            .action_results
            .iter()
            .all(|r| r.success)
        {
            "✓".green()
        } else {
            "✗".red()
        };

        lines.push(format!("{} {}", status, rule_result.rule_name));

        for (i, action_result) in rule_result.action_results.iter().enumerate() {
            let action_status = if action_result.success { "✓" } else { "✗" };
            let msg = action_result
                .message
                .as_deref()
                .or(action_result.error.as_deref())
                .unwrap_or("Done");

            lines.push(format!("    {} Action {}: {}", action_status, i + 1, msg));
        }
    }

    lines.push(String::new());
    lines.push(format!(
        "Summary: {} actions executed, {} failed",
        result.actions_executed, result.actions_failed
    ));

    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_config_default() {
        let config = EngineConfig::default();
        assert!(!config.dry_run);
        assert_eq!(config.max_actions, 10);
        assert!(config.queue_on_failure);
    }

    #[test]
    fn test_engine_result_empty() {
        let result = EngineResult::empty();
        assert_eq!(result.rules_evaluated, 0);
        assert_eq!(result.rules_triggered, 0);
    }
}
