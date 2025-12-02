//! Shell prompt integration.
//!
//! Provides fast, lightweight output for shell prompts showing Things 3 task counts.

use serde::{Deserialize, Serialize};

use crate::error::ClingsError;
use crate::things::{ListView, ThingsClient};

/// Format for prompt segment output.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum PromptFormat {
    /// Plain numbers only (e.g., "3 5")
    #[default]
    Plain,
    /// With emoji icons (e.g., "📥3 📅5")
    Emoji,
    /// With text labels (e.g., "inbox:3 today:5")
    Labeled,
    /// Custom format with placeholders
    Custom,
    /// JSON output
    Json,
    /// Powerline-style output
    Powerline,
}

impl PromptFormat {
    /// Parse format from string.
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "plain" => Self::Plain,
            "emoji" => Self::Emoji,
            "labeled" | "label" => Self::Labeled,
            "json" => Self::Json,
            "powerline" | "pl" => Self::Powerline,
            _ => Self::Plain,
        }
    }
}

/// What to show in the prompt segment.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PromptSegment {
    /// Inbox count
    Inbox,
    /// Today count
    Today,
    /// Upcoming count
    Upcoming,
    /// Anytime count
    Anytime,
    /// Someday count
    Someday,
    /// All segments
    All,
}

impl PromptSegment {
    /// Parse segment from string.
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "inbox" | "i" => Self::Inbox,
            "today" | "t" => Self::Today,
            "upcoming" | "u" => Self::Upcoming,
            "anytime" | "a" => Self::Anytime,
            "someday" | "s" => Self::Someday,
            "all" | "*" => Self::All,
            _ => Self::All,
        }
    }
}

/// Counts for prompt display.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptCounts {
    pub inbox: usize,
    pub today: usize,
    pub upcoming: usize,
    pub anytime: usize,
    pub someday: usize,
}

impl PromptCounts {
    /// Get counts from Things 3.
    pub fn fetch(client: &ThingsClient) -> Result<Self, ClingsError> {
        // Fetch counts for each list
        let inbox = client.get_list(ListView::Inbox).map(|t| t.len()).unwrap_or(0);
        let today = client.get_list(ListView::Today).map(|t| t.len()).unwrap_or(0);
        let upcoming = client
            .get_list(ListView::Upcoming)
            .map(|t| t.len())
            .unwrap_or(0);
        let anytime = client
            .get_list(ListView::Anytime)
            .map(|t| t.len())
            .unwrap_or(0);
        let someday = client
            .get_list(ListView::Someday)
            .map(|t| t.len())
            .unwrap_or(0);

        Ok(Self {
            inbox,
            today,
            upcoming,
            anytime,
            someday,
        })
    }

    /// Check if all counts are zero.
    pub fn is_empty(&self) -> bool {
        self.inbox == 0
            && self.today == 0
            && self.upcoming == 0
            && self.anytime == 0
            && self.someday == 0
    }
}

/// Generate prompt segment output.
///
/// # Arguments
///
/// * `client` - Things client
/// * `segment` - Which segment(s) to show
/// * `format` - Output format
/// * `custom_format` - Custom format string (for Custom format)
///
/// # Returns
///
/// Formatted string for shell prompt.
pub fn prompt_segment(
    client: &ThingsClient,
    segment: PromptSegment,
    format: PromptFormat,
    custom_format: Option<&str>,
) -> Result<String, ClingsError> {
    let counts = PromptCounts::fetch(client)?;

    match format {
        PromptFormat::Json => {
            let json = serde_json::to_string(&counts)?;
            Ok(json)
        }
        PromptFormat::Custom => {
            let template = custom_format.unwrap_or("{inbox} {today}");
            Ok(apply_custom_format(template, &counts))
        }
        _ => Ok(format_counts(&counts, segment, format)),
    }
}

fn format_counts(counts: &PromptCounts, segment: PromptSegment, format: PromptFormat) -> String {
    let mut parts = Vec::new();

    let segments: Vec<(PromptSegment, usize, &str, &str)> = vec![
        (PromptSegment::Inbox, counts.inbox, "📥", "inbox"),
        (PromptSegment::Today, counts.today, "📅", "today"),
        (PromptSegment::Upcoming, counts.upcoming, "📆", "upcoming"),
        (PromptSegment::Anytime, counts.anytime, "⏳", "anytime"),
        (PromptSegment::Someday, counts.someday, "💭", "someday"),
    ];

    for (seg, count, emoji, label) in segments {
        if segment == PromptSegment::All || segment == seg {
            if count > 0 || segment != PromptSegment::All {
                let part = match format {
                    PromptFormat::Plain => count.to_string(),
                    PromptFormat::Emoji => format!("{emoji}{count}"),
                    PromptFormat::Labeled => format!("{label}:{count}"),
                    PromptFormat::Powerline => format_powerline_segment(emoji, count),
                    _ => count.to_string(),
                };
                if count > 0 || segment != PromptSegment::All {
                    parts.push(part);
                }
            }
        }
    }

    // Filter out zero counts for "all" segment
    if segment == PromptSegment::All {
        match format {
            PromptFormat::Plain => parts
                .iter()
                .zip([counts.inbox, counts.today, counts.upcoming, counts.anytime, counts.someday])
                .filter(|(_, c)| *c > 0)
                .map(|(p, _)| p.clone())
                .collect::<Vec<_>>()
                .join(" "),
            _ => parts
                .into_iter()
                .zip([counts.inbox, counts.today, counts.upcoming, counts.anytime, counts.someday])
                .filter(|(_, c)| *c > 0)
                .map(|(p, _)| p)
                .collect::<Vec<_>>()
                .join(" "),
        }
    } else {
        parts.join(" ")
    }
}

fn format_powerline_segment(emoji: &str, count: usize) -> String {
    // Powerline style: icon count with special chars
    format!(" {emoji} {count} ")
}

fn apply_custom_format(template: &str, counts: &PromptCounts) -> String {
    template
        .replace("{inbox}", &counts.inbox.to_string())
        .replace("{today}", &counts.today.to_string())
        .replace("{upcoming}", &counts.upcoming.to_string())
        .replace("{anytime}", &counts.anytime.to_string())
        .replace("{someday}", &counts.someday.to_string())
        .replace("{total}", &(counts.inbox + counts.today).to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_prompt_format_from_str() {
        assert_eq!(PromptFormat::from_str("plain"), PromptFormat::Plain);
        assert_eq!(PromptFormat::from_str("emoji"), PromptFormat::Emoji);
        assert_eq!(PromptFormat::from_str("labeled"), PromptFormat::Labeled);
        assert_eq!(PromptFormat::from_str("json"), PromptFormat::Json);
        assert_eq!(PromptFormat::from_str("powerline"), PromptFormat::Powerline);
        assert_eq!(PromptFormat::from_str("unknown"), PromptFormat::Plain);
    }

    #[test]
    fn test_prompt_segment_from_str() {
        assert_eq!(PromptSegment::from_str("inbox"), PromptSegment::Inbox);
        assert_eq!(PromptSegment::from_str("i"), PromptSegment::Inbox);
        assert_eq!(PromptSegment::from_str("today"), PromptSegment::Today);
        assert_eq!(PromptSegment::from_str("all"), PromptSegment::All);
        assert_eq!(PromptSegment::from_str("*"), PromptSegment::All);
    }

    #[test]
    fn test_format_counts_plain() {
        let counts = PromptCounts {
            inbox: 3,
            today: 5,
            upcoming: 0,
            anytime: 2,
            someday: 0,
        };
        let result = format_counts(&counts, PromptSegment::All, PromptFormat::Plain);
        assert!(result.contains("3"));
        assert!(result.contains("5"));
    }

    #[test]
    fn test_format_counts_emoji() {
        let counts = PromptCounts {
            inbox: 3,
            today: 5,
            upcoming: 0,
            anytime: 0,
            someday: 0,
        };
        let result = format_counts(&counts, PromptSegment::All, PromptFormat::Emoji);
        assert!(result.contains("📥3"));
        assert!(result.contains("📅5"));
    }

    #[test]
    fn test_custom_format() {
        let counts = PromptCounts {
            inbox: 3,
            today: 5,
            upcoming: 10,
            anytime: 2,
            someday: 1,
        };
        let result = apply_custom_format("I:{inbox} T:{today} Total:{total}", &counts);
        assert_eq!(result, "I:3 T:5 Total:8");
    }

    #[test]
    fn test_counts_is_empty() {
        let empty = PromptCounts {
            inbox: 0,
            today: 0,
            upcoming: 0,
            anytime: 0,
            someday: 0,
        };
        assert!(empty.is_empty());

        let not_empty = PromptCounts {
            inbox: 1,
            today: 0,
            upcoming: 0,
            anytime: 0,
            someday: 0,
        };
        assert!(!not_empty.is_empty());
    }
}
