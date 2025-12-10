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
                    creationDate: todo.creationDate().toISOString(),
                    modificationDate: todo.modificationDate().toISOString()
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
                creationDate: todo.creationDate().toISOString(),
                modificationDate: todo.modificationDate().toISOString()
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

    /// Create a new todo with the given properties.
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
        let tagsArray = tags.map { "'\($0.jxaEscaped)'" }.joined(separator: ", ")
        let checklistArray = checklistItems.map { "'\($0.jxaEscaped)'" }.joined(separator: ", ")

        var propsCode = "name: '\(name.jxaEscaped)'"
        if let notes = notes, !notes.isEmpty {
            propsCode += ", notes: '\(notes.jxaEscaped)'"
        }

        return """
        (() => {
            const app = Application('Things3');

            const props = { \(propsCode) };
            const todo = app.make({ new: 'to do', withProperties: props });

            // Set when date
            \(when != nil ? "todo.activationDate = new Date('\(when!.jxaEscaped)');" : "")

            // Set deadline
            \(deadline != nil ? "todo.dueDate = new Date('\(deadline!.jxaEscaped)');" : "")

            // Add tags
            const tagNames = [\(tagsArray)];
            tagNames.forEach(tagName => {
                let tag = app.tags.byName(tagName);
                if (!tag.exists()) {
                    tag = app.make({ new: 'tag', withProperties: { name: tagName }});
                }
                todo.tags.push(tag);
            });

            // Add to project
            \(project != nil ? """
            const project = app.projects.byName('\(project!.jxaEscaped)');
            if (project.exists()) {
                todo.project = project;
            }
            """ : "")

            // Add to area
            \(area != nil ? """
            const area = app.areas.byName('\(area!.jxaEscaped)');
            if (area.exists()) {
                todo.area = area;
            }
            """ : "")

            // Add checklist items
            const checklistItems = [\(checklistArray)];
            checklistItems.forEach(itemName => {
                app.make({
                    new: 'to do',
                    withProperties: { name: itemName },
                    at: todo
                });
            });

            return JSON.stringify({
                success: true,
                id: todo.id(),
                name: todo.name()
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

                return {
                    id: todo.id(),
                    name: todo.name(),
                    notes: todo.notes() || null,
                    status: todo.status(),
                    dueDate: todo.dueDate() ? todo.dueDate().toISOString() : null,
                    tags: todo.tags().map(t => ({ id: t.id(), name: t.name() })),
                    project: proj,
                    creationDate: todo.creationDate().toISOString(),
                    modificationDate: todo.modificationDate().toISOString()
                };
            }));
        })()
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
}
