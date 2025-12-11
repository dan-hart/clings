# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in clings, please report it responsibly.

### How to Report

1. **Do NOT open a public GitHub issue** for security vulnerabilities
2. **Email**: Send details to the repository maintainer via GitHub's private vulnerability reporting feature, or contact through the email associated with commits
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes (optional)

### What to Expect

- **Acknowledgment**: Within 48 hours of your report
- **Initial Assessment**: Within 7 days
- **Resolution Timeline**: Depends on severity, typically within 30 days for critical issues

### Scope

This security policy applies to:
- The clings CLI application
- Build and release processes
- Dependencies (we monitor via Dependabot)

### Out of Scope

- Issues in third-party dependencies should be reported to those projects directly
- The Things 3 application itself (report to Cultured Code)
- macOS security issues (report to Apple)

## Security Measures

This project implements several security measures:

- **Swift memory safety**: Swift's type system and ARC prevent common memory vulnerabilities
- **Pre-commit hooks**: git-secrets scans for accidental credential commits
- **Input sanitization**: All JXA script parameters are properly escaped
- **Read-only database access**: SQLite reads use read-only connections
- **Minimal permissions**: Only requests necessary macOS permissions for Things 3 access

## Security Best Practices for Users

1. **Keep clings updated** to receive security fixes
2. **Review permissions** when prompted by macOS
3. **Report suspicious behavior** immediately
