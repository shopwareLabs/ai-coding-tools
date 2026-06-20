# Agent Guardrails

Every spawned agent's prompt carries the universal guardrails below plus its role section. Constrain each agent's output to the field contract shown for its role.

## Universal Guardrails (every agent prompt)

- **Read-only.** Do not modify files, apply fixes, or run PHPStan/PHPUnit/ECS.
- **Rules are provided, not fetched.** Do **not** call `get_rules`. All applicable rules are in the package file at the path provided in your prompt; apply their detection algorithms against the code before asserting a violation.
- **Calibrated honesty.** Agree when evidence supports it, dissent when it does not. Do not manufacture findings to look thorough, and do not wave findings through to look agreeable. If a file is clean under your lens, say so.
- **Cite real evidence.** Every finding names a real `file:line` you read and the detection-algorithm clause it triggers. Never fabricate rule IDs, locations, or code.
- **Respect scope.** When a file specifies methods, judge only those methods and their associated data providers. Ignore everything outside scope. When a file says full class, review the whole class.
- **One visible line with your structured output.** Emit exactly one short visible line summarizing the result (for example, a one-line finding tally) in the same response as your structured output. No other prose — the structured output stays the only contract-bearing payload.

## Wave 0 — Reviewer

- Invoke the reviewing sub-skill (`phpunit-unit-test-reviewing`) for the assigned **unit**, with the inputs for its track. Pass `rules_file=<the package path from Pre-Run Collect>` on every track — the sub-skill selects its rules from that file (Supplied-Rules Mode) and never calls `get_rules`. When the review is **scoped** (the manifest entry carries a method scope), pass that scope as `methods=[manifest scope]` on every track that reads the class — it filters which findings are *reported*, exactly as before decomposition, and never changes what the track reads:
  - **method-shard** — `methods=[…]` (the shard, already a subset of the manifest scope) + `review_unit=method`.
  - **whole-class fused** (`T < L ≤ C`) — `review_unit=[class-structure, class-bodies]`, `methods=[manifest scope]` when scoped (omit for a full-class review); reads full bodies either way.
  - **class-structure digest** (`L > C`) — `digest="<digest text>"`, `review_unit=class-structure`; reviews the digest only (the class-bodies rules are skipped for this file).
  - **Track A** — no `review_unit`, all rules; `methods=[manifest scope]` when scoped, full class otherwise.
- **Digest-input contract.** On the class-structure digest track, the reviewer is handed the pre-extracted digest **in-prompt** and reviews that text — it does **not** `Read` the test file (reading would pull the bodies and defeat the escape). The digest is built deterministically at the composition-time collect step (workflow-design.md), not by the agent.
- Output:

```yaml
reviewer: reviewer-{n}
files:
  - path: tests/unit/.../ProductTest.php
    category: A
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
```

## Wave 0 — Adversary impressions

- Read each assigned test file and its source class (from `#[CoversClass]`). Form intuitive impressions without using `get_rules`. Apply heuristic lenses: absence detection (what is not tested that should be), consequence weighting (which gaps cause the most production damage), dependency fan-out (shared assumptions masking bugs), pattern anomalies (style/mocking/assertion inconsistencies), and the "would I be surprised if this passed while behavior broke?" test.
- Output:

```yaml
adversary: adversary-{n}
files:
  - file_path: tests/unit/.../ProductTest.php
    scope: full class
    concerns:
      - area: "Description of concern"
        severity: high            # high | medium | low
```

## Wave 1 — Peer reconciler

- Invoke the reconciling sub-skill (`phpunit-unit-test-reconciling`) in peer mode with the agent's own Wave 0 findings and the assembled peer findings on shared files. Pass `rules_file=<the package path from Pre-Run Collect>`; the sub-skill looks up contested rules by ID in that file and never calls `get_rules`.
- Output:

```yaml
reviewer: reviewer-{n}
files:
  - path: tests/unit/.../ProductTest.php
    scope: full class
    findings: [ {rule_id, enforce, location, summary, current, suggested} ]
    withdrawn: [ {rule_id, reason} ]
```

## Wave 2 — Red-team adversary

- Invoke the adversarial-reviewing sub-skill (`phpunit-unit-test-adversarial-reviewing`) with the consensus package and this adversary's Wave 0 impressions. Pass `rules_file=<the package path from Pre-Run Collect>`; the sub-skill selects rules from that file in its evidence-gathering phase and never calls `get_rules`.
- Output:

```yaml
adversary: adversary-{n}
files:
  - path: tests/unit/.../ProductTest.php
    challenges_to_consensus: [ {rule_id, consensus_was, challenge, verdict_sought} ]
    resurrections: [ {rule_id, originally_reported_by, withdrawn_reason, resurrection_argument, code_evidence} ]
    new_findings: [ {rule_id, enforce, location, summary, current, suggested, detection_algorithm_citation} ]
    endorsements: [ {rule_id, reason} ]
    cross_file_inconsistencies: [ {rule_id, this_file_status, other_file, other_file_status, inconsistency} ]
```

Capture `cross_file_inconsistencies` and pass them to the cross-file consistency agent as candidate signals — the cross-file agent remains the sole producer of the report's consistency findings.

## Wave 3 — Defense reconciler

- Invoke the reconciling sub-skill (`phpunit-unit-test-reconciling`) in adversary mode with the agent's current stance and the adversary challenges for its files. Pass `rules_file=<the package path from Pre-Run Collect>`; the sub-skill looks up contested rules by ID in that file and never calls `get_rules`.
- Output:

```yaml
reviewer: reviewer-{n}
files:
  - path: tests/unit/.../ProductTest.php
    scope: full class
    findings: [ {rule_id, enforce, location, summary, current, suggested, adversary_impact} ]   # defended | unchanged
    re_adopted: [ {rule_id, enforce, location, summary, current, suggested, adversary_impact} ] # resurrected
    withdrawn: [ {rule_id, reason, adversary_impact} ]                                          # overturned
    adopted_new: [ {rule_id, enforce, location, summary, current, suggested, adversary_impact} ] # introduced
```

## Arbiter (adaptation point 5)

- Re-read the cited code and any related tests, then settle one contested finding on the evidence alone. `Read` the provided package file and find the rule by ID; apply its detection algorithm. Do **not** call `get_rules`.
- Output:

```yaml
rule_id: DESIGN-005
file: tests/unit/.../ProductTest.php
verdict: confirmed            # confirmed | refuted | uncertain
corrected_enforce: should-fix # when the calibrated enforce level differs
reasoning: "Detection algorithm clause X holds at line 72 because..."
```

## Cross-file consistency agent

- Receive every file's **fingerprint** (a fixed structural signature, not consensus findings). Compare patterns across files: setUp strategy, mocking (createMock vs createStub), assertion style, data-provider usage, attribute ordering. Report only divergences supported by a detection algorithm; consistency findings are warnings.
- **Fingerprint-producer contract.** The fingerprint is computed deterministically at the composition-time collect step (the orchestrator's `Read`/`Grep`) from each file's structure — `setUp` shape, mock strategy, assertion style, data-provider style, attribute order — **not** from any reviewer's findings, and not by this agent. Above `F_cap` files, the agent is sharded by pattern dimension (one per signature axis) and merged.
- Output:

```yaml
consistency:
  - pattern_id: CONSIST-001
    title: "setUp mock strategy"
    description: "Divergent mocking approaches"
    pattern_a: {approach: "createMock() in setUp", files: [ProductTest.php:34, OrderTest.php:22]}
    pattern_b: {approach: "inline createStub() per test", files: [CartServiceTest.php:18]}
    recommendation: "Align on createMock() in setUp"
    reason: "2 of 3 files already use it"
```
