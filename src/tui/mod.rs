//! Terminal User Interface (TUI) for clings.
//!
//! Provides an interactive terminal interface for managing Things 3 todos.
//! Built with ratatui and crossterm.

mod app;
mod event;
mod ui;

pub use app::App;

use std::io;

use crossterm::{
    event::{DisableMouseCapture, EnableMouseCapture},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::prelude::*;

use crate::error::ClingsError;
use crate::things::ThingsClient;

/// Run the TUI application.
///
/// # Errors
///
/// Returns an error if the TUI fails to initialize or run.
pub fn run(client: &ThingsClient) -> Result<(), ClingsError> {
    // Setup terminal
    enable_raw_mode().map_err(|e| ClingsError::Config(format!("Failed to enable raw mode: {e}")))?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)
        .map_err(|e| ClingsError::Config(format!("Failed to setup terminal: {e}")))?;

    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)
        .map_err(|e| ClingsError::Config(format!("Failed to create terminal: {e}")))?;

    // Create app state and run main loop
    let mut app = App::new(client)?;
    let result = run_app(&mut terminal, &mut app);

    // Restore terminal
    disable_raw_mode().ok();
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )
    .ok();
    terminal.show_cursor().ok();

    result
}

/// Run the main application loop.
fn run_app<B: Backend>(terminal: &mut Terminal<B>, app: &mut App<'_>) -> Result<(), ClingsError> {
    loop {
        // Draw UI
        terminal
            .draw(|frame| ui::render(frame, app))
            .map_err(|e| ClingsError::Config(format!("Failed to draw: {e}")))?;

        // Handle events
        if let Some(action) = event::handle_events(app)? {
            match action {
                event::Action::Quit => break,
                event::Action::Refresh => app.refresh()?,
                event::Action::Complete => app.complete_selected()?,
                event::Action::Cancel => app.cancel_selected()?,
                event::Action::Open => app.open_selected()?,
            }
        }
    }

    Ok(())
}
