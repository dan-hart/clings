// clings - A powerful CLI for Things 3
// Copyright (C) 2024 Dan Hart
// SPDX-License-Identifier: GPL-3.0-or-later

import ArgumentParser

struct CompletionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "completions",
        abstract: "Generate shell completions",
        discussion: """
        Generate bash, zsh, or fish completions from the actual command tree.

        Writes the script to stdout without installing it. Create the destination
        directory before redirecting. Bash requires sourcing the generated file;
        zsh requires ~/.zfunc in fpath before compinit. Fish loads its completions
        directory automatically. See docs/cli/getting-started.md for setup.

        EXAMPLES:
          clings completions bash > ~/.bash_completion.d/clings
          clings completions zsh > ~/.zfunc/_clings
          clings completions fish > ~/.config/fish/completions/clings.fish
        """
    )

    @Argument(help: "Shell to generate completions for (bash, zsh, fish)")
    var shell: Shell

    enum Shell: String, ExpressibleByArgument, CaseIterable {
        case bash, zsh, fish

        var completionShell: CompletionShell {
            switch self {
            case .bash: .bash
            case .zsh: .zsh
            case .fish: .fish
            }
        }
    }

    var script: String {
        Clings.completionScript(for: shell.completionShell)
    }

    func run() throws {
        print(script)
    }
}
