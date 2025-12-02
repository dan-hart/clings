//! Event handling for the TUI.

use std::time::Duration;

use crossterm::event::{self, Event, KeyCode, KeyModifiers};

use crate::error::ClingsError;
use crate::tui::app::App;

/// Action to take after handling an event.
pub enum Action {
    /// Quit the application.
    Quit,
    /// Refresh the todo list.
    Refresh,
    /// Complete the selected todo.
    Complete,
    /// Cancel the selected todo.
    Cancel,
    /// Open the selected todo in Things.
    Open,
}

/// Handle terminal events.
///
/// Returns an action to take, or None if no action is needed.
///
/// # Errors
///
/// Returns an error if event polling fails.
pub fn handle_events(app: &mut App<'_>) -> Result<Option<Action>, ClingsError> {
    // Poll for events with a small timeout
    if event::poll(Duration::from_millis(100))
        .map_err(|e| ClingsError::Config(format!("Event poll failed: {e}")))?
    {
        if let Event::Key(key) = event::read()
            .map_err(|e| ClingsError::Config(format!("Event read failed: {e}")))?
        {
            // Handle Ctrl+C
            if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
                return Ok(Some(Action::Quit));
            }

            match key.code {
                // Quit
                KeyCode::Char('q') | KeyCode::Esc => {
                    app.cancel_pending();
                    return Ok(Some(Action::Quit));
                }

                // Navigation - vim style
                KeyCode::Char('j') | KeyCode::Down => {
                    app.cancel_pending();
                    app.select_next();
                }
                KeyCode::Char('k') | KeyCode::Up => {
                    app.cancel_pending();
                    app.select_previous();
                }

                // Jump to top/bottom
                KeyCode::Char('g') => {
                    app.handle_g();
                }
                KeyCode::Char('G') => {
                    app.cancel_pending();
                    app.select_last();
                }
                KeyCode::Home => {
                    app.cancel_pending();
                    app.select_first();
                }
                KeyCode::End => {
                    app.cancel_pending();
                    app.select_last();
                }

                // Actions
                KeyCode::Char('c') => {
                    app.cancel_pending();
                    return Ok(Some(Action::Complete));
                }
                KeyCode::Char('x') => {
                    app.cancel_pending();
                    return Ok(Some(Action::Cancel));
                }
                KeyCode::Enter => {
                    app.cancel_pending();
                    return Ok(Some(Action::Open));
                }

                // Refresh
                KeyCode::Char('r') => {
                    app.cancel_pending();
                    return Ok(Some(Action::Refresh));
                }

                // Help
                KeyCode::Char('?') => {
                    app.cancel_pending();
                    app.status = Some(
                        "j/k:nav | c:complete | x:cancel | Enter:open | r:refresh | q:quit"
                            .to_string(),
                    );
                }

                _ => {
                    app.cancel_pending();
                }
            }
        }
    }

    Ok(None)
}
