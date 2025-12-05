//! Shared traits for Things 3 items.
//!
//! These traits provide common interfaces for filtering, rendering, and
//! scheduling operations across todos, projects, and other items.

use chrono::NaiveDate;

/// A value that can be extracted from a filterable item.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FieldValue {
    /// String value.
    String(String),
    /// Optional string value.
    OptionalString(Option<String>),
    /// Boolean value.
    Bool(bool),
    /// Integer value.
    Integer(i64),
    /// Date value.
    Date(NaiveDate),
    /// Optional date value.
    OptionalDate(Option<NaiveDate>),
    /// List of strings (e.g., tags).
    StringList(Vec<String>),
}

impl FieldValue {
    /// Check if this value contains a substring (case-insensitive).
    #[must_use]
    pub fn contains_str(&self, needle: &str) -> bool {
        let needle_lower = needle.to_lowercase();
        match self {
            Self::String(s) | Self::OptionalString(Some(s)) => {
                s.to_lowercase().contains(&needle_lower)
            },
            Self::StringList(list) => list
                .iter()
                .any(|s| s.to_lowercase().contains(&needle_lower)),
            Self::OptionalString(None)
            | Self::Bool(_)
            | Self::Integer(_)
            | Self::Date(_)
            | Self::OptionalDate(_) => false,
        }
    }

    /// Check if this value equals another (for string comparisons).
    #[must_use]
    pub fn equals_str(&self, other: &str) -> bool {
        match self {
            Self::String(s) | Self::OptionalString(Some(s)) => s.eq_ignore_ascii_case(other),
            Self::OptionalString(None)
            | Self::Bool(_)
            | Self::Integer(_)
            | Self::Date(_)
            | Self::OptionalDate(_)
            | Self::StringList(_) => false,
        }
    }

    /// Check if this value is null/none.
    #[must_use]
    pub const fn is_null(&self) -> bool {
        matches!(self, Self::OptionalString(None) | Self::OptionalDate(None))
    }

    /// Get as a date for comparison.
    #[must_use]
    pub const fn as_date(&self) -> Option<NaiveDate> {
        match self {
            Self::Date(d) => Some(*d),
            Self::OptionalDate(d) => *d,
            _ => None,
        }
    }

    /// Check if a list contains a specific value.
    #[must_use]
    pub fn list_contains(&self, item: &str) -> bool {
        match self {
            Self::StringList(list) => list.iter().any(|s| s.eq_ignore_ascii_case(item)),
            _ => false,
        }
    }
}

/// Trait for items that can be filtered.
///
/// This trait allows todos, projects, and other items to be filtered
/// using a unified interface.
pub trait Filterable {
    /// Get the value of a named field.
    ///
    /// Returns `None` if the field doesn't exist.
    fn field_value(&self, field: &str) -> Option<FieldValue>;

    /// Get the unique identifier.
    fn id(&self) -> &str;

    /// Get the display name.
    fn name(&self) -> &str;
}

/// Trait for items with scheduling capabilities.
pub trait Schedulable {
    /// Get the "when" date (scheduled date).
    fn when_date(&self) -> Option<NaiveDate>;

    /// Get the deadline date.
    fn deadline(&self) -> Option<NaiveDate>;

    /// Check if this item is due today or earlier.
    fn is_due(&self) -> bool {
        let today = chrono::Local::now().date_naive();
        self.when_date().is_some_and(|d| d <= today)
    }

    /// Check if this item is overdue (past deadline).
    fn is_overdue(&self) -> bool {
        let today = chrono::Local::now().date_naive();
        self.deadline().is_some_and(|d| d < today)
    }

    /// Check if this item is due within the next N days.
    fn is_due_within(&self, days: i64) -> bool {
        let today = chrono::Local::now().date_naive();
        let deadline = today + chrono::Duration::days(days);
        self.when_date().is_some_and(|d| d <= deadline)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_field_value_contains_str() {
        let value = FieldValue::String("Hello World".to_string());
        assert!(value.contains_str("hello"));
        assert!(value.contains_str("WORLD"));
        assert!(!value.contains_str("foo"));
    }

    #[test]
    fn test_field_value_string_list() {
        let value = FieldValue::StringList(vec!["work".to_string(), "urgent".to_string()]);
        assert!(value.list_contains("work"));
        assert!(value.list_contains("URGENT"));
        assert!(!value.list_contains("personal"));
    }

    #[test]
    fn test_field_value_is_null() {
        assert!(FieldValue::OptionalString(None).is_null());
        assert!(FieldValue::OptionalDate(None).is_null());
        assert!(!FieldValue::String("test".to_string()).is_null());
        assert!(!FieldValue::OptionalString(Some("test".to_string())).is_null());
    }

    #[test]
    fn test_field_value_as_date() {
        let date = NaiveDate::from_ymd_opt(2024, 1, 15).unwrap();
        assert_eq!(FieldValue::Date(date).as_date(), Some(date));
        assert_eq!(FieldValue::OptionalDate(Some(date)).as_date(), Some(date));
        assert_eq!(FieldValue::OptionalDate(None).as_date(), None);
        assert_eq!(FieldValue::String("test".to_string()).as_date(), None);
    }
}
