---
name: phpunit-unit-test-adversarial-reviewing
version: 3.1.0
description: >
  Adversarial review of PHPUnit test consensus. Forms independent assessment
  before exposure to reviewer consensus, then challenges weak findings,
  resurrects premature withdrawals, and discovers missed violations. Invoked
  by adversary agents, not directly by orchestrators.
allowed-tools: Glob, Grep, Read, mcp__plugin_test-writing_test-rules__list_rules, mcp__plugin_test-writing_test-rules__get_rules
---

# PHPUnit Adversarial Test Review

Stress-tests reviewer consensus by forming independent judgment before exposure to findings, then challenging weak consensus, resurrecting premature withdrawals, and discovering missed violations.

## Overview

The adversarial reviewer operates on a different cognitive model than the standard reviewer. Where the reviewer applies rules systematically group-by-group, the adversary:

1. Reads the code with fresh eyes (no rules framework)
2. Receives the consensus (first exposure to reviewer reasoning)
3. Compares independent impressions against consensus to find gaps
4. Gathers rule evidence only for substantiated challenges
5. Scans for cross-file inconsistencies

**Input**: Consensus package (required) + optional pre-formed impressions from team idle time.

**Output**: Structured challenges report per [output-format.md]({baseDir}/references/output-format.md).

## Phase 1: Independent Intuitive Scan

**Skip condition**: If `impressions` input is provided (pre-formed by the adversary during idle time in team context), skip this phase entirely and proceed to Phase 2.

Read each assigned test file and its source class (from `#[CoversClass]`). Do NOT use MCP rule tools (`list_rules`, `get_rules`) in this phase.

Load [intuitive-scan-guidance.md]({baseDir}/references/intuitive-scan-guidance.md) for heuristic lenses, then for each file:

1. Read the test file completely
2. Read the source class under test (from `#[CoversClass]`)
3. Apply each heuristic lens from the guidance
4. Record concerns as free-form observations with severity estimate

Output per file:

```yaml
impressions:
  - file_path: tests/unit/Path/To/ClassTest.php
    concerns:
      - area: "brief description of concern"
        severity: high | medium | low
```

## Phase 2: Receive Consensus Package

Parse the consensus package provided as input:

1. Validate the package contains `consensus_findings`, `withdrawn_findings`, and `debate_transcript` per file
2. This is the first exposure to reviewer reasoning — note your initial reactions before proceeding

The consensus package follows the format defined in the team-reviewing skill's `red-team-context.md`.

## Phase 3: Structured Comparison

Load [comparison-strategies.md]({baseDir}/references/comparison-strategies.md). For each file, contrast Phase 1 impressions against Phase 2 consensus:

1. **Intuition-consensus gaps** — Phase 1 concerns that no reviewer raised. These are the highest-value candidates for new findings. For each unmatched concern, note which area of the code it targets.

2. **Weak consensus findings** — for each consensus finding, apply the "would this survive harder pushback?" test:
   - MAJORITY findings with thin reasoning in the debate transcript
   - Findings where the debate transcript shows quick concession without evidence
   - Findings that don't match your Phase 1 impressions at all

3. **Premature withdrawals** — for each withdrawn finding, check:
   - Does the concession reason cite a specific detection algorithm? If not, flag it.
   - Did your Phase 1 scan independently flag the same area? If yes, strong resurrection candidate.
   - Did only one reviewer push back while others followed? Bandwagon pattern.

4. **Assumption excavation** — for each consensus finding, state the unstated premise:
   - What must be true for this finding to be valid?
   - What breaks if that premise is wrong?

Output: prioritized list of candidate challenges, resurrections, and new findings — not yet evidence-backed.

## Phase 4: Evidence Gathering

For each candidate from Phase 3 (starting with highest-priority):

1. Call `mcp__plugin_test-writing_test-rules__list_rules(test_type=unit, test_category={category})` to discover applicable rules in the area of concern
2. Call `mcp__plugin_test-writing_test-rules__get_rules(ids={relevant rule IDs})` to load detection algorithms
3. Apply the detection algorithm against the actual code

**Promotion gate**: promote a candidate to a formal challenge ONLY if a detection algorithm substantiates it. Drop candidates where the evidence doesn't hold up. This is the filter against contrarianism — intuition proposes, evidence disposes.

**Endorsement**: consensus findings that Phase 1 intuition independently confirmed AND that have strong detection algorithm support get endorsed. Endorsements are part of the output — they strengthen findings in the final report.

## Phase 5: Cross-File Inconsistency Scan

Only applicable when reviewing multiple files. Compare patterns across all assigned files:

1. For each rule_id that appears in any file's consensus, check if the same pattern exists in other files:
   - File A's consensus accepted a pattern that file B's consensus flagged -> high-value challenge
   - All files share the same weakness but none flagged it -> systemic finding

2. Compare treatment of similar code patterns:
   - setUp() strategies across files
   - Mocking approaches (createMock vs createStub)
   - Assertion styles
   - Data provider usage

Cross-file inconsistencies use the same promotion gate as Phase 4 — cite the detection algorithm.

## Phase 6: Generate Challenges Report

Load [output-format.md]({baseDir}/references/output-format.md). Assemble the structured output:

1. Group all promoted challenges by file path
2. Include all endorsements
3. Include cross-file inconsistencies (from Phase 5)
4. Set status:
   - `CHALLENGES_RAISED` if any challenges, resurrections, new findings, or cross-file inconsistencies
   - `NO_CHALLENGES` if only endorsements
   - `FAILED` if input validation or processing failed

### Output Contract

```yaml
status: CHALLENGES_RAISED | NO_CHALLENGES | FAILED
files:
  - file_path: tests/unit/Path/To/ClassTest.php
    challenges_to_consensus:
      - rule_id: CONV-004
        consensus_was: UNANIMOUS | MAJORITY
        challenge: "Detection algorithm requires X but..."
        verdict_sought: overturn | weaken
    resurrections:
      - rule_id: DESIGN-005
        originally_reported_by: reviewer-1
        resurrection_argument: "The concession was premature because..."
        code_evidence: "ClassTest.php:72 — ..."
    new_findings:
      - rule_id: ISOLATION-002
        enforce: must-fix
        location: ClassTest.php:88
        summary: "Description"
        current: |
          # code
        suggested: |
          # fix
        detection_algorithm_citation: "ISOLATION-002 specifies..."
    endorsements:
      - rule_id: UNIT-003
        reason: "Strong finding, correctly applied"
    cross_file_inconsistencies:
      - rule_id: CONV-004
        this_file_status: accepted
        other_file: tests/unit/Other/ClassTest.php
        other_file_status: flagged
        inconsistency: "Same pattern, divergent treatment"
reason: null  # explanation if FAILED
```

## Troubleshooting

### No Impressions Formed in Phase 1

If the test file or source class cannot be read:
- Return FAILED with the file path and error
- Do not proceed to comparison phases without impressions

### MCP Tool Unavailability

If `mcp__plugin_test-writing_test-rules__list_rules` or `mcp__plugin_test-writing_test-rules__get_rules` are unavailable:
- Report error: "test-rules MCP server not available — ensure the test-writing plugin is installed and Claude Code was restarted"
- Candidates from Phase 3 cannot be promoted without evidence — return NO_CHALLENGES with a note explaining the limitation

### All Candidates Fail Promotion Gate

If Phase 4 drops all candidates (none substantiated by detection algorithms):
- This is a valid outcome — return NO_CHALLENGES
- Include endorsements for strong consensus findings
- The adversary adds value by confirming the consensus is robust
