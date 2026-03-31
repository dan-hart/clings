// CompletionsCommand.swift
// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser

struct CompletionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "completions",
        abstract: "Generate shell completions",
        discussion: """
        Generate shell completion scripts for bash, zsh, or fish.

        EXAMPLES:
          bash:  clings completions bash > ~/.bash_completion.d/clings
          zsh:   clings completions zsh > ~/.zfunc/_clings
          fish:  clings completions fish > ~/.config/fish/completions/clings.fish
        """
    )

    @Argument(help: "Shell to generate completions for (bash, zsh, fish)")
    var shell: Shell

    enum Shell: String, ExpressibleByArgument, CaseIterable {
        case bash
        case zsh
        case fish
    }

    func run() throws {
        let completions: String

        switch shell {
        case .bash:
            completions = generateBashCompletions()
        case .zsh:
            completions = generateZshCompletions()
        case .fish:
            completions = generateFishCompletions()
        }

        print(completions)
    }

    private func generateBashCompletions() -> String {
        """
        # clings bash completions
        _clings() {
            local cur prev opts
            COMPREPLY=()
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"

            # Main commands
            local commands="today inbox upcoming anytime someday logbook projects project areas tags show add complete cancel delete update search views template undo focus pick doctor bulk filter open stats review completions config"

            # Bulk subcommands
            local bulk_commands="complete cancel tag move"

            # Project subcommands
            local project_commands="list add audit"

            # Tag subcommands
            local tag_commands="list add delete rename"

            # Review subcommands
            local review_commands="start status clear"

            # Stats subcommands
            local stats_commands="trends heatmap"

            # Views subcommands
            local views_commands="list save run delete"

            # Template subcommands
            local template_commands="list save run delete"

            # Pick subcommands
            local pick_commands="show complete cancel delete"

            case "${prev}" in
                clings)
                    COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
                    return 0
                    ;;
                bulk)
                    COMPREPLY=( $(compgen -W "${bulk_commands}" -- ${cur}) )
                    return 0
                    ;;
                review)
                    COMPREPLY=( $(compgen -W "${review_commands}" -- ${cur}) )
                    return 0
                    ;;
                project)
                    COMPREPLY=( $(compgen -W "${project_commands}" -- ${cur}) )
                    return 0
                    ;;
                tags)
                    COMPREPLY=( $(compgen -W "${tag_commands}" -- ${cur}) )
                    return 0
                    ;;
                stats)
                    COMPREPLY=( $(compgen -W "${stats_commands}" -- ${cur}) )
                    return 0
                    ;;
                views)
                    COMPREPLY=( $(compgen -W "${views_commands}" -- ${cur}) )
                    return 0
                    ;;
                template)
                    COMPREPLY=( $(compgen -W "${template_commands}" -- ${cur}) )
                    return 0
                    ;;
                pick)
                    COMPREPLY=( $(compgen -W "${pick_commands}" -- ${cur}) )
                    return 0
                    ;;
                completions)
                    COMPREPLY=( $(compgen -W "bash zsh fish" -- ${cur}) )
                    return 0
                    ;;
                --list)
                    COMPREPLY=( $(compgen -W "today inbox upcoming anytime someday logbook" -- ${cur}) )
                    return 0
                    ;;
                *)
                    ;;
            esac

            # Global options
            if [[ ${cur} == -* ]] ; then
                local opts="--json --no-color --help --version"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                return 0
            fi
        }
        complete -F _clings clings
        """
    }

    private func generateZshCompletions() -> String {
        """
        #compdef clings

        _clings() {
            local -a commands
            commands=(
                'today:Show today'"'"'s todos'
                'inbox:Show inbox todos'
                'upcoming:Show upcoming todos'
                'anytime:Show anytime todos'
                'someday:Show someday todos'
                'logbook:Show completed todos'
                'projects:List all projects'
                'project:Manage projects'
                'areas:List all areas'
                'tags:Manage tags'
                'show:Show details of a todo'
                'add:Add a new todo'
                'complete:Mark a todo as completed'
                'cancel:Cancel a todo'
                'delete:Delete a todo'
                'update:Update a todo'
                'search:Search todos'
                'views:Manage saved filter views'
                'template:Manage reusable task templates'
                'undo:Undo the most recent supported mutation'
                'focus:Show a focused queue of high-attention tasks'
                'pick:Interactively pick a todo for a follow-up action'
                'doctor:Check clings setup and local environment'
                'bulk:Bulk operations'
                'filter:Filter todos'
                'open:Open in Things (currently disabled)'
                'stats:Show statistics'
                'review:Weekly review workflow'
                'completions:Generate shell completions'
                'config:Configure clings settings'
            )

            local -a bulk_commands
            bulk_commands=(
                'complete:Mark multiple todos as completed'
                'cancel:Cancel multiple todos'
                'tag:Add tags to multiple todos'
                'move:Move multiple todos to a project'
            )

            local -a review_commands
            review_commands=(
                'start:Start or resume a weekly review'
                'status:Show review session status'
                'clear:Clear the review session'
            )

            local -a project_commands
            project_commands=(
                'list:List all projects'
                'add:Create a new project'
                'audit:Audit project health and missing next actions'
            )

            local -a tag_commands
            tag_commands=(
                'list:List all tags'
                'add:Create a new tag'
                'delete:Delete a tag'
                'rename:Rename a tag'
            )

            local -a stats_commands
            stats_commands=(
                'trends:Show completion trends over time'
                'heatmap:Show contribution heatmap'
            )

            local -a views_commands
            views_commands=(
                'list:List saved views'
                'save:Save a named filter view'
                'run:Run a saved filter view'
                'delete:Delete a saved view'
            )

            local -a template_commands
            template_commands=(
                'list:List saved templates'
                'save:Save a task template'
                'run:Create a task from a template'
                'delete:Delete a template'
            )

            local -a pick_commands
            pick_commands=(
                'show:Interactively pick a todo to inspect'
                'complete:Interactively pick a todo to complete'
                'cancel:Interactively pick a todo to cancel'
                'delete:Interactively pick a todo to delete'
            )

            local -a config_commands
            config_commands=(
                'set-auth-token:Set the Things auth token'
            )

            _arguments -C \\
                '1: :->command' \\
                '2: :->subcommand' \\
                '*::arg:->args'

            case $state in
                command)
                    _describe 'command' commands
                    ;;
                subcommand)
                    case $words[1] in
                        bulk)
                            _describe 'bulk command' bulk_commands
                            ;;
                        review)
                            _describe 'review command' review_commands
                            ;;
                        project)
                            _describe 'project command' project_commands
                            ;;
                        tags)
                            _describe 'tags command' tag_commands
                            ;;
                        stats)
                            _describe 'stats command' stats_commands
                            ;;
                        views)
                            _describe 'views command' views_commands
                            ;;
                        template)
                            _describe 'template command' template_commands
                            ;;
                        pick)
                            _describe 'pick command' pick_commands
                            ;;
                        config)
                            _describe 'config command' config_commands
                            ;;
                        completions)
                            _values 'shell' bash zsh fish
                            ;;
                    esac
                    ;;
            esac
        }

        _clings "$@"
        """
    }

    private func generateFishCompletions() -> String {
        """
        # clings fish completions

        # Disable file completions
        complete -c clings -f

        # Main commands
        complete -c clings -n "__fish_use_subcommand" -a "today" -d "Show today's todos"
        complete -c clings -n "__fish_use_subcommand" -a "inbox" -d "Show inbox todos"
        complete -c clings -n "__fish_use_subcommand" -a "upcoming" -d "Show upcoming todos"
        complete -c clings -n "__fish_use_subcommand" -a "anytime" -d "Show anytime todos"
        complete -c clings -n "__fish_use_subcommand" -a "someday" -d "Show someday todos"
        complete -c clings -n "__fish_use_subcommand" -a "logbook" -d "Show completed todos"
        complete -c clings -n "__fish_use_subcommand" -a "projects" -d "List all projects"
        complete -c clings -n "__fish_use_subcommand" -a "project" -d "Manage projects"
        complete -c clings -n "__fish_use_subcommand" -a "areas" -d "List all areas"
        complete -c clings -n "__fish_use_subcommand" -a "tags" -d "Manage tags"
        complete -c clings -n "__fish_use_subcommand" -a "show" -d "Show details of a todo"
        complete -c clings -n "__fish_use_subcommand" -a "add" -d "Add a new todo"
        complete -c clings -n "__fish_use_subcommand" -a "complete" -d "Mark a todo as completed"
        complete -c clings -n "__fish_use_subcommand" -a "cancel" -d "Cancel a todo"
        complete -c clings -n "__fish_use_subcommand" -a "delete" -d "Delete a todo"
        complete -c clings -n "__fish_use_subcommand" -a "update" -d "Update a todo"
        complete -c clings -n "__fish_use_subcommand" -a "search" -d "Search todos"
        complete -c clings -n "__fish_use_subcommand" -a "views" -d "Manage saved filter views"
        complete -c clings -n "__fish_use_subcommand" -a "template" -d "Manage reusable task templates"
        complete -c clings -n "__fish_use_subcommand" -a "undo" -d "Undo the most recent supported mutation"
        complete -c clings -n "__fish_use_subcommand" -a "focus" -d "Show a focused queue of high-attention tasks"
        complete -c clings -n "__fish_use_subcommand" -a "pick" -d "Interactively pick a todo for a follow-up action"
        complete -c clings -n "__fish_use_subcommand" -a "doctor" -d "Check clings setup and local environment"
        complete -c clings -n "__fish_use_subcommand" -a "bulk" -d "Bulk operations"
        complete -c clings -n "__fish_use_subcommand" -a "filter" -d "Filter todos"
        complete -c clings -n "__fish_use_subcommand" -a "open" -d "Open in Things (currently disabled)"
        complete -c clings -n "__fish_use_subcommand" -a "stats" -d "Show statistics"
        complete -c clings -n "__fish_use_subcommand" -a "review" -d "Weekly review workflow"
        complete -c clings -n "__fish_use_subcommand" -a "completions" -d "Generate shell completions"
        complete -c clings -n "__fish_use_subcommand" -a "config" -d "Configure clings settings"

        # Bulk subcommands
        complete -c clings -n "__fish_seen_subcommand_from bulk" -a "complete" -d "Mark multiple todos as completed"
        complete -c clings -n "__fish_seen_subcommand_from bulk" -a "cancel" -d "Cancel multiple todos"
        complete -c clings -n "__fish_seen_subcommand_from bulk" -a "tag" -d "Add tags to multiple todos"
        complete -c clings -n "__fish_seen_subcommand_from bulk" -a "move" -d "Move multiple todos to a project"

        # Project subcommands
        complete -c clings -n "__fish_seen_subcommand_from project" -a "list" -d "List all projects"
        complete -c clings -n "__fish_seen_subcommand_from project" -a "add" -d "Create a new project"
        complete -c clings -n "__fish_seen_subcommand_from project" -a "audit" -d "Audit project health and missing next actions"

        # Tag subcommands
        complete -c clings -n "__fish_seen_subcommand_from tags" -a "list" -d "List all tags"
        complete -c clings -n "__fish_seen_subcommand_from tags" -a "add" -d "Create a new tag"
        complete -c clings -n "__fish_seen_subcommand_from tags" -a "delete" -d "Delete a tag"
        complete -c clings -n "__fish_seen_subcommand_from tags" -a "rename" -d "Rename a tag"

        # Views subcommands
        complete -c clings -n "__fish_seen_subcommand_from views" -a "list" -d "List saved views"
        complete -c clings -n "__fish_seen_subcommand_from views" -a "save" -d "Save a named filter view"
        complete -c clings -n "__fish_seen_subcommand_from views" -a "run" -d "Run a saved filter view"
        complete -c clings -n "__fish_seen_subcommand_from views" -a "delete" -d "Delete a saved view"

        # Template subcommands
        complete -c clings -n "__fish_seen_subcommand_from template" -a "list" -d "List saved templates"
        complete -c clings -n "__fish_seen_subcommand_from template" -a "save" -d "Save a task template"
        complete -c clings -n "__fish_seen_subcommand_from template" -a "run" -d "Create a task from a template"
        complete -c clings -n "__fish_seen_subcommand_from template" -a "delete" -d "Delete a template"

        # Pick subcommands
        complete -c clings -n "__fish_seen_subcommand_from pick" -a "show" -d "Interactively pick a todo to inspect"
        complete -c clings -n "__fish_seen_subcommand_from pick" -a "complete" -d "Interactively pick a todo to complete"
        complete -c clings -n "__fish_seen_subcommand_from pick" -a "cancel" -d "Interactively pick a todo to cancel"
        complete -c clings -n "__fish_seen_subcommand_from pick" -a "delete" -d "Interactively pick a todo to delete"

        # Review subcommands
        complete -c clings -n "__fish_seen_subcommand_from review" -a "start" -d "Start or resume a weekly review"
        complete -c clings -n "__fish_seen_subcommand_from review" -a "status" -d "Show review session status"
        complete -c clings -n "__fish_seen_subcommand_from review" -a "clear" -d "Clear the review session"

        # Stats subcommands
        complete -c clings -n "__fish_seen_subcommand_from stats" -a "trends" -d "Show completion trends over time"
        complete -c clings -n "__fish_seen_subcommand_from stats" -a "heatmap" -d "Show contribution heatmap"

        # Completions subcommand
        complete -c clings -n "__fish_seen_subcommand_from completions" -a "bash zsh fish"

        # Config subcommands
        complete -c clings -n "__fish_seen_subcommand_from config" -a "set-auth-token" -d "Set the Things auth token"

        # Global options
        complete -c clings -l json -d "Output as JSON"
        complete -c clings -l no-color -d "Disable colored output"
        complete -c clings -s h -l help -d "Show help"
        complete -c clings -l version -d "Show version"
        """
    }
}
