# Consensus & Verdicts

The script computes these deterministically from the binding stances. Use Wave 3 defense stances when the red team ran; otherwise use Wave 1 peer stances.

## Per-File Consensus Merge

For each file, take its 3 binding stances. For each unique `(rule_id, location)`:

- **3-of-3 — unanimous**: include; no dissent annotation.
- **2-of-3 — majority**: include; attach a dissent annotation from the reviewer who omitted it.
- **1-of-3 — minority**: exclude from the report body; record as a contested finding.

**Location matching**: match by `rule_id` first; treat locations within a 5-line range of the same method as the same finding. When locations are ambiguous, use the majority's location.

**Enforce-level conflicts**: when reviewers agree a violation exists but disagree on enforce level, use the majority enforce level and note the disagreement.

## Arbitration (adaptation point 5)

When an arbiter settled a contested finding, its verdict overrides the raw vote for that finding:

- `confirmed` → include; annotate with the arbiter's reasoning; apply `corrected_enforce` if given.
- `refuted` → exclude; record as contested with the arbiter's reasoning.
- `uncertain` → keep as contested; do not include in the body.

## Cross-File Consistency

Fold the dedicated cross-file agent's `consistency` findings into the result as warnings (should-fix). They count toward `NEEDS_ATTENTION` but never toward `ISSUES_FOUND`. Individual reviewers do not produce cross-file findings — this agent is their sole source.

## Adversary Impact

Tag each finding in the final result:

- `unchanged` — not challenged; stable across waves.
- `defended` — challenged by an adversary, survived defense.
- `overturned` — challenged by an adversary, withdrawn in defense.
- `resurrected` — withdrawn in peer reconciliation, resurrected by an adversary, re-adopted in defense.
- `introduced` — new finding from an adversary, adopted by the majority in defense.

When the red team was skipped, every finding is `unchanged`.

## Status Determination

- **PASS** — all files PASS and no consistency findings.
- **NEEDS_ATTENTION** — 0 errors across all files, but 1+ warnings or consistency findings.
- **ISSUES_FOUND** — 1+ errors (must-fix) in any file.
