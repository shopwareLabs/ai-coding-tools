# Report Format

Render the review's result into the report below. The result already carries the computed status, consensus levels, and adversary-impact tags — render them, do not recompute.

## Dry-Run Projection

The Phase-2 projection run returns an agents-free shape (no review was performed). Render it as a table so the user can pick a preset before the real run:

```
{ dry_run: true, files: <N>, slots: <SLOTS>, model_combos: [<names>],
  projections: { <preset>: { units, reviewers_per_wave, adversaries_per_wave,
                             wave0_agents, max_structural_agents, chunks, lenses, arbMax }, ... } }
```

```markdown
**Projected agents** ({files} files) — pick a preset:

| Preset   | Units | Wave-0 agents | Max agents (upper bound) | Chunks | Lenses | arbMax |
|----------|-------|---------------|--------------------------|--------|--------|--------|
| deep     | {units} | {wave0_agents} | {max_structural_agents} | {chunks} | {lenses} | {arbMax or ∞} |
| standard | …     | …             | …                        | …      | …      | …      |
| lean     | …     | …             | …                        | …      | …      | …      |

Model combos ({model_combos}) change cost, not agent count. `Max agents` is an upper bound — the conditional peer-reconciliation, red-team, and defense waves plus arbitration run fewer on a clean review.
```

## Multi-File Report Template

```markdown
# PHPUnit Team Review

## Summary
- **Files reviewed**: {N} ({files_reviewed_by_type, e.g. unit×3, integration×2, migration×1})
- **Reviewers**: {R}
- **Overall status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND
- **Files with issues**: {count} of {N}
- **Source-change escalations**: {implies_src_change_count} (findings implying a production change — informational; render only when > 0)

| File | Type | Status | Category | Errors | Warnings |
|------|------|--------|----------|--------|----------|
| `ProductTest.php` | unit | ISSUES_FOUND | A | 2 | 1 |
| `FooControllerTest.php` | integration | PASS | n/a | 0 | 0 |

## File: ProductTest.php

### Summary
- **Path**: `tests/unit/Core/Content/ProductTest.php`
- **Type**: unit
- **Status**: ISSUES_FOUND
- **Category**: A (DTO) — `n/a` for integration/migration
- **Reviewers**: reviewer-0, reviewer-1, reviewer-2
- **Consensus**: 2 unanimous, 1 majority, 1 contested
- **Decomposition**: Track A (or `Track B — 3 method-shards + whole-class (fused)`, or `Track B — 3 method-shards + class-structure digest; class-bodies skipped (920 lines > C)`)

> [!WARNING]
> **Split this test class.** Rendered only on the `L > C` escape: `ProductTest.php` (920 lines) exceeds the cross-body review limit `C`; the class-bodies (cross-method) rules were not evaluated. Method-shard and structural findings below are still complete.

### Errors (Must Fix)

#### [CONV-001] Title — UNANIMOUS — UNCHANGED
- **Method**: `testRendersLabel` · `ProductTest.php:45` (method is the stable locator; line is a hint that drifts)
- **Current Code**:
  ```php
  // problematic code
  ```
- **Suggested Fix**:
  ```php
  // corrected code
  ```

#### [DESIGN-003] Title — MAJORITY — UNCHANGED — OUT OF BRANCH SCOPE
- **Method**: `testAppliesDiscount` · `ProductTest.php:78` (the diff did not touch this method — `branch_touched: false`)
- **Dissent**: reviewer-2: "reason for disagreement"

#### [DESIGN-005] Title — MAJORITY — ADVERSARY_RESURRECTED
- **Method**: `testHandlesNullCustomer` · `ProductTest.php:72`
- **Adversary**: adversary-0 resurrected this finding after it was withdrawn in peer reconciliation
- **Dissent**: reviewer-2: "reason for disagreement"

#### [UNIT-001] Title — ARBITRATED (confirmed) — UNCHANGED — IMPLIES SRC CHANGE
- **Method**: `testPrivateHelper` · `ProductTest.php:90` (fix cannot be made in the test alone — `implies_src_change: true`)
- **Arbiter**: contested 1-of-3; arbiter confirmed — "reasoning"

#### [DESIGN-002] Title — ARBITRATED (split — needs human judgment) — UNCHANGED
- **Method**: `testComputesTotal` · `ProductTest.php:120`
- **Arbiter**: contested must-fix; 3 adversary-tier arbiters reached no majority (e.g. 1 confirmed / 1 refuted / 1 uncertain, of 3) — kept in the body for a human to settle, never silently dropped. Render only when `arbitration.verdict` is `split`.

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

## Cross-Cutting Coverage

The same SUT covered by more than one test, across types (`coverage_overlap`). Render only when `coverage_overlap` is non-empty.

### SUT: `src/Core/Content/Product/ProductController.php`
- **Covered by**: `tests/unit/.../ProductControllerTest.php` (unit), `tests/integration/.../ProductControllerTest.php` (integration)
- **Note**: integration test redundant with existing unit coverage of this SUT

---

## Placement Flags

Integration tests whose placement is suspect (`placement_flags`) — **informational, never raises status**. Render only when `placement_flags` is non-empty.

### `tests/integration/.../BarTest.php`
- **Reason**: `assertions_unit_shape` | `redundant_with_unit` | `both`
- **Evidence**: {evidence — assertion-shape consensus and/or the overlapping unit test}
- **To audit/migrate**: invoke `phpunit-integration-to-unit-migrating` on this file.

---

## Source-Change Escalations

Findings whose fix cannot be made in the test alone — they imply a production (`src/`) change (`implies_src_change`). A test-only task that surfaces a likely source defect — **informational, never raises status**. Render only when `implies_src_change` is non-empty.

| File | Rule | Method | Summary |
|------|------|--------|---------|
| `ProductTest.php` | UNIT-001 | `testPrivateHelper` | Private method only reachable via reflection — the class likely needs a public seam |

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
- **Arbiters**: {count} contested findings arbitrated ({confirmed} confirmed, {refuted} refuted, {split} split — needs human judgment); contested must-fix get 3 adversary-tier arbiters (uncapped on deep/standard; capped at `arbMax` on lean, must-fix always arbitrated)
```

## Per-finding render conventions

Apply to every finding (errors, warnings, informational, contested):

- **Consensus on every finding** — render each finding's consensus (`UNANIMOUS` / `MAJORITY`) and its adversary/arbitration status on ALL findings, not just the high-severity ones, and keep the `Contested Findings` section. Do not collapse the convention bulk into bare location lists — a contested CONV finding must read differently from a unanimous one.
- **Method-primary locator** — render `**Method**: \`testName\` · \`File:line\``. The method is the stable locator; the `:line` is a drift-prone hint. `method` is `class-level` for whole-class/structural findings.
- **Branch scope** (diff-scoped runs only) — append ` — OUT OF BRANCH SCOPE` to the finding's header when `branch_touched` is `false`: the finding sits on a method the diff did not touch. A modified file is reviewed full-class so ripple is covered, so out-of-scope findings are expected and this suffix is the triage signal. Omit the suffix when `branch_touched` is `true` or `null` (non-diff run, or a `class-level` finding).
- **Source-change** — append ` — IMPLIES SRC CHANGE` to the header when `implies_src_change` is `true`, and list the finding under Source-Change Escalations.

## Output Contract

The result the rendering consumes:

```yaml
summary:
  files_reviewed: {N}
  files_reviewed_by_type: {unit: 3, integration: 2, migration: 1}
  reviewers: {R}
  overall_status: PASS | NEEDS_ATTENTION | ISSUES_FOUND
  files_with_issues: {count}
  implies_src_change_count: {count}        # findings implying a production change (informational escalation)
files:
  - path: tests/unit/Core/Content/ProductTest.php
    test_type: unit | integration | migration
    status: ISSUES_FOUND
    category: A          # "n/a" for integration/migration
    reviewers: [reviewer-0, reviewer-1, reviewer-2]
    errors:
      - rule_id: CONV-001
        title: "Title"
        enforce: must-fix
        method: testRendersLabel       # stable locator; "class-level" for whole-class/structural findings
        location: ProductTest.php:45    # line is a hint
        branch_touched: true | false | null   # diff-scoped runs: is method in changed_methods? null = non-diff / class-level
        implies_src_change: false       # true when the fix needs a production src/ change
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
coverage_overlap:                                  # SUT -> tests covering it, by type
  - sut: src/Core/Content/Product/ProductController.php
    covered_by:
      - {path: tests/unit/.../ProductControllerTest.php, test_type: unit}
      - {path: tests/integration/.../ProductControllerTest.php, test_type: integration}
    note: integration test redundant with existing unit coverage of this SUT
placement_flags:                                   # informational, never raises status
  - path: tests/integration/.../BarTest.php
    reason: assertions_unit_shape | redundant_with_unit | both
    evidence: "assertion-shape consensus: …; already covered by unit test(s): …"
    pointer: phpunit-integration-to-unit-migrating
implies_src_change:                                # informational escalation, never raises status
  - path: tests/unit/.../ProductTest.php
    rule_id: UNIT-001
    method: testPrivateHelper
    location: ProductTest.php:90
    summary: "fix requires a production src/ change, not test-only"
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
