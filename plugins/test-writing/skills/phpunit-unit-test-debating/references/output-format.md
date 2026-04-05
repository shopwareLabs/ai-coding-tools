# Debating Output Format

## Debate Message (sent via SendMessage to co-reviewers)

```yaml
type: debate
from: reviewer-{n}
files:
  - path: tests/unit/Core/Content/ProductTest.php
    endorsements:
      - rule_id: CONV-001
        from: reviewer-2
        comment: "Agree — reason"
    challenges:
      - rule_id: DESIGN-003
        from: reviewer-3
        reason: "Detection algorithm evidence"
    justifications:
      - rule_id: UNIT-003
        reason: "Code evidence"
    concessions:
      - rule_id: ISOLATION-003
        reason: "Peer's argument is correct"
    cross_file_references:
      - from_file: tests/unit/Core/Service/CartServiceTest.php
        pattern: "uses createMock() in setUp (line 34)"
        recommendation: "this file should align"
        supports_rule_id: ISOLATION-002
```

The `cross_file_references` field is optional. Omit if you only reviewed one file.

## Final Stance (returned to lead as skill output)

```yaml
type: final_stance
reviewer: reviewer-{n}
files:
  - path: tests/unit/Core/Content/ProductTest.php
    findings:
      - rule_id: CONV-001
        enforce: must-fix
        location: ProductTest.php:45
        current: |
          # code
        suggested: |
          # fix
    withdrawn:
      - rule_id: ISOLATION-003
        reason: "Conceded after reviewer-2's argument"
```
