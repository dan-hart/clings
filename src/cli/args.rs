use clap::{Args, Parser, Subcommand, ValueEnum};
use serde::{Deserialize, Serialize};

#[derive(Parser)]
#[command(name = "clings")]
#[command(about = "A fast, feature-rich command-line interface for Things 3 on macOS")]
#[command(long_about = "clings - A Things 3 CLI for macOS

A powerful command-line interface for managing your Things 3 tasks.
Supports list views, searching, bulk operations, and more.

QUICK START:
  clings list today         Show today's todos
  clings add \"Buy milk\"     Add a new todo
  clings search \"meeting\"   Search all todos

OUTPUT FORMATS:
  --output pretty    Human-readable colored output (default)
  --output json      Machine-readable JSON for scripting

For more information on a specific command, run:
  clings <command> --help")]
#[command(version, propagate_version = true)]
pub struct Cli {
    /// Output format for command results
    ///
    /// Use 'pretty' for human-readable colored output (default),
    /// or 'json' for machine-readable output suitable for scripting.
    #[arg(short, long, value_enum, default_value = "pretty", global = true)]
    pub output: OutputFormat,

    #[command(subcommand)]
    pub command: Commands,
}

/// Output format for command results.
#[derive(ValueEnum, Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum OutputFormat {
    /// Human-readable colored output.
    #[default]
    Pretty,
    /// Machine-readable JSON output.
    Json,
}

#[derive(Subcommand)]
pub enum Commands {
    /// List todos from a view (today, inbox, upcoming, etc.)
    ///
    /// Shows todos from the specified Things 3 view. Defaults to 'today'.
    ///
    /// # Views
    ///
    ///   today     Todos scheduled for today (default)
    ///   inbox     Unprocessed todos
    ///   upcoming  Scheduled for future dates
    ///   anytime   Available anytime
    ///   someday   Someday/maybe items
    ///   logbook   Completed todos
    ///   areas     All areas
    ///   tags      All tags
    ///   projects  All projects
    ///
    /// # Examples
    ///
    ///   clings list              Show today's todos
    ///   clings list inbox        Show inbox
    ///   clings list areas        Show all areas
    ///   clings list -o json      Output as JSON
    List {
        /// View to show (today, inbox, upcoming, anytime, someday, logbook, areas, tags, projects)
        view: Option<String>,
    },

    // Convenience aliases for common list views
    /// Show today's todos (alias for 'list today')
    #[command(alias = "t")]
    Today,

    /// Show inbox todos (alias for 'list inbox')
    #[command(alias = "i")]
    Inbox,

    /// Show upcoming todos (alias for 'list upcoming')
    #[command(alias = "u")]
    Upcoming,

    /// Show anytime todos (alias for 'list anytime')
    Anytime,

    /// Show someday todos (alias for 'list someday')
    #[command(alias = "s")]
    Someday,

    /// Show completed todos (alias for 'list logbook')
    #[command(alias = "l")]
    Logbook,

    /// Quick add a todo with natural language
    ///
    /// Parses natural language input to create todos with dates, tags,
    /// projects, and more. This is the fastest way to capture tasks.
    ///
    /// # Examples
    ///
    ///   clings add "buy milk tomorrow #errands"
    ///   clings add "call mom friday 3pm for Family !high"
    ///   clings add "finish report by dec 15 #work"
    ///   clings add "task" --tags "work,urgent" --notes "Details here"
    ///   clings add "Review PR \#267" --when today    (escaped # stays literal)
    ///
    /// # Supported Patterns
    ///
    ///   Dates:      today, tomorrow, next monday, dec 15, in 3 days
    ///   Times:      3pm, 15:00, morning, evening
    ///   Tags:       #tag1 #tag2 (or --tags "tag1,tag2")
    ///   Projects:   for `ProjectName`
    ///   Areas:      in `AreaName` (or `--area "AreaName"`)
    ///   Deadlines:  by friday
    ///   Priority:   !high, !!, !!!
    ///   Notes:      // notes at the end (or --notes "text")
    ///   Checklist:  - item1 - item2
    ///   Escape #:   \#123 keeps # literal (not parsed as tag)
    #[command(alias = "a")]
    Add(QuickAddArgs),

    /// Manage todos (show, complete, cancel, delete)
    ///
    /// Commands for working with individual todos.
    ///
    /// # Subcommands
    ///
    ///   show      Show todo details by ID
    ///   complete  Mark a todo as complete
    ///   cancel    Mark a todo as canceled
    ///   delete    Move a todo to trash
    ///
    /// # Examples
    ///
    ///   clings todo show ABC123
    ///   clings todo complete ABC123
    Todo(TodoArgs),

    /// Manage projects (list, show, add)
    ///
    /// Commands for working with Things 3 projects.
    ///
    /// # Examples
    ///
    ///   clings project list
    ///   clings project show ABC123
    ///   clings project add "Q4 Planning" --area "Work"
    Project(ProjectArgs),

    /// Search todos by text or filters
    ///
    /// Search your todos with optional filters.
    ///
    /// # Examples
    ///
    ///   clings search "meeting"              Text search
    ///   clings search --tag work             Filter by tag
    ///   clings search --project "Sprint"     Filter by project
    ///   clings search --due today            Filter by due date
    ///   clings search --filter "status = 'open' AND due < today"
    ///
    /// # Advanced Filter Syntax (--filter)
    ///
    ///   FIELDS: status, due, tags, project, area, name, notes
    ///   OPERATORS: =, !=, <, >, LIKE, CONTAINS, IS NULL
    ///   LOGIC: AND, OR, NOT
    Search(SearchArgs),

    /// Open Things 3 to a specific view or item
    ///
    /// # Examples
    ///
    ///   clings open today         Open Today view
    ///   clings open inbox         Open Inbox
    ///   clings open ABC123        Open specific item by ID
    Open {
        /// View name or item ID
        target: String,
    },

    /// Bulk operations on multiple todos
    ///
    /// Apply operations to all todos matching a filter.
    ///
    /// # Safety
    ///
    /// - Operations affecting >5 items require confirmation
    /// - Use --dry-run to preview changes
    /// - Use --yes to skip confirmation
    ///
    /// # Examples
    ///
    ///   clings bulk complete --where "tags CONTAINS 'done'"
    ///   clings bulk tag --where "project = 'Work'" urgent
    ///   clings bulk move --where "area = 'Personal'" --to "Errands"
    #[command(alias = "b")]
    Bulk(BulkArgs),

    /// View productivity statistics
    ///
    /// # Examples
    ///
    ///   clings stats              Dashboard view
    ///   clings stats --trends     Show completion trends
    ///   clings stats --heatmap    Show activity heatmap
    Stats(StatsArgs),

    /// Interactive weekly review workflow
    ///
    /// Guide yourself through a GTD-style weekly review.
    ///
    /// # Examples
    ///
    ///   clings review              Start a new review
    ///   clings review --resume     Resume paused review
    ///   clings review --status     Check progress
    #[command(alias = "r")]
    Review(ReviewArgs),

    /// Shell integration (completions)
    ///
    /// # Examples
    ///
    ///   clings shell completions bash > ~/.`bash_completion.d/clings`
    ///   clings shell completions zsh > ~/.zfunc/_clings
    Shell(ShellArgs),

    /// Launch the interactive Terminal UI
    ///
    /// # Keybindings
    ///
    ///   j/k or arrows  Navigate
    ///   c              Complete todo
    ///   x              Cancel todo
    ///   Enter          Open in Things
    ///   q/Esc          Quit
    Tui,
}

/// Arguments for quick add command with natural language parsing.
#[derive(Args)]
pub struct QuickAddArgs {
    /// The task description in natural language
    pub text: String,

    /// Only parse and show what would be created, don't actually create
    #[arg(long)]
    pub parse_only: bool,

    /// Override detected project
    #[arg(long)]
    pub project: Option<String>,

    /// Override detected area
    #[arg(long)]
    pub area: Option<String>,

    /// Override detected when date (YYYY-MM-DD or natural language)
    #[arg(long, short = 'w')]
    pub when: Option<String>,

    /// Override detected deadline (YYYY-MM-DD or natural language)
    #[arg(long, short = 'd')]
    pub deadline: Option<String>,

    /// Tags to apply (comma-separated, e.g., --tags "work,urgent")
    #[arg(long, short = 't', value_delimiter = ',')]
    pub tags: Option<Vec<String>>,

    /// Notes to attach to the todo
    #[arg(long, short = 'n')]
    pub notes: Option<String>,
}

#[derive(Args)]
pub struct TodoArgs {
    #[command(subcommand)]
    pub command: TodoCommands,
}

#[derive(Subcommand)]
pub enum TodoCommands {
    /// Show details of a specific todo
    Show {
        /// Todo ID (from Things 3, visible in JSON output)
        id: String,
    },

    /// Mark a todo as complete
    Complete {
        /// Todo ID to complete
        id: String,
    },

    /// Mark a todo as canceled
    Cancel {
        /// Todo ID to cancel
        id: String,
    },

    /// Delete a todo (cancels it; Things 3 API doesn't support true deletion)
    Delete {
        /// Todo ID to delete (will be canceled)
        id: String,
    },

    /// Update a todo's properties
    Update {
        /// Todo ID to update
        id: String,

        /// New title
        #[arg(long)]
        title: Option<String>,

        /// New notes
        #[arg(long)]
        notes: Option<String>,

        /// Schedule date (when todo appears in Today/Upcoming)
        #[arg(long, value_name = "DATE")]
        when: Option<String>,

        /// Due date / deadline
        #[arg(long, value_name = "DATE")]
        deadline: Option<String>,

        /// Tags (comma-separated, replaces existing)
        #[arg(long)]
        tags: Option<String>,

        /// Move to project
        #[arg(long)]
        project: Option<String>,

        /// Move to area
        #[arg(long)]
        area: Option<String>,
    },
}

#[derive(Args)]
pub struct ProjectArgs {
    #[command(subcommand)]
    pub command: ProjectCommands,
}

#[derive(Subcommand)]
pub enum ProjectCommands {
    /// List all projects
    List,

    /// Show project details
    Show {
        /// Project ID
        id: String,
    },

    /// Add a new project
    Add(AddProjectArgs),
}

#[derive(Args)]
pub struct AddProjectArgs {
    /// Project title
    pub title: String,

    /// Notes or description
    #[arg(short, long)]
    pub notes: Option<String>,

    /// Area to organize under
    #[arg(short, long)]
    pub area: Option<String>,

    /// Tags (comma-separated)
    #[arg(short, long, value_delimiter = ',')]
    pub tags: Option<Vec<String>>,

    /// Due date/deadline
    #[arg(short, long)]
    pub due: Option<String>,
}

/// Arguments for search command.
#[derive(Args)]
pub struct SearchArgs {
    /// Text to search for in todo titles and notes
    pub query: Option<String>,

    /// Filter by tag
    #[arg(long)]
    pub tag: Option<String>,

    /// Filter by project name
    #[arg(long)]
    pub project: Option<String>,

    /// Filter by due date
    #[arg(long)]
    pub due: Option<String>,

    /// Advanced filter expression (SQL-like syntax)
    #[arg(long, short = 'f')]
    pub filter: Option<String>,
}

/// Arguments for bulk operations.
#[derive(Args)]
pub struct BulkArgs {
    #[command(subcommand)]
    pub command: BulkCommands,
}

/// Default maximum number of items for bulk operations.
pub const DEFAULT_BULK_LIMIT: usize = 50;

/// Bulk operation subcommands.
#[derive(Subcommand)]
pub enum BulkCommands {
    /// Mark matching todos as complete
    Complete {
        /// Filter expression to select todos
        #[arg(long, short = 'w')]
        r#where: String,

        /// Preview without making changes
        #[arg(long)]
        dry_run: bool,

        /// Skip confirmation prompts
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },

    /// Mark matching todos as canceled
    Cancel {
        /// Filter expression to select todos
        #[arg(long, short = 'w')]
        r#where: String,

        /// Preview without making changes
        #[arg(long)]
        dry_run: bool,

        /// Skip confirmation prompts
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },

    /// Add tags to matching todos
    Tag {
        /// Filter expression to select todos
        #[arg(long, short = 'w')]
        r#where: String,

        /// Tags to add
        #[arg(required = true)]
        tags: Vec<String>,

        /// Preview without making changes
        #[arg(long)]
        dry_run: bool,

        /// Skip confirmation prompts
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },

    /// Move matching todos to a project
    Move {
        /// Filter expression to select todos
        #[arg(long, short = 'w')]
        r#where: String,

        /// Target project name
        #[arg(long)]
        to: String,

        /// Preview without making changes
        #[arg(long)]
        dry_run: bool,

        /// Skip confirmation prompts
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },
}

/// Arguments for statistics command.
#[derive(Args)]
pub struct StatsArgs {
    /// Show completion trends
    #[arg(long)]
    pub trends: bool,

    /// Show activity heatmap
    #[arg(long)]
    pub heatmap: bool,

    /// Number of days for trends (default: 30)
    #[arg(long, short = 'd', default_value = "30")]
    pub days: usize,

    /// Number of weeks for heatmap (default: 8)
    #[arg(long, short = 'w', default_value = "8")]
    pub weeks: usize,
}

/// Arguments for weekly review.
#[derive(Args)]
pub struct ReviewArgs {
    /// Resume a paused review session
    #[arg(long, short = 'r')]
    pub resume: bool,

    /// Show current review status
    #[arg(long, short = 's')]
    pub status: bool,

    /// Clear saved review state and start fresh
    #[arg(long)]
    pub clear: bool,

    /// Days ahead to check for deadlines (default: 7)
    #[arg(long, default_value = "7")]
    pub deadline_days: i64,
}

/// Arguments for shell integration.
#[derive(Args)]
pub struct ShellArgs {
    #[command(subcommand)]
    pub command: ShellCommands,
}

/// Shell subcommands.
#[derive(Subcommand)]
pub enum ShellCommands {
    /// Generate shell completions
    Completions {
        /// Shell type (bash, zsh, fish, powershell, elvish)
        shell: String,

        /// Show installation instructions
        #[arg(long, short = 'i')]
        install: bool,
    },
}

/// Parse relative date strings like "today", "tomorrow" to ISO format.
#[must_use]
pub fn parse_date(date_str: &str) -> String {
    let today = chrono::Local::now().date_naive();
    match date_str.to_lowercase().as_str() {
        "today" => today.format("%Y-%m-%d").to_string(),
        "tomorrow" => (today + chrono::Duration::days(1))
            .format("%Y-%m-%d")
            .to_string(),
        _ => date_str.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::Parser;

    #[test]
    fn test_parse_date_today() {
        let result = parse_date("today");
        let expected = chrono::Local::now()
            .date_naive()
            .format("%Y-%m-%d")
            .to_string();
        assert_eq!(result, expected);
    }

    #[test]
    fn test_parse_date_tomorrow() {
        let result = parse_date("tomorrow");
        let expected = (chrono::Local::now().date_naive() + chrono::Duration::days(1))
            .format("%Y-%m-%d")
            .to_string();
        assert_eq!(result, expected);
    }

    #[test]
    fn test_parse_date_passthrough() {
        assert_eq!(parse_date("2024-12-15"), "2024-12-15");
        assert_eq!(parse_date("next monday"), "next monday");
    }

    #[test]
    fn test_cli_list_default() {
        let cli = Cli::try_parse_from(["clings", "list"]).unwrap();
        if let Commands::List { view } = cli.command {
            assert!(view.is_none());
        } else {
            panic!("Expected List command");
        }
    }

    #[test]
    fn test_cli_list_with_view() {
        let cli = Cli::try_parse_from(["clings", "list", "inbox"]).unwrap();
        if let Commands::List { view } = cli.command {
            assert_eq!(view, Some("inbox".to_string()));
        } else {
            panic!("Expected List command");
        }
    }

    #[test]
    fn test_cli_today_alias() {
        let cli = Cli::try_parse_from(["clings", "today"]).unwrap();
        assert!(matches!(cli.command, Commands::Today));

        let cli = Cli::try_parse_from(["clings", "t"]).unwrap();
        assert!(matches!(cli.command, Commands::Today));
    }

    #[test]
    fn test_cli_inbox_alias() {
        let cli = Cli::try_parse_from(["clings", "inbox"]).unwrap();
        assert!(matches!(cli.command, Commands::Inbox));

        let cli = Cli::try_parse_from(["clings", "i"]).unwrap();
        assert!(matches!(cli.command, Commands::Inbox));
    }

    #[test]
    fn test_cli_add() {
        let cli = Cli::try_parse_from(["clings", "add", "buy milk"]).unwrap();
        if let Commands::Add(args) = cli.command {
            assert_eq!(args.text, "buy milk");
        } else {
            panic!("Expected Add command");
        }
    }

    #[test]
    fn test_cli_search_text() {
        let cli = Cli::try_parse_from(["clings", "search", "meeting"]).unwrap();
        if let Commands::Search(args) = cli.command {
            assert_eq!(args.query, Some("meeting".to_string()));
        } else {
            panic!("Expected Search command");
        }
    }

    #[test]
    fn test_cli_search_with_filters() {
        let cli = Cli::try_parse_from(["clings", "search", "--tag", "work", "--project", "Sprint"])
            .unwrap();
        if let Commands::Search(args) = cli.command {
            assert_eq!(args.tag, Some("work".to_string()));
            assert_eq!(args.project, Some("Sprint".to_string()));
        } else {
            panic!("Expected Search command");
        }
    }

    #[test]
    fn test_cli_search_with_advanced_filter() {
        let cli = Cli::try_parse_from(["clings", "search", "--filter", "status = 'open'"]).unwrap();
        if let Commands::Search(args) = cli.command {
            assert_eq!(args.filter, Some("status = 'open'".to_string()));
        } else {
            panic!("Expected Search command");
        }
    }

    #[test]
    fn test_cli_bulk_complete() {
        let cli = Cli::try_parse_from(["clings", "bulk", "complete", "--where", "status = open"])
            .unwrap();
        if let Commands::Bulk(args) = cli.command {
            if let BulkCommands::Complete { r#where, .. } = args.command {
                assert_eq!(r#where, "status = open");
            } else {
                panic!("Expected Complete subcommand");
            }
        } else {
            panic!("Expected Bulk command");
        }
    }

    #[test]
    fn test_cli_stats_default() {
        let cli = Cli::try_parse_from(["clings", "stats"]).unwrap();
        if let Commands::Stats(args) = cli.command {
            assert!(!args.trends);
            assert!(!args.heatmap);
        } else {
            panic!("Expected Stats command");
        }
    }

    #[test]
    fn test_cli_stats_with_flags() {
        let cli = Cli::try_parse_from(["clings", "stats", "--trends", "--days", "90"]).unwrap();
        if let Commands::Stats(args) = cli.command {
            assert!(args.trends);
            assert_eq!(args.days, 90);
        } else {
            panic!("Expected Stats command");
        }
    }

    #[test]
    fn test_cli_output_format() {
        let cli = Cli::try_parse_from(["clings", "-o", "json", "today"]).unwrap();
        assert!(matches!(cli.output, OutputFormat::Json));

        let cli = Cli::try_parse_from(["clings", "today"]).unwrap();
        assert!(matches!(cli.output, OutputFormat::Pretty));
    }
}
