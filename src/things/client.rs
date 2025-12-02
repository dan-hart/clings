use std::process::Command;

use serde::de::DeserializeOwned;

use crate::error::ClingsError;
use crate::things::types::{AllListsResult, Area, BatchResult, CreateResponse, ListView, OpenListsResult, Project, Tag, Todo};
use crate::things::database;

#[derive(Clone)]
pub struct ThingsClient;

impl ThingsClient {
    pub fn new() -> Self {
        ThingsClient
    }

    /// Execute a JXA script and parse the JSON result
    pub fn execute<T: DeserializeOwned>(&self, script: &str) -> Result<T, ClingsError> {
        let output = Command::new("osascript")
            .arg("-l")
            .arg("JavaScript")
            .arg("-e")
            .arg(script)
            .output()?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(ClingsError::from_stderr(&stderr));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let trimmed = stdout.trim();

        if trimmed.is_empty() {
            // Return empty array for list queries
            return serde_json::from_str("[]").map_err(ClingsError::Parse);
        }

        serde_json::from_str(trimmed).map_err(ClingsError::Parse)
    }

    /// Execute a JXA script that returns nothing
    pub fn execute_void(&self, script: &str) -> Result<(), ClingsError> {
        let output = Command::new("osascript")
            .arg("-l")
            .arg("JavaScript")
            .arg("-e")
            .arg(script)
            .output()?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(ClingsError::from_stderr(&stderr));
        }

        Ok(())
    }

    /// Get todos from a specific list view.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    pub fn get_list(&self, view: ListView) -> Result<Vec<Todo>, ClingsError> {
        // Try database first for better performance
        match database::fetch_list(view) {
            Ok(todos) => Ok(todos),
            Err(_) => self.get_list_jxa(view),
        }
    }

    /// Get todos from a specific list view using JXA (fallback).
    fn get_list_jxa(&self, view: ListView) -> Result<Vec<Todo>, ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const list = Things.lists.byName('{}');
    const todos = list.toDos();
    return JSON.stringify(todos.map(t => {{
        let tags = [];
        try {{
            const tagNames = t.tagNames();
            if (tagNames && tagNames.length > 0) {{
                tags = tagNames.split(', ').filter(x => x.length > 0);
            }}
        }} catch(e) {{}}

        let dueDate = null;
        try {{
            const d = t.dueDate();
            if (d) dueDate = d.toISOString().split('T')[0];
        }} catch(e) {{}}

        return {{
            id: t.id(),
            name: t.name(),
            notes: t.notes() || '',
            status: t.status(),
            dueDate: dueDate,
            tags: tags,
            project: t.project() ? t.project().name() : null,
            area: t.area() ? t.area().name() : null,
            checklistItems: [],
            creationDate: t.creationDate() ? t.creationDate().toISOString() : null,
            modificationDate: t.modificationDate() ? t.modificationDate().toISOString() : null
        }};
    }}));
}})()"#,
            view.as_str()
        );

        self.execute(&script)
    }

    /// Get a specific todo by ID.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    pub fn get_todo(&self, id: &str) -> Result<Todo, ClingsError> {
        // Try database first for better performance
        match database::fetch_todo(id) {
            Ok(todo) => Ok(todo),
            Err(_) => self.get_todo_jxa(id),
        }
    }

    /// Get a specific todo by ID using JXA (fallback).
    fn get_todo_jxa(&self, id: &str) -> Result<Todo, ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const t = Things.toDos.byId('{}');
    if (!t.exists()) throw new Error("Can't get todo");

    let tags = [];
    try {{
        const tagNames = t.tagNames();
        if (tagNames && tagNames.length > 0) {{
            tags = tagNames.split(', ').filter(x => x.length > 0);
        }}
    }} catch(e) {{}}

    let dueDate = null;
    try {{
        const d = t.dueDate();
        if (d) dueDate = d.toISOString().split('T')[0];
    }} catch(e) {{}}

    let checklistItems = [];
    try {{
        const items = t.toDoS();
        if (items && items.length > 0) {{
            checklistItems = items.map(i => ({{
                name: i.name(),
                completed: i.status() === 'completed'
            }}));
        }}
    }} catch(e) {{}}

    return JSON.stringify({{
        id: t.id(),
        name: t.name(),
        notes: t.notes() || '',
        status: t.status(),
        dueDate: dueDate,
        tags: tags,
        project: t.project() ? t.project().name() : null,
        area: t.area() ? t.area().name() : null,
        checklistItems: checklistItems,
        creationDate: t.creationDate() ? t.creationDate().toISOString() : null,
        modificationDate: t.modificationDate() ? t.modificationDate().toISOString() : null
    }});
}})()"#,
            id
        );

        self.execute(&script)
    }

    /// Add a new todo
    pub fn add_todo(
        &self,
        title: &str,
        notes: Option<&str>,
        due_date: Option<&str>,
        tags: Option<&[String]>,
        list: Option<&str>,
        checklist: Option<&[String]>,
    ) -> Result<CreateResponse, ClingsError> {
        let notes_js = notes
            .map(|n| format!("props.notes = {};", Self::js_string(n)))
            .unwrap_or_default();

        let due_js = due_date
            .map(|d| format!("props.dueDate = new Date('{}');", d))
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("props.tagNames = {};", Self::js_string(&t.join(", "))))
            .unwrap_or_default();

        let list_js = list
            .map(|l| {
                format!(
                    r#"
    const targetList = Things.lists.byName({});
    if (targetList.exists()) {{
        Things.move(todo, {{ to: targetList }});
    }}"#,
                    Self::js_string(l)
                )
            })
            .unwrap_or_default();

        let checklist_js = checklist
            .map(|items| {
                let items_str: Vec<String> = items.iter().map(|i| Self::js_string(i)).collect();
                format!(
                    r#"
    const checklistItems = [{}];
    for (const item of checklistItems) {{
        Things.make({{ new: 'toDo', withProperties: {{ name: item }}, at: todo }});
    }}"#,
                    items_str.join(", ")
                )
            })
            .unwrap_or_default();

        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const props = {{ name: {} }};
    {}
    {}
    {}
    const todo = Things.make({{ new: 'toDo', withProperties: props }});
    {}
    {}
    return JSON.stringify({{ id: todo.id(), name: todo.name() }});
}})()"#,
            Self::js_string(title),
            notes_js,
            due_js,
            tags_js,
            list_js,
            checklist_js
        );

        self.execute(&script)
    }

    /// Mark a todo as complete
    pub fn complete_todo(&self, id: &str) -> Result<(), ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{}');
    if (!todo.exists()) throw new Error("Can't get todo");
    todo.status = 'completed';
}})()"#,
            id
        );

        self.execute_void(&script)
    }

    /// Mark a todo as canceled
    pub fn cancel_todo(&self, id: &str) -> Result<(), ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{}');
    if (!todo.exists()) throw new Error("Can't get todo");
    todo.status = 'canceled';
}})()"#,
            id
        );

        self.execute_void(&script)
    }

    /// Delete a todo (cancel it - Things 3 AppleScript doesn't support true deletion)
    pub fn delete_todo(&self, id: &str) -> Result<(), ClingsError> {
        // Note: Things 3 AppleScript API doesn't support moving items to trash.
        // This cancels the todo instead. Use the Things app to permanently delete.
        self.cancel_todo(id)
    }

    /// Get all projects.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    pub fn get_projects(&self) -> Result<Vec<Project>, ClingsError> {
        match database::fetch_projects() {
            Ok(projects) => Ok(projects),
            Err(_) => self.get_projects_jxa(),
        }
    }

    /// Get all projects using JXA (fallback).
    fn get_projects_jxa(&self) -> Result<Vec<Project>, ClingsError> {
        let script = r#"(() => {
    const Things = Application('Things3');
    const projects = Things.projects();
    return JSON.stringify(projects.map(p => {
        let tags = [];
        try {
            const tagNames = p.tagNames();
            if (tagNames && tagNames.length > 0) {
                tags = tagNames.split(', ').filter(x => x.length > 0);
            }
        } catch(e) {}

        let dueDate = null;
        try {
            const d = p.dueDate();
            if (d) dueDate = d.toISOString().split('T')[0];
        } catch(e) {}

        return {
            id: p.id(),
            name: p.name(),
            notes: p.notes() || '',
            status: p.status(),
            area: p.area() ? p.area().name() : null,
            tags: tags,
            dueDate: dueDate,
            creationDate: p.creationDate() ? p.creationDate().toISOString() : null
        };
    }));
})()"#;

        self.execute(script)
    }

    /// Add a new project
    pub fn add_project(
        &self,
        title: &str,
        notes: Option<&str>,
        area: Option<&str>,
        tags: Option<&[String]>,
        due_date: Option<&str>,
    ) -> Result<CreateResponse, ClingsError> {
        let notes_js = notes
            .map(|n| format!("props.notes = {};", Self::js_string(n)))
            .unwrap_or_default();

        let due_js = due_date
            .map(|d| format!("props.dueDate = new Date('{}');", d))
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("props.tagNames = {};", Self::js_string(&t.join(", "))))
            .unwrap_or_default();

        let area_js = area
            .map(|a| {
                format!(
                    r#"
    const targetArea = Things.areas.byName({});
    if (targetArea.exists()) {{
        project.area = targetArea;
    }}"#,
                    Self::js_string(a)
                )
            })
            .unwrap_or_default();

        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const props = {{ name: {} }};
    {}
    {}
    {}
    const project = Things.make({{ new: 'project', withProperties: props }});
    {}
    return JSON.stringify({{ id: project.id(), name: project.name() }});
}})()"#,
            Self::js_string(title),
            notes_js,
            due_js,
            tags_js,
            area_js
        );

        self.execute(&script)
    }

    /// Get all areas.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    pub fn get_areas(&self) -> Result<Vec<Area>, ClingsError> {
        match database::fetch_areas() {
            Ok(areas) => Ok(areas),
            Err(_) => self.get_areas_jxa(),
        }
    }

    /// Get all areas using JXA (fallback).
    fn get_areas_jxa(&self) -> Result<Vec<Area>, ClingsError> {
        let script = r#"(() => {
    const Things = Application('Things3');
    const areas = Things.areas();
    return JSON.stringify(areas.map(a => {
        let tags = [];
        try {
            const tagNames = a.tagNames();
            if (tagNames && tagNames.length > 0) {
                tags = tagNames.split(', ').filter(x => x.length > 0);
            }
        } catch(e) {}

        return {
            id: a.id(),
            name: a.name(),
            tags: tags
        };
    }));
})()"#;

        self.execute(script)
    }

    /// Get all tags.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    pub fn get_tags(&self) -> Result<Vec<Tag>, ClingsError> {
        match database::fetch_tags() {
            Ok(tags) => Ok(tags),
            Err(_) => self.get_tags_jxa(),
        }
    }

    /// Get all tags using JXA (fallback).
    fn get_tags_jxa(&self) -> Result<Vec<Tag>, ClingsError> {
        let script = r#"(() => {
    const Things = Application('Things3');
    const tags = Things.tags();
    return JSON.stringify(tags.map(t => ({
        id: t.id(),
        name: t.name()
    })));
})()"#;

        self.execute(script)
    }

    /// Search todos by query.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    pub fn search(&self, query: &str) -> Result<Vec<Todo>, ClingsError> {
        match database::search_todos(query) {
            Ok(todos) => Ok(todos),
            Err(_) => self.search_jxa(query),
        }
    }

    /// Search todos by query using JXA (fallback).
    fn search_jxa(&self, query: &str) -> Result<Vec<Todo>, ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const query = {}.toLowerCase();
    const todos = Things.toDos().filter(t => {{
        const name = t.name().toLowerCase();
        const notes = (t.notes() || '').toLowerCase();
        return name.includes(query) || notes.includes(query);
    }});
    return JSON.stringify(todos.map(t => {{
        let tags = [];
        try {{
            const tagNames = t.tagNames();
            if (tagNames && tagNames.length > 0) {{
                tags = tagNames.split(', ').filter(x => x.length > 0);
            }}
        }} catch(e) {{}}

        let dueDate = null;
        try {{
            const d = t.dueDate();
            if (d) dueDate = d.toISOString().split('T')[0];
        }} catch(e) {{}}

        return {{
            id: t.id(),
            name: t.name(),
            notes: t.notes() || '',
            status: t.status(),
            dueDate: dueDate,
            tags: tags,
            project: t.project() ? t.project().name() : null,
            area: t.area() ? t.area().name() : null,
            checklistItems: [],
            creationDate: t.creationDate() ? t.creationDate().toISOString() : null,
            modificationDate: t.modificationDate() ? t.modificationDate().toISOString() : null
        }};
    }}));
}})()"#,
            Self::js_string(query)
        );

        self.execute(&script)
    }

    /// Open Things to a specific view or item
    pub fn open(&self, target: &str) -> Result<(), ClingsError> {
        // Check if target is a list name or an ID
        let script = match target.to_lowercase().as_str() {
            "inbox" | "today" | "upcoming" | "anytime" | "someday" | "logbook" | "trash" => {
                format!(
                    r#"(() => {{
    const Things = Application('Things3');
    Things.activate();
    Things.show(Things.lists.byName('{}'));
}})()"#,
                    capitalize(target)
                )
            }
            _ => {
                // Assume it's an ID
                format!(
                    r#"(() => {{
    const Things = Application('Things3');
    Things.activate();
    const todo = Things.toDos.byId('{}');
    if (todo.exists()) {{
        Things.show(todo);
    }} else {{
        const project = Things.projects.byId('{}');
        if (project.exists()) {{
            Things.show(project);
        }} else {{
            throw new Error("Can't get item");
        }}
    }}
}})()"#,
                    target, target
                )
            }
        };

        self.execute_void(&script)
    }

    /// Update tags for a todo (adds to existing tags)
    pub fn update_todo_tags(&self, id: &str, tags: &str) -> Result<(), ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{}');
    if (!todo.exists()) throw new Error("Can't get todo");
    const currentTags = todo.tagNames() || '';
    const newTags = currentTags ? currentTags + ', ' + {} : {};
    todo.tagNames = newTags;
}})()"#,
            id,
            Self::js_string(tags),
            Self::js_string(tags)
        );

        self.execute_void(&script)
    }

    /// Move a todo to a list/project
    pub fn move_todo_to_list(&self, id: &str, list_name: &str) -> Result<(), ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{}');
    if (!todo.exists()) throw new Error("Can't get todo");
    const targetList = Things.lists.byName({});
    if (!targetList.exists()) {{
        const targetProject = Things.projects.whose({{ name: {} }})[0];
        if (targetProject) {{
            Things.move(todo, {{ to: targetProject }});
        }} else {{
            throw new Error("Can't find list or project");
        }}
    }} else {{
        Things.move(todo, {{ to: targetList }});
    }}
}})()"#,
            id,
            Self::js_string(list_name),
            Self::js_string(list_name)
        );

        self.execute_void(&script)
    }

    /// Update the due date for a todo
    pub fn update_todo_due(&self, id: &str, due_date: &str) -> Result<(), ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{}');
    if (!todo.exists()) throw new Error("Can't get todo");
    todo.dueDate = new Date('{}');
}})()"#,
            id, due_date
        );

        self.execute_void(&script)
    }

    /// Clear the due date for a todo
    pub fn clear_todo_due(&self, id: &str) -> Result<(), ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{}');
    if (!todo.exists()) throw new Error("Can't get todo");
    todo.dueDate = null;
}})()"#,
            id
        );

        self.execute_void(&script)
    }

    /// Move a todo to the Someday list
    pub fn move_to_someday(&self, id: &str) -> Result<(), ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{}');
    if (!todo.exists()) throw new Error("Can't get todo");
    const somedayList = Things.lists.byName('Someday');
    Things.move(todo, {{ to: somedayList }});
}})()"#,
            id
        );

        self.execute_void(&script)
    }

    /// Get a project by name.
    pub fn get_project_by_name(&self, name: &str) -> Result<Project, ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const projects = Things.projects.whose({{ name: {} }});
    if (projects.length === 0) throw new Error("Can't find project");
    const p = projects[0];

    let tags = [];
    try {{
        const tagNames = p.tagNames();
        if (tagNames && tagNames.length > 0) {{
            tags = tagNames.split(', ').filter(x => x.length > 0);
        }}
    }} catch(e) {{}}

    let dueDate = null;
    try {{
        const d = p.dueDate();
        if (d) dueDate = d.toISOString().split('T')[0];
    }} catch(e) {{}}

    return JSON.stringify({{
        id: p.id(),
        name: p.name(),
        notes: p.notes() || '',
        status: p.status(),
        area: p.area() ? p.area().name() : null,
        tags: tags,
        dueDate: dueDate,
        creationDate: p.creationDate() ? p.creationDate().toISOString() : null
    }});
}})()"#,
            Self::js_string(name)
        );

        self.execute(&script)
    }

    /// Get todos for a specific project by name.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    pub fn get_project_todos(&self, project_name: &str) -> Result<Vec<Todo>, ClingsError> {
        // Try to look up project ID and use database
        if let Ok(Some(project_id)) = database::lookup_project_id_by_name(project_name) {
            if let Ok(todos) = database::fetch_project_todos(&project_id) {
                return Ok(todos);
            }
        }
        // Fallback to JXA
        self.get_project_todos_jxa(project_name)
    }

    /// Get todos for a specific project using JXA (fallback).
    fn get_project_todos_jxa(&self, project_name: &str) -> Result<Vec<Todo>, ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const projects = Things.projects.whose({{ name: {} }});
    if (projects.length === 0) throw new Error("Can't find project");
    const project = projects[0];
    const todos = project.toDos();

    return JSON.stringify(todos.map(t => {{
        let tags = [];
        try {{
            const tagNames = t.tagNames();
            if (tagNames && tagNames.length > 0) {{
                tags = tagNames.split(', ').filter(x => x.length > 0);
            }}
        }} catch(e) {{}}

        let dueDate = null;
        try {{
            const d = t.dueDate();
            if (d) dueDate = d.toISOString().split('T')[0];
        }} catch(e) {{}}

        // Get checklist items (sub-todos)
        let checklistItems = [];
        try {{
            const items = t.toDoS();
            if (items && items.length > 0) {{
                checklistItems = items.map(i => ({{
                    name: i.name(),
                    completed: i.status() === 'completed'
                }}));
            }}
        }} catch(e) {{}}

        return {{
            id: t.id(),
            name: t.name(),
            notes: t.notes() || '',
            status: t.status(),
            dueDate: dueDate,
            tags: tags,
            project: project.name(),
            area: t.area() ? t.area().name() : null,
            checklistItems: checklistItems,
            creationDate: t.creationDate() ? t.creationDate().toISOString() : null,
            modificationDate: t.modificationDate() ? t.modificationDate().toISOString() : null
        }};
    }}));
}})()"#,
            Self::js_string(project_name)
        );

        self.execute(&script)
    }

    /// Get headings from a project.
    ///
    /// Returns a list of (heading_name, [todo_names]) tuples.
    pub fn get_project_headings(
        &self,
        project_name: &str,
    ) -> Result<Vec<(String, Vec<String>)>, ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const projects = Things.projects.whose({{ name: {} }});
    if (projects.length === 0) throw new Error("Can't find project");
    const project = projects[0];

    // Get all headings
    const headings = [];
    try {{
        const projectHeadings = project.headings();
        for (const h of projectHeadings) {{
            const todos = h.toDos().map(t => t.name());
            headings.push({{
                name: h.name(),
                todos: todos
            }});
        }}
    }} catch(e) {{}}

    return JSON.stringify(headings);
}})()"#,
            Self::js_string(project_name)
        );

        #[derive(serde::Deserialize)]
        struct HeadingData {
            name: String,
            todos: Vec<String>,
        }

        let headings: Vec<HeadingData> = self.execute(&script)?;
        Ok(headings.into_iter().map(|h| (h.name, h.todos)).collect())
    }

    /// Create a project with headings and todos.
    ///
    /// This creates the project, then adds headings and todos to it.
    pub fn create_project_with_structure(
        &self,
        name: &str,
        notes: Option<&str>,
        area: Option<&str>,
        tags: Option<&[String]>,
        headings: &[(String, Vec<(String, Option<String>, Option<&str>, Vec<String>)>)],
        root_todos: &[(String, Option<String>, Option<&str>, Vec<String>)],
    ) -> Result<CreateResponse, ClingsError> {
        // First create the project
        let response = self.add_project(name, notes, area, tags, None)?;
        let project_id = &response.id;

        // Add root-level todos
        for (title, notes, due, todo_tags) in root_todos {
            self.add_todo_to_project(
                project_id,
                title,
                notes.as_deref(),
                due.as_deref(),
                Some(todo_tags),
            )?;
        }

        // Add headings with their todos
        for (heading_name, todos) in headings {
            self.add_heading_to_project(project_id, heading_name)?;

            for (title, notes, due, todo_tags) in todos {
                self.add_todo_to_heading(
                    project_id,
                    heading_name,
                    title,
                    notes.as_deref(),
                    due.as_deref(),
                    Some(todo_tags),
                )?;
            }
        }

        Ok(response)
    }

    /// Add a heading to a project.
    fn add_heading_to_project(&self, project_id: &str, heading_name: &str) -> Result<(), ClingsError> {
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const project = Things.projects.byId('{}');
    if (!project.exists()) throw new Error("Can't find project");
    Things.make({{ new: 'heading', withProperties: {{ name: {} }}, at: project }});
}})()"#,
            project_id,
            Self::js_string(heading_name)
        );

        self.execute_void(&script)
    }

    /// Add a todo to a project (at root level).
    fn add_todo_to_project(
        &self,
        project_id: &str,
        title: &str,
        notes: Option<&str>,
        due_date: Option<&str>,
        tags: Option<&[String]>,
    ) -> Result<(), ClingsError> {
        let notes_js = notes
            .map(|n| format!("props.notes = {};", Self::js_string(n)))
            .unwrap_or_default();

        let due_js = due_date
            .map(|d| format!("props.dueDate = new Date('{}');", d))
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("props.tagNames = {};", Self::js_string(&t.join(", "))))
            .unwrap_or_default();

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
            Self::js_string(title),
            notes_js,
            due_js,
            tags_js
        );

        self.execute_void(&script)
    }

    /// Add a todo under a heading in a project.
    fn add_todo_to_heading(
        &self,
        project_id: &str,
        heading_name: &str,
        title: &str,
        notes: Option<&str>,
        due_date: Option<&str>,
        tags: Option<&[String]>,
    ) -> Result<(), ClingsError> {
        let notes_js = notes
            .map(|n| format!("props.notes = {};", Self::js_string(n)))
            .unwrap_or_default();

        let due_js = due_date
            .map(|d| format!("props.dueDate = new Date('{}');", d))
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("props.tagNames = {};", Self::js_string(&t.join(", "))))
            .unwrap_or_default();

        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const project = Things.projects.byId('{}');
    if (!project.exists()) throw new Error("Can't find project");

    // Find the heading
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
            Self::js_string(heading_name),
            Self::js_string(title),
            notes_js,
            due_js,
            tags_js
        );

        self.execute_void(&script)
    }

    /// Get all open todos.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    pub fn get_all_todos(&self) -> Result<Vec<Todo>, ClingsError> {
        match database::fetch_all_todos() {
            Ok(todos) => Ok(todos),
            Err(_) => self.get_all_todos_jxa(),
        }
    }

    /// Get all todos using JXA (fallback).
    fn get_all_todos_jxa(&self) -> Result<Vec<Todo>, ClingsError> {
        let script = r#"(() => {
    const Things = Application('Things3');
    const todos = Things.toDos();
    return JSON.stringify(todos.map(t => {
        let tags = [];
        try {
            const tagNames = t.tagNames();
            if (tagNames && tagNames.length > 0) {
                tags = tagNames.split(', ').filter(x => x.length > 0);
            }
        } catch(e) {}

        let dueDate = null;
        try {
            const d = t.dueDate();
            if (d) dueDate = d.toISOString().split('T')[0];
        } catch(e) {}

        return {
            id: t.id(),
            name: t.name(),
            notes: t.notes() || '',
            status: t.status(),
            dueDate: dueDate,
            tags: tags,
            project: t.project() ? t.project().name() : null,
            area: t.area() ? t.area().name() : null,
            checklistItems: [],
            creationDate: t.creationDate() ? t.creationDate().toISOString() : null,
            modificationDate: t.modificationDate() ? t.modificationDate().toISOString() : null
        };
    }));
})()"#;

        self.execute(script)
    }

    // =========================================================================
    // Batch Operations - Execute multiple operations in a single JXA call
    // =========================================================================

    /// Mark multiple todos as complete in a single JXA call.
    ///
    /// Returns the number of todos successfully completed.
    pub fn complete_todos_batch(&self, ids: &[String]) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const ids = {};
    let succeeded = 0;
    let failed = 0;
    const errors = [];

    for (const id of ids) {{
        try {{
            const todo = Things.toDos.byId(id);
            if (todo.exists()) {{
                todo.status = 'completed';
                succeeded++;
            }} else {{
                failed++;
                errors.push({{ id: id, error: 'Not found' }});
            }}
        }} catch (e) {{
            failed++;
            errors.push({{ id: id, error: e.message }});
        }}
    }}

    return JSON.stringify({{ succeeded, failed, errors }});
}})()"#,
            ids_array
        );

        self.execute(&script)
    }

    /// Mark multiple todos as canceled in a single JXA call.
    ///
    /// Returns the number of todos successfully canceled.
    pub fn cancel_todos_batch(&self, ids: &[String]) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const ids = {};
    let succeeded = 0;
    let failed = 0;
    const errors = [];

    for (const id of ids) {{
        try {{
            const todo = Things.toDos.byId(id);
            if (todo.exists()) {{
                todo.status = 'canceled';
                succeeded++;
            }} else {{
                failed++;
                errors.push({{ id: id, error: 'Not found' }});
            }}
        }} catch (e) {{
            failed++;
            errors.push({{ id: id, error: e.message }});
        }}
    }}

    return JSON.stringify({{ succeeded, failed, errors }});
}})()"#,
            ids_array
        );

        self.execute(&script)
    }

    /// Add tags to multiple todos in a single JXA call.
    ///
    /// The tags are appended to any existing tags on each todo.
    pub fn add_tags_batch(&self, ids: &[String], tags: &[String]) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let tags_str = Self::js_string(&tags.join(", "));
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const ids = {};
    const newTags = {};
    let succeeded = 0;
    let failed = 0;
    const errors = [];

    for (const id of ids) {{
        try {{
            const todo = Things.toDos.byId(id);
            if (todo.exists()) {{
                const currentTags = todo.tagNames() || '';
                todo.tagNames = currentTags ? currentTags + ', ' + newTags : newTags;
                succeeded++;
            }} else {{
                failed++;
                errors.push({{ id: id, error: 'Not found' }});
            }}
        }} catch (e) {{
            failed++;
            errors.push({{ id: id, error: e.message }});
        }}
    }}

    return JSON.stringify({{ succeeded, failed, errors }});
}})()"#,
            ids_array, tags_str
        );

        self.execute(&script)
    }

    /// Move multiple todos to a project in a single JXA call.
    pub fn move_todos_batch(&self, ids: &[String], project_name: &str) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const ids = {};
    let succeeded = 0;
    let failed = 0;
    const errors = [];

    // Find target project
    const projects = Things.projects.whose({{ name: {} }});
    if (projects.length === 0) {{
        return JSON.stringify({{ succeeded: 0, failed: ids.length, errors: [{{ id: 'all', error: 'Project not found' }}] }});
    }}
    const targetProject = projects[0];

    for (const id of ids) {{
        try {{
            const todo = Things.toDos.byId(id);
            if (todo.exists()) {{
                Things.move(todo, {{ to: targetProject }});
                succeeded++;
            }} else {{
                failed++;
                errors.push({{ id: id, error: 'Not found' }});
            }}
        }} catch (e) {{
            failed++;
            errors.push({{ id: id, error: e.message }});
        }}
    }}

    return JSON.stringify({{ succeeded, failed, errors }});
}})()"#,
            ids_array,
            Self::js_string(project_name)
        );

        self.execute(&script)
    }

    /// Set due date for multiple todos in a single JXA call.
    pub fn update_todos_due_batch(&self, ids: &[String], due_date: &str) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const ids = {};
    const dueDate = new Date('{}');
    let succeeded = 0;
    let failed = 0;
    const errors = [];

    for (const id of ids) {{
        try {{
            const todo = Things.toDos.byId(id);
            if (todo.exists()) {{
                todo.dueDate = dueDate;
                succeeded++;
            }} else {{
                failed++;
                errors.push({{ id: id, error: 'Not found' }});
            }}
        }} catch (e) {{
            failed++;
            errors.push({{ id: id, error: e.message }});
        }}
    }}

    return JSON.stringify({{ succeeded, failed, errors }});
}})()"#,
            ids_array, due_date
        );

        self.execute(&script)
    }

    /// Clear due date for multiple todos in a single JXA call.
    pub fn clear_todos_due_batch(&self, ids: &[String]) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let script = format!(
            r#"(() => {{
    const Things = Application('Things3');
    const ids = {};
    let succeeded = 0;
    let failed = 0;
    const errors = [];

    for (const id of ids) {{
        try {{
            const todo = Things.toDos.byId(id);
            if (todo.exists()) {{
                todo.dueDate = null;
                succeeded++;
            }} else {{
                failed++;
                errors.push({{ id: id, error: 'Not found' }});
            }}
        }} catch (e) {{
            failed++;
            errors.push({{ id: id, error: e.message }});
        }}
    }}

    return JSON.stringify({{ succeeded, failed, errors }});
}})()"#,
            ids_array
        );

        self.execute(&script)
    }

    /// Get todos from all list views in a single JXA call.
    ///
    /// This is more efficient than calling `get_list()` multiple times
    /// for stats collection.
    ///
    /// The Logbook is limited to the 500 most recent completions for
    /// performance, as full Logbook history can contain thousands of items.
    pub fn get_all_lists(&self) -> Result<AllListsResult, ClingsError> {
        let script = r#"(() => {
    const Things = Application('Things3');

    function mapTodo(t) {
        let tags = [];
        try {
            const tagNames = t.tagNames();
            if (tagNames && tagNames.length > 0) {
                tags = tagNames.split(', ').filter(x => x.length > 0);
            }
        } catch(e) {}

        let dueDate = null;
        try {
            const d = t.dueDate();
            if (d) dueDate = d.toISOString().split('T')[0];
        } catch(e) {}

        return {
            id: t.id(),
            name: t.name(),
            notes: t.notes() || '',
            status: t.status(),
            dueDate: dueDate,
            tags: tags,
            project: t.project() ? t.project().name() : null,
            area: t.area() ? t.area().name() : null,
            checklistItems: [],
            creationDate: t.creationDate() ? t.creationDate().toISOString() : null,
            modificationDate: t.modificationDate() ? t.modificationDate().toISOString() : null
        };
    }

    const result = {
        inbox: [],
        today: [],
        upcoming: [],
        anytime: [],
        someday: [],
        logbook: []
    };

    // Fetch regular lists (these are typically small)
    const regularLists = ['Inbox', 'Today', 'Upcoming', 'Anytime', 'Someday'];
    for (const listName of regularLists) {
        try {
            const list = Things.lists.byName(listName);
            const todos = list.toDos();
            result[listName.toLowerCase()] = todos.map(mapTodo);
        } catch(e) {}
    }

    // Fetch Logbook with a limit for performance
    // The Logbook is sorted with most recent first, so we get the 500 most recent
    try {
        const logbook = Things.lists.byName('Logbook');
        const todos = logbook.toDos();
        const limit = Math.min(todos.length, 500);
        const recentTodos = [];
        for (let i = 0; i < limit; i++) {
            recentTodos.push(mapTodo(todos[i]));
        }
        result.logbook = recentTodos;
    } catch(e) {}

    return JSON.stringify(result);
})()"#;

        self.execute(script)
    }

    /// Get todos from open list views in a single JXA call.
    ///
    /// This excludes the Logbook for better performance. Use `get_all_lists()`
    /// when you need completed todos, or access the database directly for
    /// large Logbooks.
    pub fn get_open_lists(&self) -> Result<OpenListsResult, ClingsError> {
        let script = r#"(() => {
    const Things = Application('Things3');

    function mapTodo(t) {
        let tags = [];
        try {
            const tagNames = t.tagNames();
            if (tagNames && tagNames.length > 0) {
                tags = tagNames.split(', ').filter(x => x.length > 0);
            }
        } catch(e) {}

        let dueDate = null;
        try {
            const d = t.dueDate();
            if (d) dueDate = d.toISOString().split('T')[0];
        } catch(e) {}

        return {
            id: t.id(),
            name: t.name(),
            notes: t.notes() || '',
            status: t.status(),
            dueDate: dueDate,
            tags: tags,
            project: t.project() ? t.project().name() : null,
            area: t.area() ? t.area().name() : null,
            checklistItems: [],
            creationDate: t.creationDate() ? t.creationDate().toISOString() : null,
            modificationDate: t.modificationDate() ? t.modificationDate().toISOString() : null
        };
    }

    const result = {
        inbox: [],
        today: [],
        upcoming: [],
        anytime: [],
        someday: []
    };

    const lists = ['Inbox', 'Today', 'Upcoming', 'Anytime', 'Someday'];
    for (const listName of lists) {
        try {
            const list = Things.lists.byName(listName);
            const todos = list.toDos();
            result[listName.toLowerCase()] = todos.map(mapTodo);
        } catch(e) {}
    }

    return JSON.stringify(result);
})()"#;

        self.execute(script)
    }

    // =========================================================================
    // Helper methods
    // =========================================================================

    /// Escape a string for use in JavaScript
    fn js_string(s: &str) -> String {
        let escaped = s
            .replace('\\', "\\\\")
            .replace('\'', "\\'")
            .replace('\n', "\\n")
            .replace('\r', "\\r")
            .replace('\t', "\\t");
        format!("'{}'", escaped)
    }

    /// Convert a slice of strings to a JavaScript array literal
    fn js_string_array(items: &[String]) -> String {
        let escaped: Vec<String> = items.iter().map(|s| Self::js_string(s)).collect();
        format!("[{}]", escaped.join(", "))
    }
}

impl Default for ThingsClient {
    fn default() -> Self {
        Self::new()
    }
}

fn capitalize(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().chain(c).collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ==================== js_string Tests ====================

    #[test]
    fn test_js_string_simple() {
        assert_eq!(ThingsClient::js_string("hello"), "'hello'");
    }

    #[test]
    fn test_js_string_with_single_quote() {
        assert_eq!(ThingsClient::js_string("it's"), "'it\\'s'");
    }

    #[test]
    fn test_js_string_with_backslash() {
        assert_eq!(ThingsClient::js_string("back\\slash"), "'back\\\\slash'");
    }

    #[test]
    fn test_js_string_with_newline() {
        assert_eq!(ThingsClient::js_string("line1\nline2"), "'line1\\nline2'");
    }

    #[test]
    fn test_js_string_with_carriage_return() {
        assert_eq!(ThingsClient::js_string("line1\rline2"), "'line1\\rline2'");
    }

    #[test]
    fn test_js_string_with_tab() {
        assert_eq!(ThingsClient::js_string("col1\tcol2"), "'col1\\tcol2'");
    }

    #[test]
    fn test_js_string_empty() {
        assert_eq!(ThingsClient::js_string(""), "''");
    }

    #[test]
    fn test_js_string_complex() {
        // Test multiple escapes in one string
        assert_eq!(
            ThingsClient::js_string("it's a \"test\"\nwith\ttabs"),
            "'it\\'s a \"test\"\\nwith\\ttabs'"
        );
    }

    #[test]
    fn test_js_string_unicode() {
        // Unicode should pass through unchanged
        assert_eq!(ThingsClient::js_string("日本語"), "'日本語'");
    }

    // ==================== js_string_array Tests ====================

    #[test]
    fn test_js_string_array_empty() {
        let items: Vec<String> = vec![];
        assert_eq!(ThingsClient::js_string_array(&items), "[]");
    }

    #[test]
    fn test_js_string_array_single() {
        let items = vec!["hello".to_string()];
        assert_eq!(ThingsClient::js_string_array(&items), "['hello']");
    }

    #[test]
    fn test_js_string_array_multiple() {
        let items = vec!["one".to_string(), "two".to_string(), "three".to_string()];
        assert_eq!(ThingsClient::js_string_array(&items), "['one', 'two', 'three']");
    }

    #[test]
    fn test_js_string_array_with_escapes() {
        let items = vec!["it's".to_string(), "a\ntest".to_string()];
        assert_eq!(ThingsClient::js_string_array(&items), "['it\\'s', 'a\\ntest']");
    }

    // ==================== capitalize Tests ====================

    #[test]
    fn test_capitalize_lowercase() {
        assert_eq!(capitalize("hello"), "Hello");
    }

    #[test]
    fn test_capitalize_already_uppercase() {
        assert_eq!(capitalize("Hello"), "Hello");
    }

    #[test]
    fn test_capitalize_all_uppercase() {
        assert_eq!(capitalize("HELLO"), "HELLO");
    }

    #[test]
    fn test_capitalize_empty() {
        assert_eq!(capitalize(""), "");
    }

    #[test]
    fn test_capitalize_single_char() {
        assert_eq!(capitalize("a"), "A");
        assert_eq!(capitalize("A"), "A");
    }

    #[test]
    fn test_capitalize_unicode() {
        // Unicode capitalization
        assert_eq!(capitalize("ñoño"), "Ñoño");
    }

    // ==================== ThingsClient Default ====================

    #[test]
    fn test_client_default() {
        let client = ThingsClient::default();
        // Client should be created without panicking
        let _ = client;
    }

    #[test]
    fn test_client_new() {
        let client = ThingsClient::new();
        // Client should be created without panicking
        let _ = client;
    }

    // ==================== BatchResult with Empty IDs ====================

    #[test]
    fn test_complete_todos_batch_empty_returns_default() {
        let client = ThingsClient::new();
        let ids: Vec<String> = vec![];
        let result = client.complete_todos_batch(&ids).unwrap();
        assert_eq!(result.succeeded, 0);
        assert_eq!(result.failed, 0);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn test_cancel_todos_batch_empty_returns_default() {
        let client = ThingsClient::new();
        let ids: Vec<String> = vec![];
        let result = client.cancel_todos_batch(&ids).unwrap();
        assert_eq!(result.succeeded, 0);
        assert_eq!(result.failed, 0);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn test_add_tags_batch_empty_returns_default() {
        let client = ThingsClient::new();
        let ids: Vec<String> = vec![];
        let tags = vec!["tag1".to_string()];
        let result = client.add_tags_batch(&ids, &tags).unwrap();
        assert_eq!(result.succeeded, 0);
        assert_eq!(result.failed, 0);
    }

    #[test]
    fn test_move_todos_batch_empty_returns_default() {
        let client = ThingsClient::new();
        let ids: Vec<String> = vec![];
        let result = client.move_todos_batch(&ids, "Project").unwrap();
        assert_eq!(result.succeeded, 0);
        assert_eq!(result.failed, 0);
    }

    #[test]
    fn test_update_todos_due_batch_empty_returns_default() {
        let client = ThingsClient::new();
        let ids: Vec<String> = vec![];
        let result = client.update_todos_due_batch(&ids, "2024-12-15").unwrap();
        assert_eq!(result.succeeded, 0);
        assert_eq!(result.failed, 0);
    }

    #[test]
    fn test_clear_todos_due_batch_empty_returns_default() {
        let client = ThingsClient::new();
        let ids: Vec<String> = vec![];
        let result = client.clear_todos_due_batch(&ids).unwrap();
        assert_eq!(result.succeeded, 0);
        assert_eq!(result.failed, 0);
    }

    // ==================== ListView Tests ====================

    #[test]
    fn test_listview_as_str_variants() {
        assert_eq!(ListView::Inbox.as_str(), "Inbox");
        assert_eq!(ListView::Today.as_str(), "Today");
        assert_eq!(ListView::Upcoming.as_str(), "Upcoming");
        assert_eq!(ListView::Anytime.as_str(), "Anytime");
        assert_eq!(ListView::Someday.as_str(), "Someday");
        assert_eq!(ListView::Logbook.as_str(), "Logbook");
        assert_eq!(ListView::Trash.as_str(), "Trash");
    }
}
