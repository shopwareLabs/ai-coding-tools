# Consensus & Verdicts — Adaptation Guide

Computed deterministically from the binding stances — Wave-3 defense stances when the red team ran, else Wave-1 peer stances. The script (`mergeUnit` / `mergeFile` / `bucketFile` + arbitration) owns the computation; this is the consensus policy and its adaptation surface.

## Consensus policy

- **Per unit, per `(rule_id, location)`** — 3-of-3 unanimous → include (no dissent); 2-of-3 majority → include with a dissent annotation from the reviewer who omitted it; 1-of-3 minority → exclude from the body, record as contested.
- **Location matching** — match `rule_id` first; treat locations within 5 lines of the same method as one finding; ambiguous → the majority's location.
- **Cross-track merge** — merge within each unit's 3 stances, then union per file (dedup by `(rule_id, location)`); a finding that reaches consensus in any unit wins over a contested one.
- **Enforce-level conflict** — take the majority enforce level, note the disagreement.
- **Remediation payload** — take the most complete (superset) `suggested`; combine genuinely distinct sub-actions; never an arbitrary stance's payload; note a non-obvious selection.
- **Status** — `ISSUES_FOUND` (1+ must-fix in any file); else `NEEDS_ATTENTION` (warnings, consistency findings, or "split this class" / informational); else `PASS`.

## What you can adapt

- The **vote thresholds** (3-of-3 / 2-of-3 / 1-of-3) and the **5-line** location window.
- The **remediation-selection** policy (superset vs combine).
- **Arbitration** (adaptation point 5) — contested findings are arbitrated up to the preset's `arbMax` (uncapped on `deep`/`standard`, capped on `lean`), sorted must-fix-first; **must-fix are always arbitrated** regardless of the cap, which trims only the lower-severity tail (trimmed findings stay contested). A contested **must-fix** gets **3 adversary-tier arbiters** (opus on the default model combo) and a majority verdict: ≥ 2 `confirmed` → include (+ `corrected_enforce`); ≥ 2 `refuted` → exclude/contested; no majority → **keep**, marked `arbitration: split` (a possibly-real must-fix is never silently dropped). should-fix / consider keep a **single** body-tier arbiter: `confirmed` → include; `refuted` → exclude/contested; `uncertain` → keep contested.

## Already handled — do not re-adapt

- **Adversary-impact tagging** — every finding carries `unchanged` / `defended` / `overturned` / `resurrected` / `introduced` (all `unchanged` when the red team skipped).
- **Cross-file findings** — the dedicated cross-file agent is their sole producer (fingerprint input → `consistency[]` warnings; counts toward `NEEDS_ATTENTION`, never `ISSUES_FOUND`).
- **"Split this test class"** — an `L > C` file emits a first-class informational entry; its method-shard and digest findings still merge.
- **Coverage overlaps & placement flags** — the cross-cutting SUT-coverage map (`coverage_overlap[]`) and the integration-to-unit placement flags (`placement_flags[]`) are computed deterministically from the manifest + the INTEGRATION-008 consensus signal. They are **informational**: they never raise status to `ISSUES_FOUND`, form their own finding class separate from quality findings, and only point at the standalone `phpunit-integration-to-unit-migrating` skill.
- **Per-finding `method` / `branch_touched` / `implies_src_change`** — every finding carries the method it occurs in (the stable locator; `class-level` for structural), a `branch_touched` flag computed post-merge from the manifest's `changed_methods` on diff-scoped runs (`null` otherwise), and `implies_src_change` (true when **any** clustered stance flagged it — the fix needs a production change). All three are informational metadata: none change consensus or status. Rendered shape in report-format.md.
