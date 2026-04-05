# Red Team Context Package

Defines the context package sent to adversaries in Phase 6, and the conditions under which the red team round is skipped.

## Skip Conditions

The red team round (Phases 6-7) is skipped when either condition is true:

1. **Zero findings** — all reviewers reported 0 findings across all files after Phase 5. Nothing to challenge.
2. **Substantive round 1 debate** — team lead judges from Phase 4 debate messages that challenges outnumbered concessions and findings were actively contested. The problem the red team solves (groupthink) didn't occur.

When skipped, flow goes directly from Phase 5 to Phase 8 (verdicts use round 1 final stances as binding input).

## Context Package Format

Assemble the following per file assigned to each adversary. The package includes the merged consensus from Phase 5, all withdrawn findings with reasons, and the raw debate transcript from Phase 4.

```yaml
- file_path: tests/unit/Path/To/ClassTest.php
  category: B
  consensus_findings:
    - rule_id: CONV-004
      enforce: must-fix
      consensus: UNANIMOUS  # or MAJORITY
      location: ClassTest.php:45
      summary: "Description of violation"
  withdrawn_findings:
    - rule_id: DESIGN-005
      originally_reported_by: reviewer-1
      conceded_in: debate  # or final_stance
      reason: "reviewer-2 argued detection algorithm doesn't apply because..."
  debate_transcript:
    - reviewer: reviewer-1
      challenges: [...]
      concessions: [...]
    - reviewer: reviewer-2
      challenges: [...]
      concessions: [...]
```

### consensus_findings

Merged from Phase 5 final stances. For each unique `(rule_id, location)` pair where 2+ of 3 reviewers agree:
- `consensus`: UNANIMOUS (3-of-3) or MAJORITY (2-of-3)
- Use the majority's enforce level, location, summary, current, and suggested

### withdrawn_findings

All findings that appeared in Phase 3 (independent review) but were not in Phase 5 (final stances). For each:
- `originally_reported_by`: which reviewer first reported it
- `conceded_in`: whether it was dropped during debate (Phase 4 concession) or in the final stance (Phase 5)
- `reason`: the reason given for withdrawal — this is what adversaries scrutinize for weakness

### debate_transcript

Raw Phase 4 debate messages for this file, one entry per reviewer. Include the full challenges, concessions, endorsements, justifications, and cross_file_references arrays. This lets adversaries see the reasoning process, not just the outcome.
