# Agent Guardrails

Every spawned agent's prompt carries the universal guardrails below plus its role section. Constrain each agent's output to the field contract shown for its role.

## Universal Guardrails (every agent prompt)

- **Read-only.** Do not modify files, apply fixes, or run PHPStan/PHPUnit/ECS. The only tool beyond reading code is `mcp__plugin_test-writing_test-rules__get_rules`.
- **Detection algorithm is the source of truth.** Load the rule with `get_rules` and apply its detection algorithm against the actual code before asserting a violation.
- **Calibrated honesty.** Agree when evidence supports it, dissent when it does not. Do not manufacture findings to look thorough, and do not wave findings through to look agreeable. If a file is clean under your lens, say so.
- **Cite real evidence.** Every finding names a real `file:line` you read and the detection-algorithm clause it triggers. Never fabricate rule IDs, locations, or code.
- **Respect scope.** When a file specifies methods, judge only those methods and their associated data providers. Ignore everything outside scope. When a file says full class, review the whole class.
- **Return structured output only.** No prose outside the field contract.

## Wave 0 — Reviewer

- Invoke the reviewing sub-skill (`phpunit-unit-test-reviewing`) for each assigned file, passing the method scope when present.
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

- Invoke the reconciling sub-skill (`phpunit-unit-test-reconciling`) in peer mode with the agent's own Wave 0 findings and the assembled peer findings on shared files.
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

- Invoke the adversarial-reviewing sub-skill (`phpunit-unit-test-adversarial-reviewing`) with the consensus package and this adversary's Wave 0 impressions.
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

- Invoke the reconciling sub-skill (`phpunit-unit-test-reconciling`) in adversary mode with the agent's current stance and the adversary challenges for its files.
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

- Re-read the cited code and any related tests, then settle one contested finding on the evidence alone. Load the detection algorithm with `get_rules`.
- Output:

```yaml
rule_id: DESIGN-005
file: tests/unit/.../ProductTest.php
verdict: confirmed            # confirmed | refuted | uncertain
corrected_enforce: should-fix # when the calibrated enforce level differs
reasoning: "Detection algorithm clause X holds at line 72 because..."
```

## Cross-file consistency agent

- Receive every file's final consensus findings. Compare patterns across files: setUp strategy, mocking (createMock vs createStub), assertion style, data-provider usage, attribute ordering. Report only divergences supported by a detection algorithm; consistency findings are warnings.
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
