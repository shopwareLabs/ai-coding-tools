# Reconciling Output Format

**One visible line with your structured output.** Emit exactly one short visible line summarizing the result (for example, a one-line finding tally) in the same response as your structured output. No other prose — the structured output (the revised stance below) stays the only contract-bearing payload. This applies to both modes.

## Mode: peer — Revised Stance

```yaml
type: peer_stance
reviewer: reviewer-{n}
files:
  - path: tests/unit/Core/Content/ProductTest.php
    scope: full class            # or [testFoo, testBar]
    findings:
      - rule_id: CONV-001
        enforce: must-fix
        location: ProductTest.php:45
        summary: "Description"
        current: |
          # code
        suggested: |
          # fix
    withdrawn:
      - rule_id: ISOLATION-003
        reason: "Conceded — reviewer-2's detection-algorithm citation holds at line 34"
```

## Mode: adversary — Revised Stance

```yaml
type: adversary_stance
reviewer: reviewer-{n}
files:
  - path: tests/unit/Core/Content/ProductTest.php
    scope: full class            # or [testFoo, testBar]
    findings:
      - rule_id: CONV-001
        enforce: must-fix
        location: ProductTest.php:45
        summary: "Description"
        current: |
          # code
        suggested: |
          # fix
        adversary_impact: defended      # defended | unchanged
    re_adopted:
      - rule_id: DESIGN-005
        enforce: should-fix
        location: ProductTest.php:72
        summary: "Re-adopted after adversary resurrection"
        current: |
          # code
        suggested: |
          # fix
        adversary_impact: resurrected
    withdrawn:
      - rule_id: CONV-008
        reason: "Adversary showed the detection algorithm does not apply at line 60"
        adversary_impact: overturned
    adopted_new:
      - rule_id: ISOLATION-002
        enforce: must-fix
        location: ProductTest.php:88
        summary: "Adopted from adversary"
        current: |
          # code
        suggested: |
          # fix
        adversary_impact: introduced
```
