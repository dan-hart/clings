# Release Checklist: Help Text, README, and Docs

Run this checklist before every release tag.

## 1. Automated Audit

```bash
bash scripts/release-docs-check.sh
```

This checks:
- CLI top-level help subcommands are documented in README command table
- Shell completion command list includes all CLI top-level commands
- Help/README examples avoid banned personal or placeholder phrases
- Core docs files exist (`README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `AGENTS.md`)

## 2. Manual Spot Checks

Run a few key command help pages and confirm examples/readability:

```bash
swift run clings --help
swift run clings add --help
swift run clings project add --help
swift run clings config --help
swift run clings bulk move --help
```

## 3. Documentation Sync

- Update `CHANGELOG.md` under `Unreleased`
- Confirm README command reference matches current CLI
- Confirm issue-specific docs are linked for important behavior changes
