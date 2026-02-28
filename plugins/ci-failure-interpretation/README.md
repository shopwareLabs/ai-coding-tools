# CI Failure Interpretation

Knowledge skill for interpreting CI failure logs from Shopware GitHub Actions workflows. Teaches Claude how to read tool-specific output formats, filter noise, and extract the actual root cause from job logs.

## Quick Start

The `ci-log-interpretation` skill activates automatically when analyzing CI failures:

```
What failed in this CI run?
Why did the PHPUnit job fail?
Interpret these CI logs
```

## Supported Tools

| Category | Tools |
|---|---|
| PHP | PHPUnit, PHPStan, ECS (PHP-CS-Fixer) |
| JavaScript | ESLint, TypeScript (tsc), Stylelint, Prettier, Jest |
| E2E & Quality | Playwright, Lighthouse, ludtwig |

## What It Does

CI job logs are 90-99.8% noise (setup steps, progress bars, caching, Docker pulls, cleanup). This skill provides pure knowledge that teaches Claude:

1. **Tool identification** — Map job names and output signatures to the specific tool that produced the log
2. **Noise filtering** — Recognize setup, caching, and teardown output that is never the root cause
3. **Failure extraction** — Parse the actual error details (file, line, message, rule) from each tool's specific output format
4. **False positive avoidance** — Distinguish real errors from deprecation warnings, slow test markers, and generic exit codes

## Documentation

- **Core skill**: `skills/ci-log-interpretation/SKILL.md`
- **PHP tools**: `skills/ci-log-interpretation/references/php-tools.md`
- **JS tools**: `skills/ci-log-interpretation/references/js-tools.md`
- **E2E tools**: `skills/ci-log-interpretation/references/e2e-tools.md`
- **Log format**: `skills/ci-log-interpretation/references/log-envelope.md`

## Developer Guide

See `AGENTS.md` for plugin architecture and development guidance.

## License

MIT
