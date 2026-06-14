# Security Policy

## Reporting a Vulnerability

Please do not open a public issue for sensitive security reports.

Email the maintainer at the address listed in the Git commit metadata, or open a minimal GitHub issue asking for a private contact channel without including exploit details.

## Scope

This project reads local Codex session logs and local sound files. Security-sensitive areas include:

- unintended disclosure of local log contents
- unsafe file path handling
- login item installation behavior

The project does not intentionally send telemetry or upload local Codex data.
