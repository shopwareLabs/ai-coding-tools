# Output Format

Structured output for the adversarial reviewing skill. All challenges must cite detection algorithm evidence.

**`finding_id` identifies a finding.** Every consensus and withdrawn finding in the package you are given carries one — `{rule_id}|{method}|{fingerprint}` (`method` normalized — a trailing `(...)` call suffix and surrounding whitespace stripped — into its own literal segment of the id; the fingerprint segment hashes only the whitespace-normalized `current`, or `summary` where `current` is empty, never `method`), issued by the review that raised it. Quote it verbatim on each challenge and each resurrection; it is what ties your entry to the finding, and what lets the defenders act on the one you meant. Never invent, alter, or reuse one across defects. A finding you introduce is new: it carries no `finding_id` and is issued one when the workflow ingests it. Line numbers are not identity — a `rule_id` shared by two findings does not make them one, and two locations for one defect do not make it two.

**Every distinct remediation is kept.** The merge preserves each stance's `suggested` (as `suggested_variants`, longest first), so a new finding's `suggested` is never overwritten by a competing one — write the complete fix rather than one that echoes the panel's.

## Output Contract

```yaml
status: CHALLENGES_RAISED | NO_CHALLENGES | FAILED
files:
  - file_path: tests/unit/Path/To/ClassTest.php
    challenges_to_consensus:
      - finding_id: "CONV-004|testAddsLineItem|3f2a9c14"   # quoted verbatim from the consensus package
        rule_id: CONV-004
        consensus_was: UNANIMOUS | MAJORITY
        challenge: "Detection algorithm requires X but the code at line 45 actually..."
        verdict_sought: overturn | weaken
    resurrections:
      - finding_id: "DESIGN-005|testRejectsEmptyCart|c07e5512"   # from withdrawn_findings in the package
        rule_id: DESIGN-005
        originally_reported_by: reviewer-1
        resurrection_argument: "The concession was premature because..."
        code_evidence: "ClassTest.php:72 — specific code that triggers the detection algorithm"
    new_findings:                                          # introduced here, so no finding_id
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
- `finding_id` is REQUIRED — the challenged finding's own id, quoted from the consensus package
- `rule_id` is REQUIRED — the rule the challenged finding was raised under, quoted verbatim from the leading segment of its `finding_id`. The defense wave assembles each file's disputed-rule package out of the `rule_id`s its challenges, resurrections and new findings cite, so an entry that omits it drops the very rule the defenders judge it under
- `challenge` MUST cite the detection algorithm and specific code evidence
- `verdict_sought`: `overturn` = finding should be removed entirely; `weaken` = enforce level should be reduced

### resurrections
- `finding_id` is REQUIRED — the withdrawn finding's own id, quoted from `withdrawn_findings`; a defender re-adopting it quotes the same id back
- `rule_id` is REQUIRED — the withdrawn finding's rule, quoted verbatim from the leading segment of its `finding_id`; it reaches the defenders' rule package the same way a challenge's does
- `resurrection_argument` MUST explain why the original concession was premature
- `code_evidence` MUST point to specific lines that trigger the detection algorithm

### new_findings
- MUST follow the same format as reviewer findings (rule_id, enforce, location, current, suggested), and carry NO `finding_id` — it is issued on ingest
- `detection_algorithm_citation` is REQUIRED — new findings without evidence are rejected

### endorsements
- Include for strong consensus findings that the adversary agrees with
- Endorsements are important signal — they strengthen findings in the final report

### cross_file_inconsistencies
- Only applicable when the adversary reviews multiple files
- Compares how the same rule_id was treated across different files in the consensus
