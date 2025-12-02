//! Automation rule definitions.
//!
//! Rules define when and what actions to perform.

use chrono::{DateTime, Datelike, NaiveTime, Utc, Weekday};
use serde::{Deserialize, Serialize};

use super::action::Action;
use super::condition::Condition;

/// An automation rule.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rule {
    /// Unique rule ID
    pub id: Option<i64>,
    /// Rule name
    pub name: String,
    /// Rule description
    pub description: Option<String>,
    /// Whether the rule is enabled
    pub enabled: bool,
    /// Trigger that activates this rule
    pub trigger: Trigger,
    /// Conditions that must be met
    pub conditions: Vec<Condition>,
    /// Actions to perform
    pub actions: Vec<Action>,
    /// Last time the rule was executed
    pub last_run: Option<DateTime<Utc>>,
    /// Number of times executed
    pub run_count: i64,
    /// Priority (lower = higher priority)
    pub priority: i32,
}

impl Rule {
    /// Create a new rule.
    #[must_use]
    pub fn new(name: impl Into<String>, trigger: Trigger) -> Self {
        Self {
            id: None,
            name: name.into(),
            description: None,
            enabled: true,
            trigger,
            conditions: Vec::new(),
            actions: Vec::new(),
            last_run: None,
            run_count: 0,
            priority: 100,
        }
    }

    /// Set the description.
    #[must_use]
    pub fn with_description(mut self, description: impl Into<String>) -> Self {
        self.description = Some(description.into());
        self
    }

    /// Add a condition.
    #[must_use]
    pub fn with_condition(mut self, condition: Condition) -> Self {
        self.conditions.push(condition);
        self
    }

    /// Add an action.
    #[must_use]
    pub fn with_action(mut self, action: Action) -> Self {
        self.actions.push(action);
        self
    }

    /// Set priority.
    #[must_use]
    pub fn with_priority(mut self, priority: i32) -> Self {
        self.priority = priority;
        self
    }

    /// Check if all conditions are met.
    #[must_use]
    pub fn conditions_met(&self, context: &RuleContext) -> bool {
        if self.conditions.is_empty() {
            return true;
        }
        self.conditions.iter().all(|c| c.evaluate(context))
    }

    /// Check if the trigger should fire now.
    #[must_use]
    pub fn should_trigger(&self, context: &RuleContext) -> bool {
        if !self.enabled {
            return false;
        }
        self.trigger.should_fire(context, self.last_run.as_ref())
    }
}

/// Trigger that activates a rule.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Trigger {
    /// Trigger type
    pub trigger_type: TriggerType,
    /// Additional configuration
    pub config: TriggerConfig,
}

impl Trigger {
    /// Create a scheduled trigger.
    #[must_use]
    pub fn scheduled(schedule: Schedule) -> Self {
        Self {
            trigger_type: TriggerType::Scheduled,
            config: TriggerConfig::Schedule(schedule),
        }
    }

    /// Create an event trigger.
    #[must_use]
    pub fn on_event(event: EventType) -> Self {
        Self {
            trigger_type: TriggerType::Event,
            config: TriggerConfig::Event(event),
        }
    }

    /// Create a manual trigger.
    #[must_use]
    pub fn manual() -> Self {
        Self {
            trigger_type: TriggerType::Manual,
            config: TriggerConfig::None,
        }
    }

    /// Create a startup trigger.
    #[must_use]
    pub fn on_startup() -> Self {
        Self {
            trigger_type: TriggerType::Startup,
            config: TriggerConfig::None,
        }
    }

    /// Check if the trigger should fire.
    #[must_use]
    pub fn should_fire(&self, context: &RuleContext, last_run: Option<&DateTime<Utc>>) -> bool {
        match &self.config {
            TriggerConfig::Schedule(schedule) => schedule.should_fire(context.now, last_run),
            TriggerConfig::Event(event) => context.event.as_ref() == Some(event),
            TriggerConfig::None => {
                matches!(self.trigger_type, TriggerType::Manual | TriggerType::Startup)
            }
        }
    }
}

/// Types of triggers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TriggerType {
    /// Time-based schedule
    Scheduled,
    /// Event-based (on todo complete, etc.)
    Event,
    /// Manually triggered
    Manual,
    /// On application startup
    Startup,
}

impl TriggerType {
    /// Get display name.
    #[must_use]
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Scheduled => "Scheduled",
            Self::Event => "Event",
            Self::Manual => "Manual",
            Self::Startup => "Startup",
        }
    }
}

/// Trigger configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum TriggerConfig {
    /// Schedule configuration
    Schedule(Schedule),
    /// Event configuration
    Event(EventType),
    /// No configuration
    None,
}

/// Schedule for time-based triggers.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Schedule {
    /// Schedule type
    pub schedule_type: ScheduleType,
    /// Time of day (for daily/weekly)
    pub time: Option<NaiveTime>,
    /// Days of week (for weekly)
    pub days: Option<Vec<Weekday>>,
    /// Interval in minutes (for interval-based)
    pub interval_minutes: Option<i64>,
}

impl Schedule {
    /// Create a daily schedule.
    #[must_use]
    pub fn daily(time: NaiveTime) -> Self {
        Self {
            schedule_type: ScheduleType::Daily,
            time: Some(time),
            days: None,
            interval_minutes: None,
        }
    }

    /// Create a weekly schedule.
    #[must_use]
    pub fn weekly(days: Vec<Weekday>, time: NaiveTime) -> Self {
        Self {
            schedule_type: ScheduleType::Weekly,
            time: Some(time),
            days: Some(days),
            interval_minutes: None,
        }
    }

    /// Create an interval schedule.
    #[must_use]
    pub fn every_minutes(minutes: i64) -> Self {
        Self {
            schedule_type: ScheduleType::Interval,
            time: None,
            days: None,
            interval_minutes: Some(minutes),
        }
    }

    /// Check if the schedule should fire.
    #[must_use]
    pub fn should_fire(&self, now: DateTime<Utc>, last_run: Option<&DateTime<Utc>>) -> bool {
        match self.schedule_type {
            ScheduleType::Daily => {
                // Check if we've passed the scheduled time today and haven't run yet
                if let Some(scheduled_time) = self.time {
                    let now_time = now.time();
                    let today_start = now.date_naive().and_hms_opt(0, 0, 0).map(|t| {
                        DateTime::<Utc>::from_naive_utc_and_offset(t, Utc)
                    });

                    if let Some(last) = last_run {
                        if let Some(start) = today_start {
                            // Has run since today started
                            if *last >= start {
                                return false;
                            }
                        }
                    }

                    now_time >= scheduled_time
                } else {
                    false
                }
            }
            ScheduleType::Weekly => {
                if let (Some(scheduled_time), Some(days)) = (&self.time, &self.days) {
                    let weekday = now.weekday();
                    if !days.contains(&weekday) {
                        return false;
                    }

                    let now_time = now.time();
                    let today_start = now.date_naive().and_hms_opt(0, 0, 0).map(|t| {
                        DateTime::<Utc>::from_naive_utc_and_offset(t, Utc)
                    });

                    if let Some(last) = last_run {
                        if let Some(start) = today_start {
                            if *last >= start {
                                return false;
                            }
                        }
                    }

                    now_time >= *scheduled_time
                } else {
                    false
                }
            }
            ScheduleType::Interval => {
                if let Some(interval) = self.interval_minutes {
                    match last_run {
                        Some(last) => {
                            let elapsed = now.signed_duration_since(*last);
                            elapsed.num_minutes() >= interval
                        }
                        None => true, // Never run, should fire
                    }
                } else {
                    false
                }
            }
        }
    }
}

/// Types of schedules.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ScheduleType {
    /// Run daily at a specific time
    Daily,
    /// Run weekly on specific days
    Weekly,
    /// Run at regular intervals
    Interval,
}

/// Event types that can trigger rules.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EventType {
    /// A todo was created
    TodoCreated,
    /// A todo was completed
    TodoCompleted,
    /// A todo was canceled
    TodoCanceled,
    /// A todo's due date passed
    TodoOverdue,
    /// A project was completed
    ProjectCompleted,
    /// Inbox count exceeded threshold
    InboxOverflow { threshold: usize },
    /// Focus session completed
    FocusSessionCompleted,
    /// Review completed
    ReviewCompleted,
}

impl EventType {
    /// Get display name.
    #[must_use]
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::TodoCreated => "Todo Created",
            Self::TodoCompleted => "Todo Completed",
            Self::TodoCanceled => "Todo Canceled",
            Self::TodoOverdue => "Todo Overdue",
            Self::ProjectCompleted => "Project Completed",
            Self::InboxOverflow { .. } => "Inbox Overflow",
            Self::FocusSessionCompleted => "Focus Session Completed",
            Self::ReviewCompleted => "Review Completed",
        }
    }
}

/// Context for rule evaluation.
#[derive(Debug, Clone)]
pub struct RuleContext {
    /// Current time
    pub now: DateTime<Utc>,
    /// Current event (if any)
    pub event: Option<EventType>,
    /// Current todo (if applicable)
    pub todo_id: Option<String>,
    /// Current todo name
    pub todo_name: Option<String>,
    /// Current project
    pub project: Option<String>,
    /// Current tags
    pub tags: Vec<String>,
    /// Variables for substitution
    pub variables: std::collections::HashMap<String, String>,
}

impl RuleContext {
    /// Create a new context for the current time.
    #[must_use]
    pub fn now() -> Self {
        Self {
            now: Utc::now(),
            event: None,
            todo_id: None,
            todo_name: None,
            project: None,
            tags: Vec::new(),
            variables: std::collections::HashMap::new(),
        }
    }

    /// Create a context with an event.
    #[must_use]
    pub fn with_event(event: EventType) -> Self {
        let mut ctx = Self::now();
        ctx.event = Some(event);
        ctx
    }

    /// Set the current todo.
    #[must_use]
    pub fn with_todo(mut self, id: String, name: String) -> Self {
        self.todo_id = Some(id);
        self.todo_name = Some(name);
        self
    }

    /// Set the current project.
    #[must_use]
    pub fn with_project(mut self, project: String) -> Self {
        self.project = Some(project);
        self
    }

    /// Set tags.
    #[must_use]
    pub fn with_tags(mut self, tags: Vec<String>) -> Self {
        self.tags = tags;
        self
    }

    /// Add a variable.
    pub fn set_variable(&mut self, key: impl Into<String>, value: impl Into<String>) {
        self.variables.insert(key.into(), value.into());
    }

    /// Get a variable.
    #[must_use]
    pub fn get_variable(&self, key: &str) -> Option<&String> {
        self.variables.get(key)
    }

    /// Substitute variables in a string.
    #[must_use]
    pub fn substitute(&self, template: &str) -> String {
        let mut result = template.to_string();

        // Built-in variables
        result = result.replace("{today}", &self.now.format("%Y-%m-%d").to_string());
        result = result.replace("{now}", &self.now.format("%H:%M").to_string());

        if let Some(name) = &self.todo_name {
            result = result.replace("{todo_name}", name);
        }
        if let Some(id) = &self.todo_id {
            result = result.replace("{todo_id}", id);
        }
        if let Some(project) = &self.project {
            result = result.replace("{project}", project);
        }

        // Custom variables
        for (key, value) in &self.variables {
            result = result.replace(&format!("{{{key}}}"), value);
        }

        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rule_builder() {
        let rule = Rule::new("Test Rule", Trigger::manual())
            .with_description("A test rule")
            .with_priority(50);

        assert_eq!(rule.name, "Test Rule");
        assert_eq!(rule.description, Some("A test rule".to_string()));
        assert_eq!(rule.priority, 50);
        assert!(rule.enabled);
    }

    #[test]
    fn test_schedule_interval() {
        let schedule = Schedule::every_minutes(30);
        let now = Utc::now();

        // No last run - should fire
        assert!(schedule.should_fire(now, None));

        // Ran recently - should not fire
        let recent = now - chrono::Duration::minutes(15);
        assert!(!schedule.should_fire(now, Some(&recent)));

        // Ran long ago - should fire
        let old = now - chrono::Duration::minutes(45);
        assert!(schedule.should_fire(now, Some(&old)));
    }

    #[test]
    fn test_context_substitution() {
        let mut ctx = RuleContext::now()
            .with_todo("ABC123".to_string(), "Test Todo".to_string())
            .with_project("Work".to_string());

        ctx.set_variable("custom", "value");

        let result = ctx.substitute("Todo: {todo_name} in {project} ({custom})");
        assert_eq!(result, "Todo: Test Todo in Work (value)");
    }

    #[test]
    fn test_event_trigger() {
        let trigger = Trigger::on_event(EventType::TodoCompleted);
        let ctx = RuleContext::with_event(EventType::TodoCompleted);

        assert!(trigger.should_fire(&ctx, None));

        let wrong_ctx = RuleContext::with_event(EventType::TodoCreated);
        assert!(!trigger.should_fire(&wrong_ctx, None));
    }
}
