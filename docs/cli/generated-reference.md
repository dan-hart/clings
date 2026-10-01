# Generated command reference

Generated from ArgumentParser's command tree. Do not edit by hand.
Run `ruby scripts/generate-reference.rb .build/debug/clings --write` after changing help or arguments.
Narrative recipes live in [the command guide](command-reference.md).

## `clings`

A powerful CLI for Things 3

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings today`

Show today's todos

Aliases: `t`.

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings inbox`

Show inbox todos

Aliases: `i`.

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings upcoming`

Show upcoming todos

Aliases: `u`.

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings anytime`

Show anytime todos

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings someday`

Show someday todos

Aliases: `s`.

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings logbook`

Show completed todos

Aliases: `l`.

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings projects`

List all projects

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings project`

Manage projects

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings project list`

List all projects

Aliases: `ls`.

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings project add`

Create a new project

| Argument | Description |
| --- | --- |
| `<title>` | Title of the project |
| `--notes <notes>` | Project notes/description |
| `--area <area>` | Area to assign project to |
| `--when <when>` | When to start (today, tomorrow, YYYY-MM-DD) |
| `--deadline <deadline>` | Deadline date (YYYY-MM-DD) |
| `--tags <tags>` | Tags (comma-separated) |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings project audit`

Audit project health and missing next actions

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings areas`

List all areas

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings tags`

Manage tags

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings tags list`

List all tags

Aliases: `ls`.

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings tags add`

Create a new tag

| Argument | Description |
| --- | --- |
| `<name>` | Name of the tag to create |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings tags delete`

Delete a tag

Aliases: `rm`.

| Argument | Description |
| --- | --- |
| `<name>` | Name of the tag to delete |
| `--force, -f` | Skip confirmation prompt |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings tags rename`

Rename a tag

Aliases: `mv`.

| Argument | Description |
| --- | --- |
| `<old-name>` | Current name of the tag |
| `<new-name>` | New name for the tag |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings show`

Show details of a todo by ID

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to show |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings add`

Add a new todo with natural language support

| Argument | Description |
| --- | --- |
| `<title>` | The todo title (supports natural language) |
| `--template <template>` | Start from a saved task template |
| `--notes <notes>` | Add notes to the todo |
| `--when <when>` | Planned start date, e.g. 'tomorrow' or '2027-01-15'; preview with --parse-only |
| `--deadline <deadline>` | Due date, distinct from the planned start; e.g. 'friday' or '2027-01-15' |
| `--tags <tags>...` | Space-separated tag names, combined with parsed/template tags |
| `--project <project>` | Add to a project |
| `--area <area>` | Add to an area |
| `--parse-only` | Show parsed result without creating todo |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings complete`

Mark a todo as completed

Aliases: `done`.

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to complete (optional if using --title) |
| `-t, --title <title>` | Complete todo by searching its title |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings cancel`

Cancel a todo

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to cancel |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings delete`

Cancel a todo through the automation API

Aliases: `rm`.

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to delete |
| `--force, -f` | Compatibility flag; deletion currently runs without confirmation |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings update`

Update a todo's properties

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to update |
| `--name <name>` | New title/name for the todo |
| `--notes <notes>` | New notes for the todo |
| `--due <due>` | New due date (YYYY-MM-DD or 'today', 'tomorrow') |
| `--when <when>` | Schedule for a date ('today', 'tomorrow', 'evening', 'anytime', 'someday', or YYYY-MM-DD). Requires auth token. |
| `--heading <heading>` | Move to a heading within the task's project. Requires auth token. |
| `--tags <tags>...` | New tags (replaces existing) |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--parse-only` | Preview final fields and undo capabilities without writing or requiring an auth token |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings search`

Search todos by text

Aliases: `find`, `f`.

| Argument | Description |
| --- | --- |
| `<query>` | The search query |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--list <list>` | Scope to a Things list: today, inbox, upcoming, anytime, someday, logbook, trash |
| `--include-logbook` | Include completed and canceled tasks from Logbook |
| `--sort <sort>` | Sort by id, name, due, when, created, modified; prefix with - for descending |
| `--limit <limit>` | Maximum results (positive integer) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings views`

Manage saved filter views

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings views list`

List saved views

Aliases: `ls`.

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings views save`

Save a named filter view

| Argument | Description |
| --- | --- |
| `<name>` | View name |
| `<expression>` | Filter expression |
| `--note <note>` | Optional description for this view |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings views run`

Run a saved filter view

| Argument | Description |
| --- | --- |
| `<name>` | View name |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--list <list>` | Scope to a Things list: today, inbox, upcoming, anytime, someday, logbook, trash |
| `--include-logbook` | Include completed and canceled tasks from Logbook |
| `--sort <sort>` | Sort by id, name, due, when, created, modified; prefix with - for descending |
| `--limit <limit>` | Maximum results (positive integer) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings views delete`

Delete a saved view

Aliases: `rm`.

| Argument | Description |
| --- | --- |
| `<name>` | View name |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings template`

Manage reusable task templates

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings template list`

List saved templates

Aliases: `ls`.

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings template save`

Save a task template

| Argument | Description |
| --- | --- |
| `<name>` | Template name |
| `<title>` | Template title or natural-language task |
| `--notes <notes>` | Notes to store with the template |
| `--when <when>` | Store a relative when expression, e.g. 'tomorrow morning' |
| `--deadline <deadline>` | Store a relative deadline expression, e.g. 'next friday' |
| `--tags <tags>...` | Store tags |
| `--project <project>` | Default project |
| `--area <area>` | Default area |
| `--checklist <checklist>...` | Checklist items |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings template run`

Create a task from a template

| Argument | Description |
| --- | --- |
| `<name>` | Template name |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings template delete`

Delete a template

Aliases: `rm`.

| Argument | Description |
| --- | --- |
| `<name>` | Template name |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings undo`

Undo the most recent supported mutation

| Argument | Description |
| --- | --- |
| `--show` | Show the most recent undo entry without applying it |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings focus`

Show a focused queue of high-attention tasks

| Argument | Description |
| --- | --- |
| `--limit <limit>` | Maximum number of tasks to show |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings pick`

Interactively pick a todo for a follow-up action

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings pick show`

Pick a todo and show its details

| Argument | Description |
| --- | --- |
| `<query>` | Optional search query |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings pick complete`

Pick a todo and complete it

| Argument | Description |
| --- | --- |
| `<query>` | Optional search query |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings pick cancel`

Pick a todo and cancel it

| Argument | Description |
| --- | --- |
| `<query>` | Optional search query |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings pick delete`

Pick a todo and delete it

| Argument | Description |
| --- | --- |
| `<query>` | Optional search query |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings doctor`

Check clings setup and local environment

| Argument | Description |
| --- | --- |
| `--verbose` | Include paths and extra detail |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings bulk`

Bulk operations on multiple todos

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings bulk complete`

Mark multiple todos as completed

| Argument | Description |
| --- | --- |
| `--where <where>` | Filter expression (e.g., "tags CONTAINS 'work'") |
| `--dry-run` | Show what would be changed without making changes |
| `-y, --yes` | Skip confirmation prompt |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--list <list>` | List to operate on (today, inbox, etc.) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings bulk cancel`

Cancel multiple todos

| Argument | Description |
| --- | --- |
| `--where <where>` | Filter expression (e.g., "tags CONTAINS 'work'") |
| `--dry-run` | Show what would be changed without making changes |
| `-y, --yes` | Skip confirmation prompt |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--list <list>` | List to operate on (today, inbox, etc.) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings bulk tag`

Add tags to multiple todos

| Argument | Description |
| --- | --- |
| `<tags>` | Tags to add (comma-separated) |
| `--where <where>` | Filter expression (e.g., "tags CONTAINS 'work'") |
| `--dry-run` | Show what would be changed without making changes |
| `-y, --yes` | Skip confirmation prompt |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--list <list>` | List to operate on (today, inbox, etc.) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings bulk move`

Move multiple todos to a project

| Argument | Description |
| --- | --- |
| `--to <to>` | Target project name |
| `--where <where>` | Filter expression (e.g., "tags CONTAINS 'work'") |
| `--dry-run` | Show what would be changed without making changes |
| `-y, --yes` | Skip confirmation prompt |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--list <list>` | List to operate on (today, inbox, etc.) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings filter`

Filter todos using a query expression

| Argument | Description |
| --- | --- |
| `<expression>` | Filter expression |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--list <list>` | Scope to a Things list: today, inbox, upcoming, anytime, someday, logbook, trash |
| `--include-logbook` | Include completed and canceled tasks from Logbook |
| `--sort <sort>` | Sort by id, name, due, when, created, modified; prefix with - for descending |
| `--limit <limit>` | Maximum results (positive integer) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings open`

Explain the disabled Things navigation command

| Argument | Description |
| --- | --- |
| `<target>` | The ID of the todo to open, or a list name (today, inbox, etc.) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings stats`

Show productivity statistics

| Argument | Description |
| --- | --- |
| `--days <days>` | Number of days to analyze (default: 30) |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings stats trends`

Show completion trends over time

| Argument | Description |
| --- | --- |
| `--weeks <weeks>` | Number of weeks to show (default: 4) |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings stats heatmap`

Show GitHub-style contribution calendar

| Argument | Description |
| --- | --- |
| `--weeks <weeks>` | Number of weeks to show (default: 12) |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings review`

GTD weekly review workflow

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings review start`

Start or resume a weekly review

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings review status`

Show current review session status

| Argument | Description |
| --- | --- |
| `--json` | Output as JSON where supported; takes precedence over --format |
| `--no-color` | Suppress color output |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings review clear`

Clear the current review session

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings completions`

Generate shell completions

| Argument | Description |
| --- | --- |
| `<shell>` | Shell to generate completions for (bash, zsh, fish) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings config`

Configure clings settings

| Argument | Description |
| --- | --- |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings config set-auth-token`

Set the Things 3 auth token for URL scheme operations (e.g., --heading)

| Argument | Description |
| --- | --- |
| `<token>` | The auth token from Things 3 (Settings > General > Enable Things URLs) |
| `--version` | Show the version. |
| `-h, --help` | Show help information. |

## `clings help`

Show subcommand help information.

| Argument | Description |
| --- | --- |
| `<subcommands>...` |  |
| `--version` | Show the version. |

