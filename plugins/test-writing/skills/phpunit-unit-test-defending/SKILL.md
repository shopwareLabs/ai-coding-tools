---
name: phpunit-unit-test-defending
version: 3.5.0
description: >
  Defense against adversary challenges in the team review defense round.
  Receives adversary challenges, engages each on its merits, and outputs
  defense stance with adopted, re-adopted, and withdrawn findings.
allowed-tools: Read, Glob, Grep, mcp__plugin_test-writing_test-rules__get_rules
---

# PHPUnit Test Review Defense

Defend your findings against adversary challenges. Evaluate each challenge on its merits, then produce your defense stance.

## Input

Provided in spawn prompt by team-lead:

- `own_final_stance`: your final stance from Wave 1 (debating skill output)
- `adversary_challenges`: challenges from the adversary for your assigned files

## Phase 1: Evaluate Challenges

Load references/defense-rules.md.

For each file, evaluate every adversary challenge:

### Challenges to Consensus

For each challenge:
1. Read the code at the cited location
2. Call `mcp__plugin_test-writing_test-rules__get_rules(ids={rule_id})` to load the detection algorithm
3. Apply the detection algorithm against the actual code
4. If the adversary's evidence holds: concede (withdraw the finding)
5. If your evidence is stronger: defend with counter-evidence citing the detection algorithm

### Resurrections

For each resurrection of a finding you withdrew in round 1:
1. Re-read the adversary's resurrection argument
2. Compare against your original concession reason
3. If the adversary's evidence is stronger than the reason you conceded: re-adopt the finding
4. If your concession was valid: maintain withdrawal with strengthened reason

### New Findings

For each adversary-introduced finding:
1. Verify the detection algorithm citation
2. Read the code at the cited location
3. Challenge or concede using the same standard as round 1 peer findings

### Endorsements

Note endorsed findings. No action required.

## Phase 2: Defense Stance

Produce defense stance per file using the format from references/output-format.md:

- Defended findings (`adversary_impact: defended` or `unchanged`)
- Re-adopted findings (`adversary_impact: resurrected`)
- Withdrawn findings (`adversary_impact: overturned`)
- Adopted new findings from adversary (`adversary_impact: introduced`)

This is your output. Return it to the lead.

## Troubleshooting

### MCP Tool Unavailability

If `mcp__plugin_test-writing_test-rules__get_rules` is unavailable, you cannot verify detection algorithms. Maintain your round 1 positions and note the limitation.
