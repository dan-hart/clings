# Releasing clings

Release from a fresh checkout of GitHub `main`, after the version, changelog,
documentation, and tests have been merged. Never release from a diverged local
branch. Do not move or overwrite a published version tag.

## One release, one commit

The version in `Sources/ClingsCLI/Clings.swift`, `AGENTS.md`, the changelog entry,
and the requested tag must agree. The checkout must exactly match fetched
`origin/main`, be clean (including untracked files), and contain the reviewed
PR #12 and #13 fixes. The final commit must have green build/test/release CI.

```bash
git fetch origin main --tags
bash scripts/release-preflight.sh v0.4.0
bash scripts/release-ci-check.sh "$(git rev-parse HEAD)"
```

These checks are read-only. The CI gate examines the exact SHA, not an earlier
successful run on the branch. Release jobs are excluded from that gate because
they themselves depend on CI; their success is required before publication.

## Publish and verify

```bash
bash scripts/release.sh v0.4.0
```

This creates an annotated tag, pushes it, waits for the release workflow,
checks its assets, updates the maintainer's Homebrew formula using the actual
GitHub archive checksum, updates/installs Homebrew, and performs installation
smoke checks. It requires authenticated `gh`, push rights to clings and the tap,
Homebrew, `curl`, Ruby, and `rg`. Source integrity alone is not a completed release.

The GitHub workflow builds/tests on Apple Silicon and Intel macOS runners.
Each archive contains the binary, license, bash/zsh/fish completions, and
`build-info.json` with version/architecture/commit. Archive timestamps and owners
are normalized; gzip timestamps are disabled. Both archives and `SHA256SUMS`
must exist before publication. Notes are extracted from the matching changelog
section with real newlines, not shell-escaped strings.

## Recovery

If a stage fails, inspect its exact error and the remote tag/release state before
retrying. An existing annotated tag at the same main commit is accepted; tags
pointing elsewhere are rejected. Published assets are never overwritten by the
workflow. A tap update uses the remote formula's current file SHA so concurrent
changes fail safely instead of being lost.

After publication, keep maintainer-owned mirrors synchronized. Do not push to
contributor fork remotes. Verify the source archive checksum and installed
version before telling users a release is complete. Supersede an incorrect
published release with a new version and explanatory notes rather than moving
its tag.

## Test the gates

```bash
bash scripts/tests/release-preflight-test.sh
bash scripts/tests/release-ci-test.sh
bash scripts/install-smoke-test.sh .build/release/clings 0.4.0
```

The source tests use disposable local Git clones; CI tests isolate only GitHub
API responses. Installation checks preview task parsing and inspect help,
without creating or changing Things tasks.
