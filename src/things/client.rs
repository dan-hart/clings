use std::process::Command;

use serde::de::DeserializeOwned;

use crate::error::ClingsError;
use crate::things::database;
use crate::things::types::{
    AllListsResult, Area, BatchResult, CreateResponse, ListView, OpenListsResult, Project, Tag,
    Todo,
};

/// Type alias for todo tuples used in project structure creation.
pub type TodoTuple = (String, Option<String>, Option<String>, Vec<String>);

/// Type alias for heading tuples used in project structure creation.
pub type HeadingTuple = (String, Vec<TodoTuple>);

#[derive(Clone)]
pub struct ThingsClient;

impl ThingsClient {
    #[must_use]
    pub const fn new() -> Self {
        Self
    }

    /// Execute a JXA script and parse the JSON result
    ///
    /// # Errors
    ///
    /// Returns an error if the script execution fails, Things 3 is not running,
    /// or the JSON parsing fails.
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
    ///
    /// # Errors
    ///
    /// Returns an error if the script execution fails or Things 3 is not running.
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
    ///
    /// # Errors
    ///
    /// Returns an error if both database and JXA methods fail.
    pub fn get_list(&self, view: ListView) -> Result<Vec<Todo>, ClingsError> {
        // Try database first for better performance
        database::fetch_list(view).or_else(|_| self.get_list_jxa(view))
    }

    /// Get todos from a specific list view using JXA (fallback).
    fn get_list_jxa(&self, view: ListView) -> Result<Vec<Todo>, ClingsError> {
        let script = format!(
            r"(() => {{
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
}})()",
            view.as_str()
        );

        self.execute(&script)
    }

    /// Get a specific todo by ID.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    ///
    /// # Errors
    ///
    /// Returns an error if the todo is not found or cannot be accessed.
    pub fn get_todo(&self, id: &str) -> Result<Todo, ClingsError> {
        // Try database first for better performance
        database::fetch_todo(id).or_else(|_| self.get_todo_jxa(id))
    }

    /// Get a specific todo by ID using JXA (fallback).
    fn get_todo_jxa(&self, id: &str) -> Result<Todo, ClingsError> {
        let id_str = Self::js_string(id);
        let script = format!(
            r"(() {{
    const Things = Application('Things3');
    const t = Things.toDos.byId({id_str});
    if (!t.exists()) throw new Error('Can\'t get todo');

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
}})()"
        );

        self.execute(&script)
    }

    /// Add a new todo
    ///
    /// # Arguments
    ///
    /// * `title` - The todo title
    /// * `notes` - Optional notes
    /// * `when_date` - Optional scheduling date (appears in Today/Upcoming)
    /// * `deadline` - Optional deadline/due date
    /// * `tags` - Optional tags
    /// * `list` - Optional project/list name to move todo into
    /// * `area` - Optional area name (ignored if list is specified)
    /// * `checklist` - Optional checklist items
    ///
    /// # Errors
    ///
    /// Returns an error if todo creation fails or Things 3 is not running.
    #[allow(clippy::too_many_arguments)]
    pub fn add_todo(
        &self,
        title: &str,
        notes: Option<&str>,
        when_date: Option<&str>,
        deadline: Option<&str>,
        tags: Option<&[String]>,
        list: Option<&str>,
        area: Option<&str>,
        checklist: Option<&[String]>,
    ) -> Result<CreateResponse, ClingsError> {
        let notes_js = notes
            .map(|n| format!("props.notes = {};", Self::js_string(n)))
            .unwrap_or_default();

        // Deadline sets the due date property
        let deadline_js = deadline
            .map(|d| {
                let date_str = Self::js_string(d);
                format!("props.dueDate = new Date({date_str});")
            })
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("props.tagNames = {};", Self::js_string(&t.join(", "))))
            .unwrap_or_default();

        // Schedule command sets when the todo appears in Today/Upcoming
        let schedule_js = when_date
            .map(|d| {
                let date_str = Self::js_string(d);
                format!(
                    r"
    Things.schedule(todo, {{ for: new Date({date_str}) }});"
                )
            })
            .unwrap_or_default();

        // Project/list assignment - try lists first, then fall back to projects.whose()
        // This handles both built-in lists and projects (including names with emoji)
        let list_js = list
            .map(|l| {
                let list_name = Self::js_string(l);
                format!(
                    r"
    const targetList = Things.lists.byName({list_name});
    if (targetList.exists()) {{
        Things.move(todo, {{ to: targetList }});
    }} else {{
        const targetProject = Things.projects.whose({{ name: {list_name} }})[0];
        if (targetProject) {{
            Things.move(todo, {{ to: targetProject }});
        }}
    }}"
                )
            })
            .unwrap_or_default();

        // Area assignment - set on todo AFTER make() to avoid -1700 type conversion error
        // Works alongside project assignment (area and project are independent)
        let area_js = area
            .map(|a| {
                let area_name = Self::js_string(a);
                format!(
                    r"
    const targetArea = Things.areas.byName({area_name});
    if (targetArea.exists()) {{
        todo.area = targetArea;
    }}"
                )
            })
            .unwrap_or_default();

        let checklist_js = checklist
            .map(|items| {
                let items_str: Vec<String> = items.iter().map(|i| Self::js_string(i)).collect();
                let items_joined = items_str.join(", ");
                format!(
                    r"
    const checklistItems = [{items_joined}];
    for (const item of checklistItems) {{
        Things.make({{ new: 'toDo', withProperties: {{ name: item }}, at: todo }});
    }}"
                )
            })
            .unwrap_or_default();

        let title_str = Self::js_string(title);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const props = {{ name: {title_str} }};
    {notes_js}
    {deadline_js}
    {tags_js}
    const todo = Things.make({{ new: 'toDo', withProperties: props }});
    {area_js}
    {schedule_js}
    {list_js}
    {checklist_js}
    return JSON.stringify({{ id: todo.id(), name: todo.name() }});
}})()"
        );

        self.execute(&script)
    }

    /// Mark a todo as complete
    ///
    /// # Errors
    ///
    /// Returns an error if the todo is not found or cannot be updated.
    pub fn complete_todo(&self, id: &str) -> Result<(), ClingsError> {
        let id_str = Self::js_string(id);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId({id_str});
    if (!todo.exists()) throw new Error('Can\'t get todo');
    todo.status = 'completed';
}})()"
        );

        self.execute_void(&script)
    }

    /// Mark a todo as canceled
    ///
    /// # Errors
    ///
    /// Returns an error if the todo is not found or cannot be updated.
    pub fn cancel_todo(&self, id: &str) -> Result<(), ClingsError> {
        let id_str = Self::js_string(id);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId({id_str});
    if (!todo.exists()) throw new Error('Can\'t get todo');
    todo.status = 'canceled';
}})()"
        );

        self.execute_void(&script)
    }

    /// Delete a todo (cancel it - Things 3 `AppleScript` doesn't support true deletion)
    ///
    /// # Errors
    ///
    /// Returns an error if the todo is not found or cannot be canceled.
    pub fn delete_todo(&self, id: &str) -> Result<(), ClingsError> {
        // Note: Things 3 AppleScript API doesn't support moving items to trash.
        // This cancels the todo instead. Use the Things app to permanently delete.
        self.cancel_todo(id)
    }

    /// Get all projects.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    ///
    /// # Errors
    ///
    /// Returns an error if projects cannot be fetched.
    pub fn get_projects(&self) -> Result<Vec<Project>, ClingsError> {
        database::fetch_projects().or_else(|_| self.get_projects_jxa())
    }

    /// Get all projects using JXA (fallback).
    fn get_projects_jxa(&self) -> Result<Vec<Project>, ClingsError> {
        let script = r"(() => {
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
})()";

        self.execute(script)
    }

    /// Add a new project
    ///
    /// # Errors
    ///
    /// Returns an error if project creation fails or Things 3 is not running.
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
            .map(|d| {
                let date_str = Self::js_string(d);
                format!("props.dueDate = new Date({date_str});")
            })
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("props.tagNames = {};", Self::js_string(&t.join(", "))))
            .unwrap_or_default();

        let area_js = area
            .map(|a| {
                let area_name = Self::js_string(a);
                format!(
                    r"
    const targetArea = Things.areas.byName({area_name});
    if (targetArea.exists()) {{
        project.area = targetArea;
    }}"
                )
            })
            .unwrap_or_default();

        let title_str = Self::js_string(title);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const props = {{ name: {title_str} }};
    {notes_js}
    {due_js}
    {tags_js}
    const project = Things.make({{ new: 'project', withProperties: props }});
    {area_js}
    return JSON.stringify({{ id: project.id(), name: project.name() }});
}})()"
        );

        self.execute(&script)
    }

    /// Get all areas.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    ///
    /// # Errors
    ///
    /// Returns an error if areas cannot be fetched.
    pub fn get_areas(&self) -> Result<Vec<Area>, ClingsError> {
        database::fetch_areas().or_else(|_| self.get_areas_jxa())
    }

    /// Get all areas using JXA (fallback).
    fn get_areas_jxa(&self) -> Result<Vec<Area>, ClingsError> {
        let script = r"(() => {
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
})()";

        self.execute(script)
    }

    /// Get all tags.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    ///
    /// # Errors
    ///
    /// Returns an error if tags cannot be fetched.
    pub fn get_tags(&self) -> Result<Vec<Tag>, ClingsError> {
        database::fetch_tags().or_else(|_| self.get_tags_jxa())
    }

    /// Get all tags using JXA (fallback).
    fn get_tags_jxa(&self) -> Result<Vec<Tag>, ClingsError> {
        let script = r"(() => {
    const Things = Application('Things3');
    const tags = Things.tags();
    return JSON.stringify(tags.map(t => ({
        id: t.id(),
        name: t.name()
    })));
})()";

        self.execute(script)
    }

    /// Search todos by query.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    ///
    /// # Errors
    ///
    /// Returns an error if the search fails.
    pub fn search(&self, query: &str) -> Result<Vec<Todo>, ClingsError> {
        database::search_todos(query).or_else(|_| self.search_jxa(query))
    }

    /// Search todos by query using JXA (fallback).
    fn search_jxa(&self, query: &str) -> Result<Vec<Todo>, ClingsError> {
        let query_str = Self::js_string(query);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const query = {query_str}.toLowerCase();
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
}})()"
        );

        self.execute(&script)
    }

    /// Open Things to a specific view or item
    ///
    /// # Errors
    ///
    /// Returns an error if Things 3 cannot be opened or the target is not found.
    pub fn open(&self, target: &str) -> Result<(), ClingsError> {
        // Check if target is a list name or an ID
        let script = match target.to_lowercase().as_str() {
            "inbox" | "today" | "upcoming" | "anytime" | "someday" | "logbook" | "trash" => {
                let cap_target = Self::js_string(&capitalize(target));
                format!(
                    r"(() => {{
    const Things = Application('Things3');
    Things.activate();
    Things.show(Things.lists.byName({cap_target}));
}})()"
                )
            },
            _ => {
                // Assume it's an ID
                let target_str = Self::js_string(target);
                format!(
                    r"(() => {{
    const Things = Application('Things3');
    Things.activate();
    const todo = Things.toDos.byId({target_str});
    if (todo.exists()) {{
        Things.show(todo);
    }} else {{
        const project = Things.projects.byId({target_str});
        if (project.exists()) {{
            Things.show(project);
        }} else {{
            throw new Error('Can\'t get item');
        }}
    }}
}})()"
                )
            },
        };

        self.execute_void(&script)
    }

    /// Update tags for a todo (adds to existing tags)
    ///
    /// # Errors
    ///
    /// Returns an error if the todo is not found or cannot be updated.
    pub fn update_todo_tags(&self, id: &str, tags: &str) -> Result<(), ClingsError> {
        let tags_str = Self::js_string(tags);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{id}');
    if (!todo.exists()) throw new Error('Can\'t get todo');
    const currentTags = todo.tagNames() || '';
    const newTags = currentTags ? currentTags + ', ' + {tags_str} : {tags_str};
    todo.tagNames = newTags;
}})()"
        );

        self.execute_void(&script)
    }

    /// Move a todo to a list/project
    ///
    /// # Errors
    ///
    /// Returns an error if the todo or list is not found.
    pub fn move_todo_to_list(&self, id: &str, list_name: &str) -> Result<(), ClingsError> {
        let list_str = Self::js_string(list_name);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{id}');
    if (!todo.exists()) throw new Error('Can\'t get todo');
    const targetList = Things.lists.byName({list_str});
    if (!targetList.exists()) {{
        const targetProject = Things.projects.whose({{ name: {list_str} }})[0];
        if (targetProject) {{
            Things.move(todo, {{ to: targetProject }});
        }} else {{
            throw new Error('Can\'t find list or project');
        }}
    }} else {{
        Things.move(todo, {{ to: targetList }});
    }}
}})()"
        );

        self.execute_void(&script)
    }

    /// Update the due date for a todo
    ///
    /// # Errors
    ///
    /// Returns an error if the todo is not found or cannot be updated.
    pub fn update_todo_due(&self, id: &str, due_date: &str) -> Result<(), ClingsError> {
        let id_str = Self::js_string(id);
        let date_str = Self::js_string(due_date);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId({id_str});
    if (!todo.exists()) throw new Error('Can\'t get todo');
    todo.dueDate = new Date({date_str});
}})()"
        );

        self.execute_void(&script)
    }

    /// Clear the due date for a todo
    ///
    /// # Errors
    ///
    /// Returns an error if the todo is not found or cannot be updated.
    pub fn clear_todo_due(&self, id: &str) -> Result<(), ClingsError> {
        let id_str = Self::js_string(id);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId({id_str});
    if (!todo.exists()) throw new Error('Can\'t get todo');
    todo.dueDate = null;
}})()"
        );

        self.execute_void(&script)
    }

    /// Move a todo to the Someday list
    ///
    /// # Errors
    ///
    /// Returns an error if the todo is not found or cannot be moved.
    pub fn move_to_someday(&self, id: &str) -> Result<(), ClingsError> {
        let id_str = Self::js_string(id);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId({id_str});
    if (!todo.exists()) throw new Error('Can\'t get todo');
    const somedayList = Things.lists.byName('Someday');
    Things.move(todo, {{ to: somedayList }});
}})()"
        );

        self.execute_void(&script)
    }

    /// Update a todo's properties
    ///
    /// Only specified fields are updated; None values are skipped.
    ///
    /// # Errors
    ///
    /// Returns an error if the todo is not found or cannot be updated.
    #[allow(clippy::too_many_arguments)]
    pub fn update_todo(
        &self,
        id: &str,
        title: Option<&str>,
        notes: Option<&str>,
        when_date: Option<&str>,
        deadline: Option<&str>,
        tags: Option<&str>,
        project: Option<&str>,
        area: Option<&str>,
    ) -> Result<(), ClingsError> {
        let id_str = Self::js_string(id);

        let title_js = title
            .map(|t| format!("todo.name = {};", Self::js_string(t)))
            .unwrap_or_default();

        let notes_js = notes
            .map(|n| format!("todo.notes = {};", Self::js_string(n)))
            .unwrap_or_default();

        let deadline_js = deadline
            .map(|d| {
                let date_str = Self::js_string(d);
                format!("todo.dueDate = new Date({date_str});")
            })
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("todo.tagNames = {};", Self::js_string(t)))
            .unwrap_or_default();

        let schedule_js = when_date
            .map(|d| {
                let date_str = Self::js_string(d);
                format!("Things.schedule(todo, {{ for: new Date({date_str}) }});")
            })
            .unwrap_or_default();

        // Project/list assignment - try lists first, then fall back to projects.whose()
        let project_js = project
            .map(|p| {
                let proj_name = Self::js_string(p);
                format!(
                    r"
    const targetList = Things.lists.byName({proj_name});
    if (targetList.exists()) {{
        Things.move(todo, {{ to: targetList }});
    }} else {{
        const targetProject = Things.projects.whose({{ name: {proj_name} }})[0];
        if (targetProject) {{
            Things.move(todo, {{ to: targetProject }});
        }}
    }}"
                )
            })
            .unwrap_or_default();

        // Area assignment - set directly on todo object
        let area_js = area
            .map(|a| {
                let area_name = Self::js_string(a);
                format!(
                    r"
    const targetArea = Things.areas.byName({area_name});
    if (targetArea.exists()) {{
        todo.area = targetArea;
    }}"
                )
            })
            .unwrap_or_default();

        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId({id_str});
    if (!todo.exists()) throw new Error('Can\'t get todo');
    {title_js}
    {notes_js}
    {deadline_js}
    {tags_js}
    {schedule_js}
    {project_js}
    {area_js}
}})()"
        );

        self.execute_void(&script)
    }

    /// Get a project by name.
    ///
    /// # Errors
    ///
    /// Returns an error if the project is not found.
    pub fn get_project_by_name(&self, name: &str) -> Result<Project, ClingsError> {
        let name_str = Self::js_string(name);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const projects = Things.projects.whose({{ name: {name_str} }});
    if (projects.length === 0) throw new Error('Can\'t find project');
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
}})()"
        );

        self.execute(&script)
    }

    /// Get todos for a specific project by name.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    ///
    /// # Errors
    ///
    /// Returns an error if the project is not found or todos cannot be fetched.
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
        let proj_name = Self::js_string(project_name);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const projects = Things.projects.whose({{ name: {proj_name} }});
    if (projects.length === 0) throw new Error('Can\'t find project');
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
}})()"
        );

        self.execute(&script)
    }

    /// Get headings from a project.
    ///
    /// Returns a list of `(heading_name, [todo_names])` tuples.
    ///
    /// # Errors
    ///
    /// Returns an error if the project is not found or headings cannot be fetched.
    pub fn get_project_headings(
        &self,
        project_name: &str,
    ) -> Result<Vec<(String, Vec<String>)>, ClingsError> {
        #[derive(serde::Deserialize)]
        struct HeadingData {
            name: String,
            todos: Vec<String>,
        }

        let proj_name = Self::js_string(project_name);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const projects = Things.projects.whose({{ name: {proj_name} }});
    if (projects.length === 0) throw new Error('Can\'t find project');
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
}})()"
        );

        let headings: Vec<HeadingData> = self.execute(&script)?;
        Ok(headings.into_iter().map(|h| (h.name, h.todos)).collect())
    }

    /// Create a project with headings and todos.
    ///
    /// This creates the project, then adds headings and todos to it.
    ///
    /// # Errors
    ///
    /// Returns an error if project creation or structure addition fails.
    pub fn create_project_with_structure(
        &self,
        name: &str,
        notes: Option<&str>,
        area: Option<&str>,
        tags: Option<&[String]>,
        headings: &[HeadingTuple],
        root_todos: &[TodoTuple],
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
    fn add_heading_to_project(
        &self,
        project_id: &str,
        heading_name: &str,
    ) -> Result<(), ClingsError> {
        let project_id_str = Self::js_string(project_id);
        let heading_str = Self::js_string(heading_name);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const project = Things.projects.byId({project_id_str});
    if (!project.exists()) throw new Error('Can\'t find project');
    Things.make({{ new: 'heading', withProperties: {{ name: {heading_str} }}, at: project }});
}})()"
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
        let project_id_str = Self::js_string(project_id);
        let notes_js = notes
            .map(|n| format!("props.notes = {};", Self::js_string(n)))
            .unwrap_or_default();

        let due_js = due_date
            .map(|d| {
                let date_str = Self::js_string(d);
                format!("props.dueDate = new Date({date_str});")
            })
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("props.tagNames = {};", Self::js_string(&t.join(", "))))
            .unwrap_or_default();

        let title_str = Self::js_string(title);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const project = Things.projects.byId({project_id_str});
    if (!project.exists()) throw new Error('Can\'t find project');
    const props = {{ name: {title_str} }};
    {notes_js}
    {due_js}
    {tags_js}
    Things.make({{ new: 'toDo', withProperties: props, at: project }});
}})()"
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
        let project_id_str = Self::js_string(project_id);
        let notes_js = notes
            .map(|n| format!("props.notes = {};", Self::js_string(n)))
            .unwrap_or_default();

        let due_js = due_date
            .map(|d| {
                let date_str = Self::js_string(d);
                format!("props.dueDate = new Date({date_str});")
            })
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("props.tagNames = {};", Self::js_string(&t.join(", "))))
            .unwrap_or_default();

        let heading_str = Self::js_string(heading_name);
        let title_str = Self::js_string(title);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const project = Things.projects.byId({project_id_str});
    if (!project.exists()) throw new Error('Can\'t find project');

    // Find the heading
    const headings = project.headings.whose({{ name: {heading_str} }});
    if (headings.length === 0) throw new Error('Can\'t find heading');
    const heading = headings[0];

    const props = {{ name: {title_str} }};
    {notes_js}
    {due_js}
    {tags_js}
    Things.make({{ new: 'toDo', withProperties: props, at: heading }});
}})()"
        );

        self.execute_void(&script)
    }

    /// Get all open todos.
    ///
    /// Uses direct database access for best performance, falling back to JXA if needed.
    ///
    /// # Errors
    ///
    /// Returns an error if todos cannot be fetched.
    pub fn get_all_todos(&self) -> Result<Vec<Todo>, ClingsError> {
        database::fetch_all_todos().or_else(|_| self.get_all_todos_jxa())
    }

    /// Get all todos using JXA (fallback).
    fn get_all_todos_jxa(&self) -> Result<Vec<Todo>, ClingsError> {
        let script = r"(() => {
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
})()";

        self.execute(script)
    }

    // =========================================================================
    // Batch Operations - Execute multiple operations in a single JXA call
    // =========================================================================

    /// Mark multiple todos as complete in a single JXA call.
    ///
    /// Returns the number of todos successfully completed.
    ///
    /// # Errors
    ///
    /// Returns an error if the JXA script execution fails.
    pub fn complete_todos_batch(&self, ids: &[String]) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const ids = {ids_array};
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
}})()"
        );

        self.execute(&script)
    }

    /// Mark multiple todos as canceled in a single JXA call.
    ///
    /// Returns the number of todos successfully canceled.
    ///
    /// # Errors
    ///
    /// Returns an error if the JXA script execution fails.
    pub fn cancel_todos_batch(&self, ids: &[String]) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const ids = {ids_array};
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
}})()"
        );

        self.execute(&script)
    }

    /// Add tags to multiple todos in a single JXA call.
    ///
    /// The tags are appended to any existing tags on each todo.
    ///
    /// # Errors
    ///
    /// Returns an error if the JXA script execution fails.
    pub fn add_tags_batch(
        &self,
        ids: &[String],
        tags: &[String],
    ) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let tags_str = Self::js_string(&tags.join(", "));
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const ids = {ids_array};
    const newTags = {tags_str};
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
}})()"
        );

        self.execute(&script)
    }

    /// Move multiple todos to a project in a single JXA call.
    ///
    /// # Errors
    ///
    /// Returns an error if the project is not found or the JXA script execution fails.
    pub fn move_todos_batch(
        &self,
        ids: &[String],
        project_name: &str,
    ) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let proj_str = Self::js_string(project_name);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const ids = {ids_array};
    let succeeded = 0;
    let failed = 0;
    const errors = [];

    // Find target project
    const projects = Things.projects.whose({{ name: {proj_str} }});
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
}})()"
        );

        self.execute(&script)
    }

    /// Set due date for multiple todos in a single JXA call.
    ///
    /// # Errors
    ///
    /// Returns an error if the JXA script execution fails.
    pub fn update_todos_due_batch(
        &self,
        ids: &[String],
        due_date: &str,
    ) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let date_str = Self::js_string(due_date);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const ids = {ids_array};
    const dueDate = new Date({date_str});
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
}})()"
        );

        self.execute(&script)
    }

    /// Clear due date for multiple todos in a single JXA call.
    ///
    /// # Errors
    ///
    /// Returns an error if the JXA script execution fails.
    pub fn clear_todos_due_batch(&self, ids: &[String]) -> Result<BatchResult, ClingsError> {
        if ids.is_empty() {
            return Ok(BatchResult::default());
        }

        let ids_array = Self::js_string_array(ids);
        let script = format!(
            r"(() => {{
    const Things = Application('Things3');
    const ids = {ids_array};
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
}})()"
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
    ///
    /// # Errors
    ///
    /// Returns an error if lists cannot be fetched or the JXA script execution fails.
    pub fn get_all_lists(&self) -> Result<AllListsResult, ClingsError> {
        let script = r"(() => {
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
})()";

        self.execute(script)
    }

    /// Get todos from open list views in a single JXA call.
    ///
    /// This excludes the Logbook for better performance. Use `get_all_lists()`
    /// when you need completed todos, or access the database directly for
    /// large Logbooks.
    ///
    /// # Errors
    ///
    /// Returns an error if lists cannot be fetched or the JXA script execution fails.
    pub fn get_open_lists(&self) -> Result<OpenListsResult, ClingsError> {
        let script = r"(() => {
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
})()";

        self.execute(script)
    }

    // =========================================================================
    // Helper methods
    // =========================================================================

    /// Escape a string for use in JavaScript
    ///
    /// Uses JSON encoding to properly handle all Unicode characters including emoji.
    fn js_string(s: &str) -> String {
        // serde_json::to_string produces properly escaped double-quoted JSON strings
        // which are valid JavaScript string literals with correct Unicode handling
        serde_json::to_string(s).unwrap_or_else(|_| {
            // Fallback to manual escaping if JSON serialization fails (shouldn't happen)
            let escaped = s
                .replace('\\', "\\\\")
                .replace('"', "\\\"")
                .replace('\n', "\\n")
                .replace('\r', "\\r")
                .replace('\t', "\\t");
            format!("\"{escaped}\"")
        })
    }

    /// Convert a slice of strings to a JavaScript array literal
    fn js_string_array(items: &[String]) -> String {
        let escaped: Vec<String> = items.iter().map(|s| Self::js_string(s)).collect();
        let joined = escaped.join(", ");
        format!("[{joined}]")
    }
}

impl Default for ThingsClient {
    fn default() -> Self {
        Self::new()
    }
}

fn capitalize(s: &str) -> String {
    let mut c = s.chars();
    c.next()
        .map_or_else(String::new, |f| f.to_uppercase().chain(c).collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    // ==================== js_string Tests ====================

    #[test]
    fn test_js_string_simple() {
        assert_eq!(ThingsClient::js_string("hello"), "\"hello\"");
    }

    #[test]
    fn test_js_string_with_single_quote() {
        // Single quotes don't need escaping in double-quoted JSON strings
        assert_eq!(ThingsClient::js_string("it's"), "\"it's\"");
    }

    #[test]
    fn test_js_string_with_double_quote() {
        assert_eq!(
            ThingsClient::js_string("say \"hello\""),
            "\"say \\\"hello\\\"\""
        );
    }

    #[test]
    fn test_js_string_with_backslash() {
        assert_eq!(ThingsClient::js_string("back\\slash"), "\"back\\\\slash\"");
    }

    #[test]
    fn test_js_string_with_newline() {
        assert_eq!(ThingsClient::js_string("line1\nline2"), "\"line1\\nline2\"");
    }

    #[test]
    fn test_js_string_with_carriage_return() {
        assert_eq!(ThingsClient::js_string("line1\rline2"), "\"line1\\rline2\"");
    }

    #[test]
    fn test_js_string_with_tab() {
        assert_eq!(ThingsClient::js_string("col1\tcol2"), "\"col1\\tcol2\"");
    }

    #[test]
    fn test_js_string_empty() {
        assert_eq!(ThingsClient::js_string(""), "\"\"");
    }

    #[test]
    fn test_js_string_complex() {
        // Test multiple escapes in one string
        assert_eq!(
            ThingsClient::js_string("it's a \"test\"\nwith\ttabs"),
            "\"it's a \\\"test\\\"\\nwith\\ttabs\""
        );
    }

    #[test]
    fn test_js_string_unicode() {
        // Unicode should pass through unchanged
        assert_eq!(ThingsClient::js_string("日本語"), "\"日本語\"");
    }

    #[test]
    fn test_js_string_emoji() {
        // Emoji should be properly handled
        assert_eq!(ThingsClient::js_string("⚠️ Warning"), "\"⚠️ Warning\"");
        assert_eq!(
            ThingsClient::js_string("🖥️ Under Armour"),
            "\"🖥️ Under Armour\""
        );
    }

    #[test]
    fn test_js_string_ampersand() {
        // Ampersand should pass through - it's valid in JSON strings
        assert_eq!(ThingsClient::js_string("Q&A Guide"), "\"Q&A Guide\"");
        assert_eq!(
            ThingsClient::js_string("Lunch & Learn"),
            "\"Lunch & Learn\""
        );
    }

    #[test]
    fn test_js_string_angle_brackets() {
        // Angle brackets should pass through unchanged
        assert_eq!(
            ThingsClient::js_string("foo < bar > baz"),
            "\"foo < bar > baz\""
        );
    }

    #[test]
    fn test_js_string_special_chars_combo() {
        // Complex string with multiple special characters
        assert_eq!(
            ThingsClient::js_string("Q&A: \"What?\" <test>"),
            "\"Q&A: \\\"What?\\\" <test>\""
        );
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
        assert_eq!(ThingsClient::js_string_array(&items), "[\"hello\"]");
    }

    #[test]
    fn test_js_string_array_multiple() {
        let items = vec!["one".to_string(), "two".to_string(), "three".to_string()];
        assert_eq!(
            ThingsClient::js_string_array(&items),
            "[\"one\", \"two\", \"three\"]"
        );
    }

    #[test]
    fn test_js_string_array_with_escapes() {
        let items = vec!["it's".to_string(), "a\ntest".to_string()];
        assert_eq!(
            ThingsClient::js_string_array(&items),
            "[\"it's\", \"a\\ntest\"]"
        );
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

    // ==================== add_todo JXA Script Generation Tests ====================

    /// Helper to generate the JXA script that add_todo would create
    /// This allows us to test the script generation without executing it
    fn generate_add_todo_script(
        title: &str,
        notes: Option<&str>,
        when_date: Option<&str>,
        deadline: Option<&str>,
        tags: Option<&[String]>,
        list: Option<&str>,
        area: Option<&str>,
        checklist: Option<&[String]>,
    ) -> String {
        let notes_js = notes
            .map(|n| format!("props.notes = {};", ThingsClient::js_string(n)))
            .unwrap_or_default();

        let deadline_js = deadline
            .map(|d| format!("props.dueDate = new Date('{d}');"))
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| {
                format!(
                    "props.tagNames = {};",
                    ThingsClient::js_string(&t.join(", "))
                )
            })
            .unwrap_or_default();

        let schedule_js = when_date
            .map(|d| {
                format!(
                    r#"
    Things.schedule(todo, {{ for: new Date('{}') }});"#,
                    d
                )
            })
            .unwrap_or_default();

        // Project/list assignment - try lists first, then fall back to projects.whose()
        let list_js = list
            .map(|l| {
                format!(
                    r#"
    const targetList = Things.lists.byName({});
    if (targetList.exists()) {{
        Things.move(todo, {{ to: targetList }});
    }} else {{
        const targetProject = Things.projects.whose({{ name: {} }})[0];
        if (targetProject) {{
            Things.move(todo, {{ to: targetProject }});
        }}
    }}"#,
                    ThingsClient::js_string(l),
                    ThingsClient::js_string(l)
                )
            })
            .unwrap_or_default();

        // Area assignment - set on todo AFTER make() (works alongside project)
        let area_js = area
            .map(|a| {
                format!(
                    r#"
    const targetArea = Things.areas.byName({});
    if (targetArea.exists()) {{
        todo.area = targetArea;
    }}"#,
                    ThingsClient::js_string(a)
                )
            })
            .unwrap_or_default();

        let checklist_js = checklist
            .map(|items| {
                let items_str: Vec<String> =
                    items.iter().map(|i| ThingsClient::js_string(i)).collect();
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

        format!(
            r#"(() => {{
    const Things = Application('Things3');
    const props = {{ name: {} }};
    {}
    {}
    {}
    const todo = Things.make({{ new: 'toDo', withProperties: props }});
    {}
    {}
    {}
    {}
    return JSON.stringify({{ id: todo.id(), name: todo.name() }});
}})()"#,
            ThingsClient::js_string(title),
            notes_js,
            deadline_js,
            tags_js,
            area_js,
            schedule_js,
            list_js,
            checklist_js
        )
    }

    #[test]
    fn test_add_todo_script_basic() {
        let script = generate_add_todo_script("Buy milk", None, None, None, None, None, None, None);
        assert!(script.contains("const props = { name: \"Buy milk\" }"));
        assert!(script.contains("Things.make({ new: 'toDo', withProperties: props })"));
    }

    #[test]
    fn test_add_todo_script_with_notes() {
        let script =
            generate_add_todo_script("Task", Some("My notes"), None, None, None, None, None, None);
        assert!(script.contains("props.notes = \"My notes\""));
    }

    #[test]
    fn test_add_todo_script_with_when_date_uses_schedule() {
        let script = generate_add_todo_script(
            "Task",
            None,
            Some("2024-12-15"),
            None,
            None,
            None,
            None,
            None,
        );
        // Should use schedule command for "when" date
        assert!(script.contains("Things.schedule(todo, { for: new Date('2024-12-15') })"));
        // Should NOT set dueDate for when
        assert!(!script.contains("props.dueDate = new Date('2024-12-15')"));
    }

    #[test]
    fn test_add_todo_script_with_deadline_uses_due_date() {
        let script = generate_add_todo_script(
            "Task",
            None,
            None,
            Some("2024-12-20"),
            None,
            None,
            None,
            None,
        );
        // Should set dueDate for deadline
        assert!(script.contains("props.dueDate = new Date('2024-12-20')"));
        // Should NOT use schedule for deadline
        assert!(!script.contains("Things.schedule"));
    }

    #[test]
    fn test_add_todo_script_with_both_when_and_deadline() {
        let script = generate_add_todo_script(
            "Task",
            None,
            Some("2024-12-15"), // when
            Some("2024-12-20"), // deadline
            None,
            None,
            None,
            None,
        );
        // Should have both: schedule for when, dueDate for deadline
        assert!(script.contains("Things.schedule(todo, { for: new Date('2024-12-15') })"));
        assert!(script.contains("props.dueDate = new Date('2024-12-20')"));
    }

    #[test]
    fn test_add_todo_script_with_tags() {
        let tags = vec!["work".to_string(), "urgent".to_string()];
        let script =
            generate_add_todo_script("Task", None, None, None, Some(&tags), None, None, None);
        assert!(script.contains("props.tagNames = \"work, urgent\""));
    }

    #[test]
    fn test_add_todo_script_with_project() {
        let script = generate_add_todo_script(
            "Task",
            None,
            None,
            None,
            None,
            Some("My Project"),
            None,
            None,
        );
        assert!(script.contains("Things.lists.byName(\"My Project\")"));
        assert!(script.contains("Things.move(todo, { to: targetList })"));
    }

    #[test]
    fn test_add_todo_script_with_area() {
        let script =
            generate_add_todo_script("Task", None, None, None, None, None, Some("Work"), None);
        assert!(script.contains("Things.areas.byName(\"Work\")"));
        // Area is now set on todo object AFTER make(), not on props
        assert!(script.contains("todo.area = targetArea"));
    }

    #[test]
    fn test_add_todo_script_area_works_with_project() {
        // Area and project can now be used together
        let script = generate_add_todo_script(
            "Task",
            None,
            None,
            None,
            None,
            Some("My Project"),
            Some("Work"),
            None,
        );
        // Project should be set
        assert!(script.contains("Things.lists.byName(\"My Project\")"));
        // Area should also be set (no longer ignored when project is specified)
        assert!(script.contains("Things.areas.byName(\"Work\")"));
        assert!(script.contains("todo.area = targetArea"));
    }

    #[test]
    fn test_add_todo_script_with_checklist() {
        let checklist = vec!["Item 1".to_string(), "Item 2".to_string()];
        let script =
            generate_add_todo_script("Task", None, None, None, None, None, None, Some(&checklist));
        assert!(script.contains("const checklistItems = [\"Item 1\", \"Item 2\"]"));
        assert!(script
            .contains("Things.make({ new: 'toDo', withProperties: { name: item }, at: todo })"));
    }

    #[test]
    fn test_add_todo_script_with_all_parameters() {
        let tags = vec!["work".to_string()];
        let checklist = vec!["Step 1".to_string()];
        let script = generate_add_todo_script(
            "Complete task",
            Some("Important notes"),
            Some("2024-12-15"),
            Some("2024-12-20"),
            Some(&tags),
            Some("Project X"),
            Some("Work"), // Area is now set alongside project
            Some(&checklist),
        );

        assert!(script.contains("const props = { name: \"Complete task\" }"));
        assert!(script.contains("props.notes = \"Important notes\""));
        assert!(script.contains("props.dueDate = new Date('2024-12-20')"));
        assert!(script.contains("props.tagNames = \"work\""));
        assert!(script.contains("Things.schedule(todo, { for: new Date('2024-12-15') })"));
        assert!(script.contains("Things.lists.byName(\"Project X\")"));
        // Area is now set alongside project (not ignored)
        assert!(script.contains("Things.areas.byName(\"Work\")"));
        assert!(script.contains("const checklistItems = [\"Step 1\"]"));
    }

    #[test]
    fn test_add_todo_script_escapes_special_characters() {
        let script = generate_add_todo_script(
            "Task with 'quotes' and\nnewline",
            Some("Notes with\ttabs"),
            None,
            None,
            None,
            None,
            None,
            None,
        );
        // JSON encoding uses double quotes and escapes properly
        assert!(script.contains("\"Task with 'quotes' and\\nnewline\""));
        assert!(script.contains("\"Notes with\\ttabs\""));
    }

    // ==================== Update Todo Tests ====================

    /// Helper to generate the JXA script that update_todo would create
    /// This allows us to test the script generation without executing it
    fn generate_update_todo_script(
        id: &str,
        title: Option<&str>,
        notes: Option<&str>,
        when_date: Option<&str>,
        deadline: Option<&str>,
        tags: Option<&str>,
        project: Option<&str>,
    ) -> String {
        let title_js = title
            .map(|t| format!("todo.name = {};", ThingsClient::js_string(t)))
            .unwrap_or_default();

        let notes_js = notes
            .map(|n| format!("todo.notes = {};", ThingsClient::js_string(n)))
            .unwrap_or_default();

        let deadline_js = deadline
            .map(|d| format!("todo.dueDate = new Date('{d}');"))
            .unwrap_or_default();

        let tags_js = tags
            .map(|t| format!("todo.tagNames = {};", ThingsClient::js_string(t)))
            .unwrap_or_default();

        let schedule_js = when_date
            .map(|d| format!("Things.schedule(todo, {{ for: new Date('{d}') }});"))
            .unwrap_or_default();

        let project_js = project
            .map(|p| {
                format!(
                    r#"
    const targetList = Things.lists.byName({});
    if (targetList.exists()) {{
        Things.move(todo, {{ to: targetList }});
    }}"#,
                    ThingsClient::js_string(p)
                )
            })
            .unwrap_or_default();

        format!(
            r#"(() => {{
    const Things = Application('Things3');
    const todo = Things.toDos.byId('{}');
    if (!todo.exists()) throw new Error("Can't get todo");
    {}
    {}
    {}
    {}
    {}
    {}
}})()"#,
            id, title_js, notes_js, deadline_js, tags_js, schedule_js, project_js
        )
    }

    #[test]
    fn test_update_todo_script_with_title_only() {
        let script =
            generate_update_todo_script("ABC123", Some("New Title"), None, None, None, None, None);
        assert!(script.contains("Things.toDos.byId('ABC123')"));
        assert!(script.contains("todo.name = \"New Title\""));
        assert!(!script.contains("todo.notes"));
        assert!(!script.contains("todo.dueDate"));
        assert!(!script.contains("todo.tagNames"));
        assert!(!script.contains("Things.schedule"));
        assert!(!script.contains("Things.move"));
    }

    #[test]
    fn test_update_todo_script_with_notes_only() {
        let script = generate_update_todo_script(
            "ABC123",
            None,
            Some("Important notes here"),
            None,
            None,
            None,
            None,
        );
        assert!(script.contains("todo.notes = \"Important notes here\""));
        assert!(!script.contains("todo.name ="));
    }

    #[test]
    fn test_update_todo_script_with_deadline_only() {
        let script =
            generate_update_todo_script("ABC123", None, None, None, Some("2024-12-20"), None, None);
        assert!(script.contains("todo.dueDate = new Date('2024-12-20')"));
    }

    #[test]
    fn test_update_todo_script_with_tags_only() {
        let script = generate_update_todo_script(
            "ABC123",
            None,
            None,
            None,
            None,
            Some("work, urgent"),
            None,
        );
        assert!(script.contains("todo.tagNames = \"work, urgent\""));
    }

    #[test]
    fn test_update_todo_script_with_when_only() {
        let script =
            generate_update_todo_script("ABC123", None, None, Some("2024-12-15"), None, None, None);
        assert!(script.contains("Things.schedule(todo, { for: new Date('2024-12-15') })"));
    }

    #[test]
    fn test_update_todo_script_with_project_only() {
        let script =
            generate_update_todo_script("ABC123", None, None, None, None, None, Some("Project X"));
        assert!(script.contains("Things.lists.byName(\"Project X\")"));
        assert!(script.contains("Things.move(todo, { to: targetList })"));
    }

    #[test]
    fn test_update_todo_script_with_all_fields() {
        let script = generate_update_todo_script(
            "ABC123",
            Some("New Title"),
            Some("New notes"),
            Some("2024-12-15"),
            Some("2024-12-20"),
            Some("work, urgent"),
            Some("Project X"),
        );
        assert!(script.contains("Things.toDos.byId('ABC123')"));
        assert!(script.contains("todo.name = \"New Title\""));
        assert!(script.contains("todo.notes = \"New notes\""));
        assert!(script.contains("todo.dueDate = new Date('2024-12-20')"));
        assert!(script.contains("todo.tagNames = \"work, urgent\""));
        assert!(script.contains("Things.schedule(todo, { for: new Date('2024-12-15') })"));
        assert!(script.contains("Things.lists.byName(\"Project X\")"));
        assert!(script.contains("Things.move(todo, { to: targetList })"));
    }

    #[test]
    fn test_update_todo_script_with_no_fields() {
        let script = generate_update_todo_script("ABC123", None, None, None, None, None, None);
        // Should still have the basic structure
        assert!(script.contains("Things.toDos.byId('ABC123')"));
        assert!(script.contains("if (!todo.exists()) throw new Error"));
        // But no property assignments
        assert!(!script.contains("todo.name ="));
        assert!(!script.contains("todo.notes ="));
        assert!(!script.contains("todo.dueDate ="));
        assert!(!script.contains("todo.tagNames ="));
        assert!(!script.contains("Things.schedule"));
        assert!(!script.contains("Things.move"));
    }

    #[test]
    fn test_update_todo_script_escapes_special_characters() {
        let script = generate_update_todo_script(
            "ABC123",
            Some("Title with 'quotes'"),
            Some("Notes with\nnewline"),
            None,
            None,
            None,
            None,
        );
        // JSON encoding preserves single quotes and escapes newlines
        assert!(script.contains("\"Title with 'quotes'\""));
        assert!(script.contains("\"Notes with\\nnewline\""));
    }

    #[test]
    fn test_update_todo_script_handles_emoji_in_project() {
        let script = generate_update_todo_script(
            "ABC123",
            None,
            None,
            None,
            None,
            None,
            Some("🖥️ Under Armour"),
        );
        assert!(script.contains("Things.lists.byName(\"🖥️ Under Armour\")"));
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
