//! Automation command implementation.
//!
//! Handles automation rule management commands.

use std::fs;

use colored::Colorize;

use crate::cli::args::{AutomationCommands, OutputFormat};
use crate::error::ClingsError;
use crate::features::automation::{
    format_engine_result, Action, AutomationEngine, EngineConfig, EventType, Rule, RuleContext,
    RuleStorage, Trigger,
};
use crate::output::to_json;
use crate::things::ThingsClient;

/// Execute automation subcommands.
pub fn automation(
    client: &ThingsClient,
    cmd: AutomationCommands,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let storage = RuleStorage::new()?;

    match cmd {
        AutomationCommands::List => list_rules(&storage, format),
        AutomationCommands::Show { name } => show_rule(&storage, &name, format),
        AutomationCommands::Run { rule, event, dry_run } => {
            run_automation(client, &storage, rule, event, dry_run, format)
        }
        AutomationCommands::Create {
            name,
            description,
            trigger,
        } => create_rule(&storage, &name, description, &trigger, format),
        AutomationCommands::Edit { name } => edit_rule(&storage, &name, format),
        AutomationCommands::Delete { name, force } => delete_rule(&storage, &name, force, format),
        AutomationCommands::Toggle { name, enable, disable } => {
            toggle_rule(&storage, &name, enable, disable, format)
        }
        AutomationCommands::Import { path, overwrite } => {
            import_rules(&storage, &path, overwrite, format)
        }
        AutomationCommands::Export { path, rules } => export_rules(&storage, &path, rules, format),
    }
}

/// List all rules.
fn list_rules(storage: &RuleStorage, format: OutputFormat) -> Result<String, ClingsError> {
    let rules = storage.list()?;

    match format {
        OutputFormat::Json => to_json(&rules),
        OutputFormat::Pretty => {
            if rules.is_empty() {
                return Ok("No automation rules defined.\n\nCreate one with: clings auto create <name>".to_string());
            }

            let mut lines = Vec::new();

            lines.push("Automation Rules".bold().to_string());
            lines.push("═".repeat(60));

            for rule in rules {
                let status = if rule.enabled {
                    "✓".green()
                } else {
                    "○".dimmed()
                };

                let trigger = rule.trigger.trigger_type.display_name();
                let actions = rule.actions.len();
                let conditions = rule.conditions.len();

                lines.push(format!("{} {}", status, rule.name.bold()));

                if let Some(desc) = &rule.description {
                    lines.push(format!("    {}", desc.dimmed()));
                }

                lines.push(format!(
                    "    Trigger: {} | {} actions | {} conditions",
                    trigger, actions, conditions
                ));

                if rule.run_count > 0 {
                    let last_run = rule
                        .last_run
                        .map(|t| t.format("%Y-%m-%d %H:%M").to_string())
                        .unwrap_or_else(|| "never".to_string());
                    lines.push(format!(
                        "    Runs: {} | Last: {}",
                        rule.run_count, last_run
                    ));
                }

                lines.push(String::new());
            }

            Ok(lines.join("\n"))
        }
    }
}

/// Show a specific rule.
fn show_rule(storage: &RuleStorage, name: &str, format: OutputFormat) -> Result<String, ClingsError> {
    let rule = storage
        .load(name)?
        .ok_or_else(|| ClingsError::NotFound(format!("Rule: {name}")))?;

    match format {
        OutputFormat::Json => to_json(&rule),
        OutputFormat::Pretty => {
            let mut lines = Vec::new();

            lines.push(format!("Rule: {}", rule.name.bold()));
            lines.push("═".repeat(50));

            if let Some(desc) = &rule.description {
                lines.push(format!("Description: {desc}"));
            }

            lines.push(format!(
                "Status: {}",
                if rule.enabled { "Enabled" } else { "Disabled" }
            ));
            lines.push(format!("Priority: {}", rule.priority));
            lines.push(String::new());

            lines.push("Trigger".to_string());
            lines.push("─".repeat(40));
            lines.push(format!(
                "  Type: {}",
                rule.trigger.trigger_type.display_name()
            ));
            lines.push(String::new());

            if !rule.conditions.is_empty() {
                lines.push("Conditions".to_string());
                lines.push("─".repeat(40));
                for (i, cond) in rule.conditions.iter().enumerate() {
                    lines.push(format!(
                        "  {}. {:?} {:?} {:?}",
                        i + 1,
                        cond.field,
                        cond.operator,
                        cond.value
                    ));
                }
                lines.push(String::new());
            }

            if !rule.actions.is_empty() {
                lines.push("Actions".to_string());
                lines.push("─".repeat(40));
                for (i, action) in rule.actions.iter().enumerate() {
                    lines.push(format!(
                        "  {}. {}",
                        i + 1,
                        action.action_type.display_name()
                    ));
                }
                lines.push(String::new());
            }

            lines.push("Statistics".to_string());
            lines.push("─".repeat(40));
            lines.push(format!("  Run count: {}", rule.run_count));
            if let Some(last) = rule.last_run {
                lines.push(format!("  Last run: {}", last.format("%Y-%m-%d %H:%M")));
            }

            Ok(lines.join("\n"))
        }
    }
}

/// Run automation.
fn run_automation(
    client: &ThingsClient,
    _storage: &RuleStorage,
    rule_name: Option<String>,
    event: Option<String>,
    dry_run: bool,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let config = EngineConfig {
        dry_run,
        ..Default::default()
    };

    let engine = AutomationEngine::with_config(client, config)?;

    let result = if let Some(name) = rule_name {
        // Run specific rule
        let context = RuleContext::now();
        let rule_result = engine.run_rule(&name, &context)?;

        // Create an engine result from single rule
        let mut result = crate::features::automation::EngineResult::empty();
        result.rules_evaluated = 1;
        result.rules_triggered = 1;
        for action_result in &rule_result.action_results {
            if action_result.success {
                result.actions_executed += 1;
            } else {
                result.actions_failed += 1;
            }
        }
        result.rule_results.push(rule_result);
        result
    } else if let Some(event_str) = event {
        // Trigger event
        let event_type = parse_event_type(&event_str)?;
        engine.trigger_event(event_type)?
    } else {
        // Run all matching rules
        let context = RuleContext::now();
        engine.run(&context)?
    };

    match format {
        OutputFormat::Json => {
            let data = serde_json::json!({
                "rules_evaluated": result.rules_evaluated,
                "rules_triggered": result.rules_triggered,
                "actions_executed": result.actions_executed,
                "actions_failed": result.actions_failed,
            });
            to_json(&data)
        }
        OutputFormat::Pretty => {
            if result.rules_evaluated == 0 {
                Ok("No rules defined. Create one with: clings auto create <name>".to_string())
            } else {
                Ok(format_engine_result(&result))
            }
        }
    }
}

/// Parse event type from string.
fn parse_event_type(s: &str) -> Result<EventType, ClingsError> {
    match s.to_lowercase().as_str() {
        "todo-created" | "todo_created" => Ok(EventType::TodoCreated),
        "todo-completed" | "todo_completed" => Ok(EventType::TodoCompleted),
        "todo-canceled" | "todo_canceled" => Ok(EventType::TodoCanceled),
        "todo-overdue" | "todo_overdue" => Ok(EventType::TodoOverdue),
        "project-completed" | "project_completed" => Ok(EventType::ProjectCompleted),
        "focus-completed" | "focus_completed" => Ok(EventType::FocusSessionCompleted),
        "review-completed" | "review_completed" => Ok(EventType::ReviewCompleted),
        _ => Err(ClingsError::Config(format!("Unknown event type: {s}"))),
    }
}

/// Create a new rule.
fn create_rule(
    storage: &RuleStorage,
    name: &str,
    description: Option<String>,
    trigger_type: &str,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    // Check if rule exists
    if storage.load(name)?.is_some() {
        return Err(ClingsError::Config(format!("Rule already exists: {name}")));
    }

    let trigger = match trigger_type.to_lowercase().as_str() {
        "manual" => Trigger::manual(),
        "startup" => Trigger::on_startup(),
        _ => Trigger::manual(),
    };

    let mut rule = Rule::new(name, trigger);

    if let Some(desc) = description {
        rule = rule.with_description(desc);
    }

    // Add a sample action
    rule = rule.with_action(Action::log("Rule executed: {todo_name}"));

    storage.save(&rule)?;

    match format {
        OutputFormat::Json => to_json(&rule),
        OutputFormat::Pretty => {
            let path = storage.rule_path(name);
            Ok(format!(
                "Created rule: {}\n\nEdit it at: {:?}\nOr run: clings auto edit {}",
                name, path, name
            ))
        }
    }
}

/// Edit a rule.
fn edit_rule(storage: &RuleStorage, name: &str, _format: OutputFormat) -> Result<String, ClingsError> {
    let path = storage.rule_path(name);

    if !path.exists() {
        return Err(ClingsError::NotFound(format!("Rule: {name}")));
    }

    // Try to open in editor
    let editor = std::env::var("EDITOR").unwrap_or_else(|_| "vi".to_string());

    std::process::Command::new(&editor)
        .arg(&path)
        .status()
        .map_err(|e| ClingsError::Config(format!("Failed to open editor: {e}")))?;

    Ok(format!("Edited rule: {name}"))
}

/// Delete a rule.
fn delete_rule(
    storage: &RuleStorage,
    name: &str,
    force: bool,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    if !force {
        return Err(ClingsError::Config(
            "Use --force to delete rule".to_string(),
        ));
    }

    if storage.delete(name)? {
        match format {
            OutputFormat::Json => {
                let data = serde_json::json!({"deleted": name});
                to_json(&data)
            }
            OutputFormat::Pretty => Ok(format!("Deleted rule: {name}")),
        }
    } else {
        Err(ClingsError::NotFound(format!("Rule: {name}")))
    }
}

/// Toggle a rule.
fn toggle_rule(
    storage: &RuleStorage,
    name: &str,
    enable: bool,
    disable: bool,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let mut rule = storage
        .load(name)?
        .ok_or_else(|| ClingsError::NotFound(format!("Rule: {name}")))?;

    if enable {
        rule.enabled = true;
    } else if disable {
        rule.enabled = false;
    } else {
        rule.enabled = !rule.enabled;
    }

    storage.save(&rule)?;

    let status = if rule.enabled { "enabled" } else { "disabled" };

    match format {
        OutputFormat::Json => {
            let data = serde_json::json!({"name": name, "enabled": rule.enabled});
            to_json(&data)
        }
        OutputFormat::Pretty => Ok(format!("Rule {} is now {}", name, status)),
    }
}

/// Import rules from file.
fn import_rules(
    storage: &RuleStorage,
    path: &str,
    overwrite: bool,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let yaml = fs::read_to_string(path)
        .map_err(|e| ClingsError::Config(format!("Failed to read file: {e}")))?;

    let rules: Vec<Rule> = serde_yaml::from_str(&yaml)
        .map_err(|e| ClingsError::Config(format!("Failed to parse YAML: {e}")))?;

    let mut imported = 0;
    let mut skipped = 0;

    for rule in rules {
        if storage.load(&rule.name)?.is_some() && !overwrite {
            skipped += 1;
            continue;
        }
        storage.save(&rule)?;
        imported += 1;
    }

    match format {
        OutputFormat::Json => {
            let data = serde_json::json!({
                "imported": imported,
                "skipped": skipped,
            });
            to_json(&data)
        }
        OutputFormat::Pretty => Ok(format!(
            "Imported {} rules, skipped {} existing",
            imported, skipped
        )),
    }
}

/// Export rules to file.
fn export_rules(
    storage: &RuleStorage,
    path: &str,
    rule_names: Option<Vec<String>>,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let all_rules = storage.list()?;

    let rules: Vec<Rule> = if let Some(names) = rule_names {
        all_rules
            .into_iter()
            .filter(|r| names.contains(&r.name))
            .collect()
    } else {
        all_rules
    };

    let yaml = serde_yaml::to_string(&rules)
        .map_err(|e| ClingsError::Config(format!("Failed to serialize: {e}")))?;

    fs::write(path, &yaml).map_err(|e| ClingsError::Config(format!("Failed to write file: {e}")))?;

    match format {
        OutputFormat::Json => {
            let data = serde_json::json!({
                "exported": rules.len(),
                "path": path,
            });
            to_json(&data)
        }
        OutputFormat::Pretty => Ok(format!("Exported {} rules to {}", rules.len(), path)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_event_type() {
        assert!(matches!(
            parse_event_type("todo-completed").unwrap(),
            EventType::TodoCompleted
        ));
        assert!(matches!(
            parse_event_type("focus_completed").unwrap(),
            EventType::FocusSessionCompleted
        ));
        assert!(parse_event_type("unknown").is_err());
    }
}
