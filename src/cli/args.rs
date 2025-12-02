use clap::{Args, Parser, Subcommand, ValueEnum};
use serde::{Deserialize, Serialize};

#[derive(Parser)]
#[command(name = "clings")]
#[command(about = "A fast, feature-rich command-line interface for Things 3 on macOS")]
#[command(long_about = "clings - A Things 3 CLI for macOS

A powerful command-line interface for managing your Things 3 tasks.
Supports all standard views (inbox, today, upcoming), advanced filtering,
bulk operations, templates, focus sessions, and more.

QUICK START:
  clings today              Show today's todos
  clings add \"Buy milk\"     Add a new todo
  clings search \"meeting\"   Search all todos
  clings filter \"status = 'open' AND due < today\"   Advanced filtering

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
    ///   clings add "review PR // remember to check tests - item 1 - item 2"
    ///
    /// # Supported Patterns
    ///
    ///   Dates:      today, tomorrow, next monday, dec 15, in 3 days
    ///   Times:      3pm, 15:00, morning, evening
    ///   Tags:       #tag1 #tag2
    ///   Projects:   for ProjectName
    ///   Areas:      in AreaName
    ///   Deadlines:  by friday
    ///   Priority:   !high, !!, !!!
    ///   Notes:      // notes at the end
    ///   Checklist:  - item1 - item2
    #[command(alias = "a")]
    Add(QuickAddArgs),

    /// List inbox todos
    ///
    /// Shows all todos in your Things 3 Inbox - tasks that haven't been
    /// scheduled or assigned to a project yet. In GTD methodology, the
    /// inbox is where you capture everything before processing.
    ///
    /// Output includes: title, project (if any), due date, and tags.
    ///
    /// # Examples
    ///
    ///   clings inbox              List all inbox items
    ///   clings i                  Short alias
    ///   clings inbox -o json      Output as JSON for scripting
    ///   clings inbox | wc -l      Count inbox items
    ///
    /// # See Also
    ///
    /// Use 'clings review' to process inbox items systematically.
    #[command(alias = "i")]
    Inbox,

    /// List todos scheduled for today
    ///
    /// Shows all todos scheduled for today in Things 3, including:
    /// - Todos with today as their "when" date
    /// - Todos from the Today list
    /// - Repeating todos due today
    ///
    /// Output includes: title, project, due date, and tags.
    ///
    /// # Examples
    ///
    ///   clings today              List today's todos
    ///   clings t                  Short alias
    ///   clings today -o json      Output as JSON
    ///   clings t | grep urgent    Filter by keyword
    ///
    /// # Tip
    ///
    /// Combine with 'clings focus start' to work through today's tasks.
    #[command(alias = "t")]
    Today,

    /// List upcoming todos
    ///
    /// Shows todos scheduled for the coming days in Things 3.
    /// Displays items with a "when" date in the future, grouped by date.
    /// This helps you see what's on your horizon.
    ///
    /// # Examples
    ///
    ///   clings upcoming           List upcoming todos
    ///   clings u                  Short alias
    ///   clings upcoming -o json   Output as JSON
    ///
    /// # See Also
    ///
    /// Use 'clings filter "due > today"' for custom date filtering.
    #[command(alias = "u")]
    Upcoming,

    /// List anytime todos
    ///
    /// Shows todos marked as "Anytime" in Things 3 - tasks that can be
    /// done whenever you have time, without a specific schedule.
    /// These are active tasks you want to keep visible.
    ///
    /// # Examples
    ///
    ///   clings anytime            List anytime todos
    ///   clings anytime -o json    Output as JSON
    Anytime,

    /// List someday/maybe todos
    ///
    /// Shows todos in the "Someday" list - tasks you might want to do
    /// eventually, but aren't committed to yet. In GTD, this is your
    /// "someday/maybe" list for ideas and possibilities.
    ///
    /// # Examples
    ///
    ///   clings someday            List someday items
    ///   clings s                  Short alias
    ///   clings someday -o json    Output as JSON
    ///
    /// # Tip
    ///
    /// Review this list during 'clings review' to move items to active.
    #[command(alias = "s")]
    Someday,

    /// List completed todos from the logbook
    ///
    /// Shows recently completed todos from Things 3's Logbook.
    /// Use this to review what you've accomplished or find
    /// completed items you need to reference.
    ///
    /// # Examples
    ///
    ///   clings logbook            List completed todos
    ///   clings l                  Short alias
    ///   clings logbook -o json    Output as JSON
    ///
    /// # See Also
    ///
    /// Use 'clings stats' to see completion statistics and trends.
    #[command(alias = "l")]
    Logbook,

    /// Manage todos (list, show, add, complete, cancel, delete)
    ///
    /// Commands for working with individual todos. Use subcommands to
    /// list all todos, show details, add new todos, or change status.
    ///
    /// # Subcommands
    ///
    ///   list      List all todos
    ///   show      Show todo details by ID
    ///   add       Add a new todo
    ///   complete  Mark a todo as complete
    ///   cancel    Mark a todo as canceled
    ///   delete    Move a todo to trash
    ///
    /// # Examples
    ///
    ///   clings todo list
    ///   clings todo show ABC123
    ///   clings todo add "Review PR" --due tomorrow
    ///   clings todo complete ABC123
    Todo(TodoArgs),

    /// Manage projects (list, show, add)
    ///
    /// Commands for working with Things 3 projects. Projects are
    /// multi-step outcomes that group related todos together.
    ///
    /// # Subcommands
    ///
    ///   list   List all projects
    ///   show   Show project details by ID
    ///   add    Create a new project
    ///
    /// # Examples
    ///
    ///   clings project list
    ///   clings project show ABC123
    ///   clings project add "Q4 Planning" --area "Work"
    Project(ProjectArgs),

    /// List all areas in Things 3
    ///
    /// Areas are high-level categories that group your projects and todos
    /// (e.g., "Work", "Personal", "Health"). They help organize your life
    /// into distinct areas of responsibility.
    ///
    /// # Examples
    ///
    ///   clings areas              List all areas
    ///   clings areas -o json      Output as JSON
    Areas,

    /// List all tags in Things 3
    ///
    /// Tags are labels you can apply to todos and projects for
    /// cross-cutting organization (e.g., "urgent", "waiting", "errand").
    /// This lists all tags defined in your Things 3 database.
    ///
    /// # Examples
    ///
    ///   clings tags               List all tags
    ///   clings tags -o json       Output as JSON
    ///
    /// # See Also
    ///
    /// Use 'clings bulk tag' to add tags to multiple todos at once.
    Tags,

    /// Search todos by text query
    ///
    /// Performs a simple text search across todo titles and notes.
    /// This is a quick way to find todos containing specific words.
    /// The search is case-insensitive.
    ///
    /// For more complex queries, use 'clings filter' instead.
    ///
    /// # Examples
    ///
    ///   clings search "meeting"         Find todos with "meeting"
    ///   clings search "urgent review"   Search for multiple words
    ///   clings search "Q4" -o json      Output results as JSON
    ///
    /// # Note
    ///
    /// Searches both title and notes fields. Does not support wildcards
    /// or regex - for pattern matching, use 'clings filter' with LIKE.
    Search {
        /// Text to search for in todo titles and notes
        query: String,
    },

    /// Open Things 3 to a specific view or item
    ///
    /// Launches the Things 3 app and navigates to the specified view
    /// or item. Useful for quickly jumping from the terminal to Things.
    ///
    /// # Valid Targets
    ///
    ///   Views:  inbox, today, upcoming, anytime, someday, logbook
    ///   Items:  Any todo, project, or area ID (from JSON output)
    ///
    /// # Examples
    ///
    ///   clings open today         Open Things to Today view
    ///   clings open inbox         Open Things to Inbox
    ///   clings open ABC123        Open specific item by ID
    ///
    /// # Tip
    ///
    /// Get item IDs using '-o json' with any list command.
    Open {
        /// View name (inbox, today, upcoming, anytime, someday, logbook) or item ID
        target: String,
    },

    /// Filter todos using a powerful query expression
    ///
    /// Query your todos using SQL-like filter expressions. This is the most
    /// powerful way to find specific todos based on multiple criteria.
    ///
    /// # Filter Syntax
    ///
    /// FIELDS (what you can filter on):
    ///   status    Todo status: 'open', 'completed', 'canceled'
    ///   due       Due date: YYYY-MM-DD, or relative: today, tomorrow
    ///   tags      Tag names attached to the todo
    ///   project   Project name the todo belongs to
    ///   area      Area name the todo belongs to
    ///   name      Todo title text
    ///   notes     Todo notes/description text
    ///   created   Creation date (YYYY-MM-DD)
    ///
    /// OPERATORS (how to compare):
    ///   =           Exact match:        status = 'open'
    ///   !=          Not equal:          status != 'completed'
    ///   <, >        Less/greater than:  due < today
    ///   <=, >=      Less/greater or equal: due >= '2024-01-01'
    ///   LIKE        Pattern with % wildcard: name LIKE '%meeting%'
    ///   CONTAINS    Contains value:     tags CONTAINS 'work'
    ///   IS NULL     Field is empty:     due IS NULL
    ///   IS NOT NULL Field has value:    project IS NOT NULL
    ///   IN          Match any in list:  status IN ('open', 'completed')
    ///
    /// LOGIC (combining conditions):
    ///   AND         Both must match:    status = 'open' AND due < today
    ///   OR          Either can match:   project = 'A' OR project = 'B'
    ///   NOT         Negate condition:   NOT status = 'completed'
    ///   ()          Group conditions:   (proj = 'A' OR proj = 'B') AND status = 'open'
    ///
    /// # Examples
    ///
    ///   clings filter "status = 'open'"
    ///   clings filter "status = 'open' AND due < today"
    ///   clings filter "tags CONTAINS 'work' OR tags CONTAINS 'urgent'"
    ///   clings filter "project LIKE '%Sprint%' AND status = 'open'"
    ///   clings filter "due IS NULL AND status = 'open'"
    ///   clings filter "(tags CONTAINS 'bug' OR tags CONTAINS 'fix') AND project = 'Dev'"
    ///   clings filter "name LIKE '%review%' AND area = 'Work'"
    ///   clings filter "created > '2024-01-01' AND status = 'completed'"
    ///
    /// # Tips
    ///
    /// - Use single quotes around string values
    /// - Date comparisons: today, tomorrow, or YYYY-MM-DD format
    /// - Use LIKE with % for pattern matching, CONTAINS for tags
    /// - Combine with -o json for scripting
    #[command(alias = "f")]
    Filter {
        /// Filter expression using SQL-like syntax
        ///
        /// See 'clings filter --help' for complete syntax reference.
        query: String,
    },

    /// Bulk operations on multiple todos
    ///
    /// Apply operations to all todos matching a filter expression.
    /// Supports completing, canceling, tagging, moving, and date operations.
    ///
    /// # Safety Features
    ///
    /// Bulk operations include safety measures to prevent accidental data changes:
    /// - Operations affecting >5 items require confirmation
    /// - Default limit of 50 items (use --limit to change)
    /// - Use --dry-run to preview changes first
    /// - Use --bypass-bulk-data-check to skip all safety prompts
    ///
    /// # Filter Syntax (same as 'clings filter')
    ///
    /// FIELDS:  status, due, tags, project, area, name, notes, created
    /// OPERATORS: =, !=, <, >, <=, >=, LIKE, CONTAINS, IS NULL, IS NOT NULL, IN
    /// LOGIC: AND, OR, NOT, ()
    ///
    /// # Examples
    ///
    ///   clings bulk complete --where "tags CONTAINS 'done'"
    ///   clings bulk tag --where "project = 'Work'" urgent
    ///   clings bulk move --where "area = 'Personal'" --to "Errands"
    ///   clings bulk set-due --where "name LIKE '%review%'" --date tomorrow
    ///
    /// # Subcommands
    ///
    /// Run 'clings bulk <subcommand> --help' for detailed usage.
    #[command(alias = "b")]
    Bulk(BulkArgs),

    /// Interactive fuzzy picker for todos
    ///
    /// Launch an interactive interface to search and select todos.
    /// Features fuzzy search, preview pane, and multiple actions.
    ///
    /// # Controls
    ///
    ///   Type        Filter todos by text
    ///   Up/Down     Navigate list
    ///   Enter       Select item(s)
    ///   Tab         Toggle selection (multi-select mode)
    ///   Esc         Cancel
    ///
    /// # Examples
    ///
    ///   clings pick                    Pick from all todos
    ///   clings pick today              Pick from today's todos
    ///   clings pick --action complete  Complete selected todo
    ///   clings pick --multi            Select multiple todos
    ///   clings pick -q "meeting"       Start with search query
    ///   clings pick --preview          Show preview pane
    #[command(alias = "p")]
    Pick(PickArgs),

    /// Interactive weekly review workflow
    ///
    /// Guide yourself through a GTD-style weekly review process.
    /// The review helps you stay on top of your commitments and
    /// ensure nothing falls through the cracks.
    ///
    /// # Review Steps
    ///
    ///   1. Process inbox items - decide what to do with each
    ///   2. Review someday/maybe - activate or keep for later
    ///   3. Check active projects - ensure they're progressing
    ///   4. Review upcoming deadlines - prepare for what's coming
    ///
    /// # Examples
    ///
    ///   clings review              Start a new weekly review
    ///   clings review --resume     Resume a paused review
    ///   clings review --status     Check current review progress
    ///   clings review --clear      Clear saved state and start fresh
    #[command(alias = "r")]
    Review(ReviewArgs),

    /// Manage project templates
    ///
    /// Create reusable project structures from existing projects,
    /// or apply templates to create new projects. Great for recurring
    /// projects like sprints, monthly reviews, or trip planning.
    ///
    /// # Subcommands
    ///
    ///   create   Create template from existing project
    ///   apply    Create new project from template
    ///   list     List available templates
    ///   show     Show template contents
    ///   edit     Edit a template
    ///   delete   Remove a template
    ///
    /// # Examples
    ///
    ///   clings template create "Sprint" --from-project "Sprint 42"
    ///   clings template apply "Sprint" --name "Sprint 43" --area "Work"
    ///   clings template list
    ///   clings template show "Sprint"
    Template(TemplateArgs),

    /// Shell integration and utilities
    ///
    /// Generate shell completions, prompt segments, and editor plugins.
    /// Integrates clings into your development environment.
    ///
    /// # Subcommands
    ///
    ///   completions   Generate shell completion scripts
    ///   prompt        Generate prompt segment showing task counts
    ///   editor        Generate editor plugin (vim, emacs, vscode)
    ///
    /// # Examples
    ///
    ///   clings shell completions bash > ~/.bash_completion.d/clings
    ///   clings shell completions zsh > ~/.zfunc/_clings
    ///   clings shell prompt --format emoji
    ///   clings shell editor vim > ~/.vim/plugin/clings.vim
    Shell(ShellArgs),

    /// Pipe support for stdin/stdout workflows
    ///
    /// Read todos from stdin or output in pipe-friendly formats.
    /// Useful for scripting and automation.
    ///
    /// # Subcommands
    ///
    ///   add       Add todos from stdin (one per line)
    ///   complete  Complete todos by ID from stdin
    ///   list      Output todos as plain text for piping
    ///
    /// # Examples
    ///
    ///   echo "Buy milk" | clings pipe add
    ///   cat todos.txt | clings pipe add --project "Shopping"
    ///   clings pipe list today | wc -l
    ///   clings pipe list --with-id | grep "urgent"
    Pipe(PipeArgs),

    /// Git integration and hooks
    ///
    /// Install git hooks to automatically process TODO markers in
    /// commit messages and track tasks alongside your code.
    ///
    /// # Subcommands
    ///
    ///   install-hooks     Install clings git hooks
    ///   uninstall-hooks   Remove clings git hooks
    ///   process-message   Parse commit message for TODO markers
    ///
    /// # Examples
    ///
    ///   clings git install-hooks
    ///   clings git install-hooks --hook post-commit
    ///   clings git process-message "TODO: Write tests" --execute
    ///
    /// # Commit Message Format
    ///
    ///   TODO: Task description  -> Creates new todo
    ///   DONE: Task description  -> Completes matching todo
    Git(GitArgs),

    /// View productivity statistics and insights
    ///
    /// Analyze your task completion patterns, streaks, and productivity.
    /// Get actionable insights to improve your workflow.
    ///
    /// # Subcommands
    ///
    ///   summary    Quick overview of key metrics
    ///   dashboard  Full dashboard with charts
    ///   insights   Actionable recommendations
    ///   trends     Completion trends over time
    ///   projects   Project-level breakdown
    ///   tags       Tag-level statistics
    ///   patterns   Time pattern analysis
    ///   heatmap    Visual completion calendar
    ///
    /// # Examples
    ///
    ///   clings stats                  Show dashboard overview
    ///   clings stats summary          Quick summary
    ///   clings stats insights         Productivity recommendations
    ///   clings stats projects         Project breakdown
    ///   clings stats trends --days 90 90-day trends
    Stats(StatsArgs),

    /// Focus mode with session tracking
    ///
    /// Start timed focus sessions, track your work time, and maintain
    /// productivity streaks. Implements the Pomodoro Technique with
    /// customizable durations.
    ///
    /// # Subcommands
    ///
    ///   start    Start a new focus session
    ///   stop     End the current session
    ///   status   Check current session status
    ///   pause    Pause the current session
    ///   resume   Resume a paused session
    ///   break    Take a short or long break
    ///   history  View past sessions
    ///   report   Generate productivity report
    ///   clear    Delete session history
    ///
    /// # Examples
    ///
    ///   clings focus start               Start 25-minute Pomodoro
    ///   clings focus start --task ABC123 Focus on specific task
    ///   clings focus start -d 50m        Custom 50-minute session
    ///   clings focus status              Check current session
    ///   clings focus stop                End current session
    ///   clings focus break long          Take a 15-minute break
    ///   clings focus report --week       Weekly focus report
    Focus(FocusArgs),

    /// Sync queue for offline operations
    ///
    /// Queue operations when Things 3 is unavailable, then sync later.
    /// Useful for scripting, batch operations, and offline workflows.
    ///
    /// # Subcommands
    ///
    ///   status   Show queue status (pending/completed/failed)
    ///   run      Execute pending operations
    ///   list     Show all queued operations
    ///   add      Manually queue an operation
    ///   retry    Retry failed operations
    ///   clear    Remove completed/old operations
    ///
    /// # Examples
    ///
    ///   clings sync status              Check queue status
    ///   clings sync run                 Execute pending operations
    ///   clings sync run --dry-run       Preview what would run
    ///   clings sync list --status failed Show failed operations
    ///   clings sync clear               Remove completed operations
    Sync(SyncArgs),

    /// Automation rules engine
    ///
    /// Create and run automation rules to streamline your workflow.
    /// Rules are defined in YAML files with triggers, conditions, and actions.
    ///
    /// # Subcommands
    ///
    ///   list     List all automation rules
    ///   show     Show rule details
    ///   run      Execute matching rules
    ///   create   Create a new rule
    ///   edit     Edit a rule file
    ///   delete   Remove a rule
    ///   toggle   Enable/disable a rule
    ///   import   Import rules from YAML
    ///   export   Export rules to YAML
    ///
    /// # Examples
    ///
    ///   clings auto list              List all rules
    ///   clings auto run               Run all matching rules
    ///   clings auto run --rule "daily" Run specific rule
    ///   clings auto run --dry-run     Preview without executing
    ///   clings auto create "cleanup"  Create new rule interactively
    #[command(alias = "auto")]
    Automation(AutomationArgs),

    /// Launch the interactive Terminal User Interface (TUI)
    ///
    /// Full-screen interactive view of your Things 3 todos with
    /// vim-style keyboard navigation. Browse, complete, and manage
    /// your tasks without leaving the terminal.
    ///
    /// # Keybindings
    ///
    ///   j/k or arrows  Navigate up/down
    ///   gg/G           Jump to top/bottom
    ///   c              Complete selected todo
    ///   x              Cancel selected todo
    ///   Enter          Open in Things app
    ///   r              Refresh list
    ///   q/Esc          Quit TUI
    ///
    /// # Example
    ///
    ///   clings tui     Launch the TUI
    Tui,
}

/// Arguments for quick add command with natural language parsing.
#[derive(Args)]
pub struct QuickAddArgs {
    /// The task description in natural language
    ///
    /// Supports patterns like:
    ///   - Dates: today, tomorrow, next monday, in 3 days, dec 15
    ///   - Times: 3pm, 15:00, morning, evening
    ///   - Tags: #tag1 #tag2
    ///   - Projects: for ProjectName
    ///   - Areas: in AreaName
    ///   - Deadlines: by friday
    ///   - Priority: !high, !!, !!!
    ///   - Notes: // notes at the end
    ///   - Checklist: - item1 - item2
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
}

#[derive(Args)]
pub struct TodoArgs {
    #[command(subcommand)]
    pub command: TodoCommands,
}

#[derive(Subcommand)]
pub enum TodoCommands {
    /// List all todos from Things 3
    ///
    /// Shows all todos regardless of list. For filtered views, use the
    /// dedicated commands (inbox, today, upcoming, etc.) instead.
    ///
    /// # Examples
    ///
    ///   clings todo list            List all todos
    ///   clings todo list -o json    Output as JSON
    List,

    /// Show details of a specific todo
    ///
    /// Displays full details including notes, checklist items, dates, tags,
    /// and project assignment. Requires a todo ID.
    ///
    /// # Examples
    ///
    ///   clings todo show ABC123     Show todo details
    ///   clings todo show ABC123 -o json   Output as JSON
    ///
    /// # Tip
    ///
    /// Get todo IDs using '-o json' with any list command.
    Show {
        /// Todo ID (from Things 3, visible in JSON output)
        id: String,
    },

    /// Add a new todo with options
    ///
    /// Creates a todo with explicit fields. For natural language input,
    /// use 'clings add' instead.
    ///
    /// # Examples
    ///
    ///   clings todo add "Review PR"
    ///   clings todo add "Call client" --due tomorrow --tags work,urgent
    ///   clings todo add "Buy groceries" --list "Errands" --notes "eggs, milk"
    ///   clings todo add "Setup" --checklist "Step 1" --checklist "Step 2"
    Add(AddTodoArgs),

    /// Mark a todo as complete
    ///
    /// Completes the specified todo. The todo moves to the Logbook.
    /// For bulk completion, use 'clings bulk complete' instead.
    ///
    /// # Examples
    ///
    ///   clings todo complete ABC123
    Complete {
        /// Todo ID to complete
        id: String,
    },

    /// Mark a todo as canceled
    ///
    /// Cancels the specified todo (marks as "won't do").
    /// Use this for tasks you decided not to do.
    ///
    /// # Examples
    ///
    ///   clings todo cancel ABC123
    Cancel {
        /// Todo ID to cancel
        id: String,
    },

    /// Delete a todo (move to trash)
    ///
    /// Moves the todo to Things 3's trash. Can be recovered from
    /// the trash in the Things 3 app if needed.
    ///
    /// # Examples
    ///
    ///   clings todo delete ABC123
    Delete {
        /// Todo ID to delete
        id: String,
    },
}

#[derive(Args)]
pub struct AddTodoArgs {
    /// Todo title (required)
    ///
    /// The main title/name of the todo. Keep it concise and actionable.
    pub title: String,

    /// Notes or description for the todo
    ///
    /// Additional details, context, or links related to the task.
    #[arg(short, long)]
    pub notes: Option<String>,

    /// Due date/deadline
    ///
    /// Accepts: YYYY-MM-DD format, 'today', 'tomorrow', or natural language.
    /// Example: --due 2024-12-25, --due tomorrow
    #[arg(short, long)]
    pub due: Option<String>,

    /// Tags to apply (comma-separated)
    ///
    /// Tags must already exist in Things 3.
    /// Example: --tags work,urgent,priority
    #[arg(short, long, value_delimiter = ',')]
    pub tags: Option<Vec<String>>,

    /// Add to a specific list or project
    ///
    /// Specify a project name to add this todo to.
    /// Example: --list "Work Backlog"
    #[arg(short, long)]
    pub list: Option<String>,

    /// Checklist items (can be repeated)
    ///
    /// Add subtasks/checklist items to the todo.
    /// Example: --checklist "Step 1" --checklist "Step 2"
    #[arg(short, long)]
    pub checklist: Option<Vec<String>>,
}

#[derive(Args)]
pub struct ProjectArgs {
    #[command(subcommand)]
    pub command: ProjectCommands,
}

#[derive(Subcommand)]
pub enum ProjectCommands {
    /// List all projects in Things 3
    ///
    /// Shows all projects across all areas. Projects are multi-step
    /// outcomes that contain related todos.
    ///
    /// # Examples
    ///
    ///   clings project list            List all projects
    ///   clings project list -o json    Output as JSON
    List,

    /// Show details of a specific project
    ///
    /// Displays project details including notes, todos within the project,
    /// area assignment, and any deadlines.
    ///
    /// # Examples
    ///
    ///   clings project show ABC123     Show project details
    ///   clings project show ABC123 -o json   Output as JSON
    ///
    /// # Tip
    ///
    /// Get project IDs using 'clings project list -o json'.
    Show {
        /// Project ID (from Things 3, visible in JSON output)
        id: String,
    },

    /// Add a new project
    ///
    /// Creates a new project in Things 3. Projects are used to group
    /// related todos that work toward a specific outcome.
    ///
    /// # Examples
    ///
    ///   clings project add "Website Redesign"
    ///   clings project add "Q4 Planning" --area "Work"
    ///   clings project add "Home Renovation" --tags home,big-project
    ///   clings project add "Sprint 43" --due 2024-12-31 --notes "Focus on bugs"
    Add(AddProjectArgs),
}

#[derive(Args)]
pub struct AddProjectArgs {
    /// Project title (required)
    ///
    /// A clear name describing the project outcome.
    /// Example: "Website Redesign", "Q4 Planning"
    pub title: String,

    /// Notes or description for the project
    ///
    /// Additional context, goals, or reference material.
    #[arg(short, long)]
    pub notes: Option<String>,

    /// Area to organize the project under
    ///
    /// Areas are high-level categories like "Work", "Personal".
    /// Example: --area "Work"
    #[arg(short, long)]
    pub area: Option<String>,

    /// Tags to apply (comma-separated)
    ///
    /// Tags must already exist in Things 3.
    /// Example: --tags work,priority
    #[arg(short, long, value_delimiter = ',')]
    pub tags: Option<Vec<String>>,

    /// Due date/deadline for the project
    ///
    /// When the entire project should be completed.
    /// Example: --due 2024-12-31
    #[arg(short, long)]
    pub due: Option<String>,
}

/// Arguments for bulk operations.
#[derive(Args)]
pub struct BulkArgs {
    #[command(subcommand)]
    pub command: BulkCommands,
}

/// Default maximum number of items for bulk operations without --yes flag.
pub const DEFAULT_BULK_LIMIT: usize = 50;

/// Bulk operation subcommands.
#[derive(Subcommand)]
pub enum BulkCommands {
    /// Mark matching todos as complete
    ///
    /// Completes all todos that match the filter expression. Completed todos
    /// move to the Logbook in Things 3 and are no longer shown in active lists.
    ///
    /// # Filter Syntax
    ///
    /// Use SQL-like expressions (same as 'clings filter'):
    ///   FIELDS:    status, due, tags, project, area, name, notes, created
    ///   OPERATORS: =, !=, <, >, <=, >=, LIKE, CONTAINS, IS NULL, IS NOT NULL, IN
    ///   LOGIC:     AND, OR, NOT, ()
    ///
    /// # Examples
    ///
    ///   clings bulk complete -w "tags CONTAINS 'done'"
    ///   clings bulk complete -w "status = 'open' AND due < today"
    ///   clings bulk complete -w "project = 'Sprint 42' AND name LIKE '%reviewed%'"
    ///   clings bulk complete -w "tags CONTAINS 'done'" --dry-run
    ///
    /// # Safety
    ///
    /// - Operations affecting >5 items require typing "yes" to confirm
    /// - Default limit: 50 items (use --limit to change, --bypass-bulk-data-check to remove)
    /// - Always use --dry-run first to preview what will be affected
    Complete {
        /// Filter expression to select todos (required)
        ///
        /// Examples: "status = 'open'", "tags CONTAINS 'done'", "due < today"
        #[arg(long, short = 'w')]
        r#where: String,

        /// Preview matching todos without completing them
        ///
        /// Shows what would be completed without making changes.
        /// Always recommended before running the actual operation.
        #[arg(long)]
        dry_run: bool,

        /// DANGER: Bypass all safety checks
        ///
        /// Skips confirmation prompts and limit checks.
        /// Use with extreme caution - consider --dry-run first.
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process (default: 50)
        ///
        /// Set to 0 for unlimited (requires --bypass-bulk-data-check)
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },

    /// Mark matching todos as canceled
    ///
    /// Cancels all todos that match the filter expression. Canceled todos
    /// remain in Things 3 but are marked as "Canceled" rather than completed.
    /// Use this for tasks you decided not to do (vs. complete for finished tasks).
    ///
    /// # Filter Syntax
    ///
    /// Use SQL-like expressions (same as 'clings filter'):
    ///   FIELDS:    status, due, tags, project, area, name, notes, created
    ///   OPERATORS: =, !=, <, >, <=, >=, LIKE, CONTAINS, IS NULL, IS NOT NULL, IN
    ///   LOGIC:     AND, OR, NOT, ()
    ///
    /// # Examples
    ///
    ///   clings bulk cancel -w "project = 'Old Project'"
    ///   clings bulk cancel -w "tags CONTAINS 'obsolete'"
    ///   clings bulk cancel -w "created < '2023-01-01' AND status = 'open'"
    ///   clings bulk cancel -w "area = 'Work' AND project IS NULL" --dry-run
    ///
    /// # Safety
    ///
    /// - Operations affecting >5 items require confirmation
    /// - Use --dry-run first to preview changes
    Cancel {
        /// Filter expression to select todos (required)
        ///
        /// Examples: "project = 'Old'", "tags CONTAINS 'obsolete'"
        #[arg(long, short = 'w')]
        r#where: String,

        /// Preview changes without applying them
        #[arg(long)]
        dry_run: bool,

        /// DANGER: Bypass all safety checks (confirmation prompts and limits)
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process (default: 50)
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },

    /// Add tags to matching todos
    ///
    /// Adds one or more tags to all todos matching the filter expression.
    /// Existing tags on each todo are preserved; new tags are appended.
    /// Tags must already exist in Things 3.
    ///
    /// # Filter Syntax
    ///
    /// Use SQL-like expressions (same as 'clings filter'):
    ///   FIELDS:    status, due, tags, project, area, name, notes, created
    ///   OPERATORS: =, !=, <, >, <=, >=, LIKE, CONTAINS, IS NULL, IS NOT NULL, IN
    ///   LOGIC:     AND, OR, NOT, ()
    ///
    /// # Examples
    ///
    ///   clings bulk tag -w "project = 'Work'" urgent
    ///   clings bulk tag -w "due < today AND status = 'open'" overdue priority
    ///   clings bulk tag -w "area = 'Personal'" home errand
    ///   clings bulk tag -w "name LIKE '%review%'" needs-review --dry-run
    ///
    /// # Safety
    ///
    /// - Operations affecting >5 items require confirmation
    /// - Use --dry-run first to preview changes
    Tag {
        /// Filter expression to select todos (required)
        ///
        /// Examples: "project = 'Work'", "due < today"
        #[arg(long, short = 'w')]
        r#where: String,

        /// Tags to add (space-separated, at least one required)
        ///
        /// Multiple tags can be specified: urgent priority review
        #[arg(required = true)]
        tags: Vec<String>,

        /// Preview matching todos without adding tags
        #[arg(long)]
        dry_run: bool,

        /// DANGER: Bypass all safety checks
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process (default: 50)
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },

    /// Move matching todos to a project
    ///
    /// Moves all matching todos into the specified project. Useful for
    /// organizing scattered tasks or migrating todos between projects.
    /// The target project must already exist in Things 3.
    ///
    /// # Filter Syntax
    ///
    /// Use SQL-like expressions (same as 'clings filter'):
    ///   FIELDS:    status, due, tags, project, area, name, notes, created
    ///   OPERATORS: =, !=, <, >, <=, >=, LIKE, CONTAINS, IS NULL, IS NOT NULL, IN
    ///   LOGIC:     AND, OR, NOT, ()
    ///
    /// # Examples
    ///
    ///   clings bulk move -w "tags CONTAINS 'work'" --to "Work Backlog"
    ///   clings bulk move -w "project IS NULL AND area = 'Work'" --to "Inbox Triage"
    ///   clings bulk move -w "name LIKE '%meeting%'" --to "Meetings"
    ///   clings bulk move -w "project = 'Old Sprint'" --to "Sprint 43" --dry-run
    ///
    /// # Safety
    ///
    /// - Operations affecting >5 items require confirmation
    /// - Use --dry-run first to preview changes
    Move {
        /// Filter expression to select todos (required)
        ///
        /// Examples: "tags CONTAINS 'work'", "project IS NULL"
        #[arg(long, short = 'w')]
        r#where: String,

        /// Target project name (must already exist in Things 3)
        #[arg(long)]
        to: String,

        /// Preview matching todos without moving them
        #[arg(long)]
        dry_run: bool,

        /// DANGER: Bypass all safety checks
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process (default: 50)
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },

    /// Set due date for matching todos
    ///
    /// Sets or updates the due date (deadline) for all matching todos.
    /// Useful for batch-scheduling or rescheduling tasks.
    ///
    /// # Date Formats
    ///
    ///   Natural:  today, tomorrow, next monday, next week
    ///   Absolute: 2024-12-25, 2024-01-01
    ///
    /// # Filter Syntax
    ///
    /// Use SQL-like expressions (same as 'clings filter'):
    ///   FIELDS:    status, due, tags, project, area, name, notes, created
    ///   OPERATORS: =, !=, <, >, <=, >=, LIKE, CONTAINS, IS NULL, IS NOT NULL, IN
    ///   LOGIC:     AND, OR, NOT, ()
    ///
    /// # Examples
    ///
    ///   clings bulk set-due -w "project = 'Sprint'" --date "next friday"
    ///   clings bulk set-due -w "tags CONTAINS 'urgent'" --date tomorrow
    ///   clings bulk set-due -w "due IS NULL AND status = 'open'" --date "2024-12-31"
    ///   clings bulk set-due -w "area = 'Work'" --date "next monday" --dry-run
    ///
    /// # Safety
    ///
    /// - Operations affecting >5 items require confirmation
    /// - Use --dry-run first to preview changes
    #[command(name = "set-due")]
    SetDue {
        /// Filter expression to select todos (required)
        ///
        /// Examples: "project = 'Sprint'", "tags CONTAINS 'urgent'"
        #[arg(long, short = 'w')]
        r#where: String,

        /// Due date to set (YYYY-MM-DD or natural language)
        ///
        /// Examples: tomorrow, next friday, 2024-12-25
        #[arg(long)]
        date: String,

        /// Preview matching todos without setting due dates
        #[arg(long)]
        dry_run: bool,

        /// DANGER: Bypass all safety checks
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process (default: 50)
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },

    /// Clear due date for matching todos
    ///
    /// Removes the due date from all matching todos. After clearing,
    /// todos will no longer appear in date-based views like "Upcoming"
    /// and won't show as overdue.
    ///
    /// # Filter Syntax
    ///
    /// Use SQL-like expressions (same as 'clings filter'):
    ///   FIELDS:    status, due, tags, project, area, name, notes, created
    ///   OPERATORS: =, !=, <, >, <=, >=, LIKE, CONTAINS, IS NULL, IS NOT NULL, IN
    ///   LOGIC:     AND, OR, NOT, ()
    ///
    /// # Examples
    ///
    ///   clings bulk clear-due -w "due < today AND status = 'open'"
    ///   clings bulk clear-due -w "project = 'Someday Ideas'"
    ///   clings bulk clear-due -w "tags CONTAINS 'no-deadline'"
    ///   clings bulk clear-due -w "area = 'Personal'" --dry-run
    ///
    /// # Safety
    ///
    /// - Operations affecting >5 items require confirmation
    /// - Use --dry-run first to preview changes
    #[command(name = "clear-due")]
    ClearDue {
        /// Filter expression to select todos (required)
        ///
        /// Examples: "due < today", "project = 'Someday Ideas'"
        #[arg(long, short = 'w')]
        r#where: String,

        /// Preview matching todos without clearing due dates
        #[arg(long)]
        dry_run: bool,

        /// DANGER: Bypass all safety checks (confirmation prompts and limits)
        #[arg(long, visible_alias = "yes")]
        bypass_bulk_data_check: bool,

        /// Maximum items to process (default: 50)
        #[arg(long, default_value_t = DEFAULT_BULK_LIMIT)]
        limit: usize,
    },
}

/// Arguments for interactive picker.
#[derive(Args)]
pub struct PickArgs {
    /// List or project to pick from (inbox, today, upcoming, anytime, someday, logbook, or project name)
    pub list: Option<String>,

    /// Action to perform on selected item(s)
    #[arg(short, long, value_enum, default_value = "show")]
    pub action: PickActionArg,

    /// Allow multiple selections
    #[arg(short, long)]
    pub multi: bool,

    /// Initial search query
    #[arg(short, long)]
    pub query: Option<String>,

    /// Show preview pane
    #[arg(long)]
    pub preview: bool,
}

/// Action to perform on picked items.
#[derive(ValueEnum, Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum PickActionArg {
    /// Show item details
    #[default]
    Show,
    /// Mark as complete
    Complete,
    /// Mark as canceled
    Cancel,
    /// Open in Things app
    Open,
}

impl From<PickActionArg> for crate::features::interactive::PickAction {
    fn from(arg: PickActionArg) -> Self {
        match arg {
            PickActionArg::Show => Self::Show,
            PickActionArg::Complete => Self::Complete,
            PickActionArg::Cancel => Self::Cancel,
            PickActionArg::Open => Self::Open,
        }
    }
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

/// Arguments for project templates.
#[derive(Args)]
pub struct TemplateArgs {
    #[command(subcommand)]
    pub command: TemplateCommands,
}

/// Template subcommands.
#[derive(Subcommand)]
pub enum TemplateCommands {
    /// Create a template from an existing project
    ///
    /// Extracts the structure of a project including headings and todos
    /// to create a reusable template.
    ///
    /// Example: clings template create "Sprint" --from-project "Sprint 42"
    Create {
        /// Template name
        name: String,

        /// Source project to create template from
        #[arg(long)]
        from_project: String,

        /// Template description
        #[arg(long, short = 'd')]
        description: Option<String>,
    },

    /// Apply a template to create a new project
    ///
    /// Creates a new project based on a template, with optional
    /// variable substitutions and overrides.
    ///
    /// Example: clings template apply "Sprint" --name "Sprint 43" --area "Work"
    Apply {
        /// Template name to apply
        template: String,

        /// Name for the new project
        #[arg(long)]
        name: String,

        /// Area to add the project to (overrides template default)
        #[arg(long, short = 'a')]
        area: Option<String>,

        /// Tags to apply (overrides template defaults)
        #[arg(long, short = 't', value_delimiter = ',')]
        tags: Option<Vec<String>>,

        /// Variable substitutions (key=value format)
        #[arg(long, short = 'v', value_delimiter = ',')]
        var: Option<Vec<String>>,

        /// Preview what would be created without creating it
        #[arg(long)]
        dry_run: bool,
    },

    /// List all available templates
    List,

    /// Show template details
    Show {
        /// Template name
        name: String,
    },

    /// Delete a template
    Delete {
        /// Template name
        name: String,

        /// Skip confirmation prompt
        #[arg(long, short = 'f')]
        force: bool,
    },

    /// Edit a template (opens in editor or prints path)
    Edit {
        /// Template name
        name: String,
    },
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
    ///
    /// Outputs completion script for the specified shell.
    /// Redirect to a file or source directly.
    ///
    /// Example: clings shell completions bash > ~/.bash_completion.d/clings
    Completions {
        /// Shell to generate completions for (bash, zsh, fish, powershell, elvish)
        shell: String,

        /// Show installation instructions
        #[arg(long, short = 'i')]
        install: bool,
    },

    /// Generate prompt segment
    ///
    /// Outputs task counts for shell prompt integration.
    /// Use in PS1 or with powerline/starship.
    ///
    /// Example: PS1='$(clings shell prompt -f emoji) $ '
    Prompt {
        /// Output format (plain, emoji, labeled, json, powerline)
        #[arg(long, short = 'f', default_value = "emoji")]
        format: String,

        /// Which segment to show (inbox, today, upcoming, anytime, someday, all)
        #[arg(long, short = 's', default_value = "all")]
        segment: String,

        /// Custom format string (use {inbox}, {today}, {upcoming}, {anytime}, {someday}, {total})
        #[arg(long, short = 'c')]
        custom: Option<String>,
    },

    /// Generate editor plugin
    ///
    /// Outputs plugin code for the specified editor.
    ///
    /// Example: clings shell editor vim > ~/.vim/plugin/clings.vim
    Editor {
        /// Editor to generate plugin for (vim, emacs, vscode, sublime)
        editor: String,
    },
}

/// Arguments for pipe operations.
#[derive(Args)]
pub struct PipeArgs {
    #[command(subcommand)]
    pub command: PipeCommands,
}

/// Pipe subcommands.
#[derive(Subcommand)]
pub enum PipeCommands {
    /// Add todos from stdin
    ///
    /// Reads todo titles from stdin, one per line.
    /// Supports natural language parsing.
    ///
    /// Example: cat todos.txt | clings pipe add
    Add {
        /// Project to add todos to
        #[arg(long, short = 'p')]
        project: Option<String>,

        /// Tags to apply to all todos
        #[arg(long, short = 't', value_delimiter = ',')]
        tags: Option<Vec<String>>,

        /// Preview what would be added without creating
        #[arg(long)]
        dry_run: bool,
    },

    /// Complete todos from stdin
    ///
    /// Reads todo IDs from stdin, one per line.
    ///
    /// Example: echo "ABC123" | clings pipe complete
    Complete {
        /// Preview what would be completed without doing it
        #[arg(long)]
        dry_run: bool,
    },

    /// Output todos as plain text (one per line)
    ///
    /// Outputs todo titles for piping to other commands.
    ///
    /// Example: clings pipe list today | wc -l
    List {
        /// List to output (inbox, today, upcoming, anytime, someday)
        #[arg(default_value = "today")]
        list: String,

        /// Include todo ID as prefix
        #[arg(long, short = 'i')]
        with_id: bool,

        /// Delimiter between ID and title
        #[arg(long, short = 'd', default_value = "\t")]
        delimiter: String,
    },
}

/// Arguments for git integration.
#[derive(Args)]
pub struct GitArgs {
    #[command(subcommand)]
    pub command: GitCommands,
}

/// Git subcommands.
#[derive(Subcommand)]
pub enum GitCommands {
    /// Install git hooks
    ///
    /// Installs clings git hooks in the current repository.
    /// Hooks process commit messages for TODO markers.
    ///
    /// Example: clings git install-hooks
    #[command(name = "install-hooks")]
    InstallHooks {
        /// Specific hook to install (post-commit, pre-push, prepare-commit-msg, commit-msg)
        #[arg(long)]
        hook: Option<String>,

        /// Overwrite existing hooks
        #[arg(long, short = 'f')]
        force: bool,

        /// Path to git repository (default: current directory)
        #[arg(long)]
        repo: Option<String>,
    },

    /// Uninstall git hooks
    ///
    /// Removes clings git hooks from the current repository.
    ///
    /// Example: clings git uninstall-hooks
    #[command(name = "uninstall-hooks")]
    UninstallHooks {
        /// Specific hook to uninstall
        #[arg(long)]
        hook: Option<String>,

        /// Path to git repository (default: current directory)
        #[arg(long)]
        repo: Option<String>,
    },

    /// Process a commit message for todo markers
    ///
    /// Extracts TODO/DONE markers from a commit message.
    /// Useful for testing or manual processing.
    ///
    /// Example: clings git process-message "TODO: Write tests"
    #[command(name = "process-message")]
    ProcessMessage {
        /// Commit message to process
        message: String,

        /// Project to associate todos with
        #[arg(long, short = 'p')]
        project: Option<String>,

        /// Actually create/complete todos (default: dry run)
        #[arg(long)]
        execute: bool,
    },
}

/// Arguments for statistics.
#[derive(Args)]
pub struct StatsArgs {
    #[command(subcommand)]
    pub command: Option<StatsCommands>,
}

/// Statistics subcommands.
#[derive(Subcommand)]
pub enum StatsCommands {
    /// Show a quick summary of key metrics
    ///
    /// Displays completion stats, streak info, and current task counts.
    Summary,

    /// Show full dashboard with all metrics
    ///
    /// Comprehensive view of productivity data including charts.
    Dashboard,

    /// Show actionable insights
    ///
    /// Get recommendations based on your productivity patterns.
    Insights,

    /// Show completion trends over time
    ///
    /// Visualize your completion history with charts.
    Trends {
        /// Number of days to show (default: 30)
        #[arg(long, short = 'd', default_value = "30")]
        days: usize,
    },

    /// Show project-level statistics
    ///
    /// Breakdown of tasks by project with completion rates.
    Projects,

    /// Show tag-level statistics
    ///
    /// Breakdown of tasks by tag.
    Tags,

    /// Show time pattern analysis
    ///
    /// When you're most productive by hour and day of week.
    Patterns,

    /// Show a productivity heatmap
    ///
    /// Visual calendar of completion activity.
    Heatmap {
        /// Number of weeks to show (default: 8)
        #[arg(long, short = 'w', default_value = "8")]
        weeks: usize,
    },
}

/// Arguments for focus mode.
#[derive(Args)]
pub struct FocusArgs {
    #[command(subcommand)]
    pub command: FocusCommands,
}

/// Focus mode subcommands.
#[derive(Subcommand)]
pub enum FocusCommands {
    /// Start a new focus session
    ///
    /// Starts a timed or open-ended focus session.
    /// Default is a 25-minute Pomodoro.
    ///
    /// Examples:
    ///   clings focus start
    ///   clings focus start --task ABC123
    ///   clings focus start --duration 50m
    ///   clings focus start --type focus
    Start {
        /// Task ID to focus on (from Things 3)
        #[arg(long, short = 't')]
        task: Option<String>,

        /// Session duration (e.g., 25m, 1h, 50)
        #[arg(long, short = 'd')]
        duration: Option<String>,

        /// Session type (pomodoro, focus, open)
        #[arg(long, short = 's', default_value = "pomodoro")]
        session_type: String,

        /// Notes for this session
        #[arg(long, short = 'n')]
        notes: Option<String>,
    },

    /// Stop the current focus session
    ///
    /// Ends the active session and records completion.
    Stop {
        /// Abandon/cancel the session instead of completing
        #[arg(long, short = 'a')]
        abandon: bool,

        /// Add notes to the session
        #[arg(long, short = 'n')]
        notes: Option<String>,
    },

    /// Show current session status
    ///
    /// Displays information about the active session.
    Status {
        /// Watch mode - continuously update status
        #[arg(long, short = 'w')]
        watch: bool,
    },

    /// Pause the current session
    Pause,

    /// Resume a paused session
    Resume,

    /// Start a break
    ///
    /// Take a short (5 min) or long (15 min) break.
    Break {
        /// Break type (short, long) or duration
        #[arg(default_value = "short")]
        duration: String,
    },

    /// View session history
    ///
    /// Shows recent focus sessions.
    History {
        /// Number of sessions to show
        #[arg(long, short = 'n', default_value = "10")]
        limit: usize,

        /// Filter by task ID
        #[arg(long, short = 't')]
        task: Option<String>,
    },

    /// Generate a focus report
    ///
    /// Summary of focus time and productivity.
    Report {
        /// Time period (today, week, month, all)
        #[arg(long, short = 'p', default_value = "week")]
        period: String,
    },

    /// Clear session data
    ///
    /// Delete session history (use with caution).
    Clear {
        /// Skip confirmation
        #[arg(long, short = 'f')]
        force: bool,
    },
}

/// Arguments for sync queue.
#[derive(Args)]
pub struct SyncArgs {
    #[command(subcommand)]
    pub command: SyncCommands,
}

/// Sync queue subcommands.
#[derive(Subcommand)]
pub enum SyncCommands {
    /// Show sync queue status
    ///
    /// Displays pending, completed, and failed operations.
    Status,

    /// Run pending sync operations
    ///
    /// Executes all queued operations against Things 3.
    Run {
        /// Stop on first error
        #[arg(long)]
        stop_on_error: bool,

        /// Dry run - show what would be done
        #[arg(long)]
        dry_run: bool,

        /// Maximum operations to execute
        #[arg(long, short = 'n', default_value = "100")]
        limit: usize,
    },

    /// List queued operations
    ///
    /// Shows all operations in the sync queue.
    List {
        /// Filter by status (pending, completed, failed)
        #[arg(long, short = 's')]
        status: Option<String>,

        /// Maximum operations to show
        #[arg(long, short = 'n', default_value = "20")]
        limit: usize,
    },

    /// Add an operation to the queue
    ///
    /// Queue an operation for later execution.
    Add {
        /// Operation type (complete, cancel, add-todo, add-tags, move)
        #[arg(long, short = 't')]
        operation: String,

        /// Target todo ID
        #[arg(long, short = 'i')]
        id: Option<String>,

        /// Additional payload as JSON
        #[arg(long, short = 'p')]
        payload: Option<String>,
    },

    /// Retry failed operations
    ///
    /// Reset failed operations to pending status for retry.
    Retry {
        /// Retry all failed operations
        #[arg(long)]
        all: bool,

        /// Specific operation ID to retry
        id: Option<i64>,
    },

    /// Clear operations from queue
    ///
    /// Remove completed or all operations.
    Clear {
        /// Clear all operations (not just completed)
        #[arg(long)]
        all: bool,

        /// Maximum age in hours for cleanup
        #[arg(long, default_value = "24")]
        older_than: i64,

        /// Skip confirmation
        #[arg(long, short = 'f')]
        force: bool,
    },
}

/// Arguments for automation.
#[derive(Args)]
pub struct AutomationArgs {
    #[command(subcommand)]
    pub command: AutomationCommands,
}

/// Automation subcommands.
#[derive(Subcommand)]
pub enum AutomationCommands {
    /// List all automation rules
    ///
    /// Shows all defined rules with their status.
    List,

    /// Show a specific rule
    ///
    /// Display rule details including triggers, conditions, and actions.
    Show {
        /// Rule name
        name: String,
    },

    /// Run automation rules
    ///
    /// Execute matching rules based on current context.
    Run {
        /// Run a specific rule by name
        #[arg(long, short = 'r')]
        rule: Option<String>,

        /// Trigger an event
        #[arg(long, short = 'e')]
        event: Option<String>,

        /// Dry run - show what would be done
        #[arg(long)]
        dry_run: bool,
    },

    /// Create a new rule
    ///
    /// Create a rule from a template or interactively.
    Create {
        /// Rule name
        name: String,

        /// Rule description
        #[arg(long, short = 'd')]
        description: Option<String>,

        /// Trigger type (manual, scheduled, event)
        #[arg(long, short = 't', default_value = "manual")]
        trigger: String,
    },

    /// Edit a rule
    ///
    /// Open the rule file in your editor.
    Edit {
        /// Rule name
        name: String,
    },

    /// Delete a rule
    ///
    /// Remove a rule permanently.
    Delete {
        /// Rule name
        name: String,

        /// Skip confirmation
        #[arg(long, short = 'f')]
        force: bool,
    },

    /// Enable or disable a rule
    ///
    /// Toggle a rule's enabled state.
    Toggle {
        /// Rule name
        name: String,

        /// Explicitly enable
        #[arg(long)]
        enable: bool,

        /// Explicitly disable
        #[arg(long)]
        disable: bool,
    },

    /// Import rules from a file
    ///
    /// Load rules from a YAML file.
    Import {
        /// Path to YAML file
        path: String,

        /// Overwrite existing rules
        #[arg(long)]
        overwrite: bool,
    },

    /// Export rules to a file
    ///
    /// Save rules to a YAML file.
    Export {
        /// Path to output file
        path: String,

        /// Rule names to export (all if not specified)
        #[arg(long, short = 'r')]
        rules: Option<Vec<String>>,
    },
}

/// Parse relative date strings like "today", "tomorrow" to ISO format
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

    // ==================== parse_date Tests ====================

    #[test]
    fn test_parse_date_today() {
        let result = parse_date("today");
        let expected = chrono::Local::now().date_naive().format("%Y-%m-%d").to_string();
        assert_eq!(result, expected);
    }

    #[test]
    fn test_parse_date_today_uppercase() {
        let result = parse_date("TODAY");
        let expected = chrono::Local::now().date_naive().format("%Y-%m-%d").to_string();
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
    fn test_parse_date_iso_passthrough() {
        let result = parse_date("2024-12-15");
        assert_eq!(result, "2024-12-15");
    }

    #[test]
    fn test_parse_date_unknown_passthrough() {
        let result = parse_date("next monday");
        assert_eq!(result, "next monday");
    }

    // ==================== CLI Parsing Tests ====================

    #[test]
    fn test_cli_today_command() {
        let cli = Cli::try_parse_from(["clings", "today"]).unwrap();
        assert!(matches!(cli.command, Commands::Today));
    }

    #[test]
    fn test_cli_inbox_command() {
        let cli = Cli::try_parse_from(["clings", "inbox"]).unwrap();
        assert!(matches!(cli.command, Commands::Inbox));
    }

    #[test]
    fn test_cli_inbox_alias() {
        let cli = Cli::try_parse_from(["clings", "i"]).unwrap();
        assert!(matches!(cli.command, Commands::Inbox));
    }

    #[test]
    fn test_cli_today_alias() {
        let cli = Cli::try_parse_from(["clings", "t"]).unwrap();
        assert!(matches!(cli.command, Commands::Today));
    }

    #[test]
    fn test_cli_upcoming_alias() {
        let cli = Cli::try_parse_from(["clings", "u"]).unwrap();
        assert!(matches!(cli.command, Commands::Upcoming));
    }

    #[test]
    fn test_cli_someday_alias() {
        let cli = Cli::try_parse_from(["clings", "s"]).unwrap();
        assert!(matches!(cli.command, Commands::Someday));
    }

    #[test]
    fn test_cli_logbook_alias() {
        let cli = Cli::try_parse_from(["clings", "l"]).unwrap();
        assert!(matches!(cli.command, Commands::Logbook));
    }

    #[test]
    fn test_cli_output_format_default() {
        let cli = Cli::try_parse_from(["clings", "today"]).unwrap();
        assert!(matches!(cli.output, OutputFormat::Pretty));
    }

    #[test]
    fn test_cli_output_format_json() {
        let cli = Cli::try_parse_from(["clings", "--output", "json", "today"]).unwrap();
        assert!(matches!(cli.output, OutputFormat::Json));
    }

    #[test]
    fn test_cli_output_format_short() {
        let cli = Cli::try_parse_from(["clings", "-o", "json", "today"]).unwrap();
        assert!(matches!(cli.output, OutputFormat::Json));
    }

    #[test]
    fn test_cli_add_command() {
        let cli = Cli::try_parse_from(["clings", "add", "buy milk tomorrow"]).unwrap();
        if let Commands::Add(args) = cli.command {
            assert_eq!(args.text, "buy milk tomorrow");
        } else {
            panic!("Expected Add command");
        }
    }

    #[test]
    fn test_cli_add_with_parse_only() {
        let cli = Cli::try_parse_from(["clings", "add", "task", "--parse-only"]).unwrap();
        if let Commands::Add(args) = cli.command {
            assert!(args.parse_only);
        } else {
            panic!("Expected Add command");
        }
    }

    #[test]
    fn test_cli_search_command() {
        let cli = Cli::try_parse_from(["clings", "search", "meeting"]).unwrap();
        if let Commands::Search { query } = cli.command {
            assert_eq!(query, "meeting");
        } else {
            panic!("Expected Search command");
        }
    }

    #[test]
    fn test_cli_open_command() {
        let cli = Cli::try_parse_from(["clings", "open", "today"]).unwrap();
        if let Commands::Open { target } = cli.command {
            assert_eq!(target, "today");
        } else {
            panic!("Expected Open command");
        }
    }

    #[test]
    fn test_cli_filter_command() {
        let cli = Cli::try_parse_from(["clings", "filter", "status = open"]).unwrap();
        if let Commands::Filter { query } = cli.command {
            assert_eq!(query, "status = open");
        } else {
            panic!("Expected Filter command");
        }
    }

    #[test]
    fn test_cli_tui_command() {
        let cli = Cli::try_parse_from(["clings", "tui"]).unwrap();
        assert!(matches!(cli.command, Commands::Tui));
    }

    #[test]
    fn test_cli_areas_command() {
        let cli = Cli::try_parse_from(["clings", "areas"]).unwrap();
        assert!(matches!(cli.command, Commands::Areas));
    }

    #[test]
    fn test_cli_tags_command() {
        let cli = Cli::try_parse_from(["clings", "tags"]).unwrap();
        assert!(matches!(cli.command, Commands::Tags));
    }

    // ==================== Bulk Command Tests ====================

    #[test]
    fn test_cli_bulk_complete() {
        let cli = Cli::try_parse_from(["clings", "bulk", "complete", "--where", "status = open"]).unwrap();
        if let Commands::Bulk(args) = cli.command {
            if let BulkCommands::Complete { r#where, dry_run, bypass_bulk_data_check, limit } = args.command {
                assert_eq!(r#where, "status = open");
                assert!(!dry_run);
                assert!(!bypass_bulk_data_check);
                assert_eq!(limit, DEFAULT_BULK_LIMIT);
            } else {
                panic!("Expected Complete subcommand");
            }
        } else {
            panic!("Expected Bulk command");
        }
    }

    #[test]
    fn test_cli_bulk_complete_dry_run() {
        let cli = Cli::try_parse_from(["clings", "bulk", "complete", "--where", "x", "--dry-run"]).unwrap();
        if let Commands::Bulk(args) = cli.command {
            if let BulkCommands::Complete { dry_run, .. } = args.command {
                assert!(dry_run);
            } else {
                panic!("Expected Complete subcommand");
            }
        } else {
            panic!("Expected Bulk command");
        }
    }

    #[test]
    fn test_cli_bulk_tag() {
        let cli = Cli::try_parse_from(["clings", "bulk", "tag", "--where", "x", "urgent", "work"]).unwrap();
        if let Commands::Bulk(args) = cli.command {
            if let BulkCommands::Tag { tags, .. } = args.command {
                assert_eq!(tags, vec!["urgent", "work"]);
            } else {
                panic!("Expected Tag subcommand");
            }
        } else {
            panic!("Expected Bulk command");
        }
    }

    #[test]
    fn test_cli_bulk_move() {
        let cli = Cli::try_parse_from(["clings", "bulk", "move", "--where", "x", "--to", "Project"]).unwrap();
        if let Commands::Bulk(args) = cli.command {
            if let BulkCommands::Move { to, .. } = args.command {
                assert_eq!(to, "Project");
            } else {
                panic!("Expected Move subcommand");
            }
        } else {
            panic!("Expected Bulk command");
        }
    }

    // ==================== Pick Command Tests ====================

    #[test]
    fn test_cli_pick_default() {
        let cli = Cli::try_parse_from(["clings", "pick"]).unwrap();
        if let Commands::Pick(args) = cli.command {
            assert!(args.list.is_none());
            assert!(matches!(args.action, PickActionArg::Show));
            assert!(!args.multi);
        } else {
            panic!("Expected Pick command");
        }
    }

    #[test]
    fn test_cli_pick_with_list() {
        let cli = Cli::try_parse_from(["clings", "pick", "today"]).unwrap();
        if let Commands::Pick(args) = cli.command {
            assert_eq!(args.list, Some("today".to_string()));
        } else {
            panic!("Expected Pick command");
        }
    }

    #[test]
    fn test_cli_pick_with_action() {
        let cli = Cli::try_parse_from(["clings", "pick", "--action", "complete"]).unwrap();
        if let Commands::Pick(args) = cli.command {
            assert!(matches!(args.action, PickActionArg::Complete));
        } else {
            panic!("Expected Pick command");
        }
    }

    #[test]
    fn test_cli_pick_multi() {
        let cli = Cli::try_parse_from(["clings", "pick", "--multi"]).unwrap();
        if let Commands::Pick(args) = cli.command {
            assert!(args.multi);
        } else {
            panic!("Expected Pick command");
        }
    }

    // ==================== Todo Subcommand Tests ====================

    #[test]
    fn test_cli_todo_list() {
        let cli = Cli::try_parse_from(["clings", "todo", "list"]).unwrap();
        if let Commands::Todo(args) = cli.command {
            assert!(matches!(args.command, TodoCommands::List));
        } else {
            panic!("Expected Todo command");
        }
    }

    #[test]
    fn test_cli_todo_show() {
        let cli = Cli::try_parse_from(["clings", "todo", "show", "abc123"]).unwrap();
        if let Commands::Todo(args) = cli.command {
            if let TodoCommands::Show { id } = args.command {
                assert_eq!(id, "abc123");
            } else {
                panic!("Expected Show subcommand");
            }
        } else {
            panic!("Expected Todo command");
        }
    }

    #[test]
    fn test_cli_todo_complete() {
        let cli = Cli::try_parse_from(["clings", "todo", "complete", "xyz"]).unwrap();
        if let Commands::Todo(args) = cli.command {
            if let TodoCommands::Complete { id } = args.command {
                assert_eq!(id, "xyz");
            } else {
                panic!("Expected Complete subcommand");
            }
        } else {
            panic!("Expected Todo command");
        }
    }

    #[test]
    fn test_cli_todo_cancel() {
        let cli = Cli::try_parse_from(["clings", "todo", "cancel", "xyz"]).unwrap();
        if let Commands::Todo(args) = cli.command {
            if let TodoCommands::Cancel { id } = args.command {
                assert_eq!(id, "xyz");
            } else {
                panic!("Expected Cancel subcommand");
            }
        } else {
            panic!("Expected Todo command");
        }
    }

    // ==================== Stats Subcommand Tests ====================

    #[test]
    fn test_cli_stats_default() {
        let cli = Cli::try_parse_from(["clings", "stats"]).unwrap();
        if let Commands::Stats(args) = cli.command {
            // No subcommand means None (defaults to Dashboard behavior in handler)
            assert!(args.command.is_none());
        } else {
            panic!("Expected Stats command");
        }
    }

    #[test]
    fn test_cli_stats_summary() {
        let cli = Cli::try_parse_from(["clings", "stats", "summary"]).unwrap();
        if let Commands::Stats(args) = cli.command {
            assert!(matches!(args.command, Some(StatsCommands::Summary)));
        } else {
            panic!("Expected Stats command");
        }
    }

    // ==================== Focus Subcommand Tests ====================

    #[test]
    fn test_cli_focus_start() {
        let cli = Cli::try_parse_from(["clings", "focus", "start"]).unwrap();
        if let Commands::Focus(args) = cli.command {
            if let FocusCommands::Start { task, duration, .. } = args.command {
                assert!(task.is_none());
                assert!(duration.is_none());
            } else {
                panic!("Expected Start subcommand");
            }
        } else {
            panic!("Expected Focus command");
        }
    }

    #[test]
    fn test_cli_focus_start_with_task() {
        let cli = Cli::try_parse_from(["clings", "focus", "start", "--task", "abc"]).unwrap();
        if let Commands::Focus(args) = cli.command {
            if let FocusCommands::Start { task, .. } = args.command {
                assert_eq!(task, Some("abc".to_string()));
            } else {
                panic!("Expected Start subcommand");
            }
        } else {
            panic!("Expected Focus command");
        }
    }

    #[test]
    fn test_cli_focus_status() {
        let cli = Cli::try_parse_from(["clings", "focus", "status"]).unwrap();
        if let Commands::Focus(args) = cli.command {
            assert!(matches!(args.command, FocusCommands::Status { .. }));
        } else {
            panic!("Expected Focus command");
        }
    }

    // ==================== Output Format Tests ====================

    #[test]
    fn test_output_format_default() {
        assert!(matches!(OutputFormat::default(), OutputFormat::Pretty));
    }
}
