//! Conditions for automation rules.
//!
//! Conditions determine whether a rule's actions should execute.

use chrono::{Datelike, Timelike};
use serde::{Deserialize, Serialize};

use super::rule::RuleContext;

/// A condition for rule evaluation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Condition {
    /// Field to evaluate
    pub field: ConditionField,
    /// Comparison operator
    pub operator: ConditionOperator,
    /// Value to compare against
    pub value: ConditionValue,
}

impl Condition {
    /// Create a new condition.
    #[must_use]
    pub fn new(field: ConditionField, operator: ConditionOperator, value: ConditionValue) -> Self {
        Self {
            field,
            operator,
            value,
        }
    }

    /// Create a tag contains condition.
    #[must_use]
    pub fn has_tag(tag: impl Into<String>) -> Self {
        Self::new(
            ConditionField::Tags,
            ConditionOperator::Contains,
            ConditionValue::String(tag.into()),
        )
    }

    /// Create a project equals condition.
    #[must_use]
    pub fn in_project(project: impl Into<String>) -> Self {
        Self::new(
            ConditionField::Project,
            ConditionOperator::Equals,
            ConditionValue::String(project.into()),
        )
    }

    /// Create a weekday condition.
    #[must_use]
    pub fn on_weekday(day: chrono::Weekday) -> Self {
        Self::new(
            ConditionField::DayOfWeek,
            ConditionOperator::Equals,
            ConditionValue::Integer(day.num_days_from_monday() as i64),
        )
    }

    /// Create an hour range condition.
    #[must_use]
    pub fn between_hours(start: u32, end: u32) -> Self {
        Self::new(
            ConditionField::Hour,
            ConditionOperator::Between,
            ConditionValue::Range(start as i64, end as i64),
        )
    }

    /// Evaluate the condition against a context.
    #[must_use]
    pub fn evaluate(&self, context: &RuleContext) -> bool {
        let field_value = self.field.get_value(context);
        self.operator.evaluate(&field_value, &self.value)
    }
}

/// Fields that can be used in conditions.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConditionField {
    /// Todo name
    TodoName,
    /// Project name
    Project,
    /// Area name
    Area,
    /// Tags
    Tags,
    /// Day of week (0 = Monday)
    DayOfWeek,
    /// Hour of day (0-23)
    Hour,
    /// Variable value
    Variable(String),
}

impl ConditionField {
    /// Get the value of this field from a context.
    #[must_use]
    pub fn get_value(&self, context: &RuleContext) -> ConditionValue {
        match self {
            Self::TodoName => {
                ConditionValue::String(context.todo_name.clone().unwrap_or_default())
            }
            Self::Project => {
                ConditionValue::String(context.project.clone().unwrap_or_default())
            }
            Self::Area => ConditionValue::String(String::new()), // TODO: Add area to context
            Self::Tags => ConditionValue::List(context.tags.clone()),
            Self::DayOfWeek => {
                ConditionValue::Integer(context.now.weekday().num_days_from_monday() as i64)
            }
            Self::Hour => ConditionValue::Integer(context.now.hour() as i64),
            Self::Variable(name) => {
                ConditionValue::String(context.get_variable(name).cloned().unwrap_or_default())
            }
        }
    }
}

/// Comparison operators for conditions.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConditionOperator {
    /// Equal to
    Equals,
    /// Not equal to
    NotEquals,
    /// Contains (for strings/lists)
    Contains,
    /// Does not contain
    NotContains,
    /// Starts with
    StartsWith,
    /// Ends with
    EndsWith,
    /// Greater than
    GreaterThan,
    /// Less than
    LessThan,
    /// Between two values
    Between,
    /// Is empty
    IsEmpty,
    /// Is not empty
    IsNotEmpty,
    /// Matches regex pattern
    Matches,
}

impl ConditionOperator {
    /// Evaluate the operator.
    #[must_use]
    pub fn evaluate(&self, field_value: &ConditionValue, compare_value: &ConditionValue) -> bool {
        match self {
            Self::Equals => field_value == compare_value,
            Self::NotEquals => field_value != compare_value,
            Self::Contains => match (field_value, compare_value) {
                (ConditionValue::String(s), ConditionValue::String(needle)) => s.contains(needle),
                (ConditionValue::List(list), ConditionValue::String(item)) => list.contains(item),
                _ => false,
            },
            Self::NotContains => !self.evaluate_contains(field_value, compare_value),
            Self::StartsWith => match (field_value, compare_value) {
                (ConditionValue::String(s), ConditionValue::String(prefix)) => s.starts_with(prefix),
                _ => false,
            },
            Self::EndsWith => match (field_value, compare_value) {
                (ConditionValue::String(s), ConditionValue::String(suffix)) => s.ends_with(suffix),
                _ => false,
            },
            Self::GreaterThan => match (field_value, compare_value) {
                (ConditionValue::Integer(a), ConditionValue::Integer(b)) => a > b,
                _ => false,
            },
            Self::LessThan => match (field_value, compare_value) {
                (ConditionValue::Integer(a), ConditionValue::Integer(b)) => a < b,
                _ => false,
            },
            Self::Between => match (field_value, compare_value) {
                (ConditionValue::Integer(v), ConditionValue::Range(min, max)) => {
                    *v >= *min && *v <= *max
                }
                _ => false,
            },
            Self::IsEmpty => match field_value {
                ConditionValue::String(s) => s.is_empty(),
                ConditionValue::List(list) => list.is_empty(),
                _ => false,
            },
            Self::IsNotEmpty => !Self::IsEmpty.evaluate(field_value, compare_value),
            Self::Matches => match (field_value, compare_value) {
                (ConditionValue::String(s), ConditionValue::String(pattern)) => {
                    regex::Regex::new(pattern)
                        .map(|re| re.is_match(s))
                        .unwrap_or(false)
                }
                _ => false,
            },
        }
    }

    fn evaluate_contains(&self, field_value: &ConditionValue, compare_value: &ConditionValue) -> bool {
        match (field_value, compare_value) {
            (ConditionValue::String(s), ConditionValue::String(needle)) => s.contains(needle),
            (ConditionValue::List(list), ConditionValue::String(item)) => list.contains(item),
            _ => false,
        }
    }
}

/// Values used in conditions.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum ConditionValue {
    /// String value
    String(String),
    /// Integer value
    Integer(i64),
    /// Boolean value
    Boolean(bool),
    /// List of strings
    List(Vec<String>),
    /// Range (min, max)
    Range(i64, i64),
}

impl From<String> for ConditionValue {
    fn from(s: String) -> Self {
        Self::String(s)
    }
}

impl From<&str> for ConditionValue {
    fn from(s: &str) -> Self {
        Self::String(s.to_string())
    }
}

impl From<i64> for ConditionValue {
    fn from(n: i64) -> Self {
        Self::Integer(n)
    }
}

impl From<bool> for ConditionValue {
    fn from(b: bool) -> Self {
        Self::Boolean(b)
    }
}

impl From<Vec<String>> for ConditionValue {
    fn from(v: Vec<String>) -> Self {
        Self::List(v)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Weekday;

    #[test]
    fn test_has_tag_condition() {
        let cond = Condition::has_tag("work");

        let ctx = RuleContext::now().with_tags(vec!["work".to_string(), "urgent".to_string()]);
        assert!(cond.evaluate(&ctx));

        let ctx_no_tag = RuleContext::now().with_tags(vec!["personal".to_string()]);
        assert!(!cond.evaluate(&ctx_no_tag));
    }

    #[test]
    fn test_project_condition() {
        let cond = Condition::in_project("Work");

        let ctx = RuleContext::now().with_project("Work".to_string());
        assert!(cond.evaluate(&ctx));

        let ctx_diff = RuleContext::now().with_project("Home".to_string());
        assert!(!cond.evaluate(&ctx_diff));
    }

    #[test]
    fn test_weekday_condition() {
        let cond = Condition::on_weekday(Weekday::Mon);

        // This test is time-dependent, so we just verify it doesn't panic
        let ctx = RuleContext::now();
        let _ = cond.evaluate(&ctx);
    }

    #[test]
    fn test_between_hours() {
        let cond = Condition::between_hours(9, 17);

        // This test is time-dependent
        let ctx = RuleContext::now();
        let _ = cond.evaluate(&ctx);
    }

    #[test]
    fn test_string_operations() {
        let ctx = RuleContext::now()
            .with_todo("ABC".to_string(), "Buy groceries".to_string());

        let starts = Condition::new(
            ConditionField::TodoName,
            ConditionOperator::StartsWith,
            ConditionValue::String("Buy".to_string()),
        );
        assert!(starts.evaluate(&ctx));

        let contains = Condition::new(
            ConditionField::TodoName,
            ConditionOperator::Contains,
            ConditionValue::String("groceries".to_string()),
        );
        assert!(contains.evaluate(&ctx));
    }
}
