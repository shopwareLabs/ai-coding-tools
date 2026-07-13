# Output Format

Structured output for the adversarial reviewing skill. All challenges must cite detection algorithm evidence.

## Output Contract

```yaml
status: CHALLENGES_RAISED | NO_CHALLENGES | FAILED
files:
  - file_path: tests/unit/Path/To/ClassTest.php
    challenges_to_consensus:
      - rule_id: CONV-004
        consensus_was: UNANIMOUS | MAJORITY
        challenge: "Detection algorithm requires X but the code at line 45 actually..."
        verdict_sought: overturn | weaken
    resurrections:
      - rule_id: DESIGN-005
        originally_reported_by: reviewer-1
        resurrection_argument: "The concession was premature because..."
        code_evidence: "ClassTest.php:72 — specific code that triggers the detection algorithm"
    new_findings:
      - rule_id: ISOLATION-002
        enforce: must-fix
        location: ClassTest.php:88
        summary: "Description of new violation"
        current: |
          # problematic code
        suggested: |
          # fixed code
        detection_algorithm_citation: "ISOLATION-002 specifies..."
    endorsements:
      - rule_id: UNIT-003
        reason: "Strong finding, correctly applied — Phase 1 scan independently flagged this area"
    cross_file_inconsistencies:
      - rule_id: CONV-004
        this_file_status: accepted
        other_file: tests/unit/Other/ClassTest.php
        other_file_status: flagged
        inconsistency: "Same pattern, divergent treatment across files"
reason: null  # explanation if FAILED
```

## Status Values

| Status | Condition |
|--------|-----------|
| CHALLENGES_RAISED | 1+ challenges, resurrections, new findings, or cross-file inconsistencies |
| NO_CHALLENGES | All consensus findings endorsed, no resurrections or new findings |
| FAILED | Input validation failed or skill could not complete |

## Field Requirements

### challenges_to_consensus
- `challenge` MUST cite the detection algorithm and specific code evidence
- `verdict_sought`: `overturn` = finding should be removed entirely; `weaken` = enforce level should be reduced

### resurrections
- `resurrection_argument` MUST explain why the original concession was premature
- `code_evidence` MUST point to specific lines that trigger the detection algorithm

### new_findings
- MUST follow the same format as reviewer findings (rule_id, enforce, location, current, suggested)
- `detection_algorithm_citation` is REQUIRED — new findings without evidence are rejected

### endorsements
- Include for strong consensus findings that the adversary agrees with
- Endorsements are important signal — they strengthen findings in the final report

### cross_file_inconsistencies
- Only applicable when the adversary reviews multiple files
- Compares how the same rule_id was treated across different files in the consensus
