# Generated command reference

Generated from ArgumentParser's command tree. Do not edit by hand.
Run `ruby scripts/generate-reference.rb .build/debug/clings --write` after changing help or arguments.
Narrative recipes live in [the command guide](command-reference.md).

## `clings`

A powerful CLI for Things 3

| Argument | Description |
| --- | --- |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings today`

Show today's todos

Aliases: `t`.

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings inbox`

Show inbox todos

Aliases: `i`.

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings upcoming`

Show upcoming todos

Aliases: `u`.

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings anytime`

Show anytime todos

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings someday`

Show someday todos

Aliases: `s`.

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings logbook`

Show completed todos

Aliases: `l`.

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings projects`

List all projects

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings project`

Manage projects

| Argument | Description |
| --- | --- |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings project list`

List all projects

Aliases: `ls`.

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings project add`

Create a new project

| Argument | Description |
| --- | --- |
| `<title>` | Title of the project Required. |
| `--notes <notes>` | Project notes/description Optional. |
| `--area <area>` | Area to assign project to Optional. |
| `--when <when>` | When to start (today, tomorrow, YYYY-MM-DD) Optional. |
| `--deadline <deadline>` | Deadline date (YYYY-MM-DD) Optional. |
| `--tags <tags>` | Tags (comma-separated) Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings project audit`

Audit project health and missing next actions

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings areas`

List all areas

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings tags`

Manage tags

| Argument | Description |
| --- | --- |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings tags list`

List all tags

Aliases: `ls`.

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings tags add`

Create a new tag

| Argument | Description |
| --- | --- |
| `<name>` | Name of the tag to create Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings tags delete`

Delete a tag

Aliases: `rm`.

| Argument | Description |
| --- | --- |
| `<name>` | Name of the tag to delete Required. |
| `--force, -f` | Skip confirmation prompt Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings tags rename`

Rename a tag

Aliases: `mv`.

| Argument | Description |
| --- | --- |
| `<old-name>` | Current name of the tag Required. |
| `<new-name>` | New name for the tag Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings show`

Show details of a todo by ID

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to show Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings add`

Add a new todo with natural language support

| Argument | Description |
| --- | --- |
| `<title>` | The todo title (supports natural language) Required. |
| `--template <template>` | Start from a saved task template Optional. |
| `--notes <notes>` | Add notes to the todo Optional. |
| `--when <when>` | Planned start date, e.g. 'tomorrow' or '2027-01-15'; preview with --parse-only Optional. |
| `--deadline <deadline>` | Due date, distinct from the planned start; e.g. 'friday' or '2027-01-15' Optional. |
| `--tags <tags>...` | Space-separated tag names, combined with parsed/template tags Optional. |
| `--project <project>` | Add to a project Optional. |
| `--area <area>` | Add to an area Optional. |
| `--parse-only` | Show parsed result without creating todo Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings complete`

Mark a todo as completed

Aliases: `done`.

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to complete (optional if using --title) Optional. |
| `-t, --title <title>` | Complete todo by searching its title Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings cancel`

Cancel a todo

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to cancel Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings delete`

Cancel a todo through the automation API

Aliases: `rm`.

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to delete Required. |
| `--force, -f` | Authorize cancellation without prompting (never moves to Trash) Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings update`

Update a todo's properties

| Argument | Description |
| --- | --- |
| `<id>` | The ID of the todo to update Required. |
| `--name <name>` | New title/name for the todo Optional. |
| `--notes <notes>` | New notes for the todo Optional. |
| `--due <due>` | New due date (YYYY-MM-DD or 'today', 'tomorrow') Optional. |
| `--when <when>` | Schedule for a date ('today', 'tomorrow', 'evening', 'anytime', 'someday', or YYYY-MM-DD). Requires auth token. Optional. |
| `--heading <heading>` | Move to a heading within the task's project. Requires auth token. Optional. |
| `--tags <tags>...` | New tags (replaces existing) Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--parse-only` | Preview final fields and undo capabilities without writing or requiring an auth token Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings search`

Search todos by text

Aliases: `find`, `f`.

| Argument | Description |
| --- | --- |
| `<query>` | The search query Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--list <list>` | Scope to a Things list: today, inbox, upcoming, anytime, someday, logbook, trash Optional. |
| `--include-logbook` | Include completed and canceled tasks from Logbook Optional. |
| `--sort <sort>` | Sort by id, name, due, when, created, modified; prefix with - for descending Optional. |
| `--limit <limit>` | Maximum results (positive integer) Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings views`

Manage saved filter views

| Argument | Description |
| --- | --- |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings views list`

List saved views

Aliases: `ls`.

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings views save`

Save a named filter view

| Argument | Description |
| --- | --- |
| `<name>` | View name Required. |
| `<expression>` | Filter expression Required. |
| `--note <note>` | Optional description for this view Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings views run`

Run a saved filter view

| Argument | Description |
| --- | --- |
| `<name>` | View name Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--list <list>` | Scope to a Things list: today, inbox, upcoming, anytime, someday, logbook, trash Optional. |
| `--include-logbook` | Include completed and canceled tasks from Logbook Optional. |
| `--sort <sort>` | Sort by id, name, due, when, created, modified; prefix with - for descending Optional. |
| `--limit <limit>` | Maximum results (positive integer) Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings views delete`

Delete a saved view

Aliases: `rm`.

| Argument | Description |
| --- | --- |
| `<name>` | View name Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings template`

Manage reusable task templates

| Argument | Description |
| --- | --- |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings template list`

List saved templates

Aliases: `ls`.

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings template save`

Save a task template

| Argument | Description |
| --- | --- |
| `<name>` | Template name Required. |
| `<title>` | Template title or natural-language task Required. |
| `--notes <notes>` | Notes to store with the template Optional. |
| `--when <when>` | Store a relative when expression, e.g. 'tomorrow morning' Optional. |
| `--deadline <deadline>` | Store a relative deadline expression, e.g. 'next friday' Optional. |
| `--tags <tags>...` | Store tags Optional. |
| `--project <project>` | Default project Optional. |
| `--area <area>` | Default area Optional. |
| `--checklist <checklist>...` | Checklist items Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings template run`

Create a task from a template

| Argument | Description |
| --- | --- |
| `<name>` | Template name Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings template delete`

Delete a template

Aliases: `rm`.

| Argument | Description |
| --- | --- |
| `<name>` | Template name Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings undo`

Undo the most recent supported mutation

| Argument | Description |
| --- | --- |
| `--show` | Show the most recent undo entry without applying it Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings focus`

Show a focused queue of high-attention tasks

| Argument | Description |
| --- | --- |
| `--limit <limit>` | Maximum number of tasks to show Optional. Default: 10. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings pick`

Interactively pick a todo for a follow-up action

| Argument | Description |
| --- | --- |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings pick show`

Pick a todo and show its details

| Argument | Description |
| --- | --- |
| `<query>` | Optional search query Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings pick complete`

Pick a todo and complete it

| Argument | Description |
| --- | --- |
| `<query>` | Optional search query Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings pick cancel`

Pick a todo and cancel it

| Argument | Description |
| --- | --- |
| `<query>` | Optional search query Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings pick delete`

Pick a todo and delete it

| Argument | Description |
| --- | --- |
| `<query>` | Optional search query Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings doctor`

Check clings setup and local environment

| Argument | Description |
| --- | --- |
| `--verbose` | Include local paths in human output; JSON remains redacted Optional. |
| `--probe-automation` | Opt in to a read-only Things automation query Optional. |
| `--support-bundle <support-bundle>` | Create a new redacted support JSON file without overwriting Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings bulk`

Bulk operations on multiple todos

| Argument | Description |
| --- | --- |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings bulk complete`

Mark multiple todos as completed

| Argument | Description |
| --- | --- |
| `--where <where>` | Filter expression scoped to the selected list Optional. |
| `--dry-run` | Preview a reusable plan without writing Optional. |
| `-y, --yes` | Authorize the whole plan without prompting Optional. |
| `--execute-plan <execute-plan>` | Execute or resume a saved exact-ID plan Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--list <list>` | Source list (default: today) Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings bulk cancel`

Cancel multiple todos

| Argument | Description |
| --- | --- |
| `--where <where>` | Filter expression scoped to the selected list Optional. |
| `--dry-run` | Preview a reusable plan without writing Optional. |
| `-y, --yes` | Authorize the whole plan without prompting Optional. |
| `--execute-plan <execute-plan>` | Execute or resume a saved exact-ID plan Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--list <list>` | Source list (default: today) Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings bulk tag`

Add tags to multiple todos

| Argument | Description |
| --- | --- |
| `<tags>` | Comma-separated tags; omit when executing a plan Optional. |
| `--where <where>` | Filter expression scoped to the selected list Optional. |
| `--dry-run` | Preview a reusable plan without writing Optional. |
| `-y, --yes` | Authorize the whole plan without prompting Optional. |
| `--execute-plan <execute-plan>` | Execute or resume a saved exact-ID plan Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--list <list>` | Source list (default: today) Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings bulk move`

Move multiple todos to a project

| Argument | Description |
| --- | --- |
| `--to <to>` | Exact destination project ID or unambiguous name; omit when executing a plan Optional. |
| `--where <where>` | Filter expression scoped to the selected list Optional. |
| `--dry-run` | Preview a reusable plan without writing Optional. |
| `-y, --yes` | Authorize the whole plan without prompting Optional. |
| `--execute-plan <execute-plan>` | Execute or resume a saved exact-ID plan Optional. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--list <list>` | Source list (default: today) Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings filter`

Filter todos using a query expression

| Argument | Description |
| --- | --- |
| `<expression>` | Filter expression Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--list <list>` | Scope to a Things list: today, inbox, upcoming, anytime, someday, logbook, trash Optional. |
| `--include-logbook` | Include completed and canceled tasks from Logbook Optional. |
| `--sort <sort>` | Sort by id, name, due, when, created, modified; prefix with - for descending Optional. |
| `--limit <limit>` | Maximum results (positive integer) Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings open`

Explain the disabled Things navigation command

| Argument | Description |
| --- | --- |
| `<target>` | The ID of the todo to open, or a list name (today, inbox, etc.) Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings stats`

Show productivity statistics

| Argument | Description |
| --- | --- |
| `--days <days>` | Number of days to analyze (1...36600; default: 30) Optional. Default: 30. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings stats trends`

Show completion trends over time

| Argument | Description |
| --- | --- |
| `--weeks <weeks>` | Number of weeks to show (1...5200; default: 4) Optional. Default: 4. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings stats heatmap`

Show GitHub-style contribution calendar

| Argument | Description |
| --- | --- |
| `--weeks <weeks>` | Number of weeks to show (1...5200; default: 12) Optional. Default: 12. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings review`

GTD weekly review workflow

| Argument | Description |
| --- | --- |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings review start`

Start or resume a weekly review

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings review status`

Show current review session status

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings review clear`

Clear the current review session

| Argument | Description |
| --- | --- |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings completions`

Generate shell completions

| Argument | Description |
| --- | --- |
| `<shell>` | Shell to generate completions for (bash, zsh, fish) Required. Values: bash, zsh, fish. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings config`

Configure clings settings

| Argument | Description |
| --- | --- |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings config set-auth-token`

Set the Things 3 auth token for URL scheme operations (e.g., --heading)

| Argument | Description |
| --- | --- |
| `<token>` | The auth token from Things 3 (Settings > General > Enable Things URLs) Required. |
| `--json` | Output a schema 1 JSON response with payload under data; takes precedence over --format Optional. |
| `--no-color` | Suppress color output Optional. |
| `--format <format>` | Todo-line template: {id}, {name}, {status}, {due}, {project}, {area}, {tags}; only used by todo renderers Optional. |
| `--version` | Show the version. Optional. |
| `-h, --help` | Show help information. Optional. |

## `clings help`

Show subcommand help information.

| Argument | Description |
| --- | --- |
| `<subcommands>...` | Optional. |
| `--version` | Show the version. Optional. |
