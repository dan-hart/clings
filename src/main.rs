use anyhow::Result;
use clap::Parser;
use colored::Colorize;

use clings::cli::args::{BulkCommands, Cli, Commands};
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
        Commands::Add(args) => commands::quick_add(&client, args, format)?,
        Commands::Inbox => commands::inbox(&client, format)?,
        Commands::Today => commands::today(&client, format)?,
        Commands::Upcoming => commands::upcoming(&client, format)?,
        Commands::Anytime => commands::anytime(&client, format)?,
        Commands::Someday => commands::someday(&client, format)?,
        Commands::Logbook => commands::logbook(&client, format)?,
        Commands::Todo(args) => commands::todo(&client, args.command, format)?,
        Commands::Project(args) => commands::project(&client, args.command, format)?,
        Commands::Areas => commands::areas(&client, format)?,
        Commands::Tags => commands::tags(&client, format)?,
        Commands::Search { query } => commands::search(&client, &query, format)?,
        Commands::Open { target } => commands::open(&client, &target)?,
        Commands::Filter { query } => commands::filter(&client, &query, format)?,
        Commands::Bulk(args) => match args.command {
            BulkCommands::Complete { r#where, dry_run, bypass_bulk_data_check, limit } => {
                commands::bulk_complete(&client, Some(&r#where), dry_run, bypass_bulk_data_check, limit, format)?
            }
            BulkCommands::Cancel { r#where, dry_run, bypass_bulk_data_check, limit } => {
                commands::bulk_cancel(&client, Some(&r#where), dry_run, bypass_bulk_data_check, limit, format)?
            }
            BulkCommands::Tag {
                r#where,
                tags,
                dry_run,
                bypass_bulk_data_check,
                limit,
            } => commands::bulk_tag(&client, Some(&r#where), &tags, dry_run, bypass_bulk_data_check, limit, format)?,
            BulkCommands::Move {
                r#where,
                to,
                dry_run,
                bypass_bulk_data_check,
                limit,
            } => commands::bulk_move(&client, Some(&r#where), &to, dry_run, bypass_bulk_data_check, limit, format)?,
            BulkCommands::SetDue {
                r#where,
                date,
                dry_run,
                bypass_bulk_data_check,
                limit,
            } => commands::bulk_set_due(&client, Some(&r#where), &date, dry_run, bypass_bulk_data_check, limit, format)?,
            BulkCommands::ClearDue { r#where, dry_run, bypass_bulk_data_check, limit } => {
                commands::bulk_clear_due(&client, Some(&r#where), dry_run, bypass_bulk_data_check, limit, format)?
            }
        },
        Commands::Pick(args) => commands::pick(
            &client,
            args.list.as_deref(),
            args.action.into(),
            args.multi,
            args.query.as_deref(),
            args.preview,
            format,
        )?,
        Commands::Review(args) => commands::review(client, &args, format)?,
        Commands::Template(args) => commands::template(&client, args.command, format)?,
        Commands::Shell(args) => commands::shell(&client, args.command, format)?,
        Commands::Pipe(args) => commands::pipe(&client, args.command, format)?,
        Commands::Git(args) => commands::git(&client, args.command, format)?,
        Commands::Stats(args) => commands::stats(&client, args.command, format)?,
        Commands::Focus(args) => commands::focus(&client, args.command, format)?,
        Commands::Sync(args) => commands::sync(&client, args.command, format)?,
        Commands::Automation(args) => commands::automation(&client, args.command, format)?,
        Commands::Tui => {
            clings::tui::run(&client)?;
            String::new()
        }
    };

    if !output.is_empty() {
        println!("{}", output);
    }
    Ok(())
}
