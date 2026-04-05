# Defending Output Format

## Defense Stance (returned to lead as skill output)

```yaml
type: defense_stance
reviewer: reviewer-{n}
files:
  - path: tests/unit/Core/Content/ProductTest.php
    findings:
      - rule_id: CONV-001
        enforce: must-fix
        location: ProductTest.php:45
        summary: "Description"
        current: |
          # code
        suggested: |
          # fix
        adversary_impact: defended  # defended | unchanged
    re_adopted:
      - rule_id: DESIGN-005
        enforce: should-fix
        location: ProductTest.php:72
        summary: "Description — re-adopted after adversary resurrection"
        current: |
          # code
        suggested: |
          # fix
        adversary_impact: resurrected
    withdrawn:
      - rule_id: CONV-008
        reason: "Adversary challenge showed detection algorithm doesn't apply here..."
        adversary_impact: overturned
    adopted_new:
      - rule_id: ISOLATION-002
        enforce: must-fix
        location: ProductTest.php:88
        summary: "Adopted from adversary — description"
        current: |
          # code
        suggested: |
          # fix
        adversary_impact: introduced
```

The `adversary_impact` field on each entry traces the adversary's influence for the report.
