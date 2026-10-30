# Review Coverage Protocol

Index: baseline, coverage, enumeration, sibling comparison, challenge, prior findings, reporting.

## Baseline and Scope

- Pin the commit and working-tree changes, target version, requested surfaces, and any prior report. Identify the source of record for writes and the actual active feature/configuration.
- Match review depth to the request and risk. Use static-only analysis when requested; otherwise run permitted targeted tests or runtime checks when they can resolve a material question. Static source does not prove deployment, provider enforcement, browser behavior, or live exploitability.
- Research external contracts when a finding depends on provider capabilities. Treat undocumented capabilities as verification gaps, not invented guarantees.
- A broad audit covers the relevant end-to-end flow; a diff review follows callers, siblings, configuration, and downstream effects needed to judge that diff.

## Coverage

1. Map entry points, mutations, authority, ownership, persistence, state transitions, caches, queues, frontend contracts, and error/retry paths that apply.
2. Read the relevant code rather than treating a checklist as the scan boundary. Enumerate repeated security-sensitive call sites and compare sibling implementations.
3. Challenge candidate findings against actual inputs, guards, intentional limitations, and clean controls. Verify prior findings before reporting them again.

These are coverage checks, not three mandatory full-codebase passes. Repeat an independent challenge or focused pass when risk, uncertainty, or the request warrants it.

## Enumerate Instances

One correct call site does not establish that every instance is correct. Before declaring a security-relevant pattern clean, enumerate the instances in the reviewed scope and judge each.

```text
Two query methods share a file. Inspect both bindings and their callers;
one parameterized query does not clear a sibling that interpolates input.
```

## Compare Siblings

Compare similar methods, routes, processors, or handlers for version/language scoping, visibility, parameter binding, transactions, and error handling. A difference is a lead to investigate, not automatically a defect: it may represent an intentional contract difference.

## Challenge Findings

- Require an exact location, reachable scenario, concrete failure, impact, and smallest coherent safe fix direction. Use [08](08-analysis-and-reviews.md) for severity and output.
- Separate confirmed defects from inactive/deferred surfaces, context-dependent concerns, and verification gaps. Missing tests do not automatically imply P1.
- Recheck important comments, contracts, and feature state before proposing behavior changes.
- Include code or patches when requested and useful, regardless of severity. Do not prohibit a necessary business-logic or frontend correction merely to make the diff small; preserve intended behavior and explain compatibility impact.

## Prior Findings and Fixes

- Confirm, reject, or mark each relevant prior finding unresolved, with evidence. Distinguish new findings from revalidated findings and note a changed baseline.
- Remediate one finding at a time unless tightly coupled. Verify the changed flow and adjacent regression risks before widening scope again.
- Do not create report files, date/version naming schemes, or repeated full scans unless requested or required by the repository.

## Reporting

Findings first; use the literal template in [08](08-analysis-and-reviews.md). For a broad audit, add a compact coverage/limitations note with inspected categories and evidence. Say what was checked and dismissed only when actually checked; do not invent counts or claim the entire repository is clean from a partial scan.

```md
## Coverage and Limits

- Customer mutations: inspected all three changed routes and their ownership filters.
- Payment retry: traced provider operation key and reconciliation path; runtime replay not run.
- Deferred: inactive wallet integration excluded by the requested scope.
```
