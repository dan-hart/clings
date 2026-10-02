// JXAScripts.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// JavaScript for Automation (JXA) script templates for Things 3.
public enum JXAScripts {
    /// Reports each completed assignment even when a later Apple event fails.
    /// Foundation performs JSON escaping for arbitrary IDs/error strings.
    static func trackedAppleScript(id: String?, body: String) -> String {
        """
        use framework "Foundation"
        use scripting additions
        set mutationID to \(id.map { "\"\($0.appleScriptEscaped)\"" } ?? "missing value")
        set appliedFields to {}
        try
            \(body)
            return my mutationJSON(true, mutationID, appliedFields, missing value)
        on error errorMessage number errorNumber
            return my mutationJSON(false, mutationID, appliedFields, errorMessage & " (" & errorNumber & ")")
        end try

        on mutationJSON(successFlag, mutationID, appliedFields, errorMessage)
            set payload to current application's NSMutableDictionary's dictionary()
            payload's setObject:(current application's NSNumber's numberWithBool:successFlag) forKey:"success"
            if mutationID is missing value then
                payload's setObject:(current application's NSNull's null()) forKey:"id"
            else
                payload's setObject:(mutationID as text) forKey:"id"
            end if
            payload's setObject:(current application's NSArray's arrayWithArray:appliedFields) forKey:"appliedFields"
            if errorMessage is missing value then
                payload's setObject:(current application's NSNull's null()) forKey:"error"
            else
                payload's setObject:(errorMessage as text) forKey:"error"
            end if
            set encodedData to current application's NSJSONSerialization's dataWithJSONObject:payload options:0 |error|:(missing value)
            set resultText to current application's NSString's alloc()'s initWithData:encodedData encoding:(current application's NSUTF8StringEncoding)
            return resultText as text
        end mutationJSON
        """
    }

    public static func moveTodoToProjectID(id: String, projectID: String) -> String {
        """
        tell application "Things3"
            set targetTodo to to do id "\(id.appleScriptEscaped)"
            set project of targetTodo to project id "\(projectID.appleScriptEscaped)"
        end tell
        """
    }

    public static func restoreTodoAppleScript(_ snapshot: TodoSnapshot) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "MMMM d, yyyy HH:mm:ss"
        let setup = appleScriptDateSetup(variableName: "restoredDeadline", dateString: snapshot.dueDate.map { formatter.string(from: $0) })
        let status = snapshot.status == .open ? "open" : snapshot.status == .completed ? "completed" : "canceled"
        return trackedAppleScript(id: snapshot.id, body: """
        tell application "Things3"
            set targetTodo to to do id "\(snapshot.id.appleScriptEscaped)"
            set name of targetTodo to "\(snapshot.name.appleScriptEscaped)"
            set end of appliedFields to "title"
            set notes of targetTodo to "\((snapshot.notes ?? "").appleScriptEscaped)"
            set end of appliedFields to "notes"
            \(setup)
            set due date of targetTodo to \(snapshot.dueDate == nil ? "missing value" : "restoredDeadline")
            set end of appliedFields to "deadline"
            set status of targetTodo to \(status)
            set end of appliedFields to "status"
        end tell
        """)
    }
    // MARK: - List Queries

    /// Fetch all todos from a specific list view.
    public static func fetchList(_ listName: String) -> String {
        """
        (() => {
            const app = Application('Things3');
            const list = app.lists.byName('\(listName.jxaEscaped)');
            const todos = list.toDos();

            return JSON.stringify(todos.map(todo => {
                let proj = null;
                try {
                    const p = todo.project();
                    if (p && p.id()) {
                        proj = { id: p.id(), name: p.name() };
                    }
                } catch (e) {}

                let ar = null;
                try {
                    const a = todo.area();
                    if (a && a.id()) {
                        ar = { id: a.id(), name: a.name() };
                    }
                } catch (e) {}

                // Get checklist items safely
                let checklist = [];
                try {
                    const items = todo.checklistItems();
                    if (items && items.length > 0) {
                        checklist = items.map(ci => ({
                            id: ci.id(),
                            name: ci.name(),
                            completed: ci.status() === 'completed'
                        }));
                    }
                } catch (e) {}

                const creationDate = todo.creationDate();
                const modificationDate = todo.modificationDate();

                return {
                    id: todo.id(),
                    name: todo.name(),
                    notes: todo.notes() || null,
                    status: todo.status(),
                    dueDate: todo.dueDate() ? todo.dueDate().toISOString() : null,
                    scheduledDate: (() => { try { const date = todo.activationDate(); return date ? date.toISOString() : null; } catch (e) { return null; } })(),
                    tags: todo.tags().map(t => ({ id: t.id(), name: t.name() })),
                    project: proj,
                    area: ar,
                    checklistItems: checklist,
                    creationDate: creationDate.toISOString(),
                    modificationDate: (modificationDate ? modificationDate.toISOString() : creationDate.toISOString())
                };
            }));
        })()
        """
    }

    /// Fetch a single todo by ID.
    public static func fetchTodo(id: String) -> String {
        """
        (() => {
            const app = Application('Things3');
            const todo = app.toDos.byId('\(id.jxaEscaped)');

            if (!todo.exists()) {
                return JSON.stringify({ error: 'Todo not found', id: '\(id.jxaEscaped)' });
            }

            let proj = null;
            try {
                const p = todo.project();
                if (p && p.id()) {
                    proj = { id: p.id(), name: p.name() };
                }
            } catch (e) {}

            let ar = null;
            try {
                const a = todo.area();
                if (a && a.id()) {
                    ar = { id: a.id(), name: a.name() };
                }
            } catch (e) {}

            // Get checklist items safely
            let checklist = [];
            try {
                const items = todo.checklistItems();
                if (items && items.length > 0) {
                    checklist = items.map(ci => ({
                        id: ci.id(),
                        name: ci.name(),
                        completed: ci.status() === 'completed'
                    }));
                }
            } catch (e) {}

            const creationDate = todo.creationDate();
            const modificationDate = todo.modificationDate();

            return JSON.stringify({
                id: todo.id(),
                name: todo.name(),
                notes: todo.notes() || null,
                status: todo.status(),
                dueDate: todo.dueDate() ? todo.dueDate().toISOString() : null,
                scheduledDate: (() => { try { const date = todo.activationDate(); return date ? date.toISOString() : null; } catch (e) { return null; } })(),
                tags: todo.tags().map(t => ({ id: t.id(), name: t.name() })),
                project: proj,
                area: ar,
                checklistItems: checklist,
                creationDate: creationDate.toISOString(),
                modificationDate: (modificationDate ? modificationDate.toISOString() : creationDate.toISOString())
            });
        })()
        """
    }

    /// Fetch all projects.
    public static func fetchProjects() -> String {
        """
        (() => {
            const app = Application('Things3');
            const projects = app.projects();

            return JSON.stringify(projects.map(proj => {
                let ar = null;
                try {
                    const a = proj.area();
                    if (a && a.id()) {
                        ar = { id: a.id(), name: a.name() };
                    }
                } catch (e) {}

                return {
                    id: proj.id(),
                    name: proj.name(),
                    notes: proj.notes() || null,
                    status: proj.status(),
                    area: ar,
                    tags: proj.tags().map(t => ({ id: t.id(), name: t.name() })),
                    dueDate: proj.dueDate() ? proj.dueDate().toISOString() : null,
                    creationDate: proj.creationDate().toISOString()
                };
            }));
        })()
        """
    }

    /// Fetch all areas.
    public static func fetchAreas() -> String {
        """
        (() => {
            const app = Application('Things3');
            const areas = app.areas();

            return JSON.stringify(areas.map(area => ({
                id: area.id(),
                name: area.name(),
                tags: area.tags().map(t => ({ id: t.id(), name: t.name() }))
            })));
        })()
        """
    }

    /// Fetch all tags.
    public static func fetchTags() -> String {
        """
        (() => {
            const app = Application('Things3');
            const tags = app.tags();

            return JSON.stringify(tags.map(tag => ({
                id: tag.id(),
                name: tag.name()
            })));
        })()
        """
    }

    // MARK: - Mutations

    /// Complete a todo by ID.
    public static func completeTodo(id: String) -> String {
        """
        (() => {
            const app = Application('Things3');
            const todo = app.toDos.byId('\(id.jxaEscaped)');

            if (!todo.exists()) {
                return JSON.stringify({ success: false, error: 'Todo not found' });
            }

            todo.status = 'completed';
            return JSON.stringify({ success: true, id: '\(id.jxaEscaped)' });
        })()
        """
    }

    /// Re-open a todo by ID.
    public static func reopenTodo(id: String) -> String {
        """
        (() => {
            const app = Application('Things3');
            const todo = app.toDos.byId('\(id.jxaEscaped)');

            if (!todo.exists()) {
                return JSON.stringify({ success: false, error: 'Todo not found' });
            }

            todo.status = 'open';
            return JSON.stringify({ success: true, id: '\(id.jxaEscaped)' });
        })()
        """
    }

    /// Cancel a todo by ID.
    public static func cancelTodo(id: String) -> String {
        """
        (() => {
            const app = Application('Things3');
            const todo = app.toDos.byId('\(id.jxaEscaped)');

            if (!todo.exists()) {
                return JSON.stringify({ success: false, error: 'Todo not found' });
            }

            todo.status = 'canceled';
            return JSON.stringify({ success: true, id: '\(id.jxaEscaped)' });
        })()
        """
    }

    /// Cancel a todo by ID through the supported API; this never moves it to Trash.
    public static func deleteTodo(id: String) -> String {
        """
        (() => {
            const app = Application('Things3');
            const todo = app.toDos.byId('\(id.jxaEscaped)');

            if (!todo.exists()) {
                return JSON.stringify({ success: false, error: 'Todo not found' });
            }

            // Things 3 doesn't have a direct delete, we cancel it
            todo.status = 'canceled';
            return JSON.stringify({ success: true, id: '\(id.jxaEscaped)' });
        })()
        """
    }

    /// Move a todo to a project.
    public static func moveTodo(id: String, toProject projectName: String) -> String {
        """
        (() => {
            const app = Application('Things3');
            const todo = app.toDos.byId('\(id.jxaEscaped)');

            if (!todo.exists()) {
                return JSON.stringify({ success: false, error: 'Todo not found' });
            }

            const project = app.projects.byName('\(projectName.jxaEscaped)');
            if (!project.exists()) {
                return JSON.stringify({ success: false, error: 'Project not found: \(projectName.jxaEscaped)' });
            }

            todo.project = project;
            return JSON.stringify({ success: true, id: '\(id.jxaEscaped)' });
        })()
        """
    }

    /// Update a todo's properties.
    public static func updateTodo(
        id: String,
        name: String? = nil,
        notes: String? = nil,
        dueDate: Date? = nil,
        tags: [String]? = nil
    ) -> String {
        let dueDateISO = dueDate.map { ISO8601DateFormatter().string(from: $0) }

        // Tags are handled via AppleScript for reliability.
        _ = tags // Tags are applied separately.
        var assignments: [String] = []
        if let name { assignments.append("todo.name = '\(name.jxaEscaped)'; appliedFields.push('title');") }
        if let notes { assignments.append("todo.notes = '\(notes.jxaEscaped)'; appliedFields.push('notes');") }
        if let dueDateISO { assignments.append("todo.dueDate = new Date('\(dueDateISO)'); appliedFields.push('deadline');") }

        return """
        (() => {
            const appliedFields = [];
            try {
                const app = Application('Things3');
                const todo = app.toDos.byId('\(id.jxaEscaped)');
                if (!todo.exists()) {
                    return JSON.stringify({ success: false, id: '\(id.jxaEscaped)', appliedFields, error: 'Todo not found' });
                }
                \(assignments.joined(separator: "\n"))
                return JSON.stringify({ success: true, id: '\(id.jxaEscaped)', appliedFields });
            } catch (error) {
                return JSON.stringify({ success: false, id: '\(id.jxaEscaped)', appliedFields, error: String(error) });
            }
        })()
        """
    }

    /// Build an AppleScript date value without invoking AppleScript's locale-sensitive
    /// `date "..."` parser. The input format is generated internally using en_US_POSIX.
    private static func appleScriptDateSetup(variableName: String, dateString: String?) -> String {
        guard let dateString else { return "" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MMMM d, yyyy HH:mm:ss"
        formatter.isLenient = false

        guard let date = formatter.date(from: dateString) else {
            return "error \"Invalid date value: \(dateString.appleScriptEscaped)\""
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        guard
            let year = components.year,
            let month = components.month,
            let day = components.day,
            let hour = components.hour,
            let minute = components.minute,
            let second = components.second,
            (1 ... 12).contains(month)
        else {
            return "error \"Invalid date components\""
        }

        let monthNames = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        // Work at noon while changing calendar fields, then assign wall-clock
        // components. AppleScript's `set time` can cross back into the previous
        // day when the target date starts with a DST gap (e.g. Santiago).
        // Set the hour last so half-hour DST gaps do not affect intermediate times.
        return """
        set \(variableName) to current date
        set hours of \(variableName) to 12
        set day of \(variableName) to 1
        set year of \(variableName) to \(year)
        set month of \(variableName) to \(monthNames[month - 1])
        set day of \(variableName) to \(day)
        set minutes of \(variableName) to \(minute)
        set seconds of \(variableName) to \(second)
        set hours of \(variableName) to \(hour)
        """
    }

    /// Create a new todo with the given properties via AppleScript.
    public static func createTodo(
        name: String,
        notes: String? = nil,
        when: String? = nil,
        deadline: String? = nil,
        tags: [String] = [],
        project: String? = nil,
        area: String? = nil,
        checklistItems: [String] = []
    ) -> String {
        _ = tags // Tags are applied separately via AppleScript.
        let checklistArray = checklistItems.map { "\"\($0.appleScriptEscaped)\"" }.joined(separator: ", ")
        let whenDateSetup = appleScriptDateSetup(variableName: "scheduledDate", dateString: when)
        let deadlineDateSetup = appleScriptDateSetup(variableName: "deadlineDate", dateString: deadline)

        var propsCode = "name: \"\(name.appleScriptEscaped)\""
        if let notes = notes, !notes.isEmpty {
            propsCode += ", notes: \"\(notes.appleScriptEscaped)\""
        }
        let projectCode = project.map { projectName in
            """
            if exists project "\(projectName.appleScriptEscaped)" then
                set project of newTodo to project "\(projectName.appleScriptEscaped)"
                set end of appliedFields to "project"
            end if
            """
        } ?? ""
        let areaCode = area.map { areaName in
            """
            if exists area "\(areaName.appleScriptEscaped)" then
                set area of newTodo to area "\(areaName.appleScriptEscaped)"
                set end of appliedFields to "area"
            end if
            """
        } ?? ""

        return trackedAppleScript(id: nil, body: """
        tell application "Things3"
            set newTodo to make new to do with properties {\(propsCode)}
            set mutationID to id of newTodo
            set end of appliedFields to "create"

            \(projectCode)
            \(areaCode)

            \(whenDateSetup)
            \(when != nil ? "schedule newTodo for scheduledDate" : "")
            \(when != nil ? "set end of appliedFields to \"schedule\"" : "")

            \(deadlineDateSetup)
            \(deadline != nil ? "set due date of newTodo to deadlineDate" : "")
            \(deadline != nil ? "set end of appliedFields to \"deadline\"" : "")

            set checklistItems to {\(checklistArray)}
            repeat with itemName in checklistItems
                make new to do with properties {name:itemName} at newTodo
                if appliedFields does not contain "checklist" then set end of appliedFields to "checklist"
            end repeat

        end tell
        """)
    }

    /// Create a new project with the given properties.
    public static func createProject(
        name: String,
        notes: String? = nil,
        when: Date? = nil,
        deadline: Date? = nil,
        area: String? = nil
    ) -> String {
        let whenISO = when.map { ISO8601DateFormatter().string(from: $0) }
        let deadlineISO = deadline.map { ISO8601DateFormatter().string(from: $0) }

        var propsCode = "name: '\(name.jxaEscaped)'"
        if let notes = notes, !notes.isEmpty {
            propsCode += ", notes: '\(notes.jxaEscaped)'"
        }

        return """
        (() => {
            const app = Application('Things3');

            const props = { \(propsCode) };
            const project = app.make({ new: 'project', withProperties: props });

            // Set when date
            \(whenISO != nil ? "project.activationDate = new Date('\(whenISO!)');" : "")

            // Set deadline
            \(deadlineISO != nil ? "project.dueDate = new Date('\(deadlineISO!)');" : "")

            // Add to area
            \(area != nil ? """
            const area = app.areas.byName('\(area!.jxaEscaped)');
            if (area.exists()) {
                project.area = area;
            }
            """ : "")

            return JSON.stringify({
                success: true,
                id: project.id(),
                name: project.name()
            });
        })()
        """
    }

    // MARK: - Search

    /// Search todos by query text.
    public static func search(query: String) -> String {
        """
        (() => {
            const app = Application('Things3');
            const query = '\(query.jxaEscaped)'.toLowerCase();

            const allTodos = app.toDos();
            const matches = allTodos.filter(todo => {
                const name = (todo.name() || '').toLowerCase();
                const notes = (todo.notes() || '').toLowerCase();
                return name.includes(query) || notes.includes(query);
            });

            return JSON.stringify(matches.map(todo => {
                let proj = null;
                try {
                    const p = todo.project();
                    if (p && p.id()) {
                        proj = { id: p.id(), name: p.name() };
                    }
                } catch (e) {}

                const creationDate = todo.creationDate();
                const modificationDate = todo.modificationDate();

                return {
                    id: todo.id(),
                    name: todo.name(),
                    notes: todo.notes() || null,
                    status: todo.status(),
                    dueDate: todo.dueDate() ? todo.dueDate().toISOString() : null,
                    scheduledDate: (() => { try { const date = todo.activationDate(); return date ? date.toISOString() : null; } catch (e) { return null; } })(),
                    tags: todo.tags().map(t => ({ id: t.id(), name: t.name() })),
                    project: proj,
                    creationDate: creationDate.toISOString(),
                    modificationDate: (modificationDate ? modificationDate.toISOString() : creationDate.toISOString())
                };
            }));
        })()
        """
    }

    // MARK: - Tag Management (AppleScript)

    /// Create a new tag via AppleScript.
    /// Returns the ID of the created tag.
    public static func createTagAppleScript(name: String) -> String {
        """
        tell application "Things3"
            set newTag to make new tag with properties {name:"\(name.appleScriptEscaped)"}
            return id of newTag
        end tell
        """
    }

    /// Delete a tag by name via AppleScript.
    public static func deleteTagAppleScript(name: String) -> String {
        """
        tell application "Things3"
            if exists tag "\(name.appleScriptEscaped)" then
                delete tag "\(name.appleScriptEscaped)"
                return "deleted"
            else
                error "Tag not found: \(name.appleScriptEscaped)"
            end if
        end tell
        """
    }

    /// Rename a tag via AppleScript.
    public static func renameTagAppleScript(oldName: String, newName: String) -> String {
        """
        tell application "Things3"
            if exists tag "\(oldName.appleScriptEscaped)" then
                set name of tag "\(oldName.appleScriptEscaped)" to "\(newName.appleScriptEscaped)"
                return "renamed"
            else
                error "Tag not found: \(oldName.appleScriptEscaped)"
            end if
        end tell
        """
    }

    /// Set tag names for a todo via AppleScript.
    public static func setTodoTagsAppleScript(id: String, tags: [String]) -> String {
        let tagList = tags.map { "\"\($0.appleScriptEscaped)\"" }.joined(separator: ", ")

        return """
        tell application "Things3"
            set tagNames to {\(tagList)}
            repeat with tagName in tagNames
                if not (exists tag tagName) then
                    make new tag with properties {name: tagName}
                end if
            end repeat
            set tagNamesStr to tagNames as string
            set theTodo to to do id "\(id.appleScriptEscaped)"
            if not (exists theTodo) then
                error "Todo not found: \(id.appleScriptEscaped)"
            end if
            set tag names of theTodo to tagNamesStr
            return "ok"
        end tell
        """
    }

    /// Set tag names for a project via AppleScript.
    public static func setProjectTagsAppleScript(id: String, tags: [String]) -> String {
        let tagList = tags.map { "\"\($0.appleScriptEscaped)\"" }.joined(separator: ", ")

        return """
        tell application "Things3"
            set tagNames to {\(tagList)}
            repeat with tagName in tagNames
                if not (exists tag tagName) then
                    make new tag with properties {name: tagName}
                end if
            end repeat
            set tagNamesStr to tagNames as string
            set theProject to project id "\(id.appleScriptEscaped)"
            if not (exists theProject) then
                error "Project not found: \(id.appleScriptEscaped)"
            end if
            set tag names of theProject to tagNamesStr
            return "ok"
        end tell
        """
    }

    /// Check if a tag exists via AppleScript.
    public static func tagExistsAppleScript(name: String) -> String {
        """
        tell application "Things3"
            exists tag "\(name.appleScriptEscaped)"
        end tell
        """
    }
}

// MARK: - String Extension for JXA Escaping

extension String {
    /// Escape a string for safe use in JXA single-quoted strings.
    var jxaEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    /// Escape a string for safe use in AppleScript double-quoted strings.
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
