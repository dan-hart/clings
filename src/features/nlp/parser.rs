//! Natural language task parser.
//!
//! Parses strings like "buy milk tomorrow 3pm #errands for Shopping !high"
//! into structured task data.

use once_cell::sync::Lazy;
use regex::Regex;

use crate::core::{parse_natural_date, parse_natural_datetime, DateParseResult};

/// Priority levels for tasks.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Priority {
    /// No priority set.
    #[default]
    None,
    /// Low priority (!low or !)
    Low,
    /// Medium priority (!medium or !!)
    Medium,
    /// High priority (!high or !!!)
    High,
}

impl Priority {
    /// Convert to Things 3 priority value (0 = none, 1 = low, 2 = medium, 3 = high).
    #[must_use]
    pub const fn as_things_value(&self) -> Option<u8> {
        match self {
            Self::None => None,
            Self::Low => Some(1),
            Self::Medium => Some(2),
            Self::High => Some(3),
        }
    }
}

impl std::fmt::Display for Priority {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::None => "none",
            Self::Low => "low",
            Self::Medium => "medium",
            Self::High => "high",
        })
    }
}

/// Result of parsing a natural language task string.
#[derive(Debug, Clone, Default)]
pub struct ParsedTask {
    /// The task title (main text after extracting all patterns).
    pub title: String,
    /// Optional notes (text after //).
    pub notes: Option<String>,
    /// Parsed date/time for when the task should be done.
    pub when: Option<DateParseResult>,
    /// Parsed deadline date.
    pub deadline: Option<DateParseResult>,
    /// Tags extracted from #tag patterns.
    pub tags: Vec<String>,
    /// Project name (from `for ProjectName` pattern).
    pub project: Option<String>,
    /// Area name (from `in AreaName` pattern).
    pub area: Option<String>,
    /// Task priority.
    pub priority: Priority,
    /// Checklist items (from "- item" patterns).
    pub checklist: Vec<String>,
}

impl ParsedTask {
    /// Check if this task has any date/time set.
    #[must_use]
    pub const fn has_schedule(&self) -> bool {
        self.when.is_some() || self.deadline.is_some()
    }

    /// Get the when date as an ISO string.
    #[must_use]
    pub fn when_date_iso(&self) -> Option<String> {
        self.when.as_ref().map(DateParseResult::to_iso_date)
    }

    /// Get the deadline date as an ISO string.
    #[must_use]
    pub fn deadline_date_iso(&self) -> Option<String> {
        self.deadline.as_ref().map(DateParseResult::to_iso_date)
    }
}

// Compiled regex patterns
static TAG_PATTERN: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"#([\w-]+)").unwrap_or_else(|e| panic!("Invalid tag regex: {e}")));

static PROJECT_PATTERN: Lazy<Regex> = Lazy::new(|| {
    // "for ProjectName" - capture word(s) after "for"
    Regex::new(r"\bfor\s+(\w+(?:\s+\w+)*)").unwrap_or_else(|e| panic!("Invalid project regex: {e}"))
});

static AREA_PATTERN: Lazy<Regex> = Lazy::new(|| {
    // "in AreaName" - capture word(s) after "in" (but not dates like "in 3 days")
    Regex::new(r"\bin\s+([A-Z][\w]*(?:\s+\w+)*)")
        .unwrap_or_else(|e| panic!("Invalid area regex: {e}"))
});

static PRIORITY_PATTERN: Lazy<Regex> = Lazy::new(|| {
    // !!! or !! or ! or !high or !medium or !low
    Regex::new(r"!(?:high|medium|low|!!|!)?")
        .unwrap_or_else(|e| panic!("Invalid priority regex: {e}"))
});

static DEADLINE_PATTERN: Lazy<Regex> = Lazy::new(|| {
    // "by <date>" pattern - supports "by friday", "by dec 15", "by 2024-12-15"
    Regex::new(r"\bby\s+([\w-]+(?:\s+\d+)?)")
        .unwrap_or_else(|e| panic!("Invalid deadline regex: {e}"))
});

static NOTES_PATTERN: Lazy<Regex> = Lazy::new(|| {
    // "// notes" at the end
    Regex::new(r"\s*//\s*(.+)$").unwrap_or_else(|e| panic!("Invalid notes regex: {e}"))
});

// For checklist, we use a simpler pattern to detect if there are checklist items
static CHECKLIST_MARKER: Lazy<Regex> = Lazy::new(|| {
    // Check if string contains " - " which indicates checklist items
    Regex::new(r"\s+-\s+").unwrap_or_else(|e| panic!("Invalid checklist marker regex: {e}"))
});

/// Parse a natural language task string into structured data.
///
/// # Examples
///
/// ```
/// use clings::features::nlp::{parse_task, Priority};
///
/// let task = parse_task("buy milk tomorrow #errands");
/// assert_eq!(task.title, "buy milk");
/// assert_eq!(task.tags, vec!["errands"]);
/// assert!(task.when.is_some());
///
/// let task = parse_task("call mom for Family !high");
/// assert_eq!(task.title, "call mom");
/// assert_eq!(task.project, Some("Family".to_string()));
/// assert_eq!(task.priority, Priority::High);
/// ```
// Placeholder for escaped hash characters - uses null byte to avoid conflicts
const ESCAPED_HASH_PLACEHOLDER: &str = "\x00HASH\x00";

#[must_use]
pub fn parse_task(input: &str) -> ParsedTask {
    let mut task = ParsedTask::default();

    // Replace escaped hash (\#) with placeholder before parsing
    let mut remaining = input.trim().replace("\\#", ESCAPED_HASH_PLACEHOLDER);

    // Extract notes first (// at end)
    if let Some(caps) = NOTES_PATTERN.captures(&remaining) {
        if let Some(notes) = caps.get(1) {
            task.notes = Some(notes.as_str().trim().to_string());
        }
        remaining = NOTES_PATTERN.replace(&remaining, "").to_string();
    }

    // Extract checklist items (title - item1 - item2 - item3)
    if CHECKLIST_MARKER.is_match(&remaining) {
        let parts: Vec<String> = remaining.split(" - ").map(String::from).collect();
        if parts.len() > 1 {
            // First part is the title/text before checklist
            remaining.clone_from(&parts[0]);
            // Rest are checklist items
            for item in &parts[1..] {
                let trimmed = item.trim();
                if !trimmed.is_empty() {
                    task.checklist.push(trimmed.to_string());
                }
            }
        }
    }

    // Extract tags (#tag)
    for caps in TAG_PATTERN.captures_iter(&remaining.clone()) {
        if let Some(tag) = caps.get(1) {
            task.tags.push(tag.as_str().to_string());
        }
    }
    remaining = TAG_PATTERN.replace_all(&remaining, "").to_string();

    // Extract priority (!, !!, !!!, !high, !medium, !low)
    if let Some(m) = PRIORITY_PATTERN.find(&remaining) {
        task.priority = match m.as_str() {
            "!high" | "!!!" => Priority::High,
            "!medium" | "!!" => Priority::Medium,
            "!low" | "!" => Priority::Low,
            _ => Priority::None,
        };
    }
    remaining = PRIORITY_PATTERN.replace_all(&remaining, "").to_string();

    // Extract project (for ProjectName)
    if let Some(caps) = PROJECT_PATTERN.captures(&remaining) {
        if let Some(project) = caps.get(1) {
            let proj = project.as_str().trim();
            if !proj.is_empty() {
                task.project = Some(proj.to_string());
            }
        }
    }
    remaining = PROJECT_PATTERN.replace(&remaining, "").to_string();

    // Extract area (in AreaName)
    if let Some(caps) = AREA_PATTERN.captures(&remaining) {
        if let Some(area) = caps.get(1) {
            let a = area.as_str().trim();
            if !a.is_empty() {
                task.area = Some(a.to_string());
            }
        }
    }
    remaining = AREA_PATTERN.replace(&remaining, "").to_string();

    // Extract deadline (by <date>)
    if let Some(caps) = DEADLINE_PATTERN.captures(&remaining) {
        if let Some(deadline) = caps.get(1) {
            if let Some(parsed) = parse_natural_date(deadline.as_str()) {
                task.deadline = Some(parsed.as_deadline());
            }
        }
    }
    remaining = DEADLINE_PATTERN.replace(&remaining, "").to_string();

    // Try to extract date/time from what's left
    // We need to find date patterns in the remaining text
    remaining = extract_datetime(&mut task, &remaining);

    // Clean up remaining text to get the title
    // Restore escaped hash placeholders back to literal #
    task.title = clean_title(&remaining).replace(ESCAPED_HASH_PLACEHOLDER, "#");

    task
}

/// Extract datetime patterns from the text.
fn extract_datetime(task: &mut ParsedTask, text: &str) -> String {
    let words: Vec<&str> = text.split_whitespace().collect();
    let mut result_words = Vec::new();
    let mut i = 0;

    while i < words.len() {
        // Try to match datetime patterns of varying lengths
        let mut matched = false;

        // Try 3-word patterns first (e.g., "in 3 days", "next monday 3pm")
        if i + 2 < words.len() {
            let three_words = format!("{} {} {}", words[i], words[i + 1], words[i + 2]);
            if let Some(parsed) = parse_natural_datetime(&three_words) {
                task.when = Some(parsed);
                i += 3;
                matched = true;
            }
        }

        // Try 2-word patterns (e.g., "tomorrow 3pm", "next monday", "dec 15")
        if !matched && i + 1 < words.len() {
            let two_words = format!("{} {}", words[i], words[i + 1]);
            if let Some(parsed) = parse_natural_datetime(&two_words) {
                task.when = Some(parsed);
                i += 2;
                matched = true;
            }
        }

        // Try single-word patterns (e.g., "today", "tomorrow", "3pm")
        if !matched {
            if let Some(parsed) = parse_natural_datetime(words[i]) {
                task.when = Some(parsed);
                i += 1;
                matched = true;
            }
        }

        if !matched {
            result_words.push(words[i]);
            i += 1;
        }
    }

    result_words.join(" ")
}

/// Clean up the title by removing extra whitespace.
fn clean_title(text: &str) -> String {
    text.split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .trim()
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    // ===================
    // Basic Parsing Tests
    // ===================

    #[test]
    fn test_parse_simple_task() {
        let task = parse_task("buy milk");
        assert_eq!(task.title, "buy milk");
        assert!(task.tags.is_empty());
        assert!(task.when.is_none());
        assert_eq!(task.priority, Priority::None);
    }

    #[test]
    fn test_parse_empty_input() {
        let task = parse_task("");
        assert_eq!(task.title, "");
        assert!(task.tags.is_empty());
    }

    #[test]
    fn test_parse_whitespace_only() {
        let task = parse_task("   ");
        assert_eq!(task.title, "");
    }

    #[test]
    fn test_parse_preserves_case_in_title() {
        let task = parse_task("Buy MILK from Store");
        assert_eq!(task.title, "Buy MILK from Store");
    }

    // ============
    // Tag Tests
    // ============

    #[test]
    fn test_parse_task_with_tag() {
        let task = parse_task("buy milk #errands");
        assert_eq!(task.title, "buy milk");
        assert_eq!(task.tags, vec!["errands"]);
    }

    #[test]
    fn test_parse_task_with_multiple_tags() {
        let task = parse_task("finish report #work #urgent");
        assert_eq!(task.title, "finish report");
        assert_eq!(task.tags, vec!["work", "urgent"]);
    }

    #[test]
    fn test_parse_tag_at_start() {
        let task = parse_task("#work complete report");
        assert_eq!(task.title, "complete report");
        assert_eq!(task.tags, vec!["work"]);
    }

    #[test]
    fn test_parse_tag_in_middle() {
        let task = parse_task("complete #work report");
        assert_eq!(task.title, "complete report");
        assert_eq!(task.tags, vec!["work"]);
    }

    #[test]
    fn test_parse_tag_with_hyphen() {
        let task = parse_task("task #high-priority");
        assert_eq!(task.tags, vec!["high-priority"]);
    }

    #[test]
    fn test_parse_tag_with_numbers() {
        let task = parse_task("task #q4-2024");
        assert_eq!(task.tags, vec!["q4-2024"]);
    }

    #[test]
    fn test_parse_many_tags() {
        let task = parse_task("task #a #b #c #d #e");
        assert_eq!(task.tags, vec!["a", "b", "c", "d", "e"]);
    }

    // ====================
    // Escaped Hash Tests
    // ====================

    #[test]
    fn test_escaped_hash_stays_in_title() {
        let task = parse_task("Review PR \\#267");
        assert_eq!(task.title, "Review PR #267");
        assert!(task.tags.is_empty());
    }

    #[test]
    fn test_escaped_hash_with_real_tag() {
        let task = parse_task("Fix issue \\#123 #urgent");
        assert_eq!(task.title, "Fix issue #123");
        assert_eq!(task.tags, vec!["urgent"]);
    }

    #[test]
    fn test_multiple_escaped_hashes() {
        let task = parse_task("Issues \\#1, \\#2, and \\#3 need review");
        assert_eq!(task.title, "Issues #1, #2, and #3 need review");
        assert!(task.tags.is_empty());
    }

    #[test]
    fn test_escaped_hash_mixed_with_tags() {
        // Note: "for" is parsed as project indicator, so we use different text
        let task = parse_task("PR \\#42 needs review #work #code-review");
        assert_eq!(task.title, "PR #42 needs review");
        assert_eq!(task.tags, vec!["work", "code-review"]);
    }

    // ===============
    // Project Tests
    // ===============

    #[test]
    fn test_parse_task_with_project() {
        let task = parse_task("call mom for Family");
        assert_eq!(task.title, "call mom");
        assert_eq!(task.project, Some("Family".to_string()));
    }

    #[test]
    fn test_parse_task_with_multi_word_project() {
        let task = parse_task("write docs for Home Renovation");
        assert_eq!(task.title, "write docs");
        assert_eq!(task.project, Some("Home Renovation".to_string()));
    }

    #[test]
    fn test_parse_project_with_tag() {
        let task = parse_task("task for MyProject #work");
        assert_eq!(task.project, Some("MyProject".to_string()));
        assert_eq!(task.tags, vec!["work"]);
    }

    // ============
    // Area Tests
    // ============

    #[test]
    fn test_parse_task_with_area() {
        let task = parse_task("review budget in Work");
        assert_eq!(task.title, "review budget");
        assert_eq!(task.area, Some("Work".to_string()));
    }

    #[test]
    fn test_parse_area_not_date() {
        // "in 3 days" should be parsed as date, not area
        let task = parse_task("finish report in 3 days");
        assert!(task.when.is_some());
        assert!(task.area.is_none());
    }

    // ===============
    // Priority Tests
    // ===============

    #[test]
    fn test_parse_task_with_priority_exclamation() {
        let task = parse_task("urgent task !!!");
        assert_eq!(task.title, "urgent task");
        assert_eq!(task.priority, Priority::High);
    }

    #[test]
    fn test_parse_task_with_priority_word() {
        let task = parse_task("important meeting !high");
        assert_eq!(task.title, "important meeting");
        assert_eq!(task.priority, Priority::High);
    }

    #[test]
    fn test_parse_priority_medium() {
        let task = parse_task("task !medium");
        assert_eq!(task.priority, Priority::Medium);

        let task = parse_task("task !!");
        assert_eq!(task.priority, Priority::Medium);
    }

    #[test]
    fn test_parse_priority_low() {
        let task = parse_task("task !low");
        assert_eq!(task.priority, Priority::Low);

        let task = parse_task("task !");
        assert_eq!(task.priority, Priority::Low);
    }

    #[test]
    fn test_parse_priority_at_start() {
        let task = parse_task("!high urgent meeting");
        assert_eq!(task.priority, Priority::High);
    }

    // ===========
    // Date Tests
    // ===========

    #[test]
    fn test_parse_task_with_date() {
        let task = parse_task("buy milk tomorrow");
        assert_eq!(task.title, "buy milk");
        assert!(task.when.is_some());
    }

    #[test]
    fn test_parse_task_with_today() {
        let task = parse_task("call doctor today");
        assert_eq!(task.title, "call doctor");
        assert!(task.when.is_some());
    }

    #[test]
    fn test_parse_task_with_weekday() {
        let task = parse_task("meeting monday");
        assert!(task.when.is_some());
    }

    #[test]
    fn test_parse_task_with_next_weekday() {
        let task = parse_task("meeting next tuesday");
        assert!(task.when.is_some());
    }

    #[test]
    fn test_parse_task_with_relative_days() {
        let task = parse_task("follow up in 3 days");
        assert!(task.when.is_some());
    }

    #[test]
    fn test_parse_task_with_relative_weeks() {
        let task = parse_task("review in 2 weeks");
        assert!(task.when.is_some());
    }

    #[test]
    fn test_parse_task_with_iso_date() {
        let task = parse_task("event 2024-12-25");
        assert!(task.when.is_some());
        assert_eq!(task.when_date_iso(), Some("2024-12-25".to_string()));
    }

    #[test]
    fn test_parse_task_with_month_day() {
        let task = parse_task("birthday dec 15");
        assert!(task.when.is_some());
    }

    // ===========
    // Time Tests
    // ===========

    #[test]
    fn test_parse_task_with_datetime() {
        let task = parse_task("meeting tomorrow 3pm");
        assert_eq!(task.title, "meeting");
        assert!(task.when.is_some());
        if let Some(when) = &task.when {
            assert!(when.time.is_some());
        }
    }

    #[test]
    fn test_parse_task_with_24hour_time() {
        let task = parse_task("call tomorrow 15:00");
        assert!(task.when.is_some());
        if let Some(when) = &task.when {
            assert!(when.time.is_some());
        }
    }

    #[test]
    fn test_parse_task_with_morning() {
        let task = parse_task("standup tomorrow morning");
        assert!(task.when.is_some());
        if let Some(when) = &task.when {
            assert!(when.time.is_some());
        }
    }

    #[test]
    fn test_parse_task_with_evening() {
        let task = parse_task("dinner tomorrow evening");
        assert!(task.when.is_some());
        if let Some(when) = &task.when {
            assert!(when.time.is_some());
        }
    }

    // ==============
    // Deadline Tests
    // ==============

    #[test]
    fn test_parse_task_with_deadline() {
        let task = parse_task("finish report by friday");
        assert_eq!(task.title, "finish report");
        assert!(task.deadline.is_some());
        if let Some(deadline) = &task.deadline {
            assert!(deadline.is_deadline);
        }
    }

    #[test]
    fn test_parse_deadline_with_month() {
        let task = parse_task("complete project by dec 31");
        assert!(task.deadline.is_some());
    }

    #[test]
    fn test_parse_both_when_and_deadline() {
        let task = parse_task("start project tomorrow by friday");
        assert!(task.when.is_some());
        assert!(task.deadline.is_some());
    }

    // ===========
    // Notes Tests
    // ===========

    #[test]
    fn test_parse_task_with_notes() {
        let task = parse_task("call dentist // remember to ask about insurance");
        assert_eq!(task.title, "call dentist");
        assert_eq!(
            task.notes,
            Some("remember to ask about insurance".to_string())
        );
    }

    #[test]
    fn test_parse_notes_with_tags() {
        let task = parse_task("task #work // important notes here");
        assert_eq!(task.tags, vec!["work"]);
        assert_eq!(task.notes, Some("important notes here".to_string()));
    }

    #[test]
    fn test_parse_notes_preserve_content() {
        let task = parse_task("task // notes with #hashtag and !priority");
        assert_eq!(
            task.notes,
            Some("notes with #hashtag and !priority".to_string())
        );
        // The #hashtag in notes should NOT be parsed as a tag
        assert!(task.tags.is_empty());
    }

    // ================
    // Checklist Tests
    // ================

    #[test]
    fn test_parse_task_with_checklist() {
        let task = parse_task("packing list - shirt - pants - shoes");
        assert_eq!(task.title, "packing list");
        assert_eq!(task.checklist, vec!["shirt", "pants", "shoes"]);
    }

    #[test]
    fn test_parse_checklist_single_item() {
        let task = parse_task("shopping - milk");
        assert_eq!(task.title, "shopping");
        assert_eq!(task.checklist, vec!["milk"]);
    }

    #[test]
    fn test_parse_checklist_with_tag() {
        let task = parse_task("grocery list #errands - eggs - bread");
        assert_eq!(task.tags, vec!["errands"]);
        // Note: checklist is extracted before tags, so title includes the tag
    }

    // ====================
    // Complex Combination Tests
    // ====================

    #[test]
    fn test_parse_complex_task() {
        let task = parse_task(
            "write tests tomorrow 2pm #work #dev for Clings !high // don't forget edge cases",
        );
        assert_eq!(task.title, "write tests");
        assert!(task.when.is_some());
        assert_eq!(task.tags, vec!["work", "dev"]);
        assert_eq!(task.project, Some("Clings".to_string()));
        assert_eq!(task.priority, Priority::High);
        assert_eq!(task.notes, Some("don't forget edge cases".to_string()));
    }

    #[test]
    fn test_parse_all_features() {
        let task = parse_task("review code in Work for Project #urgent !high by friday tomorrow 9am // check the tests - unit tests - integration tests");
        // This tests that multiple features work together
        assert!(!task.title.is_empty());
        assert!(task.priority == Priority::High);
        assert!(task.tags.contains(&"urgent".to_string()));
    }

    #[test]
    fn test_parse_reordered_components() {
        // Components in different orders should still parse
        let task1 = parse_task("task #work !high tomorrow");
        let task2 = parse_task("task tomorrow !high #work");
        let task3 = parse_task("!high #work tomorrow task");

        assert_eq!(task1.tags, vec!["work"]);
        assert_eq!(task2.tags, vec!["work"]);
        assert_eq!(task3.tags, vec!["work"]);
    }

    // ===============
    // Utility Tests
    // ===============

    #[test]
    fn test_priority_values() {
        assert_eq!(Priority::None.as_things_value(), None);
        assert_eq!(Priority::Low.as_things_value(), Some(1));
        assert_eq!(Priority::Medium.as_things_value(), Some(2));
        assert_eq!(Priority::High.as_things_value(), Some(3));
    }

    #[test]
    fn test_priority_display() {
        assert_eq!(format!("{}", Priority::None), "none");
        assert_eq!(format!("{}", Priority::Low), "low");
        assert_eq!(format!("{}", Priority::Medium), "medium");
        assert_eq!(format!("{}", Priority::High), "high");
    }

    #[test]
    fn test_parsed_task_has_schedule() {
        let task = parse_task("buy milk");
        assert!(!task.has_schedule());

        let task = parse_task("buy milk tomorrow");
        assert!(task.has_schedule());

        let task = parse_task("buy milk by friday");
        assert!(task.has_schedule());
    }

    #[test]
    fn test_when_date_iso() {
        let task = parse_task("buy milk 2024-12-15");
        assert_eq!(task.when_date_iso(), Some("2024-12-15".to_string()));
    }

    #[test]
    fn test_deadline_date_iso() {
        let task = parse_task("buy milk by 2024-12-15");
        assert!(task.deadline_date_iso().is_some());
    }

    #[test]
    fn test_parsed_task_default() {
        let task = ParsedTask::default();
        assert!(task.title.is_empty());
        assert!(task.notes.is_none());
        assert!(task.when.is_none());
        assert!(task.deadline.is_none());
        assert!(task.tags.is_empty());
        assert!(task.project.is_none());
        assert!(task.area.is_none());
        assert_eq!(task.priority, Priority::None);
        assert!(task.checklist.is_empty());
    }

    // ====================
    // Edge Case Tests
    // ====================

    #[test]
    fn test_parse_only_tag() {
        let task = parse_task("#work");
        assert_eq!(task.title, "");
        assert_eq!(task.tags, vec!["work"]);
    }

    #[test]
    fn test_parse_only_date() {
        let task = parse_task("tomorrow");
        assert_eq!(task.title, "");
        assert!(task.when.is_some());
    }

    #[test]
    fn test_parse_only_priority() {
        let task = parse_task("!high");
        assert_eq!(task.priority, Priority::High);
    }

    #[test]
    fn test_parse_special_characters_in_title() {
        let task = parse_task("email john@example.com about project");
        assert!(task.title.contains("john@example.com"));
    }

    #[test]
    fn test_parse_unicode_in_title() {
        let task = parse_task("买牛奶 tomorrow");
        assert!(task.title.contains("买牛奶"));
        assert!(task.when.is_some());
    }

    #[test]
    fn test_parse_long_title() {
        let long_title = "a".repeat(500);
        let task = parse_task(&long_title);
        assert_eq!(task.title.len(), 500);
    }
}
