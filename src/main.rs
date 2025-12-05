#![deny(unsafe_code)]
#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]
#![warn(clippy::pedantic)]
#![warn(clippy::nursery)]
#![allow(clippy::module_name_repetitions)]

use anyhow::Result;
use clap::Parser;
use colored::Colorize;

use clings::cli::args::{BulkCommands, Cli, Commands, SearchArgs};
use clings::cli::commands;
use clings::error::ClingsError;
use clings::things::ThingsClient;

fn main() {
    if let Err(e) = run() {
        eprintln!("{}: {}", "error".red().bold(), e);
        std::process::exit(1);
    }
}

fn run() -> Result<(), ClingsError> {
    let cli = Cli::parse();
    let client = ThingsClient::new();
    let format = cli.output;

    let output = match cli.command {
        // Consolidated list command
        Commands::List { view } => commands::list(&client, view.as_deref(), format)?,

        // Convenience aliases for list views
        Commands::Today => commands::list(&client, Some("today"), format)?,
        Commands::Inbox => commands::list(&client, Some("inbox"), format)?,
        Commands::Upcoming => commands::list(&client, Some("upcoming"), format)?,
        Commands::Anytime => commands::list(&client, Some("anytime"), format)?,
        Commands::Someday => commands::list(&client, Some("someday"), format)?,
        Commands::Logbook => commands::list(&client, Some("logbook"), format)?,

        // Quick add
        Commands::Add(args) => commands::quick_add(&client, args, format)?,

        // Todo CRUD
        Commands::Todo(args) => commands::todo(&client, args.command, format)?,

        // Project CRUD
        Commands::Project(args) => commands::project(&client, args.command, format)?,

        // Search with optional filters
        Commands::Search(SearchArgs {
            query,
            tag,
            project,
            due,
            filter,
        }) => commands::search(
            &client,
            query.as_deref(),
            tag.as_deref(),
            project.as_deref(),
            due.as_deref(),
            filter.as_deref(),
            format,
        )?,

        // Open in Things app
        Commands::Open { target } => commands::open(&client, &target)?,

        // Bulk operations
        Commands::Bulk(args) => match args.command {
            BulkCommands::Complete {
                r#where,
                dry_run,
                bypass_bulk_data_check,
                limit,
            } => commands::bulk_complete(
                &client,
                Some(&r#where),
                dry_run,
                bypass_bulk_data_check,
                limit,
                format,
            )?,
            BulkCommands::Cancel {
                r#where,
                dry_run,
                bypass_bulk_data_check,
                limit,
            } => commands::bulk_cancel(
                &client,
                Some(&r#where),
                dry_run,
                bypass_bulk_data_check,
                limit,
                format,
            )?,
            BulkCommands::Tag {
                r#where,
                tags,
                dry_run,
                bypass_bulk_data_check,
                limit,
            } => commands::bulk_tag(
                &client,
                Some(&r#where),
                &tags,
                dry_run,
                bypass_bulk_data_check,
                limit,
                format,
            )?,
            BulkCommands::Move {
                r#where,
                to,
                dry_run,
                bypass_bulk_data_check,
                limit,
            } => commands::bulk_move(
                &client,
                Some(&r#where),
                &to,
                dry_run,
                bypass_bulk_data_check,
                limit,
                format,
            )?,
        },

        // Stats
        Commands::Stats(args) => commands::stats(&client, &args, format)?,

        // Review
        Commands::Review(args) => commands::review(client, &args, format)?,

        // Shell completions
        Commands::Shell(args) => commands::shell(&client, args.command, format)?,

        // TUI
        Commands::Tui => {
            clings::tui::run(&client)?;
            String::new()
        },
    };

    if !output.is_empty() {
        println!("{output}");
    }
    Ok(())
}
