//! Application state for the TUI.

use crate::error::ClingsError;
use crate::things::{ListView, ThingsClient, Todo};

/// Application state.
pub struct App<'a> {
    /// Reference to the Things client.
    client: &'a ThingsClient,
    /// Current list of todos.
    pub todos: Vec<Todo>,
    /// Currently selected index.
    pub selected: usize,
    /// Current view.
    pub view: ListView,
    /// Status message to display.
    pub status: Option<String>,
    /// Whether the app should quit.
    pub should_quit: bool,
    /// Pending 'g' key for 'gg' command.
    pub pending_g: bool,
}

impl<'a> App<'a> {
    /// Create a new app instance.
    ///
    /// # Errors
    ///
    /// Returns an error if fetching todos fails.
    pub fn new(client: &'a ThingsClient) -> Result<Self, ClingsError> {
        let todos = client.get_list(ListView::Today)?;

        Ok(Self {
            client,
            todos,
            selected: 0,
            view: ListView::Today,
            status: Some("Press ? for help".to_string()),
            should_quit: false,
            pending_g: false,
        })
    }

    /// Refresh todos from Things.
    ///
    /// # Errors
    ///
    /// Returns an error if fetching todos fails.
    pub fn refresh(&mut self) -> Result<(), ClingsError> {
        self.todos = self.client.get_list(self.view)?;

        // Adjust selection if it's out of bounds
        if !self.todos.is_empty() && self.selected >= self.todos.len() {
            self.selected = self.todos.len() - 1;
        }

        self.status = Some(format!("Refreshed {} items", self.todos.len()));
        Ok(())
    }

    /// Get the currently selected todo.
    pub fn selected_todo(&self) -> Option<&Todo> {
        self.todos.get(self.selected)
    }

    /// Move selection up.
    pub fn select_previous(&mut self) {
        if self.selected > 0 {
            self.selected -= 1;
        }
        self.pending_g = false;
    }

    /// Move selection down.
    pub fn select_next(&mut self) {
        if !self.todos.is_empty() && self.selected < self.todos.len() - 1 {
            self.selected += 1;
        }
        self.pending_g = false;
    }

    /// Jump to first item.
    pub fn select_first(&mut self) {
        self.selected = 0;
        self.pending_g = false;
    }

    /// Jump to last item.
    pub fn select_last(&mut self) {
        if !self.todos.is_empty() {
            self.selected = self.todos.len() - 1;
        }
        self.pending_g = false;
    }

    /// Complete the selected todo.
    ///
    /// # Errors
    ///
    /// Returns an error if the operation fails.
    pub fn complete_selected(&mut self) -> Result<(), ClingsError> {
        if let Some(todo) = self.selected_todo() {
            let name = todo.name.clone();
            let id = todo.id.clone();
            self.client.complete_todo(&id)?;
            self.status = Some(format!("Completed: {name}"));
            self.refresh()?;
        }
        Ok(())
    }

    /// Cancel the selected todo.
    ///
    /// # Errors
    ///
    /// Returns an error if the operation fails.
    pub fn cancel_selected(&mut self) -> Result<(), ClingsError> {
        if let Some(todo) = self.selected_todo() {
            let name = todo.name.clone();
            let id = todo.id.clone();
            self.client.cancel_todo(&id)?;
            self.status = Some(format!("Canceled: {name}"));
            self.refresh()?;
        }
        Ok(())
    }

    /// Open the selected todo in Things.
    ///
    /// # Errors
    ///
    /// Returns an error if the operation fails.
    pub fn open_selected(&mut self) -> Result<(), ClingsError> {
        if let Some(todo) = self.selected_todo() {
            let name = todo.name.clone();
            let id = todo.id.clone();
            self.client.open(&id)?;
            self.status = Some(format!("Opened: {name}"));
        }
        Ok(())
    }

    /// Handle 'g' key for 'gg' command.
    pub fn handle_g(&mut self) {
        if self.pending_g {
            // Second 'g' - go to top
            self.select_first();
        } else {
            // First 'g' - wait for second
            self.pending_g = true;
            self.status = Some("g-".to_string());
        }
    }

    /// Cancel pending 'g' command.
    pub fn cancel_pending(&mut self) {
        self.pending_g = false;
        self.status = None;
    }
}
