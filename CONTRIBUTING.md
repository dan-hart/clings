# Contributing

## Ground Rules

- Treat this repository as public.
- Never commit private/sensitive data or internal infrastructure details.
- Local agent state and research logs are not part of this project and must stay untracked.

## Pull Request Checklist

Before opening a PR:

1. Review staged changes:
   ```bash
   git diff --staged
   ```
2. Run repository safety preflight:
   ```bash
   bash scripts/asp-preflight.sh --staged --strict
   ```
3. Run secret scan:
   ```bash
   git secrets --scan --cached
   ```
4. Run project checks:
   ```bash
   swift build && swift test
   ```
5. Confirm banned local-only paths are not tracked:
   ```bash
   git ls-files research .claude private
   ```
   Expected: no output.

## Content Safety Rules

- Use placeholders for credentials and private values.
- Redact internal IPs, hostnames, and private remote URLs.
- Do not include local workflow notes, private remotes, or personal machine paths in committed docs.
- If a change might expose sensitive data, stop and request review before merge.

## Related Policy

- Security policy: `SECURITY.md`
