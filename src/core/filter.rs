//! Filter engine for querying Things 3 items.
//!
//! Provides a SQL-like query language for filtering todos, projects, and other items.
//!
//! # Syntax
//!
//! ```text
//! field OPERATOR value [AND|OR condition...]
//! ```
//!
//! ## Operators
//! - `=`, `!=` - Equality
//! - `<`, `>`, `<=`, `>=` - Comparison (for dates and numbers)
//! - `LIKE` - Pattern matching (% for wildcard)
//! - `CONTAINS` - Substring match
//! - `IS NULL`, `IS NOT NULL` - Null checks
//! - `IN` - List membership (for tags)
//!
//! ## Fields
//! - `status` - open, completed, canceled
//! - `due` - Due date (YYYY-MM-DD or relative: today, tomorrow, etc.)
//! - `tags` - Tag list
//! - `project` - Project name
//! - `area` - Area name
//! - `name` - Item name/title
//! - `notes` - Item notes
//! - `created` - Creation date
//!
//! ## Examples
//!
//! ```text
//! status = open
//! status = open AND due < today
//! tags CONTAINS 'work' OR project = 'Home'
//! name LIKE '%report%' AND status != completed
//! due IS NOT NULL AND due <= tomorrow
//! ```

use chrono::NaiveDate;
use regex::Regex;

use crate::core::{parse_natural_date, FieldValue, Filterable};
use crate::error::ClingsError;

/// Comparison operators for filter conditions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Operator {
    /// Equality (=)
    Equal,
    /// Inequality (!=)
    NotEqual,
    /// Less than (<)
    LessThan,
    /// Less than or equal (<=)
    LessThanOrEqual,
    /// Greater than (>)
    GreaterThan,
    /// Greater than or equal (>=)
    GreaterThanOrEqual,
    /// Pattern match with wildcards (LIKE)
    Like,
    /// Substring containment (CONTAINS)
    Contains,
    /// Null check (IS NULL)
    IsNull,
    /// Non-null check (IS NOT NULL)
    IsNotNull,
    /// List membership (IN)
    In,
}

/// A single filter condition.
#[derive(Debug, Clone)]
pub struct Condition {
    /// The field to compare.
    pub field: String,
    /// The comparison operator.
    pub operator: Operator,
    /// The value to compare against.
    pub value: FilterValue,
}

/// A value in a filter expression.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FilterValue {
    /// String value (e.g., 'work')
    String(String),
    /// Date value (e.g., today, 2024-12-01)
    Date(NaiveDate),
    /// Boolean value
    Bool(bool),
    /// Integer value
    Integer(i64),
    /// List of strings (e.g., for IN operator)
    StringList(Vec<String>),
    /// No value (for IS NULL, IS NOT NULL)
    None,
}

impl FilterValue {
    /// Parse a value from a string.
    fn parse(s: &str) -> Self {
        let trimmed = s.trim();

        // Check for quoted string
        if (trimmed.starts_with('\'') && trimmed.ends_with('\''))
            || (trimmed.starts_with('"') && trimmed.ends_with('"'))
        {
            return Self::String(trimmed[1..trimmed.len() - 1].to_string());
        }

        // Check for list (for IN operator)
        if trimmed.starts_with('(') && trimmed.ends_with(')') {
            let inner = &trimmed[1..trimmed.len() - 1];
            let items: Vec<String> = inner
                .split(',')
                .map(|s| {
                    let t = s.trim();
                    if (t.starts_with('\'') && t.ends_with('\''))
                        || (t.starts_with('"') && t.ends_with('"'))
                    {
                        t[1..t.len() - 1].to_string()
                    } else {
                        t.to_string()
                    }
                })
                .collect();
            return Self::StringList(items);
        }

        // Check for boolean
        match trimmed.to_lowercase().as_str() {
            "true" => return Self::Bool(true),
            "false" => return Self::Bool(false),
            _ => {},
        }

        // Check for integer
        if let Ok(n) = trimmed.parse::<i64>() {
            return Self::Integer(n);
        }

        // Check for date (try natural date parsing)
        if let Some(result) = parse_natural_date(trimmed) {
            return Self::Date(result.date);
        }

        // Default to string
        Self::String(trimmed.to_string())
    }
}

/// Logical operators for combining conditions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogicalOp {
    /// Both conditions must be true.
    And,
    /// At least one condition must be true.
    Or,
}

/// A filter expression (condition or compound expression).
#[derive(Debug, Clone)]
pub enum FilterExpr {
    /// A single condition.
    Condition(Condition),
    /// Negation of an expression.
    Not(Box<FilterExpr>),
    /// Compound expression with logical operator.
    Compound {
        left: Box<FilterExpr>,
        op: LogicalOp,
        right: Box<FilterExpr>,
    },
}

impl FilterExpr {
    /// Evaluate this expression against a filterable item.
    pub fn matches<T: Filterable>(&self, item: &T) -> bool {
        match self {
            Self::Condition(cond) => evaluate_condition(item, cond),
            Self::Not(expr) => !expr.matches(item),
            Self::Compound { left, op, right } => match op {
                LogicalOp::And => left.matches(item) && right.matches(item),
                LogicalOp::Or => left.matches(item) || right.matches(item),
            },
        }
    }
}

/// Evaluate a single condition against an item.
fn evaluate_condition<T: Filterable>(item: &T, condition: &Condition) -> bool {
    let Some(field_value) = item.field_value(&condition.field) else {
        // Unknown field - check if it's a null check
        return matches!(condition.operator, Operator::IsNull);
    };

    match condition.operator {
        Operator::Equal => match_equal(&field_value, &condition.value),
        Operator::NotEqual => !match_equal(&field_value, &condition.value),
        Operator::LessThan => match_compare(&field_value, &condition.value, |a, b| a < b),
        Operator::LessThanOrEqual => match_compare(&field_value, &condition.value, |a, b| a <= b),
        Operator::GreaterThan => match_compare(&field_value, &condition.value, |a, b| a > b),
        Operator::GreaterThanOrEqual => {
            match_compare(&field_value, &condition.value, |a, b| a >= b)
        },
        Operator::Like => match_like(&field_value, &condition.value),
        Operator::Contains => match_contains(&field_value, &condition.value),
        Operator::IsNull => field_value.is_null(),
        Operator::IsNotNull => !field_value.is_null(),
        Operator::In => match_in(&field_value, &condition.value),
    }
}

/// Match equality.
fn match_equal(field_value: &FieldValue, filter_value: &FilterValue) -> bool {
    match (field_value, filter_value) {
        (FieldValue::String(s) | FieldValue::OptionalString(Some(s)), FilterValue::String(v)) => {
            s.eq_ignore_ascii_case(v)
        },
        (FieldValue::Date(d) | FieldValue::OptionalDate(Some(d)), FilterValue::Date(v)) => d == v,
        (FieldValue::Bool(b), FilterValue::Bool(v)) => b == v,
        (FieldValue::Integer(i), FilterValue::Integer(v)) => i == v,
        (FieldValue::StringList(list), FilterValue::String(v)) => {
            list.iter().any(|s| s.eq_ignore_ascii_case(v))
        },
        _ => false,
    }
}

/// Match with comparison function.
fn match_compare<F>(field_value: &FieldValue, filter_value: &FilterValue, cmp: F) -> bool
where
    F: Fn(&NaiveDate, &NaiveDate) -> bool,
{
    match (field_value, filter_value) {
        (FieldValue::Date(d) | FieldValue::OptionalDate(Some(d)), FilterValue::Date(v)) => {
            cmp(d, v)
        },
        _ => false,
    }
}

/// Match LIKE pattern (% as wildcard).
fn match_like(field_value: &FieldValue, filter_value: &FilterValue) -> bool {
    let FilterValue::String(pattern) = filter_value else {
        return false;
    };

    let text = match field_value {
        FieldValue::String(s) | FieldValue::OptionalString(Some(s)) => s.to_lowercase(),
        _ => return false,
    };

    let pattern_lower = pattern.to_lowercase();

    // Convert LIKE pattern to regex
    let regex_pattern = pattern_lower.replace('%', ".*").replace('_', ".");

    let full_pattern = format!("^{regex_pattern}$");

    Regex::new(&full_pattern)
        .map(|re| re.is_match(&text))
        .unwrap_or(false)
}

/// Match CONTAINS (substring).
fn match_contains(field_value: &FieldValue, filter_value: &FilterValue) -> bool {
    let FilterValue::String(needle) = filter_value else {
        return false;
    };

    field_value.contains_str(needle)
}

/// Match IN (list membership).
fn match_in(field_value: &FieldValue, filter_value: &FilterValue) -> bool {
    let FilterValue::StringList(list) = filter_value else {
        return false;
    };

    match field_value {
        FieldValue::String(s) => list.iter().any(|v| s.eq_ignore_ascii_case(v)),
        FieldValue::OptionalString(Some(s)) => list.iter().any(|v| s.eq_ignore_ascii_case(v)),
        FieldValue::StringList(items) => {
            // Check if any item is in the filter list
            items
                .iter()
                .any(|item| list.iter().any(|v| item.eq_ignore_ascii_case(v)))
        },
        _ => false,
    }
}

/// Parse a filter query string into a filter expression.
///
/// # Errors
///
/// Returns an error if the query string is invalid.
///
/// # Examples
///
/// ```
/// use clings::core::filter::parse_filter;
///
/// let expr = parse_filter("status = open").unwrap();
/// let expr = parse_filter("status = open AND due < today").unwrap();
/// ```
pub fn parse_filter(query: &str) -> Result<FilterExpr, ClingsError> {
    let query = query.trim();

    if query.is_empty() {
        return Err(ClingsError::Filter("Empty filter query".to_string()));
    }

    // Handle NOT prefix
    if query.to_uppercase().starts_with("NOT ") {
        let inner = parse_filter(&query[4..])?;
        return Ok(FilterExpr::Not(Box::new(inner)));
    }

    // Handle parentheses
    if query.starts_with('(') {
        if let Some(end_idx) = find_matching_paren(query) {
            if end_idx == query.len() - 1 {
                // Entire expression is wrapped in parens
                return parse_filter(&query[1..end_idx]);
            }
            // Expression after closing paren
            let inner = parse_filter(&query[1..end_idx])?;
            let rest = query[end_idx + 1..].trim();

            // Check if rest starts with AND or OR (case-insensitive)
            let rest_upper = rest.to_uppercase();
            if rest_upper.starts_with("AND ") {
                let right = parse_filter(rest[4..].trim())?;
                return Ok(FilterExpr::Compound {
                    left: Box::new(inner),
                    op: LogicalOp::And,
                    right: Box::new(right),
                });
            } else if rest_upper.starts_with("OR ") {
                let right = parse_filter(rest[3..].trim())?;
                return Ok(FilterExpr::Compound {
                    left: Box::new(inner),
                    op: LogicalOp::Or,
                    right: Box::new(right),
                });
            }
            return Ok(inner);
        }
        return Err(ClingsError::Filter(
            "Unmatched parenthesis in filter".to_string(),
        ));
    }

    // Find logical operators (respecting parentheses)
    if let Some((left_str, op, right_str)) = split_by_logical_op(query) {
        let left = parse_filter(left_str)?;
        let right = parse_filter(right_str)?;
        return Ok(FilterExpr::Compound {
            left: Box::new(left),
            op,
            right: Box::new(right),
        });
    }

    // Parse single condition
    parse_condition(query).map(FilterExpr::Condition)
}

/// Split a query by a logical operator (AND/OR), respecting parentheses.
fn split_by_logical_op(query: &str) -> Option<(&str, LogicalOp, &str)> {
    let query_upper = query.to_uppercase();
    let mut paren_depth = 0;

    // Try OR first (lower precedence, split first)
    for (i, c) in query.char_indices() {
        match c {
            '(' => paren_depth += 1,
            ')' => paren_depth -= 1,
            _ => {},
        }

        if paren_depth == 0 {
            // Check for OR
            if query_upper[i..].starts_with(" OR ") {
                return Some((&query[..i], LogicalOp::Or, &query[i + 4..]));
            }
        }
    }

    // Then try AND
    paren_depth = 0;
    for (i, c) in query.char_indices() {
        match c {
            '(' => paren_depth += 1,
            ')' => paren_depth -= 1,
            _ => {},
        }

        if paren_depth == 0 && query_upper[i..].starts_with(" AND ") {
            return Some((&query[..i], LogicalOp::And, &query[i + 5..]));
        }
    }

    None
}

/// Find the index of the matching closing parenthesis.
fn find_matching_paren(s: &str) -> Option<usize> {
    let mut depth = 0;
    for (i, c) in s.char_indices() {
        match c {
            '(' => depth += 1,
            ')' => {
                depth -= 1;
                if depth == 0 {
                    return Some(i);
                }
            },
            _ => {},
        }
    }
    None
}

/// Parse a single condition (field operator value).
fn parse_condition(s: &str) -> Result<Condition, ClingsError> {
    let s = s.trim();

    // Try IS NULL / IS NOT NULL first
    let s_upper = s.to_uppercase();
    if let Some(idx) = s_upper.find(" IS NOT NULL") {
        let field = s[..idx].trim().to_lowercase();
        return Ok(Condition {
            field,
            operator: Operator::IsNotNull,
            value: FilterValue::None,
        });
    }
    if let Some(idx) = s_upper.find(" IS NULL") {
        let field = s[..idx].trim().to_lowercase();
        return Ok(Condition {
            field,
            operator: Operator::IsNull,
            value: FilterValue::None,
        });
    }

    // Try other operators (order matters: longer operators first)
    let operators = [
        ("!=", Operator::NotEqual),
        ("<>", Operator::NotEqual),
        ("<=", Operator::LessThanOrEqual),
        (">=", Operator::GreaterThanOrEqual),
        ("==", Operator::Equal),
        ("<", Operator::LessThan),
        (">", Operator::GreaterThan),
        ("=", Operator::Equal),
    ];

    for (op_str, op) in operators {
        if let Some(idx) = s.find(op_str) {
            let field = s[..idx].trim().to_lowercase();
            let value_str = s[idx + op_str.len()..].trim();
            return Ok(Condition {
                field,
                operator: op,
                value: FilterValue::parse(value_str),
            });
        }
    }

    // Try keyword operators (LIKE, CONTAINS, IN)
    let keyword_ops = [
        (" LIKE ", Operator::Like),
        (" CONTAINS ", Operator::Contains),
        (" IN ", Operator::In),
        (" like ", Operator::Like),
        (" contains ", Operator::Contains),
        (" in ", Operator::In),
    ];

    for (op_str, op) in keyword_ops {
        if let Some(idx) = s.find(op_str) {
            let field = s[..idx].trim().to_lowercase();
            let value_str = s[idx + op_str.len()..].trim();
            return Ok(Condition {
                field,
                operator: op,
                value: FilterValue::parse(value_str),
            });
        }
    }

    Err(ClingsError::Filter(format!(
        "Invalid filter condition: {s}"
    )))
}

/// Apply a filter expression to a collection of items.
pub fn filter_items<'a, T: Filterable>(items: &'a [T], expr: &FilterExpr) -> Vec<&'a T> {
    items.iter().filter(|item| expr.matches(*item)).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::things::types::{Status, Todo};

    // Helper to create a test todo
    fn make_todo(name: &str, status: Status, due: Option<&str>, tags: &[&str]) -> Todo {
        Todo {
            id: format!("test-{}", name.replace(' ', "-")),
            name: name.to_string(),
            notes: String::new(),
            status,
            due_date: due.and_then(|d| NaiveDate::parse_from_str(d, "%Y-%m-%d").ok()),
            tags: tags.iter().map(|s| (*s).to_string()).collect(),
            project: None,
            area: None,
            checklist_items: vec![],
            creation_date: None,
            modification_date: None,
        }
    }

    // Note: Filterable for Todo is implemented in things/types.rs

    // Basic condition parsing tests
    #[test]
    fn test_parse_simple_equality() {
        let expr = parse_filter("status = open").unwrap();
        let todo = make_todo("Test", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    #[test]
    fn test_parse_not_equal() {
        let expr = parse_filter("status != completed").unwrap();
        let todo = make_todo("Test", Status::Open, None, &[]);
        assert!(expr.matches(&todo));

        let completed = make_todo("Done", Status::Completed, None, &[]);
        assert!(!expr.matches(&completed));
    }

    #[test]
    fn test_parse_quoted_value() {
        let expr = parse_filter("name = 'Buy Milk'").unwrap();
        let todo = make_todo("Buy Milk", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    #[test]
    fn test_parse_double_quoted_value() {
        let expr = parse_filter(r#"name = "Buy Milk""#).unwrap();
        let todo = make_todo("Buy Milk", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    // Date comparison tests
    #[test]
    fn test_date_less_than() {
        let expr = parse_filter("due < 2024-12-15").unwrap();
        let todo = make_todo("Early", Status::Open, Some("2024-12-10"), &[]);
        assert!(expr.matches(&todo));

        let late = make_todo("Late", Status::Open, Some("2024-12-20"), &[]);
        assert!(!expr.matches(&late));
    }

    #[test]
    fn test_date_greater_than_or_equal() {
        let expr = parse_filter("due >= 2024-12-15").unwrap();
        let todo = make_todo("Same", Status::Open, Some("2024-12-15"), &[]);
        assert!(expr.matches(&todo));

        let late = make_todo("Later", Status::Open, Some("2024-12-20"), &[]);
        assert!(expr.matches(&late));
    }

    // LIKE operator tests
    #[test]
    fn test_like_prefix() {
        let expr = parse_filter("name LIKE 'Buy%'").unwrap();
        let todo = make_todo("Buy Milk", Status::Open, None, &[]);
        assert!(expr.matches(&todo));

        let no_match = make_todo("Sell Milk", Status::Open, None, &[]);
        assert!(!expr.matches(&no_match));
    }

    #[test]
    fn test_like_suffix() {
        let expr = parse_filter("name LIKE '%Milk'").unwrap();
        let todo = make_todo("Buy Milk", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    #[test]
    fn test_like_contains() {
        let expr = parse_filter("name LIKE '%report%'").unwrap();
        let todo = make_todo("Write quarterly report", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    // CONTAINS operator tests
    #[test]
    fn test_contains_string() {
        let expr = parse_filter("name CONTAINS 'milk'").unwrap();
        let todo = make_todo("Buy Milk", Status::Open, None, &[]);
        assert!(expr.matches(&todo)); // Case insensitive
    }

    #[test]
    fn test_contains_in_tags() {
        let expr = parse_filter("tags CONTAINS 'work'").unwrap();
        let todo = make_todo("Task", Status::Open, None, &["work", "urgent"]);
        assert!(expr.matches(&todo));

        let no_match = make_todo("Task", Status::Open, None, &["personal"]);
        assert!(!expr.matches(&no_match));
    }

    // IS NULL / IS NOT NULL tests
    #[test]
    fn test_is_null() {
        let expr = parse_filter("due IS NULL").unwrap();
        let todo = make_todo("No due", Status::Open, None, &[]);
        assert!(expr.matches(&todo));

        let with_due = make_todo("Has due", Status::Open, Some("2024-12-15"), &[]);
        assert!(!expr.matches(&with_due));
    }

    #[test]
    fn test_is_not_null() {
        let expr = parse_filter("due IS NOT NULL").unwrap();
        let todo = make_todo("Has due", Status::Open, Some("2024-12-15"), &[]);
        assert!(expr.matches(&todo));

        let no_due = make_todo("No due", Status::Open, None, &[]);
        assert!(!expr.matches(&no_due));
    }

    #[test]
    fn test_project_is_null() {
        let expr = parse_filter("project IS NULL").unwrap();
        let todo = make_todo("No project", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    // IN operator tests
    #[test]
    fn test_in_operator() {
        let expr = parse_filter("status IN ('open', 'canceled')").unwrap();
        let open = make_todo("Open", Status::Open, None, &[]);
        let canceled = make_todo("Canceled", Status::Canceled, None, &[]);
        let completed = make_todo("Completed", Status::Completed, None, &[]);

        assert!(expr.matches(&open));
        assert!(expr.matches(&canceled));
        assert!(!expr.matches(&completed));
    }

    #[test]
    fn test_tags_in_operator() {
        let expr = parse_filter("tags IN ('work', 'urgent')").unwrap();
        let work = make_todo("Work task", Status::Open, None, &["work"]);
        let urgent = make_todo("Urgent task", Status::Open, None, &["urgent"]);
        let both = make_todo("Both", Status::Open, None, &["work", "urgent"]);
        let neither = make_todo("Neither", Status::Open, None, &["personal"]);

        assert!(expr.matches(&work));
        assert!(expr.matches(&urgent));
        assert!(expr.matches(&both));
        assert!(!expr.matches(&neither));
    }

    // Logical operator tests
    #[test]
    fn test_and_operator() {
        let expr = parse_filter("status = open AND tags CONTAINS 'work'").unwrap();
        let match_both = make_todo("Work task", Status::Open, None, &["work"]);
        let wrong_status = make_todo("Done task", Status::Completed, None, &["work"]);
        let wrong_tag = make_todo("Personal", Status::Open, None, &["personal"]);

        assert!(expr.matches(&match_both));
        assert!(!expr.matches(&wrong_status));
        assert!(!expr.matches(&wrong_tag));
    }

    #[test]
    fn test_or_operator() {
        let expr = parse_filter("status = completed OR tags CONTAINS 'done'").unwrap();
        let completed = make_todo("Done", Status::Completed, None, &[]);
        let tagged = make_todo("Tagged", Status::Open, None, &["done"]);
        let neither = make_todo("Open", Status::Open, None, &["work"]);

        assert!(expr.matches(&completed));
        assert!(expr.matches(&tagged));
        assert!(!expr.matches(&neither));
    }

    #[test]
    fn test_complex_expression() {
        let expr =
            parse_filter("status = open AND (tags CONTAINS 'work' OR tags CONTAINS 'urgent')")
                .unwrap();
        let work = make_todo("Work", Status::Open, None, &["work"]);
        let urgent = make_todo("Urgent", Status::Open, None, &["urgent"]);
        let neither = make_todo("Personal", Status::Open, None, &["personal"]);
        let completed = make_todo("Done", Status::Completed, None, &["work"]);

        assert!(expr.matches(&work));
        assert!(expr.matches(&urgent));
        assert!(!expr.matches(&neither));
        assert!(!expr.matches(&completed));
    }

    #[test]
    fn test_not_operator() {
        let expr = parse_filter("NOT status = completed").unwrap();
        let open = make_todo("Open", Status::Open, None, &[]);
        let completed = make_todo("Done", Status::Completed, None, &[]);

        assert!(expr.matches(&open));
        assert!(!expr.matches(&completed));
    }

    // Operator precedence tests
    #[test]
    fn test_and_or_precedence() {
        // OR should be evaluated first (lower precedence in splitting)
        let expr =
            parse_filter("status = open AND tags CONTAINS 'a' OR tags CONTAINS 'b'").unwrap();
        // This should be: (status = open AND tags CONTAINS 'a') OR tags CONTAINS 'b'
        let only_b = make_todo("B", Status::Completed, None, &["b"]);
        assert!(expr.matches(&only_b)); // Should match because of OR

        let open_with_a = make_todo("A", Status::Open, None, &["a"]);
        assert!(expr.matches(&open_with_a));
    }

    // Case insensitivity tests
    #[test]
    fn test_case_insensitive_field() {
        let expr = parse_filter("STATUS = open").unwrap();
        let todo = make_todo("Test", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    #[test]
    fn test_case_insensitive_value() {
        let expr = parse_filter("status = OPEN").unwrap();
        let todo = make_todo("Test", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    #[test]
    fn test_case_insensitive_like() {
        let expr = parse_filter("name like '%MILK%'").unwrap();
        let todo = make_todo("buy milk today", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    // Filter items collection test
    #[test]
    fn test_filter_items() {
        let todos = vec![
            make_todo("Task 1", Status::Open, None, &["work"]),
            make_todo("Task 2", Status::Completed, None, &["work"]),
            make_todo("Task 3", Status::Open, None, &["personal"]),
        ];

        let expr = parse_filter("status = open AND tags CONTAINS 'work'").unwrap();
        let filtered = filter_items(&todos, &expr);

        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered[0].name, "Task 1");
    }

    // Error handling tests
    #[test]
    fn test_empty_query_error() {
        assert!(parse_filter("").is_err());
        assert!(parse_filter("   ").is_err());
    }

    #[test]
    fn test_invalid_operator_error() {
        assert!(parse_filter("status ?? open").is_err());
    }

    // Edge case tests
    #[test]
    fn test_whitespace_handling() {
        let expr = parse_filter("  status   =   open  ").unwrap();
        let todo = make_todo("Test", Status::Open, None, &[]);
        assert!(expr.matches(&todo));
    }

    #[test]
    fn test_multiple_conditions() {
        let expr =
            parse_filter("status = open AND due IS NOT NULL AND tags CONTAINS 'work'").unwrap();
        let match_all = make_todo("Match", Status::Open, Some("2024-12-15"), &["work"]);
        let no_due = make_todo("No due", Status::Open, None, &["work"]);
        let no_tag = make_todo("No tag", Status::Open, Some("2024-12-15"), &["personal"]);

        assert!(expr.matches(&match_all));
        assert!(!expr.matches(&no_due));
        assert!(!expr.matches(&no_tag));
    }

    #[test]
    fn test_nested_parentheses() {
        let expr =
            parse_filter("(status = open OR status = canceled) AND tags CONTAINS 'work'").unwrap();
        let open_work = make_todo("Open", Status::Open, None, &["work"]);
        let canceled_work = make_todo("Canceled", Status::Canceled, None, &["work"]);
        let completed_work = make_todo("Completed", Status::Completed, None, &["work"]);
        let open_personal = make_todo("Personal", Status::Open, None, &["personal"]);

        assert!(expr.matches(&open_work));
        assert!(expr.matches(&canceled_work));
        assert!(!expr.matches(&completed_work));
        assert!(!expr.matches(&open_personal));
    }

    #[test]
    fn test_alternative_operators() {
        // Test <> for not equal
        let expr = parse_filter("status <> completed").unwrap();
        let open = make_todo("Open", Status::Open, None, &[]);
        assert!(expr.matches(&open));

        // Test == for equal
        let expr2 = parse_filter("status == open").unwrap();
        assert!(expr2.matches(&open));
    }
}
