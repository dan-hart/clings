# Ten improvements delivered in v0.4.0

The original roadmap is implemented while preserving Things terminology, fast
read-only SQLite access, supported automation writes, and shell composition.

| Improvement | Delivered behavior |
| --- | --- |
| 1. Verifiable releases | Clean current-main and exact-commit CI gates, matching versions, pinned dependencies, provenance-bearing archives, checksums, tap and installed smoke checks |
| 2. Consistent JSON | Schema 1 envelopes with `.data`, structured errors, and retained partial results |
| 3. Meaningful exits | 0 success, 1 invalid/ambiguous/refused input, 2 runtime/partial failure or unhealthy required capability |
| 4. Safe deletion | Explicit cancellation, confirmation, meaningful `--force`, no false Trash promise |
| 5. Retryable undo | Failed reversals retained, original status restored, reversible fields journaled, grouped status/tag undo |
| 6. Strict dates and previews | Invalid/impossible dates rejected, add/update final-field previews, relative template dates resolved at execution |
| 7. Shared query controls | Explicit scope/history, stable sort and limits, validated fields, scheduled starts distinct from deadlines |
| 8. Resumable batch plans | Frozen exact IDs and snapshots, stale/conflict detection, per-item persistence, retries that skip successful writes |
| 9. Generated discovery | Parser-generated bash/zsh/fish scripts and reference, local saved-name completion, help/example checks |
| 10. Read-only diagnostics | Real database reads, capability-specific health, optional token warnings, opt-in automation probe, private redacted support bundles |

## Boundaries that remain intentional

Deletion cancels rather than moving to Trash. Scheduling, headings, project moves,
and project/tag management are not fully undoable. Batch writes are sequential,
not a Things database transaction. A journal failure after a successful write is
reported as an applied mutation without reliable undo, not as a rolled-back task.

Default diagnostics do not prove automation authorization. The opt-in version
probe may launch Things or display a permission prompt, but does not modify tasks.
Completions do not require live Things project/tag reads. Support bundles omit
private paths, tokens, and task content; batch plans and undo history do contain
task data and should be kept private.

See the [machine-interface migration guide](machine-interface.md),
[generated reference](generated-reference.md), and
[release procedure](../release/releasing.md) for the concrete contracts.
