---
name: ci-log-interpretation
version: 1.0.0
description: |
  Knowledge for interpreting CI failure logs from GitHub Actions. Covers
  PHPUnit, PHPStan, ECS, ESLint, TypeScript, Stylelint, Prettier, Jest,
  Playwright, ludtwig, and Lighthouse. Use this skill whenever reading CI
  logs, diagnosing why a CI check failed, analyzing GitHub Actions job output,
  debugging a red build, or when the user asks "why did CI fail", "what broke
  the build", "check the pipeline", or shares log output that contains tool
  errors. Also use when fetching or reviewing run logs, job logs, or check
  annotations from GitHub Actions, even if the user does not explicitly
  mention "CI" — any interaction with GitHub Actions failure output benefits
  from this skill's noise-filtering and tool-identification knowledge.
allowed-tools: Read, Grep, Glob
---

# CI Log Interpretation

## Job Name → Tool Mapping

| Job name pattern | Tool |
|---|---|
| `PHPUnit` | PHPUnit |
| `PHP analysis` / `PHPStan` | PHPStan |
| `PHP lint` / `ECS` / `php-cs-fixer` | ECS |
| `lint` (in admin/storefront workflow) | ESLint, tsc, Stylelint, or Prettier |
| `Jest` / `unit` (JS context) | Jest |
| `acceptance` / `Playwright` | Playwright |
| `Lighthouse` | Lighthouse |
| `Twig Lint` / `ludtwig` | ludtwig |

## Output Signatures

When the job name is ambiguous, identify the tool from its output:

| Signature in log | Tool |
|---|---|
| `There was 1 failure:` or `There were N errors:` | PHPUnit |
| `[ERROR] Found N errors` | PHPStan |
| `Found N of M files that can be fixed` | ECS |
| `✖ N problems (N errors, N warnings)` | ESLint |
| `error TS` followed by 4-digit code | TypeScript (tsc) |
| `✖ N problems` in SCSS context | Stylelint |
| `Code style issues found` | Prettier |
| `● suite-name › test-name` | Jest |
| `expect(locator).toXxx() failed` | Playwright |
| `Assertion failed. Exiting with status code 1.` | Lighthouse |
| `error[RuleName]:` | ludtwig |

## Universal Noise (Never the Root Cause)

These patterns appear in ALL GitHub Actions logs and are never the actual error:

- **Timestamp prefix**: Every line starts with `YYYY-MM-DDTHH:MM:SS.NNNNNNNZ` — ignore it
- **Step boundaries**: `##[group]Step Name` / `##[endgroup]` — structural, not errors
- **Step exit marker**: `##[error]Process completed with exit code N.` — ALWAYS the last line of a failed step. This is the step exit marker, NOT the actual error. Never report this as the root cause.
- **Setup noise**: checkout, Docker pulls, `actions/cache`, composer install, npm install, tool downloads
- **Post-job noise**: cache saving, git config cleanup, orphan process termination
- **Infrastructure noise**: `npm error command failed`, `socket hang up`, `ECONNREFUSED` — CI environment issues, not code errors (exception: for Playwright these CAN be the actual cause)

For detailed GitHub Actions log format knowledge, see `references/log-envelope.md`.

## Tool-Specific References

Detailed failure anatomy, output format, false positives, and real examples for each tool:

| Tool(s) | Reference |
|---|---|
| PHPUnit, PHPStan, ECS | `references/php-tools.md` |
| ESLint, tsc, Stylelint, Prettier, Jest | `references/js-tools.md` |
| Playwright, Lighthouse, ludtwig | `references/e2e-tools.md` |

## What to Report

- The specific file(s) and line number(s) that caused the failure
- The error message in the tool's own words
- The rule or check that failed (if applicable)
- For diff-based tools (ECS, Prettier): the expected vs actual code
