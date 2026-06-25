# Red Team — Adaptation Guide

The conditional red team (Wave 2) + defense (Wave 3) challenge the preliminary consensus. The script owns the skip signal and the context-package assembly; this is the skip policy and the adversary's input contract.

## Skip policy

Skip Wave 2 + Wave 3 — go straight to verdicts and mark every finding `unchanged` — when either holds:

- **Zero findings** survive into the preliminary consensus. Nothing to challenge.
- **Concession rate ≥ 0.5** — the share of distinct Wave-0 findings withdrawn during peer reconciliation; the peer wave already did the adversarial work.

## Context package (the adversary's input)

Assemble per file for each adversary, alongside its category-scoped `## RULES`:

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
- Adversary coverage gaps (in-scope files left un-red-teamed after re-spawn) surface in `red_team.coverage_gap`.
