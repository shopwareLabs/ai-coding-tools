# Report Format

Render the review's result into the report below. The result already carries the computed status, consensus levels, and adversary-impact tags — render them, do not recompute.

## Multi-File Report Template

```markdown
# PHPUnit Team Review

## Summary
- **Files reviewed**: {N}
- **Reviewers**: {R}
- **Overall status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND
- **Files with issues**: {count} of {N}

| File | Status | Category | Errors | Warnings |
|------|--------|----------|--------|----------|
| `ProductTest.php` | ISSUES_FOUND | A | 2 | 1 |
| `CartServiceTest.php` | PASS | B | 0 | 0 |

## File: ProductTest.php

### Summary
- **Path**: `tests/unit/Core/Content/ProductTest.php`
- **Status**: ISSUES_FOUND
- **Category**: A (DTO)
- **Reviewers**: reviewer-0, reviewer-1, reviewer-2
- **Consensus**: 2 unanimous, 1 majority, 1 contested
- **Decomposition**: Track A (or `Track B — 3 method-shards + whole-class (fused)`, or `Track B — 3 method-shards + class-structure digest; class-bodies skipped (920 lines > C)`)

> [!WARNING]
> **Split this test class.** Rendered only on the `L > C` escape: `ProductTest.php` (920 lines) exceeds the cross-body review limit `C`; the class-bodies (cross-method) rules were not evaluated. Method-shard and structural findings below are still complete.

### Errors (Must Fix)

#### [CONV-001] Title — UNANIMOUS — UNCHANGED
- **Location**: `ProductTest.php:45`
- **Current Code**:
  ```php
  // problematic code
  ```
- **Suggested Fix**:
  ```php
  // corrected code
  ```

#### [DESIGN-003] Title — MAJORITY — UNCHANGED
- **Location**: `ProductTest.php:78`
- **Dissent**: reviewer-2: "reason for disagreement"

#### [DESIGN-005] Title — MAJORITY — ADVERSARY_RESURRECTED
- **Location**: `ProductTest.php:72`
- **Adversary**: adversary-0 resurrected this finding after it was withdrawn in peer reconciliation
- **Dissent**: reviewer-2: "reason for disagreement"

#### [UNIT-003] Title — ARBITRATED (confirmed) — UNCHANGED
- **Location**: `ProductTest.php:90`
- **Arbiter**: contested 1-of-3; arbiter confirmed — "reasoning"

#### [DESIGN-002] Title — ARBITRATED (split — needs human judgment) — UNCHANGED
- **Location**: `ProductTest.php:120`
- **Arbiter**: contested must-fix; 3 opus arbiters reached no majority (e.g. 1 confirmed / 1 refuted / 1 uncertain, of 3) — kept in the body for a human to settle, never silently dropped. Render only when `arbitration.verdict` is `split`.

### Warnings (Should Fix)
(same structure as Errors)

### Informational
(same structure, without Dissent)

### Contested Findings

Findings reported by only 1 reviewer, or refuted by an arbiter (excluded from above):

#### [RULE-ID] Title
- **Reported by**: reviewer-{n}
- **Reason**: "why they flagged it"
- **Outcome**: not flagged by reviewer-{a}, reviewer-{b} / arbiter refuted: "reasoning"

---

## Cross-File Consistency

Patterns that diverge across reviewed files. Fixing these alongside the per-file findings ensures alignment.

### [CONSIST-001] Title
- **Pattern**: Description of the divergence
- **Files using pattern A**: `ProductTest.php:34`, `OrderTest.php:22`
- **Files using pattern B**: `CartServiceTest.php:18`
- **Recommendation**: Align on pattern A because {reason}
- **Source**: cross-file consistency agent

---

## Red Team Impact

| Metric | Count |
|--------|-------|
| Findings challenged by adversaries | {count} |
| Challenges survived (defended) | {count} |
| Challenges succeeded (overturned) | {count} |
| Withdrawn findings resurrected | {count} |
| New findings introduced by adversaries | {count} |
| New findings adopted by reviewers | {count} |
| Findings changed between peer and defense stances | {count} ({pct}%) |

> [!CAUTION]
> **Adversary coverage gap.** In-scope files left un-red-teamed after re-spawn — adversary coverage is incomplete: {red_team.coverage_gap.files}. (Render only when `red_team.coverage_gap` is set.)

_Red team round was skipped: {reason}_ (only when skipped)

---

## Adaptation

What the review adapted this run (omit the section when nothing fired):

- **Extra peer pass**: ran for {count} reviewer(s) with unresolved disputes
- **Extra reviewers**: spawned for `{file}` ({+count} reviewers, high contention)
- **Arbiters**: {count} contested findings arbitrated ({confirmed} confirmed, {refuted} refuted, {split} split — needs human judgment); contested must-fix get 3 opus arbiters
```

## Output Contract

The result the rendering consumes:

```yaml
summary:
  files_reviewed: {N}
  reviewers: {R}
  overall_status: PASS | NEEDS_ATTENTION | ISSUES_FOUND
  files_with_issues: {count}
files:
  - path: tests/unit/Core/Content/ProductTest.php
    status: ISSUES_FOUND
    category: A
    reviewers: [reviewer-0, reviewer-1, reviewer-2]
    errors:
      - rule_id: CONV-001
        title: "Title"
        enforce: must-fix
        location: ProductTest.php:45
        consensus: unanimous|majority
        adversary_impact: unchanged|defended|overturned|resurrected|introduced
        arbitration: null | {verdict: confirmed|refuted|uncertain|split, reasoning}   # split = contested must-fix, no arbiter majority, kept for human judgment
        current: |
          # code
        suggested: |
          # fix
        dissent: null | {reviewer: reason}
    warnings: [...]
    informational: [...]
    contested: [...]
    consensus:
      unanimous: {count}
      majority: {count}
      contested: {count}
consistency:
  - pattern_id: CONSIST-001
    title: "setUp mock strategy"
    description: "Divergent mocking approaches"
    pattern_a:
      approach: "createMock() in setUp"
      files: [ProductTest.php:34, OrderTest.php:22]
    pattern_b:
      approach: "inline createStub() per test"
      files: [CartServiceTest.php:18]
    recommendation: "Align on createMock() in setUp"
    reason: "2 of 3 files already use it"
    source: "cross-file consistency agent"
decomposition:
  - path: tests/unit/Core/Content/ProductTest.php
    track: A | B
    method_shards: 0          # >0 only for Track B
    whole_class: fused | digest-escape | n/a
    split_skip: null | "920 lines > C; class-bodies rules not evaluated"
red_team:
  skipped: false
  skip_reason: null
  challenges_made: {count}
  challenges_defended: {count}
  challenges_overturned: {count}
  resurrections: {count}
  new_findings_introduced: {count}
  new_findings_adopted: {count}
  change_rate: {pct}
  coverage_gap: null | {files: [...], note: "in-scope files left un-red-teamed after re-spawn — adversary coverage is incomplete"}
adaptation:
  extra_peer_pass_reviewers: {count}
  extra_reviewers_by_file: {ProductTest.php: 2}
  arbiters: {count}
  arbiters_confirmed: {count}
  arbiters_refuted: {count}
  arbiters_split: {count}      # contested must-fix with no arbiter majority, kept for human judgment
```
