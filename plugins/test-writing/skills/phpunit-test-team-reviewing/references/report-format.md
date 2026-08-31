# Report Format

Render the campaign's persisted stage results into the report below. The results already carry the computed statuses, consensus levels, and adversary-impact tags — render them, do not recompute.

## Stage Results & Merge

The campaign persists one result per stage; the report consumes the **merged** view:

| Stage result | Contributes |
|---|---|
| `shard-k.result.json` (`mode: review`) | per-file consensus-stage verdicts, `adversarial_input` payloads, the `adversarial_gate` signal, `decomposition`, per-stage cost |
| `adversarial.result.json` (`mode: adversarial`) | **final** per-file verdicts — they supersede the consensus-stage entries for every file they cover — plus `red_team` metrics and per-stage cost |
| `signals.result.json` (`mode: signals`) | `consistency` + `adoption_opportunities` |
| skill merge (Phase 5, deterministic) | `coverage_overlap` + `placement_flags` — computed from the manifest and the merged per-file results, not by any run |

Merge rule for `files`: start from the concatenated shard results; when an adversarial result exists, replace each file's entry with the adversarial one (keep the shard entry's `track`/`units`/`reviewers`/`wholeClass` fields, which the adversarial entry does not repeat). A stage result with `partial: true` never reaches this merge — the campaign stops on it (error-handling.md).

## Dry-Run Projection

The Phase-2 projection run returns an agents-free shape (no review was performed). Render it as a table so the user can pick a preset before the campaign starts:

```
{ dry_run: true, files: <N>, slots: <SLOTS>, model_combos: [<names>],
  projections: { <preset>: { units, reviewers_per_wave, adversaries_per_wave, wave0_agents,
                             review_agents_bound, adversarial_agents_bound,
                             max_structural_agents, chunks, lenses, arbMax,
                             per_file: [{path, units, weight}] }, ... } }
```

```markdown
**Projected agents** ({files} files) — pick a preset:

| Preset   | Units | Wave-0 agents | Review bound | Adversarial bound | Lenses | arbMax |
|----------|-------|---------------|--------------|-------------------|--------|--------|
| deep     | {units} | {wave0_agents} | {review_agents_bound} | {adversarial_agents_bound} | {lenses} | {arbMax} |
| standard | …     | …             | …            | …                 | …      | …      |
| lean     | …     | …             | …            | …                 | …      | …      |

Model combos ({model_combos}) change cost, not agent count. The bounds are upper bounds — conditional waves and capped arbitration run fewer. `per_file` weights drive the shard plan (reviewer-allocation.md §Shard Budget); render the resulting plan (shards × files, projected agents each) under the table.
```

## Multi-File Report Template

```markdown
# PHPUnit Team Review

## Summary
- **Files reviewed**: {N} ({files_reviewed_by_type, e.g. unit×3, integration×2, migration×1})
- **Reviewers**: {R}
- **Stages**: {k} review shard(s) + signals{ + adversarial | ; adversarial skipped: {gate reason/user choice}}
- **Agents / output tokens per stage**: {one line per stage result: agents_spawned, output_tokens} (true fan-out — every agent, retries included; output tokens are NOT the cache-inclusive billable total — render `n/a` when null)
- **Overall status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND (from the merged per-file statuses)
- **Files with issues**: {count} of {N}
- **Source-change escalations**: {implies_src_change_count} (findings implying a production change — informational; render only when > 0)

| File | Type | Status | Category | Errors | Warnings |
|------|------|--------|----------|--------|----------|
| `ProductTest.php` | unit | ISSUES_FOUND | A | 2 | 1 |
| `FooControllerTest.php` | integration | PASS | n/a | 0 | 0 |

## File: ProductTest.php
- **Baseline**: pass | fail | unavailable

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

#### [CONV-001] Title
- **Method**: `testRendersLabel` · `ProductTest.php:45` (method is the stable locator; line is a hint that drifts)
- **Consensus**: UNANIMOUS
- **Provenance**: UNCHANGED
- **Branch scope**: n/a
- **Arbitration**: none
- **Source change**: no
- **Removed assertions**: none
- **Current Code**:
  ```php
  // problematic code
  ```
- **Suggested Fix**:
  ```php
  // corrected code
  ```

#### [DESIGN-003] Title
- **Method**: `testAppliesDiscount` · `ProductTest.php:78`
- **Consensus**: MAJORITY
- **Provenance**: UNCHANGED
- **Branch scope**: untouched (the diff did not touch this method — `branch_touched: false`)
- **Arbitration**: none
- **Source change**: no
- **Removed assertions**: none
- **Dissent**: reviewer-2: "reason for disagreement"

#### [DESIGN-005] Title
- **Method**: `testHandlesNullCustomer` · `ProductTest.php:72`
- **Consensus**: MAJORITY
- **Provenance**: ADVERSARY_RESURRECTED (an adversary resurrected it after peer reconciliation withdrew it)
- **Branch scope**: n/a
- **Arbitration**: none
- **Source change**: no
- **Removed assertions**: none
- **Dissent**: reviewer-2: "reason for disagreement"

#### [UNIT-001] Title
- **Method**: `testPrivateHelper` · `ProductTest.php:90`
- **Consensus**: MAJORITY
- **Provenance**: UNCHANGED
- **Branch scope**: n/a
- **Arbitration**: confirmed — contested 1-of-3; arbiter confirmed: "reasoning"
- **Source change**: yes (the fix cannot be made in the test alone — `implies_src_change: true`)
- **Removed assertions**: none

#### [DESIGN-002] Title
- **Method**: `testComputesTotal` · `ProductTest.php:120`
- **Consensus**: MAJORITY
- **Provenance**: UNCHANGED
- **Branch scope**: n/a
- **Arbitration**: split (needs human judgment) — contested must-fix; 3 adversary-tier arbiters reached no majority (e.g. 1 confirmed / 1 refuted / 1 uncertain, of 3): "reasoning". A `split` finding stays in the body for a human to settle, never silently dropped.
- **Source change**: no
- **Removed assertions**: `static::assertSame(0, $cart->getPrice())` → covered by `testComputesEmptyTotal`
- **Current Code**:
  ```php
  // problematic code
  ```
- **Suggested Fix 1** (most complete):
  ```php
  // corrected code — suggested_variants[0]
  ```
- **Suggested Fix 2**:
  ```php
  // the other stance's remediation — suggested_variants[1]
  ```

### Warnings (Should Fix)
(same structure as Errors)

### Informational
(same structure, without Dissent)

### Contested Findings

Findings reported by only 1 reviewer, or refuted by an arbiter (excluded from above):

#### [RULE-ID] Title
- **Method**: `testComputesTotal` · `ProductTest.php:120`
- **Consensus**: CONTESTED
- **Provenance**: UNCHANGED
- **Branch scope**: touched | untouched | n/a
- **Arbitration**: none | refuted — "reasoning"
- **Source change**: no
- **Removed assertions**: `static::assertSame(0, $cart->getPrice())` → covered by `testComputesEmptyTotal`
- **Reported by**: reviewer-{n}
- **Reason**: "why they flagged it"
- **Outcome**: not flagged by reviewer-{a}, reviewer-{b} / arbiter refuted: "reasoning"
- **Current Code**:
  ```php
  // problematic code
  ```
- **Suggested Fix 1** (most complete):
  ```php
  // corrected code — suggested_variants[0]
  ```
- **Suggested Fix 2**:
  ```php
  // the other stance's remediation — suggested_variants[1]
  ```

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

## Adoption Opportunities

A reusable test abstraction the changeset introduced that an untouched changeset peer could adopt (`adoption_opportunities`) — **informational, never raises status**, changeset-bounded (diff runs only). Render only when `adoption_opportunities` is non-empty.

### New abstraction: `tests/unit/.../Stub/FooStub.php`
- **Introduced by**: `tests/unit/.../FooTest.php`
- **Could be adopted by**:
  - `tests/unit/.../BarTest.php` · `testBaz` — [UNIT-003] inline `createMock(Foo)` chain could use the new `FooStub`

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

_Adversarial stage was skipped: {gate signal (zero kept findings / concession ≥ 50%) or the user's gate decision}_ (only when skipped — the per-file verdicts are then the consensus-stage results)

---

## Adaptation

What the review adapted this run (omit the section when nothing fired):

- **Extra peer pass**: ran for {count} reviewer(s) with unresolved disputes
- **Extra reviewers**: spawned for `{file}` ({+count} reviewers, high contention)
- **Arbiters**: {count} contested findings arbitrated ({confirmed} confirmed, {refuted} refuted, {split} split — needs human judgment); contested must-fix get 3 adversary-tier arbiters; hard caps `arbFile` per file and `arbMax` per run, must-fix first — the trimmed tail stays contested
```

## Per-finding render conventions

Apply to every finding (errors, warnings, informational, contested):

- **The heading is the defect, nothing else** — a finding's heading is exactly `#### [RULE-ID] Title`. Consensus, provenance, branch scope, arbitration, and source-change status are field lines under it; no heading suffix carries any of them.
- **Consensus on every finding** — render `**Consensus**: UNANIMOUS | MAJORITY | CONTESTED` (from `consensus`) on ALL findings, not just the high-severity ones, and keep the `Contested Findings` section. Do not collapse the convention bulk into bare location lists — a contested CONV finding must read differently from a unanimous one.
- **Method-primary locator** — render `**Method**: \`testName\` · \`File:line\``. The method is the stable locator; the `:line` is a drift-prone hint. `method` is `class-level` for whole-class/structural findings.
- **Provenance** — render `**Provenance**:` holding the finding's `adversary_impact` value, upper-cased: `UNCHANGED`, `DEFENDED`, `OVERTURNED`, `ADVERSARY_RESURRECTED` (`resurrected`), `ADVERSARY_INTRODUCED` (`introduced`).
- **Branch scope** — render `**Branch scope**: touched` when `branch_touched` is `true`, `untouched` when `false`, `n/a` when `null` (non-diff run, or a `class-level` finding). A modified file is reviewed full-class so ripple is covered, so `untouched` findings are expected and this field is the triage signal.
- **Arbitration** — render `**Arbitration**: none` when `arbitration` is `null`; otherwise the `verdict` (`confirmed` / `refuted` / `uncertain` / `split`) followed by ` — ` and its `reasoning`.
- **Source change** — render `**Source change**: yes` when `implies_src_change` is `true` (and list the finding under Source-Change Escalations), `no` otherwise.
- **Removed assertions** — render `**Removed assertions**: none` when `removed_assertions` is empty; otherwise one `assertion` → `covered_by_test` pair per entry, where `covered_by_test` is the surviving test or the literal `none — coverage lost`.
- **Deleted methods** — render `- **Deleted methods**: \`testFoo\`, \`testBar\`` (bare method names, comma-separated) whenever `deleted_methods` is non-empty; omit the line entirely otherwise. A deletion remediation contributes no entry to `suggested_variants` (there is no rewritten body to show), so where every kept variant was a deletion this line renders in place of the `- **Suggested Fix**:` entries rather than the finding showing no remediation at all.
- **Every remediation is rendered** — with one entry in `suggested_variants`, render a single `- **Suggested Fix**:`. With more than one, render each entry under its own numbered entry — `- **Suggested Fix 1** (most complete):`, `- **Suggested Fix 2**:`, … in list order — so no stance's remediation is dropped from the report.

## Output Contract

The merged view the rendering consumes, assembled from the persisted stage results. Every stage result carries `mode` and its own `summary` (`agents_spawned`, `output_tokens` per stage). Stage-specific summary fields: a `review` result adds `kept_findings`, `contested_findings`, `concession_rate`, and `adversarial_gate: {skip_recommended, reason}` (the Phase-6 gate inputs); a `signals` result carries `consistency_findings` and `adoption_count`. A `review` file entry additionally carries `adversarial_input` — the persisted payload the adversarial launch consumes; never render it. A stage may instead return `{ mode, partial: true, halted_at: {wave, dead_agents, wave_size}, files, unprocessed_files }` — that stops the campaign (error-handling.md) and never reaches this merge.

```yaml
summary:
  files_reviewed: {N}
  files_reviewed_by_type: {unit: 3, integration: 2, migration: 1}
  reviewers: {R}
  agents_spawned: {count}                  # every agent() invocation across all waves (retries included) — true fan-out; render per stage
  output_tokens: {count}                   # each stage's output tokens (budget.spent()); NOT the cache-inclusive billable total; null if unavailable
  overall_status: PASS | NEEDS_ATTENTION | ISSUES_FOUND
  files_with_issues: {count}
  implies_src_change_count: {count}        # findings implying a production change (informational escalation)
files:
  - path: tests/unit/Core/Content/ProductTest.php
    test_type: unit | integration | migration
    baseline: pass | fail | unavailable   # the manifest entry's supplied pre-review test state, carried through the run
    status: ISSUES_FOUND
    category: A          # "n/a" for integration/migration
    reviewers: [reviewer-0, reviewer-1, reviewer-2]
    errors:
      - finding_id: "CONV-001|testRendersLabel|<fingerprint>"   # identity: rule + method + a hash of the finding's current (or summary)
        rule_id: CONV-001
        title: "Title"
        enforce: must-fix
        method: testRendersLabel       # stable locator; "class-level" for whole-class/structural findings
        location: ProductTest.php:45    # line is a hint; the location of the record supplying `suggested`
        locations: [ProductTest.php:45] # every distinct location the merged stances reported, first-seen order
        branch_touched: true | false | null   # diff-scoped runs: is method in changed_methods? null = non-diff / class-level
        implies_src_change: false       # true when the fix needs a production src/ change
        consensus: unanimous|majority
        adversary_impact: unchanged|defended|overturned|resurrected|introduced
        arbitration: null | {verdict: confirmed|refuted|uncertain|split, reasoning}   # split = contested must-fix, no arbiter majority, kept for human judgment
        summary: "what the defect is"   # the Issue text the reviewing sub-skills render; names every line `current` holds and `suggested` drops
        current: |
          # code
        suggested: |
          # fix
        suggested_variants:             # every distinct remediation the merged stances proposed, longest first; suggested is [0]
          - |
            # fix
        deleted_methods: []             # test methods this finding's fix removes entirely; [] when none
        removed_assertions: []          # [{assertion, covered_by_test}] — covered_by_test names the surviving test, or is the literal "none — coverage lost"
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
coverage_overlap:                                  # SUT -> tests covering it, by type — computed by the skill merge (Phase 5), not by a run
  - sut: src/Core/Content/Product/ProductController.php
    covered_by:
      - {path: tests/unit/.../ProductControllerTest.php, test_type: unit}
      - {path: tests/integration/.../ProductControllerTest.php, test_type: integration}
    note: integration test redundant with existing unit coverage of this SUT
placement_flags:                                   # informational, never raises status — computed by the skill merge (Phase 5): INTEGRATION-008 informational in the merged result and/or coverage-map redundancy
  - path: tests/integration/.../BarTest.php
    reason: assertions_unit_shape | redundant_with_unit | both
    evidence: "assertion-shape consensus: …; already covered by unit test(s): …"
    pointer: phpunit-integration-to-unit-migrating
adoption_opportunities:                            # informational, never raises status; diff runs only, changeset-bounded
  - new_abstraction: tests/unit/.../Stub/FooStub.php   # or class name
    introduced_by: tests/unit/.../FooTest.php
    candidates:                                    # reviewed changeset peers only
      - path: tests/unit/.../BarTest.php
        method: testBaz
        rule_ref: UNIT-003
        note: "inline createMock(Foo) chain could use the new FooStub"
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
red_team:                                          # from the adversarial stage result; when the gate skipped the stage, render the skip note instead
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
