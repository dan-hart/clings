# Ten ways to improve clings

Proposals, not implemented features or release commitments. These come from the
current CLI source and the gaps encountered while documenting it. The goal is
to preserve the CLI's spirit: Things terminology, fast local reads, supported
automation writes, and shell composition.

## 1. Make releases reproducible and verifiable

Build tags from current main only after checks pass. Generate version output,
release notes, source checksums, completion artifacts, and the tap update from
one workflow. Add an installation smoke test that verifies the installed version
and key fixes. This prevents a valid-looking tag from publishing stale code.

First deliverable: a release preflight that rejects a tag missing required main
commits or disagreeing with the source version, plus a tap install check.

## 2. Make JSON a consistent machine interface

Ensure `--json` emits only JSON, including ambiguous searches, bulk previews,
and errors. Send human prompts/progress to stderr. Define documented response
envelopes and versioned schemas. Today, list envelopes, bare definition arrays,
embedded models, and mixed text require different consumer logic.

First deliverable: JSON contract tests for every public command, including
empty results and failures, with explicit treatment of interactive commands.

## 3. Make failed operations visible to scripts

Standardize nonzero exits for validation errors, partial bulk failure, ambiguity,
and unhealthy diagnostics. `doctor` warnings and some per-item failures currently
need payload inspection. Preserve useful error messages and provide per-item
error details rather than only a failed count.

First deliverable: a published exit-status contract and tests for partial success.

## 4. Make deletion behavior explicit and safe

Choose a clear contract: support genuine Trash movement through an official API
if feasible, or name/explain cancellation consistently. Implement confirmation
for destructive commands and make `--force` meaningful. Single-task delete
currently cancels immediately despite accepting a confirmation-related flag.

First deliverable: a tested confirmation flow and help that distinguishes cancel,
trash, and permanent deletion without suggesting direct database writes.

## 5. Strengthen undo and mutation journaling

Keep history entries until a reversal succeeds, preserve the original status,
and capture all reversible fields. Expose unsupported fields before a write.
Add grouped undo for bulk operations where the official API permits it. Today's
undo can lose entries on failure and cannot reverse schedule/heading changes.

First deliverable: failed-undo retry tests and a mutation capability matrix.

## 6. Reject invalid dates and preview the whole mutation

Stop silently converting unrecognized date options to missing dates. Use typed
date parsing with actionable errors, a shared preview interface for add/update,
and tests across locales, calendars, and DST boundaries. Retain relative template
expressions explicitly and make parsing precedence visible.

First deliverable: invalid-date rejection for add/template execution and a
structured preview showing final title, assignments, tags, and both dates.

## 7. Make queries share explicit scope, sorting, and limits

Add consistent `--list`, `--include-logbook`, `--sort`, and `--limit` controls to
search/filter/views. Validate field names instead of letting unknown-field null
checks succeed. Add a scheduled-start field, distinct from deadlines. Scope is
currently implicit and differs between search, filter, and bulk.

First deliverable: shared query options with stable sorting and scope tests.

## 8. Plan batches before executing them

Produce a reusable batch plan with exact IDs and proposed field changes, then
confirm it before writes. Report every result, support controlled retries, and
avoid reselecting different items between preview and execution. Preserve
sequential/supported API writes rather than assuming database transactions.

First deliverable: `bulk --dry-run --json` plans and per-item result output.

## 9. Generate completions and reference docs from the command tree

Replace hand-maintained command lists in completion scripts with ArgumentParser
metadata. Add context-aware completion for saved views/templates and, where
practical, project/tag names. Generate a reference baseline and check examples
against real parsing so new options cannot silently drift from documentation.

First deliverable: generated static completions plus a recursive help/examples
check in CI. Keep narrative recipes handwritten for readability.

## 10. Improve diagnostics without changing user data

Distinguish missing configuration, unavailable Things data, denied automation,
and unsupported capabilities. Add an opt-in read-only automation probe, actionable
next steps, redacted JSON diagnostics, and meaningful health exit statuses.
`doctor` currently proves runtime presence rather than automation authorization.

First deliverable: capability-specific checks and a redacted support bundle.

## Suggested order

Start with **release integrity, JSON contracts, exit statuses, and deletion**.
They protect existing users and automation. Then improve **undo, dates, query
scope, and bulk planning**. Finish with **generated completions/docs and stronger
diagnostics**, which make the broader interface easier to maintain and discover.
