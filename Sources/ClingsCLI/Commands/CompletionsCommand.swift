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

        Installation:
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
            local commands="today inbox upcoming anytime someday logbook projects areas tags show add complete cancel delete search bulk open stats review completions"

            # Bulk subcommands
            local bulk_commands="complete cancel tag"

            # Review subcommands
            local review_commands="start status clear"

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
                'areas:List all areas'
                'tags:List all tags'
                'show:Show details of a todo'
                'add:Add a new todo'
                'complete:Mark a todo as completed'
                'cancel:Cancel a todo'
                'delete:Delete a todo'
                'search:Search todos'
                'bulk:Bulk operations'
                'open:Open in Things'
                'stats:Show statistics'
                'review:Weekly review workflow'
                'completions:Generate shell completions'
            )

            local -a bulk_commands
            bulk_commands=(
                'complete:Mark multiple todos as completed'
                'cancel:Cancel multiple todos'
                'tag:Add tags to multiple todos'
            )

            local -a review_commands
            review_commands=(
                'start:Start or resume a weekly review'
                'status:Show review session status'
                'clear:Clear the review session'
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
        complete -c clings -n "__fish_use_subcommand" -a "areas" -d "List all areas"
        complete -c clings -n "__fish_use_subcommand" -a "tags" -d "List all tags"
        complete -c clings -n "__fish_use_subcommand" -a "show" -d "Show details of a todo"
        complete -c clings -n "__fish_use_subcommand" -a "add" -d "Add a new todo"
        complete -c clings -n "__fish_use_subcommand" -a "complete" -d "Mark a todo as completed"
        complete -c clings -n "__fish_use_subcommand" -a "cancel" -d "Cancel a todo"
        complete -c clings -n "__fish_use_subcommand" -a "delete" -d "Delete a todo"
        complete -c clings -n "__fish_use_subcommand" -a "search" -d "Search todos"
        complete -c clings -n "__fish_use_subcommand" -a "bulk" -d "Bulk operations"
        complete -c clings -n "__fish_use_subcommand" -a "open" -d "Open in Things"
        complete -c clings -n "__fish_use_subcommand" -a "stats" -d "Show statistics"
        complete -c clings -n "__fish_use_subcommand" -a "review" -d "Weekly review workflow"
        complete -c clings -n "__fish_use_subcommand" -a "completions" -d "Generate shell completions"

        # Bulk subcommands
        complete -c clings -n "__fish_seen_subcommand_from bulk" -a "complete" -d "Mark multiple todos as completed"
        complete -c clings -n "__fish_seen_subcommand_from bulk" -a "cancel" -d "Cancel multiple todos"
        complete -c clings -n "__fish_seen_subcommand_from bulk" -a "tag" -d "Add tags to multiple todos"

        # Review subcommands
        complete -c clings -n "__fish_seen_subcommand_from review" -a "start" -d "Start or resume a weekly review"
        complete -c clings -n "__fish_seen_subcommand_from review" -a "status" -d "Show review session status"
        complete -c clings -n "__fish_seen_subcommand_from review" -a "clear" -d "Clear the review session"

        # Completions subcommand
        complete -c clings -n "__fish_seen_subcommand_from completions" -a "bash zsh fish"

        # Global options
        complete -c clings -l json -d "Output as JSON"
        complete -c clings -l no-color -d "Disable colored output"
        complete -c clings -s h -l help -d "Show help"
        complete -c clings -l version -d "Show version"
        """
    }
}
