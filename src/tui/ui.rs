//! UI rendering for the TUI.

use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Frame,
};

use crate::things::types::Status;
use crate::tui::app::App;

/// Render the application UI.
pub fn render(frame: &mut Frame<'_>, app: &App<'_>) {
    // Create layout: header, list, status bar
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header
            Constraint::Min(0),    // List
            Constraint::Length(1), // Status bar
        ])
        .split(frame.area());

    render_header(frame, app, chunks[0]);
    render_list(frame, app, chunks[1]);
    render_status_bar(frame, app, chunks[2]);
}

/// Render the header.
fn render_header(frame: &mut Frame<'_>, app: &App<'_>, area: Rect) {
    let title = format!(" {} ({} items) ", app.view, app.todos.len());

    let header = Paragraph::new(title)
        .style(
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        )
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::Cyan)),
        );

    frame.render_widget(header, area);
}

/// Render the todo list.
fn render_list(frame: &mut Frame<'_>, app: &App<'_>, area: Rect) {
    let items: Vec<ListItem<'_>> = app
        .todos
        .iter()
        .enumerate()
        .map(|(i, todo)| {
            let is_selected = i == app.selected;

            // Status indicator
            let status_icon = match todo.status {
                Status::Open => "[ ]",
                Status::Completed => "[x]",
                Status::Canceled => "[-]",
            };

            // Build the line
            let mut spans = vec![
                Span::styled(
                    format!("{status_icon} "),
                    Style::default().fg(match todo.status {
                        Status::Open => Color::White,
                        Status::Completed => Color::Green,
                        Status::Canceled => Color::Red,
                    }),
                ),
                Span::styled(
                    &todo.name,
                    Style::default().add_modifier(if is_selected {
                        Modifier::BOLD
                    } else {
                        Modifier::empty()
                    }),
                ),
            ];

            // Add project if present
            if let Some(ref project) = todo.project {
                spans.push(Span::styled(
                    format!("  [{project}]"),
                    Style::default().fg(Color::DarkGray),
                ));
            }

            // Add tags if present
            if !todo.tags.is_empty() {
                let tags_str = todo
                    .tags
                    .iter()
                    .map(|t| format!("#{t}"))
                    .collect::<Vec<_>>()
                    .join(" ");
                spans.push(Span::styled(
                    format!("  {tags_str}"),
                    Style::default().fg(Color::Blue),
                ));
            }

            // Add due date if present
            if let Some(due) = todo.due_date {
                spans.push(Span::styled(
                    format!("  {due}"),
                    Style::default().fg(Color::Yellow),
                ));
            }

            let style = if is_selected {
                Style::default().bg(Color::DarkGray)
            } else {
                Style::default()
            };

            ListItem::new(Line::from(spans)).style(style)
        })
        .collect();

    let list = List::new(items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::White)),
        )
        .highlight_style(Style::default().bg(Color::DarkGray));

    // Create list state for scrolling
    let mut state = ListState::default();
    state.select(Some(app.selected));

    frame.render_stateful_widget(list, area, &mut state);
}

/// Render the status bar.
fn render_status_bar(frame: &mut Frame<'_>, app: &App<'_>, area: Rect) {
    let status_text = app
        .status
        .as_deref()
        .unwrap_or("j/k:nav | c:complete | x:cancel | Enter:open | r:refresh | ?:help | q:quit");

    let status = Paragraph::new(status_text).style(Style::default().fg(Color::DarkGray));

    frame.render_widget(status, area);
}
