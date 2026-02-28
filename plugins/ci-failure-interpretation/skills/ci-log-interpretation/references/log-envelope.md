# GitHub Actions Log Envelope

The log format that wraps ALL tool output in GitHub Actions.

## Timestamp Prefix

Every line starts with an ISO 8601 timestamp: `2026-02-27T16:47:10.5479424Z`. Strip mentally when reading.

## Step Markers

- `##[group]Step Name` begins a step
- `##[endgroup]` ends it
- Steps run sequentially within a job

## Error Annotations

`##[error]Message` — used by GitHub to create PR annotations. PHPStan uses this extensively (one `##[error]` per error).

The FINAL `##[error]Process completed with exit code N.` is always the step exit marker — never the actual error.

## Noise Budget (Typical Shopware CI)

| Phase | Lines | Relevance |
|---|---|---|
| Checkout | ~20 | Noise |
| Docker/service setup | ~50-200 | Noise |
| Cache restore | ~10-30 | Noise |
| Dependency install (composer/npm) | ~50-500 | Noise |
| **Tool execution** | **varies** | **The only part that matters** |
| Cache save | ~10-20 | Noise |
| Post-job cleanup | ~20-50 | Noise |

## Finding Tool Output

The actual tool output starts AFTER the last `##[group]Run ...` or `##[group]Install ...` step and before the first `##[group]Post ...` step.
