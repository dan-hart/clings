//! Date and time parsing utilities.
//!
//! This module provides enhanced date/time parsing for natural language input.
//! It extends the basic date parsing in `cli/args.rs` with more patterns.

use chrono::{Datelike, Duration, Local, NaiveDate, NaiveDateTime, NaiveTime, Weekday};

/// Result of parsing a natural language date.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DateParseResult {
    /// The parsed date.
    pub date: NaiveDate,
    /// Optional time of day.
    pub time: Option<NaiveTime>,
    /// Whether this is a deadline ("by friday") vs when ("friday").
    pub is_deadline: bool,
}

impl DateParseResult {
    /// Create a new result with just a date.
    #[must_use]
    pub const fn date_only(date: NaiveDate) -> Self {
        Self {
            date,
            time: None,
            is_deadline: false,
        }
    }

    /// Create a new result with date and time.
    #[must_use]
    pub const fn with_time(date: NaiveDate, time: NaiveTime) -> Self {
        Self {
            date,
            time: Some(time),
            is_deadline: false,
        }
    }

    /// Mark this as a deadline.
    #[must_use]
    pub const fn as_deadline(mut self) -> Self {
        self.is_deadline = true;
        self
    }

    /// Convert to ISO 8601 date string.
    #[must_use]
    pub fn to_iso_date(&self) -> String {
        self.date.format("%Y-%m-%d").to_string()
    }

    /// Convert to a datetime, using the time if available or midnight otherwise.
    #[must_use]
    pub fn to_datetime(&self) -> NaiveDateTime {
        let time = self
            .time
            .unwrap_or_else(|| NaiveTime::from_hms_opt(0, 0, 0).unwrap_or_default());
        NaiveDateTime::new(self.date, time)
    }
}

/// Parse a natural language date expression.
///
/// Supports patterns like:
/// - `today`, `tomorrow`, `yesterday`
/// - `monday`, `tuesday`, etc. (next occurrence)
/// - `next monday`, `next week`
/// - `in 3 days`, `in 2 weeks`
/// - `dec 15`, `december 15`, `12/15`
/// - `2024-12-15` (ISO format)
///
/// Returns `None` if the input cannot be parsed.
#[must_use]
pub fn parse_natural_date(input: &str) -> Option<DateParseResult> {
    let input = input.trim().to_lowercase();
    let today = Local::now().date_naive();

    // Handle "by" prefix for deadlines
    let (input, is_deadline) = input
        .strip_prefix("by ")
        .map_or_else(|| (input.clone(), false), |rest| (rest.to_string(), true));

    let result = parse_date_internal(&input, today)?;

    Some(if is_deadline {
        result.as_deadline()
    } else {
        result
    })
}

/// Parse a natural language datetime expression.
///
/// Supports date patterns plus time patterns like:
/// - `3pm`, `3:00pm`, `15:00`
/// - `morning` (9am), `evening` (6pm), `noon` (12pm)
///
/// Returns `None` if the input cannot be parsed.
#[must_use]
pub fn parse_natural_datetime(input: &str) -> Option<DateParseResult> {
    let input = input.trim().to_lowercase();
    let today = Local::now().date_naive();

    // Try to split into date and time parts
    // Common patterns: "tomorrow 3pm", "monday at 2:30pm", "in 3 days at noon"

    // Handle "by" prefix for deadlines
    let (input, is_deadline) = input
        .strip_prefix("by ")
        .map_or_else(|| (input.clone(), false), |rest| (rest.to_string(), true));

    // Try to extract time from the end
    let (date_part, time) = extract_time(&input);

    let mut result = parse_date_internal(&date_part, today)?;
    result.time = time;

    Some(if is_deadline {
        result.as_deadline()
    } else {
        result
    })
}

/// Internal date parsing logic.
fn parse_date_internal(input: &str, today: NaiveDate) -> Option<DateParseResult> {
    let input = input.trim();

    // Relative dates
    match input {
        "today" => return Some(DateParseResult::date_only(today)),
        "tomorrow" => return Some(DateParseResult::date_only(today + Duration::days(1))),
        "yesterday" => return Some(DateParseResult::date_only(today - Duration::days(1))),
        _ => {},
    }

    // "in X days/weeks/months"
    if let Some(result) = parse_relative_offset(input, today) {
        return Some(result);
    }

    // Day of week ("monday", "next tuesday")
    if let Some(result) = parse_weekday(input, today) {
        return Some(result);
    }

    // "next week" (next Monday)
    if input == "next week" {
        let days_until_monday = (i64::from(Weekday::Mon.num_days_from_sunday())
            - i64::from(today.weekday().num_days_from_sunday())
            + 7)
            % 7;
        let days = if days_until_monday == 0 {
            7
        } else {
            days_until_monday
        };
        return Some(DateParseResult::date_only(today + Duration::days(days)));
    }

    // Month and day ("dec 15", "december 15")
    if let Some(result) = parse_month_day(input, today) {
        return Some(result);
    }

    // ISO format (2024-12-15)
    if let Ok(date) = NaiveDate::parse_from_str(input, "%Y-%m-%d") {
        return Some(DateParseResult::date_only(date));
    }

    // US format (12/15/2024 or 12/15)
    if let Some(result) = parse_us_date(input, today) {
        return Some(result);
    }

    None
}

/// Parse "in X days/weeks/months" patterns.
fn parse_relative_offset(input: &str, today: NaiveDate) -> Option<DateParseResult> {
    let parts: Vec<&str> = input.split_whitespace().collect();

    if parts.len() >= 3 && parts[0] == "in" {
        let amount: i64 = parts[1].parse().ok()?;
        let unit = parts[2].trim_end_matches('s'); // Handle "days" and "day"

        let days = match unit {
            "day" => amount,
            "week" => amount * 7,
            "month" => amount * 30, // Approximate
            _ => return None,
        };

        return Some(DateParseResult::date_only(today + Duration::days(days)));
    }

    None
}

/// Parse weekday names.
fn parse_weekday(input: &str, today: NaiveDate) -> Option<DateParseResult> {
    let (is_next, day_str) = input
        .strip_prefix("next ")
        .map_or((false, input), |rest| (true, rest));

    let target_weekday = match day_str {
        "monday" | "mon" => Weekday::Mon,
        "tuesday" | "tue" | "tues" => Weekday::Tue,
        "wednesday" | "wed" => Weekday::Wed,
        "thursday" | "thu" | "thur" | "thurs" => Weekday::Thu,
        "friday" | "fri" => Weekday::Fri,
        "saturday" | "sat" => Weekday::Sat,
        "sunday" | "sun" => Weekday::Sun,
        _ => return None,
    };

    let today_weekday = today.weekday();
    let mut days_until = (i64::from(target_weekday.num_days_from_sunday())
        - i64::from(today_weekday.num_days_from_sunday())
        + 7)
        % 7;

    // If it's the same day or we specified "next", add a week
    if days_until == 0 || (is_next && days_until <= 7) {
        days_until += 7;
    }

    Some(DateParseResult::date_only(
        today + Duration::days(days_until),
    ))
}

/// Parse month and day patterns.
fn parse_month_day(input: &str, today: NaiveDate) -> Option<DateParseResult> {
    let parts: Vec<&str> = input.split_whitespace().collect();

    if parts.len() != 2 {
        return None;
    }

    let month = parse_month_name(parts[0])?;
    let day: u32 = parts[1].parse().ok()?;

    // Use current year, or next year if the date has passed
    let mut year = today.year();
    let date = NaiveDate::from_ymd_opt(year, month, day)?;

    if date < today {
        year += 1;
    }

    NaiveDate::from_ymd_opt(year, month, day).map(DateParseResult::date_only)
}

/// Parse month name to number.
fn parse_month_name(input: &str) -> Option<u32> {
    match input {
        "jan" | "january" => Some(1),
        "feb" | "february" => Some(2),
        "mar" | "march" => Some(3),
        "apr" | "april" => Some(4),
        "may" => Some(5),
        "jun" | "june" => Some(6),
        "jul" | "july" => Some(7),
        "aug" | "august" => Some(8),
        "sep" | "sept" | "september" => Some(9),
        "oct" | "october" => Some(10),
        "nov" | "november" => Some(11),
        "dec" | "december" => Some(12),
        _ => None,
    }
}

/// Parse US date format (MM/DD or MM/DD/YYYY).
fn parse_us_date(input: &str, today: NaiveDate) -> Option<DateParseResult> {
    let parts: Vec<&str> = input.split('/').collect();

    match parts.len() {
        2 => {
            let month: u32 = parts[0].parse().ok()?;
            let day: u32 = parts[1].parse().ok()?;

            let mut year = today.year();
            let date = NaiveDate::from_ymd_opt(year, month, day)?;

            if date < today {
                year += 1;
            }

            NaiveDate::from_ymd_opt(year, month, day).map(DateParseResult::date_only)
        },
        3 => {
            let month: u32 = parts[0].parse().ok()?;
            let day: u32 = parts[1].parse().ok()?;
            let year: i32 = parts[2].parse().ok()?;

            // Handle 2-digit years
            let year = if year < 100 { 2000 + year } else { year };

            NaiveDate::from_ymd_opt(year, month, day).map(DateParseResult::date_only)
        },
        _ => None,
    }
}

/// Extract time from the end of a string.
///
/// Returns the remaining string and the parsed time.
fn extract_time(input: &str) -> (String, Option<NaiveTime>) {
    // Remove "at" if present
    let input = input.replace(" at ", " ").replace(" @ ", " ");
    let parts: Vec<&str> = input.split_whitespace().collect();

    if parts.is_empty() {
        return (input, None);
    }

    // Try parsing the last part as a time
    let last = parts[parts.len() - 1];
    if let Some(time) = parse_time(last) {
        let date_part = parts[..parts.len() - 1].join(" ");
        return (date_part, Some(time));
    }

    (input, None)
}

/// Parse a time string.
fn parse_time(input: &str) -> Option<NaiveTime> {
    let input = input.to_lowercase();

    // Special times
    match input.as_str() {
        "morning" => return NaiveTime::from_hms_opt(9, 0, 0),
        "noon" | "midday" => return NaiveTime::from_hms_opt(12, 0, 0),
        "afternoon" => return NaiveTime::from_hms_opt(14, 0, 0),
        "evening" => return NaiveTime::from_hms_opt(18, 0, 0),
        "night" => return NaiveTime::from_hms_opt(21, 0, 0),
        _ => {},
    }

    // 24-hour format (15:00, 15:30)
    if let Ok(time) = NaiveTime::parse_from_str(&input, "%H:%M") {
        return Some(time);
    }

    // 12-hour format (3pm, 3:30pm)
    let (time_str, is_pm) = if input.ends_with("pm") {
        (input.trim_end_matches("pm"), true)
    } else if input.ends_with("am") {
        (input.trim_end_matches("am"), false)
    } else {
        return None;
    };

    if time_str.contains(':') {
        // 3:30pm format
        let parts: Vec<&str> = time_str.split(':').collect();
        if parts.len() != 2 {
            return None;
        }
        let mut hour: u32 = parts[0].parse().ok()?;
        let minute: u32 = parts[1].parse().ok()?;

        if is_pm && hour < 12 {
            hour += 12;
        } else if !is_pm && hour == 12 {
            hour = 0;
        }

        NaiveTime::from_hms_opt(hour, minute, 0)
    } else {
        // 3pm format
        let mut hour: u32 = time_str.parse().ok()?;

        if is_pm && hour < 12 {
            hour += 12;
        } else if !is_pm && hour == 12 {
            hour = 0;
        }

        NaiveTime::from_hms_opt(hour, 0, 0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn today() -> NaiveDate {
        Local::now().date_naive()
    }

    #[test]
    fn test_parse_today() {
        let result = parse_natural_date("today").unwrap();
        assert_eq!(result.date, today());
        assert!(!result.is_deadline);
    }

    #[test]
    fn test_parse_tomorrow() {
        let result = parse_natural_date("tomorrow").unwrap();
        assert_eq!(result.date, today() + Duration::days(1));
    }

    #[test]
    fn test_parse_yesterday() {
        let result = parse_natural_date("yesterday").unwrap();
        assert_eq!(result.date, today() - Duration::days(1));
    }

    #[test]
    fn test_parse_relative_days() {
        let result = parse_natural_date("in 3 days").unwrap();
        assert_eq!(result.date, today() + Duration::days(3));
    }

    #[test]
    fn test_parse_relative_weeks() {
        let result = parse_natural_date("in 2 weeks").unwrap();
        assert_eq!(result.date, today() + Duration::days(14));
    }

    #[test]
    fn test_parse_deadline() {
        let result = parse_natural_date("by friday").unwrap();
        assert!(result.is_deadline);
    }

    #[test]
    fn test_parse_iso_date() {
        let result = parse_natural_date("2024-12-15").unwrap();
        assert_eq!(result.date, NaiveDate::from_ymd_opt(2024, 12, 15).unwrap());
    }

    #[test]
    fn test_parse_time_12hour() {
        assert_eq!(parse_time("3pm"), NaiveTime::from_hms_opt(15, 0, 0));
        assert_eq!(parse_time("3:30pm"), NaiveTime::from_hms_opt(15, 30, 0));
        assert_eq!(parse_time("12am"), NaiveTime::from_hms_opt(0, 0, 0));
        assert_eq!(parse_time("12pm"), NaiveTime::from_hms_opt(12, 0, 0));
    }

    #[test]
    fn test_parse_time_24hour() {
        assert_eq!(parse_time("15:00"), NaiveTime::from_hms_opt(15, 0, 0));
        assert_eq!(parse_time("09:30"), NaiveTime::from_hms_opt(9, 30, 0));
    }

    #[test]
    fn test_parse_time_words() {
        assert_eq!(parse_time("morning"), NaiveTime::from_hms_opt(9, 0, 0));
        assert_eq!(parse_time("noon"), NaiveTime::from_hms_opt(12, 0, 0));
        assert_eq!(parse_time("evening"), NaiveTime::from_hms_opt(18, 0, 0));
    }

    #[test]
    fn test_parse_datetime() {
        let result = parse_natural_datetime("tomorrow 3pm").unwrap();
        assert_eq!(result.date, today() + Duration::days(1));
        assert_eq!(result.time, NaiveTime::from_hms_opt(15, 0, 0));
    }
}
