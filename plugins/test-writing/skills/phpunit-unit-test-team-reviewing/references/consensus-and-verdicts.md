# Consensus & Verdicts

These are computed deterministically from the binding stances. Use Wave 3 defense stances when the red team ran; otherwise use Wave 1 peer stances.

## Per-File Cross-Track Merge

A Track B file is reviewed across tracks (method-shards + whole-class or digest). Run the consensus merge below **within each unit's 3 stances**, then **union** the per-unit results into the file's findings, deduplicated by `(rule_id, location)` as today. A finding can only originate from the track that loads its rule — a `method` rule never appears in the whole-class track — so cross-track collisions are limited to location overlaps at method boundaries; resolve them with the 5-line location rule below. A Track A file has one unit; the union is a no-op.

## Per-File Consensus Merge

For each unit, take its 3 binding stances. For each unique `(rule_id, location)`:

- **3-of-3 — unanimous**: include; no dissent annotation.
- **2-of-3 — majority**: include; attach a dissent annotation from the reviewer who omitted it.
- **1-of-3 — minority**: exclude from the report body; record as a contested finding.

**Location matching**: match by `rule_id` first; treat locations within a 5-line range of the same method as the same finding. When locations are ambiguous, use the majority's location.

**Enforce-level conflicts**: when reviewers agree a violation exists but disagree on enforce level, use the majority enforce level and note the disagreement.

**Remediation payload**: when concordant stances (2-of-3 or 3-of-3) on the same `(rule_id, location)` carry different `suggested` payloads, the merged finding takes the **most complete** remediation — the suggestion that, applied, also resolves what the others address (a superset). When the stances address genuinely **distinct sub-actions** of the same fix, **combine** them into one `suggested`. Never take an arbitrary stance's payload (e.g. first reviewer, first wave). `current` is the same code for all stances; only `suggested` is selected. When the selection is non-obvious, record a one-line note on why.

## Arbitration (adaptation point 5)

When an arbiter settled a contested finding, its verdict overrides the raw vote for that finding:

- `confirmed` → include; annotate with the arbiter's reasoning; apply `corrected_enforce` if given.
- `refuted` → exclude; record as contested with the arbiter's reasoning.
- `uncertain` → keep as contested; do not include in the body.

## Cross-File Consistency

The dedicated cross-file agent ingests per-file **fingerprints** (not full consensus findings — see workflow-design.md); its output contract is unchanged (`consistency[]` warnings). Fold those findings into the result as warnings (should-fix). They count toward `NEEDS_ATTENTION` but never toward `ISSUES_FOUND`. Individual reviewers do not produce cross-file findings — this agent is their sole source.

## "Split This Test Class" Skip

When a file's `L > C`, the class-bodies track is not evaluated (reviewer-allocation.md). Record a first-class **informational** result entry:

> `<file>` (`NNN` lines) exceeds the cross-body review limit `C`; the class-bodies (cross-method) rules were not evaluated. Split this test class.

The method-shard and class-structure-digest findings for the file are still produced and merged. This entry raises `NEEDS_ATTENTION`, never `ISSUES_FOUND` — the file is not failing review, it is too large to fully review.

## Adversary Impact

Tag each finding in the final result:

- `unchanged` — not challenged; stable across waves.
- `defended` — challenged by an adversary, survived defense.
- `overturned` — challenged by an adversary, withdrawn in defense.
- `resurrected` — withdrawn in peer reconciliation, resurrected by an adversary, re-adopted in defense.
- `introduced` — new finding from an adversary, adopted by the majority in defense.

When the red team was skipped, every finding is `unchanged`.

## Status Determination

- **PASS** — all files PASS, no consistency findings, and no "split this test class" entries.
- **NEEDS_ATTENTION** — 0 errors across all files, but 1+ warnings, consistency findings, or "split this test class" / informational entries.
- **ISSUES_FOUND** — 1+ errors (must-fix) in any file.
