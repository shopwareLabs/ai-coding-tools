# Reconciling Output Format

**One visible line with your structured output.** Emit exactly one short visible line summarizing the result (for example, a one-line finding tally) in the same response as your structured output. No other prose — the structured output (the revised stance below) stays the only contract-bearing payload. This applies to both modes.

**`finding_id` identifies a finding, in both modes.** Every finding in the payloads you are given carries one — `{rule_id}|{method}|{fingerprint}` (`method` normalized — a trailing `(...)` call suffix and surrounding whitespace stripped — into its own literal segment of the id; the fingerprint segment hashes only the whitespace-normalized `current`, or `summary` where `current` is empty, never `method`), issued by the review that raised it. Quote it verbatim on each finding you maintain, adopt, withdraw, or re-adopt: it is how the merge knows which finding you mean. Never invent one, never alter one, and never move one onto a different defect. Line numbers are not identity — a finding keeps its id after the line it cites moves.

**Your remediation survives a disagreement.** The merge keeps every distinct `suggested` its stances proposed (as `suggested_variants`, longest first, `suggested` being the first of them), so write the fix you actually mean. Do not restate a peer's wording to look aligned, and do not drop yours because a peer proposed a different one.

## Mode: peer — Revised Stance

```yaml
type: peer_stance
reviewer: reviewer-{n}
files:
  - path: tests/unit/Core/Content/ProductTest.php
    scope: full class            # or [testFoo, testBar]
    findings:
      - finding_id: "CONV-001|testAddsLineItem|3f2a9c14"   # quoted verbatim from the finding you were given
        rule_id: CONV-001
        enforce: must-fix
        location: ProductTest.php:45
        summary: "Description"
        current: |
          # code
        suggested: |
          # fix
    withdrawn:
      - finding_id: "ISOLATION-003|testAddsLineItem|8b41d0e7"
        rule_id: ISOLATION-003
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
      - finding_id: "CONV-001|testAddsLineItem|3f2a9c14"
        rule_id: CONV-001
        enforce: must-fix
        location: ProductTest.php:45
        summary: "Description"
        current: |
          # code
        suggested: |
          # fix
        adversary_impact: defended      # defended | unchanged
    re_adopted:
      - finding_id: "DESIGN-005|testRejectsEmptyCart|c07e5512"   # the id the resurrection cites
        rule_id: DESIGN-005
        enforce: should-fix
        location: ProductTest.php:72
        summary: "Re-adopted after adversary resurrection"
        current: |
          # code
        suggested: |
          # fix
        adversary_impact: resurrected
    withdrawn:
      - finding_id: "CONV-008|testRejectsEmptyCart|91ab34f0"
        rule_id: CONV-008
        reason: "Adversary showed the detection algorithm does not apply at line 60"
        adversary_impact: overturned
    adopted_new:
      - finding_id: "ISOLATION-002|testUsesFixedClock|5d6c2ea8"   # the id the adversary's new finding carries
        rule_id: ISOLATION-002
        enforce: must-fix
        location: ProductTest.php:88
        summary: "Adopted from adversary"
        current: |
          # code
        suggested: |
          # fix
        adversary_impact: introduced
```
