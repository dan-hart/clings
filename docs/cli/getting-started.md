# Getting started with clings

[README](../../README.md) · [Command reference](command-reference.md) · [Troubleshooting](troubleshooting.md)

## Requirements

- macOS 14 or later, matching `Package.swift`.
- Things 3 for Mac installed, with its local database available.
- A Swift 6 toolchain for source builds. Use `swift --version` to inspect yours.
- `jq` is optional and needed only for the JSON pipeline examples.

SQLite reads do not need to launch Things. Writes use AppleScript/JXA and may launch or communicate with Things. The CLI never writes directly to the Things database.

## Installation

### Homebrew

```bash
brew install dan-hart/tap/clings
clings --version
brew update && brew upgrade clings
```

The tap builds from a published source archive. Its version may lag features documented on `main`. Check `clings COMMAND --help` when using an installed release.

### Source

```bash
git clone https://github.com/dan-hart/clings.git
cd clings
swift build -c release
.build/release/clings --help
```

To install for your user:

```bash
mkdir -p "$HOME/.local/bin"
install .build/release/clings "$HOME/.local/bin/clings"
```

Add `$HOME/.local/bin` to `PATH` in your shell startup file if needed. To try the repository without installing, use `swift run clings --help`.

## First run

```bash
clings --help
clings today
clings inbox --no-color
clings add "Draft outline tomorrow #writing" --parse-only --json
```

`--parse-only` previews parsing without creating a todo or requiring a Things write. Inspect the extracted title and dates, then remove the flag to create it.

Use `clings doctor --verbose` when setup is unclear. It checks config storage, database access, presence of `osascript`, and token configuration. It does not test automation authorization, and warnings do not currently change its exit status.

## Automation permission

When a write first asks for access to Things, allow it if you want to perform that operation. If access was denied, inspect **System Settings > Privacy & Security > Automation** for the terminal or application running clings. Run the command from that same application after changing permission.

Database access and automation permission are separate: a successful `clings today` does not prove that `clings add` can write.

## Things URL auth token

Only `update --when` and `update --heading` need this token. Ordinary reads and `add --when`/`--deadline` do not.

Copy the token from **Things > Settings > General > Enable Things URLs**, then save it without typing the literal value into shell history:

```bash
# Bash/zsh: prompt for the secret instead of putting it in command history
printf 'Things auth token: '
read -r things_token
clings config set-auth-token "$things_token"
unset things_token
```

The prompt above echoes input; avoid entering it while screen sharing. The value is still passed as a process argument during the command. clings stores `auth-token` with permissions `0600`; do not commit or share it.

## Local state

Most clings state lives in `~/.config/clings`:

| File | Purpose |
| --- | --- |
| `auth-token` | Things URL authentication |
| `saved-views.json` | Named filter definitions |
| `templates.json` | Task defaults and relative date expressions |
| `undo-history.json` | Up to 20 supported recent mutation entries |
| `review-session.json` | Weekly review progress |

Set `CLINGS_CONFIG_DIR` to use a different directory:

```bash
CLINGS_CONFIG_DIR="$HOME/.config/clings-writing" clings views list
```

This separates clings configuration, not Things accounts or databases. Templates, notes, review state, and undo snapshots can contain task data; treat the directory as private. Weekly review also uses this configuration directory; its legacy fallback path is `~/.clings/review-session.json`.

## Shell completions

The `completions` command prints a script; it does not install it. Create the destination directory first.

### zsh

```bash
mkdir -p "$HOME/.zfunc"
clings completions zsh > "$HOME/.zfunc/_clings"
```

In `~/.zshrc`, add the directory to `fpath` **before** initializing completion:

```zsh
fpath=("$HOME/.zfunc" $fpath)
autoload -Uz compinit
compinit
```

If a shell framework already calls `compinit`, add the `fpath` line before the framework loads rather than initializing twice.

### bash

```bash
mkdir -p "$HOME/.bash_completion.d"
clings completions bash > "$HOME/.bash_completion.d/clings"
source "$HOME/.bash_completion.d/clings"
```

Add the `source` line to your Bash startup file for future sessions.

### fish

```fish
mkdir -p "$HOME/.config/fish/completions"
clings completions fish > "$HOME/.config/fish/completions/clings.fish"
```

Fish loads this directory automatically. Regenerate completion scripts after upgrades to pick up new commands.

## Where next?

Try the [workflow cookbook](workflows.md), learn the [filter language and JSON shapes](filtering-and-scripting.md), or browse the [complete command reference](command-reference.md). Every command has built-in help, including nested commands such as `clings template save --help`.
