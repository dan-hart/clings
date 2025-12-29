// JXAScripts.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// JavaScript for Automation (JXA) script templates for Things 3.
public enum JXAScripts {

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

    /// Delete a todo by ID (moves to Trash).
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
        _ = tags  // Tags are applied separately.

        return """
        (() => {
            const app = Application('Things3');
            const todo = app.toDos.byId('\(id.jxaEscaped)');

            if (!todo.exists()) {
                return JSON.stringify({ success: false, error: 'Todo not found' });
            }

            \(name != nil ? "todo.name = '\(name!.jxaEscaped)';" : "")
            \(notes != nil ? "todo.notes = '\(notes!.jxaEscaped)';" : "")
            \(dueDateISO != nil ? "todo.dueDate = new Date('\(dueDateISO!)');" : "")

            return JSON.stringify({ success: true, id: '\(id.jxaEscaped)' });
        })()
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
        _ = tags  // Tags are applied separately via AppleScript.
        let checklistArray = checklistItems.map { "\"\($0.appleScriptEscaped)\"" }.joined(separator: ", ")

        var propsCode = "name: \"\(name.appleScriptEscaped)\""
        if let notes = notes, !notes.isEmpty {
            propsCode += ", notes: \"\(notes.appleScriptEscaped)\""
        }

        return """
        tell application "Things3"
            set newTodo to make new to do with properties {\(propsCode)}

            \(project != nil ? """
            if exists project "\(project!.appleScriptEscaped)" then
                set project of newTodo to project "\(project!.appleScriptEscaped)"
            end if
            """ : "")

            \(area != nil ? """
            if exists area "\(area!.appleScriptEscaped)" then
                set area of newTodo to area "\(area!.appleScriptEscaped)"
            end if
            """ : "")

            \(when != nil ? "schedule newTodo for date \"\(when!.appleScriptEscaped)\"" : "")
            \(deadline != nil ? "set due date of newTodo to date \"\(deadline!.appleScriptEscaped)\"" : "")

            set checklistItems to {\(checklistArray)}
            repeat with itemName in checklistItems
                make new to do with properties {name:itemName} at newTodo
            end repeat

            return id of newTodo
        end tell
        """
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
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    /// Escape a string for safe use in AppleScript double-quoted strings.
    var appleScriptEscaped: String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
