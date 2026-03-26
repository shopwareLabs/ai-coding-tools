# Batched Message Formats

All reviewer messages are batched — one message per phase covering all assigned files, grouped by file path.

## Findings (Phase 1)

```yaml
type: findings
reviewer: reviewer-{n}
files:
  - path: tests/unit/Core/Content/ProductTest.php
    category: A
    findings:
      - rule_id: CONV-001
        enforce: must-fix
        location: ProductTest.php:45
        summary: "Description of violation"
        current: |
          # problematic code
        suggested: |
          # fixed code
  - path: tests/unit/Core/Service/CartServiceTest.php
    category: B
    findings:
      - rule_id: DESIGN-003
        enforce: should-fix
        location: CartServiceTest.php:78
        summary: "Description"
        current: |
          # code
        suggested: |
          # fix
```

## Debate Response (Phase 2)

```yaml
type: debate
reviewer: reviewer-{n}
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

The `cross_file_references` field is optional — a reviewer who only sees one file omits it.

## Final Stance (Phase 3)

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
