//! Template CLI command implementation.
//!
//! This module implements the `clings template` command for managing project templates.

use std::collections::HashMap;
use std::io::{self, Write};

use colored::Colorize;
use serde_json::json;

use crate::cli::args::{OutputFormat, TemplateCommands};
use crate::error::ClingsError;
use crate::features::templates::{
    ProjectTemplate, RelativeDate, TemplateHeading, TemplateStorage, TemplateTodo,
};
use crate::things::ThingsClient;

/// Execute the template command.
///
/// # Errors
///
/// Returns an error if the template operation fails.
pub fn template(
    client: &ThingsClient,
    cmd: TemplateCommands,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    match cmd {
        TemplateCommands::Create {
            name,
            from_project,
            description,
        } => create_template(client, &name, &from_project, description.as_deref(), format),
        TemplateCommands::Apply {
            template,
            name,
            area,
            tags,
            var,
            dry_run,
        } => apply_template(
            client,
            &template,
            &name,
            area.as_deref(),
            tags.as_deref(),
            var.as_deref(),
            dry_run,
            format,
        ),
        TemplateCommands::List => list_templates(format),
        TemplateCommands::Show { name } => show_template(&name, format),
        TemplateCommands::Delete { name, force } => delete_template(&name, force, format),
        TemplateCommands::Edit { name } => edit_template(&name),
    }
}

/// Create a template from an existing project.
fn create_template(
    client: &ThingsClient,
    name: &str,
    from_project: &str,
    description: Option<&str>,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    // Check if template already exists
    let storage = TemplateStorage::new()?;
    if storage.exists(name) {
        return Err(ClingsError::Config(format!(
            "Template '{}' already exists. Delete it first or choose a different name.",
            name
        )));
    }

    // Get project details
    let project = client.get_project_by_name(from_project)?;
    let todos = client.get_project_todos(from_project)?;
    let headings = client.get_project_headings(from_project)?;

    // Build the template
    let mut template = ProjectTemplate::new(name).with_source(from_project);

    if let Some(desc) = description {
        template = template.with_description(desc);
    }

    if !project.notes.is_empty() {
        template = template.with_notes(&project.notes);
    }

    if let Some(area) = &project.area {
        template = template.with_area(area);
    }

    if !project.tags.is_empty() {
        template = template.with_tags(project.tags.clone());
    }

    // Get heading names for categorization
    let heading_todos: HashMap<String, Vec<String>> = headings
        .iter()
        .map(|(h, t)| (h.clone(), t.clone()))
        .collect();

    // Build headings with todos
    let mut template_headings: Vec<TemplateHeading> = Vec::new();
    let mut root_todos: Vec<TemplateTodo> = Vec::new();

    for (heading_name, todo_names) in &headings {
        let mut heading = TemplateHeading::new(heading_name);
        let mut heading_todo_list = Vec::new();

        for todo_name in todo_names {
            // Find the full todo details
            if let Some(todo) = todos.iter().find(|t| &t.name == todo_name) {
                let mut template_todo = TemplateTodo::new(&todo.name);

                if !todo.notes.is_empty() {
                    template_todo = template_todo.with_notes(&todo.notes);
                }

                if !todo.tags.is_empty() {
                    template_todo = template_todo.with_tags(todo.tags.clone());
                }

                // Convert due date to relative date (relative to today)
                if let Some(due) = todo.due_date {
                    let today = chrono::Local::now().date_naive();
                    let diff = (due - today).num_days();
                    let relative = if diff == 0 {
                        "today".to_string()
                    } else if diff == 1 {
                        "tomorrow".to_string()
                    } else if diff > 0 {
                        format!("+{}d", diff)
                    } else {
                        format!("{}d", diff)
                    };
                    template_todo = template_todo.with_due(RelativeDate::new(&relative));
                }

                heading_todo_list.push(template_todo);
            }
        }

        heading.todos = heading_todo_list;
        template_headings.push(heading);
    }

    // Find root-level todos (not in any heading)
    for todo in &todos {
        let in_heading = heading_todos.values().any(|names| names.contains(&todo.name));
        if !in_heading {
            let mut template_todo = TemplateTodo::new(&todo.name);

            if !todo.notes.is_empty() {
                template_todo = template_todo.with_notes(&todo.notes);
            }

            if !todo.tags.is_empty() {
                template_todo = template_todo.with_tags(todo.tags.clone());
            }

            if let Some(due) = todo.due_date {
                let today = chrono::Local::now().date_naive();
                let diff = (due - today).num_days();
                let relative = if diff == 0 {
                    "today".to_string()
                } else if diff == 1 {
                    "tomorrow".to_string()
                } else if diff > 0 {
                    format!("+{}d", diff)
                } else {
                    format!("{}d", diff)
                };
                template_todo = template_todo.with_due(RelativeDate::new(&relative));
            }

            root_todos.push(template_todo);
        }
    }

    template.todos = root_todos;
    template.headings = template_headings;

    // Save the template
    storage.save(&template)?;

    match format {
        OutputFormat::Json => {
            let output = json!({
                "status": "created",
                "name": template.name,
                "source_project": from_project,
                "headings": template.headings.len(),
                "todos": template.todo_count(),
            });
            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        }
        OutputFormat::Pretty => Ok(format!(
            "Created template '{}' from project '{}'\n  {} headings, {} todos",
            template.name.green().bold(),
            from_project,
            template.headings.len(),
            template.todo_count()
        )),
    }
}

/// Apply a template to create a new project.
#[allow(clippy::too_many_arguments)]
fn apply_template(
    client: &ThingsClient,
    template_name: &str,
    project_name: &str,
    area: Option<&str>,
    tags: Option<&[String]>,
    vars: Option<&[String]>,
    dry_run: bool,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    let storage = TemplateStorage::new()?;
    let template = storage.load(template_name)?;

    // Parse variable substitutions
    let mut var_map: HashMap<String, String> = HashMap::new();
    if let Some(vars) = vars {
        for v in vars {
            if let Some((key, value)) = v.split_once('=') {
                var_map.insert(key.to_string(), value.to_string());
            }
        }
    }

    // Determine final values
    let final_area = area.or(template.area.as_deref());
    let final_tags = tags.map(|t| t.to_vec()).or(Some(template.tags.clone()));
    let final_notes = template.notes.as_ref().map(|n| template.substitute(n, &var_map));
    let substituted_name = template.substitute(project_name, &var_map);

    if dry_run {
        return format_dry_run(&template, &substituted_name, final_area, &final_tags, format);
    }

    // Create the project
    let response = client.add_project(
        &substituted_name,
        final_notes.as_deref(),
        final_area,
        final_tags.as_deref(),
        None,
    )?;

    let project_id = &response.id;

    // Add root todos
    for todo in &template.todos {
        let title = template.substitute(&todo.title, &var_map);
        let notes = todo.notes.as_ref().map(|n| template.substitute(n, &var_map));
        let due_str = todo.due.as_ref().map(|d| d.resolve().format("%Y-%m-%d").to_string());

        add_todo_to_project_direct(client, project_id, &title, notes.as_deref(), due_str.as_deref(), &todo.tags)?;
    }

    // Add headings with todos
    for heading in &template.headings {
        let heading_name = template.substitute(&heading.title, &var_map);
        add_heading_direct(client, project_id, &heading_name)?;

        for todo in &heading.todos {
            let title = template.substitute(&todo.title, &var_map);
            let notes = todo.notes.as_ref().map(|n| template.substitute(n, &var_map));
            let due_str = todo.due.as_ref().map(|d| d.resolve().format("%Y-%m-%d").to_string());

            add_todo_to_heading_direct(client, project_id, &heading_name, &title, notes.as_deref(), due_str.as_deref(), &todo.tags)?;
        }
    }

    match format {
        OutputFormat::Json => {
            let output = json!({
                "status": "created",
                "template": template_name,
                "project": {
                    "id": response.id,
                    "name": response.name,
                },
                "headings": template.headings.len(),
                "todos": template.todo_count(),
            });
            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        }
        OutputFormat::Pretty => Ok(format!(
            "Created project '{}' from template '{}'\n  {} headings, {} todos\n  Project ID: {}",
            response.name.green().bold(),
            template_name,
            template.headings.len(),
            template.todo_count(),
            response.id.dimmed()
        )),
    }
}

/// Helper to add a heading directly.
fn add_heading_direct(client: &ThingsClient, project_id: &str, heading_name: &str) -> Result<(), ClingsError> {
    let script = format!(
        r#"(() => {{
    const Things = Application('Things3');
    const project = Things.projects.byId('{}');
    if (!project.exists()) throw new Error("Can't find project");
    Things.make({{ new: 'heading', withProperties: {{ name: {} }}, at: project }});
}})()"#,
        project_id,
        escape_js_string(heading_name)
    );

    client.execute_void(&script)
}

/// Helper to add a todo to a project.
fn add_todo_to_project_direct(
    client: &ThingsClient,
    project_id: &str,
    title: &str,
    notes: Option<&str>,
    due_date: Option<&str>,
    tags: &[String],
) -> Result<(), ClingsError> {
    let notes_js = notes
        .map(|n| format!("props.notes = {};", escape_js_string(n)))
        .unwrap_or_default();

    let due_js = due_date
        .map(|d| format!("props.dueDate = new Date('{}');", d))
        .unwrap_or_default();

    let tags_js = if tags.is_empty() {
        String::new()
    } else {
        format!("props.tagNames = {};", escape_js_string(&tags.join(", ")))
    };

    let script = format!(
        r#"(() => {{
    const Things = Application('Things3');
    const project = Things.projects.byId('{}');
    if (!project.exists()) throw new Error("Can't find project");
    const props = {{ name: {} }};
    {}
    {}
    {}
    Things.make({{ new: 'toDo', withProperties: props, at: project }});
}})()"#,
        project_id,
        escape_js_string(title),
        notes_js,
        due_js,
        tags_js
    );

    client.execute_void(&script)
}

/// Helper to add a todo to a heading.
fn add_todo_to_heading_direct(
    client: &ThingsClient,
    project_id: &str,
    heading_name: &str,
    title: &str,
    notes: Option<&str>,
    due_date: Option<&str>,
    tags: &[String],
) -> Result<(), ClingsError> {
    let notes_js = notes
        .map(|n| format!("props.notes = {};", escape_js_string(n)))
        .unwrap_or_default();

    let due_js = due_date
        .map(|d| format!("props.dueDate = new Date('{}');", d))
        .unwrap_or_default();

    let tags_js = if tags.is_empty() {
        String::new()
    } else {
        format!("props.tagNames = {};", escape_js_string(&tags.join(", ")))
    };

    let script = format!(
        r#"(() => {{
    const Things = Application('Things3');
    const project = Things.projects.byId('{}');
    if (!project.exists()) throw new Error("Can't find project");

    const headings = project.headings.whose({{ name: {} }});
    if (headings.length === 0) throw new Error("Can't find heading");
    const heading = headings[0];

    const props = {{ name: {} }};
    {}
    {}
    {}
    Things.make({{ new: 'toDo', withProperties: props, at: heading }});
}})()"#,
        project_id,
        escape_js_string(heading_name),
        escape_js_string(title),
        notes_js,
        due_js,
        tags_js
    );

    client.execute_void(&script)
}

/// Escape a string for JavaScript.
fn escape_js_string(s: &str) -> String {
    let escaped = s
        .replace('\\', "\\\\")
        .replace('\'', "\\'")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t");
    format!("'{}'", escaped)
}

/// Format dry run output.
fn format_dry_run(
    template: &ProjectTemplate,
    project_name: &str,
    area: Option<&str>,
    tags: &Option<Vec<String>>,
    format: OutputFormat,
) -> Result<String, ClingsError> {
    match format {
        OutputFormat::Json => {
            let output = json!({
                "dry_run": true,
                "template": template.name,
                "would_create": {
                    "name": project_name,
                    "area": area,
                    "tags": tags,
                    "headings": template.headings.iter().map(|h| {
                        json!({
                            "title": h.title,
                            "todos": h.todos.iter().map(|t| &t.title).collect::<Vec<_>>()
                        })
                    }).collect::<Vec<_>>(),
                    "root_todos": template.todos.iter().map(|t| &t.title).collect::<Vec<_>>(),
                }
            });
            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        }
        OutputFormat::Pretty => {
            let mut output = String::new();
            output.push_str(&format!(
                "{} Would create project '{}'\n",
                "[DRY RUN]".yellow().bold(),
                project_name.green().bold()
            ));

            if let Some(area) = area {
                output.push_str(&format!("  Area: {}\n", area));
            }

            if let Some(tags) = tags {
                if !tags.is_empty() {
                    output.push_str(&format!("  Tags: {}\n", tags.join(", ")));
                }
            }

            output.push_str("\n");

            // Root todos
            if !template.todos.is_empty() {
                output.push_str(&format!("{}\n", "Root Todos:".cyan().bold()));
                for todo in &template.todos {
                    output.push_str(&format!("  [ ] {}\n", todo.title));
                }
                output.push_str("\n");
            }

            // Headings
            for heading in &template.headings {
                output.push_str(&format!("{}\n", format!("{}:", heading.title).cyan().bold()));
                for todo in &heading.todos {
                    output.push_str(&format!("  [ ] {}\n", todo.title));
                }
                output.push_str("\n");
            }

            output.push_str(&format!(
                "Total: {} headings, {} todos",
                template.headings.len(),
                template.todo_count()
            ));

            Ok(output)
        }
    }
}

/// List all templates.
fn list_templates(format: OutputFormat) -> Result<String, ClingsError> {
    let storage = TemplateStorage::new()?;
    let templates = storage.list()?;

    match format {
        OutputFormat::Json => {
            let output: Vec<_> = templates
                .iter()
                .map(|t| {
                    json!({
                        "name": t.name,
                        "description": t.description,
                        "source_project": t.source_project,
                        "headings": t.headings.len(),
                        "todos": t.todo_count(),
                        "created_at": t.created_at,
                    })
                })
                .collect();
            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        }
        OutputFormat::Pretty => {
            if templates.is_empty() {
                return Ok("No templates found.\n\nCreate one with: clings template create \"Name\" --from-project \"Project\"".to_string());
            }

            let mut output = format!("{}\n", "Templates".cyan().bold());
            output.push_str(&format!("{}\n\n", "─".repeat(50).dimmed()));

            for template in templates {
                output.push_str(&format!("  {} ", template.name.green().bold()));

                if let Some(desc) = &template.description {
                    output.push_str(&format!("- {}", desc.dimmed()));
                }
                output.push_str("\n");

                let mut details = Vec::new();
                if let Some(source) = &template.source_project {
                    details.push(format!("from: {}", source));
                }
                details.push(format!("{} headings", template.headings.len()));
                details.push(format!("{} todos", template.todo_count()));

                output.push_str(&format!("    {}\n\n", details.join(" | ").dimmed()));
            }

            Ok(output)
        }
    }
}

/// Show template details.
fn show_template(name: &str, format: OutputFormat) -> Result<String, ClingsError> {
    let storage = TemplateStorage::new()?;
    let template = storage.load(name)?;

    match format {
        OutputFormat::Json => {
            serde_json::to_string_pretty(&template).map_err(ClingsError::Parse)
        }
        OutputFormat::Pretty => {
            let mut output = String::new();

            output.push_str(&format!("{}\n", template.name.cyan().bold()));
            output.push_str(&format!("{}\n\n", "─".repeat(50).dimmed()));

            if let Some(desc) = &template.description {
                output.push_str(&format!("{}\n\n", desc));
            }

            if let Some(source) = &template.source_project {
                output.push_str(&format!("  {} {}\n", "Source:".bold(), source));
            }

            if let Some(area) = &template.area {
                output.push_str(&format!("  {} {}\n", "Area:".bold(), area));
            }

            if !template.tags.is_empty() {
                output.push_str(&format!("  {} {}\n", "Tags:".bold(), template.tags.join(", ")));
            }

            if let Some(notes) = &template.notes {
                output.push_str(&format!("  {} {}\n", "Notes:".bold(), notes));
            }

            if !template.variables.is_empty() {
                output.push_str(&format!("\n{}\n", "Variables:".cyan().bold()));
                for var in &template.variables {
                    output.push_str(&format!("  {{{{{}}}}}", var.name));
                    if let Some(default) = &var.default {
                        output.push_str(&format!(" = {}", default.dimmed()));
                    }
                    if let Some(desc) = &var.description {
                        output.push_str(&format!(" - {}", desc.dimmed()));
                    }
                    output.push_str("\n");
                }
            }

            output.push_str("\n");
            output.push_str(&format!("{}\n", "Structure:".cyan().bold()));

            // Root todos
            if !template.todos.is_empty() {
                output.push_str(&format!("\n  {}\n", "(Root)".dimmed()));
                for todo in &template.todos {
                    format_template_todo(&mut output, &todo, 4);
                }
            }

            // Headings
            for heading in &template.headings {
                output.push_str(&format!("\n  {}\n", heading.title.bold()));
                for todo in &heading.todos {
                    format_template_todo(&mut output, &todo, 4);
                }
            }

            output.push_str(&format!(
                "\n{} {} headings, {} todos\n",
                "Total:".bold(),
                template.headings.len(),
                template.todo_count()
            ));

            Ok(output)
        }
    }
}

/// Format a template todo for display.
fn format_template_todo(output: &mut String, todo: &TemplateTodo, indent: usize) {
    let spaces = " ".repeat(indent);
    output.push_str(&format!("{}[ ] {}", spaces, todo.title));

    let mut meta = Vec::new();
    if let Some(due) = &todo.due {
        meta.push(format!("due: {}", due));
    }
    if !todo.tags.is_empty() {
        meta.push(format!("#{}", todo.tags.join(" #")));
    }

    if !meta.is_empty() {
        output.push_str(&format!(" {}", meta.join(" ").dimmed()));
    }

    output.push('\n');

    if let Some(notes) = &todo.notes {
        let note_preview = if notes.len() > 50 {
            format!("{}...", &notes[..50])
        } else {
            notes.clone()
        };
        output.push_str(&format!("{}  {}\n", spaces, note_preview.dimmed()));
    }
}

/// Delete a template.
fn delete_template(name: &str, force: bool, format: OutputFormat) -> Result<String, ClingsError> {
    let storage = TemplateStorage::new()?;

    if !storage.exists(name) {
        return Err(ClingsError::NotFound(format!("Template '{}'", name)));
    }

    if !force {
        print!("Delete template '{}'? [y/N] ", name);
        io::stdout().flush().map_err(ClingsError::Io)?;

        let mut input = String::new();
        io::stdin().read_line(&mut input).map_err(ClingsError::Io)?;

        if !input.trim().eq_ignore_ascii_case("y") {
            return Ok("Cancelled.".to_string());
        }
    }

    storage.delete(name)?;

    match format {
        OutputFormat::Json => {
            let output = json!({
                "status": "deleted",
                "name": name,
            });
            serde_json::to_string_pretty(&output).map_err(ClingsError::Parse)
        }
        OutputFormat::Pretty => Ok(format!("Deleted template '{}'", name)),
    }
}

/// Edit a template (opens editor or shows path).
fn edit_template(name: &str) -> Result<String, ClingsError> {
    let storage = TemplateStorage::new()?;

    if !storage.exists(name) {
        return Err(ClingsError::NotFound(format!("Template '{}'", name)));
    }

    let paths = crate::config::Paths::default();
    let safe_name = name
        .chars()
        .map(|c| if c.is_alphanumeric() || c == '-' || c == '_' { c } else { '_' })
        .collect::<String>();
    let template_path = paths.templates.join(format!("{}.yaml", safe_name));

    // Try to open in editor
    if let Ok(editor) = std::env::var("EDITOR") {
        std::process::Command::new(&editor)
            .arg(&template_path)
            .status()
            .map_err(|e| ClingsError::Config(format!("Failed to open editor: {}", e)))?;
        Ok(format!("Opened {} in {}", template_path.display(), editor))
    } else {
        Ok(format!(
            "Template file: {}\n\nSet $EDITOR to open directly, e.g.:\n  EDITOR=vim clings template edit \"{}\"",
            template_path.display(),
            name
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_escape_js_string() {
        assert_eq!(escape_js_string("hello"), "'hello'");
        assert_eq!(escape_js_string("it's"), "'it\\'s'");
        assert_eq!(escape_js_string("line1\nline2"), "'line1\\nline2'");
    }
}
