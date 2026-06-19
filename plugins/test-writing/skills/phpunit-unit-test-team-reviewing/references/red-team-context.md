# Red Team Skip & Context Package

## Skip Conditions

Compute the skip signal from the preliminary consensus and the peer-reconciliation stances. Skip Wave 2 (red team) and Wave 3 (defense) when either holds:

1. **Zero findings** — no findings survive into the preliminary consensus. Nothing to challenge.
2. **Substantive contention** — peer reconciliation already stress-tested the findings hard. Compute the concession rate: the share of distinct Wave-0 findings that were withdrawn during peer reconciliation. When it is ≥ 0.5, the peer wave did the adversarial work the red team would; skip it.

When skipped, go straight to verdicts using the peer stances as binding input, and mark every finding `unchanged`.

## Context Package

Assemble this per file for each adversary and provide it in the adversary's prompt:

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
      originally_reported_by: reviewer-1
      reason: "reviewer-2 argued the detection algorithm does not apply because..."
  reconciliation_record:
    - reviewer: reviewer-1
      maintained: [ {rule_id, evidence} ]
      withdrawn: [ {rule_id, reason} ]
    - reviewer: reviewer-2
      maintained: [ {rule_id, evidence} ]
      withdrawn: [ {rule_id, reason} ]
```

- **consensus_findings** — the preliminary 2-of-3 merge: unanimous or majority, with the majority's enforce level, location, and summary.
- **withdrawn_findings** — every finding present in Wave 0 review but absent from the peer stances, with who first reported it and the withdrawal reason. The reasons are what adversaries scrutinize for weakness.
- **reconciliation_record** — each reviewer's peer-mode stance: what they maintained (with evidence) and withdrew (with reasons). This shows the reasoning, not just the outcome.
