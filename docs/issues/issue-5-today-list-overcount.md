# Issue #5: `today` List Overcounted Tasks

- GitHub issue: https://github.com/dan-hart/clings/issues/5
- Status: fixed in source (see `ThingsDatabase.fetchList`)

## Symptom

Users reported `clings today` returning far more tasks than expected, often appearing to include large backlog sets (for example, Anytime-style tasks).

## Root Cause

There were two coupled problems in SQLite list filters:

1. `today` query was too broad:
   - It used `start = 1 OR startDate = ?`.
   - In real datasets, `start = 1` can match many non-today tasks.

2. Date encoding assumption was wrong:
   - Code treated `startDate` as "days since 2001".
   - Things stores packed integer day codes (`(year << 16) | (month << 12) | (day << 7)`).
   - This broke boundary comparisons in `anytime` and `upcoming`.

## Fix

- `today`: require `start = 1 AND startDate = todayCode`
- `upcoming`: compare against packed `todayCode`
- `anytime`: compare against packed `todayCode`
- Replaced old day conversion helper with `thingsDateCode(_:)`

## Regression Coverage

Implemented in:
- `Tests/ClingsCoreTests/ThingsClient/ThingsDatabaseTests.swift`

Coverage includes:
- Issue #5: today excludes non-today `start=1` tasks
- Issue #5: anytime uses packed Things date comparisons
- Issue #5: upcoming excludes tasks starting today
- Issue #5: list queries still enforce open/untrashed constraints

## Verification Commands

```bash
swift test --filter ThingsDatabaseTests
swift test --quiet
```
