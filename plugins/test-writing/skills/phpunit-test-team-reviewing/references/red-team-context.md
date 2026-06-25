# Red Team — Adaptation Guide

The conditional red team (Wave 2) + defense (Wave 3) challenge the preliminary consensus. The script owns the skip signal and the context-package assembly; this is the skip policy and the adversary's input contract.

## Adversaries: per file, K independent lenses

Each file gets **K = 3 independent adversaries, one per lens**, in both the Wave-0 impression pass and the Wave-2 red team. Each adversary reads **exactly one file**, so its context cannot accumulate across a file group — the bound that prevents an adversary from overflowing the window and being dropped (a true coverage gap requires all K of a file's adversaries to die, not one). The adversaries do not vote for a majority; their introductions are *unioned* and held to precision by the Wave-3 defense adopt-gate (≥ 2 defenders), so K is the lens count, not a quorum.

The three lenses are the three orthogonal ways a test fails its purpose. The axes are **test-agnostic**; each lens draws the rules it cites from its `## RULES` block (the full catalog for the file's `test_type`) rather than a hardcoded per-type ID list:

- **L1 — Tautology hunter** *(does it run for real?)*: would the test pass even if the SUT were broken — over-mocking the SUT or its real collaborators, asserting on stubs/doubles, call-count coupling, guard-clause leakage. (Unit catalog instances: UNIT-001/003/004/005, ISOLATION-001/002, DESIGN-010; integration: INTEGRATION-002 over-mock; migration: idempotency/verification gaps.)
- **L2 — Weak-assertion hunter** *(does it assert enough?)*: do assertions pin the real contract, and are edge and error cases covered? (Unit: CONV-009, DESIGN-005/006, PROVIDER-*; integration: INTEGRATION-007 setup/assertion ratio; migration: MIGRATION-007 assertSame.)
- **L3 — Missed-coverage / completeness hunter** *(is it there at all?)*: enumerate the SUT's public surface, branches, and error paths, and introduce findings for those with no test.

**No convention lens.** Convention/structure rules are rule-mechanical and high-agreement — the reviewer wave's strength, with the cross-file agent covering cross-file convention drift. A convention adversary would mostly duplicate the reviewers; L3 may opportunistically flag a glaring convention issue, but convention is not a dedicated axis.

The red team receives the **full** catalog for the file's `test_type`: category-scoping it barely shrinks the catalog, and the per-file scope — not the rule subset — is what bounds adversary size. Adversaries run on **opus** (the hard "plausible but wrong" / "untested edge case" reasoning).

## Skip policy

Skip Wave 2 + Wave 3 — go straight to verdicts and mark every finding `unchanged` — when either holds:

- **Zero findings** survive into the preliminary consensus. Nothing to challenge.
- **Concession rate ≥ 0.5** — the share of distinct Wave-0 findings withdrawn during peer reconciliation; the peer wave already did the adversarial work.

## Context package (the adversary's input)

Assemble for the one file each adversary covers, alongside its full-catalog `## RULES`:

```yaml
- file_path: tests/unit/.../ClassTest.php
  category: B
  consensus_findings:
    - rule_id: CONV-004
      enforce: must-fix
      consensus: unanimous        # or majority
      location: ClassTest.php:45
      summary: "Description"
  withdrawn_findings:
    - rule_id: DESIGN-005
      originally_reported_by: [reviewer-1]
      reason: "reviewer-2 argued the detection algorithm does not apply because..."
  reconciliation_record:
    - reviewer: reviewer-1
      maintained: [ {rule_id, location} ]
      withdrawn: [ {rule_id, reason} ]
    - reviewer: reviewer-2
      maintained: [ {rule_id, location} ]
      withdrawn: [ {rule_id, reason} ]
```

- **consensus_findings** — the preliminary 2-of-3 merge: unanimous or majority, with the majority's enforce level, location, and summary.
- **withdrawn_findings** — Wave-0 findings absent from the peer stances, with who first reported them and the withdrawal reason.
- **reconciliation_record** — each reviewer's peer-mode stance: what it maintained (`rule_id` + `location`) and withdrew (with reasons).

## What you can adapt

- The **0.5 concession-rate** skip threshold and the zero-findings skip.
- The **context-package** fields the adversary receives.

## Already handled — do not re-adapt

- The cross-file agent is the sole producer of cross-file findings; the adversary's `cross_file_inconsistencies` are candidate signals only.
- Adversary coverage gaps surface in `red_team.coverage_gap`. A file is covered iff ≥ 1 of its K adversaries returned; the gap (and its `[!CAUTION]`) fires only when **all K** of a file's adversaries die after re-spawn.
