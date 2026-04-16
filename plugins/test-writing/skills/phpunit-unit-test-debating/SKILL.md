---
name: phpunit-unit-test-debating
version: 3.5.0
description: >
  Peer-to-peer debate of PHPUnit test review findings within an Agent Teams wave.
  Receives own findings and peer findings, debates with co-reviewers via SendMessage,
  and outputs final stance with withdrawn findings and reasons.
allowed-tools: Read, Glob, Grep, SendMessage, mcp__plugin_test-writing_test-rules__get_rules
---

# PHPUnit Test Review Debate

Peer-to-peer debate of review findings within a single Agent Teams wave. You debate directly with co-reviewers via SendMessage, then produce your final stance.

## Input

Provided in spawn prompt by team-lead:

- `own_findings`: your findings from Wave 0 (reviewing skill output)
- `peer_findings`: findings from co-reviewers on shared files
- `co_reviewers`: list of co-reviewer names and shared files

## Phase 1: Prepare Positions

Load references/debate-rules.md.

For each file, compare own findings against peer findings:

1. **Shared findings** (both you and peer reported) — prepare endorsement
2. **Peer-only findings** (peer reported, you didn't) — prepare challenge with detection algorithm citation, OR concession
3. **Own-only findings** (you reported, peer didn't) — prepare justification with code evidence

For challenges: call `mcp__plugin_test-writing_test-rules__get_rules(ids={rule_id})` to load the detection algorithm. Apply it against the code. If the peer is right, prepare concession instead.

## Phase 2: Debate (max 2 rounds)

### Round 1

For each co-reviewer, send ONE message via `SendMessage(to: "{co_reviewer_name}")` covering all shared files. Use the debate message format from references/output-format.md:

- Endorsements for shared findings
- Challenges with detection algorithm citations
- Justifications for own-only findings with code evidence
- Concessions where peer evidence is stronger
- Cross-file references where applicable (first-hand only)

After sending, wait for co-reviewer responses.

### Round 2 (if needed)

If you received challenges from co-reviewers in round 1:

1. Evaluate each challenge against the detection algorithm
2. Concede where their evidence is stronger
3. Defend where your evidence holds, citing specific code

Send ONE response per co-reviewer. Then proceed to Phase 3.

If no challenges were received, or all challenges are conceded, skip round 2.

### Convergence

- After round 2: proceed to Phase 3
- After round 1 with no open challenges: proceed to Phase 3
- If co-reviewer does not respond: proceed to Phase 3 with available input
- Do NOT send more than 2 debate messages per co-reviewer

## Phase 3: Final Stance

Produce final stance per file using the format from references/output-format.md:

- All findings you still stand by (with enforce level, location, current, suggested)
- Withdrawn findings with reasons (citing the peer's argument that convinced you)
- Cross-file references used during debate

This is your output. Return it to the lead.

## Troubleshooting

### Co-Reviewer Unresponsive

If a co-reviewer does not respond to your round 1 message, produce final stance from your own analysis and whatever peer findings you received in the input. Do not block.

### MCP Tool Unavailability

If `mcp__plugin_test-writing_test-rules__get_rules` is unavailable, you cannot verify detection algorithms. Concede peer findings you cannot verify and note the limitation in your final stance.
