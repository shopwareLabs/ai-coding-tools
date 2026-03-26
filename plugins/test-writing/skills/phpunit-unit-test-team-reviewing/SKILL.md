---
name: phpunit-unit-test-team-reviewing
version: 2.2.1
description: >
  Team-based PHPUnit test review with 3 independent reviewers reaching consensus
  through structured debate. Use when user requests "team review", "consensus review",
  "review with team", or "team-based review" of a Shopware unit test.
allowed-tools: >
  Bash, TeamCreate, TeamDelete, Agent, SendMessage,
  Read, Glob, Grep, AskUserQuestion,
  mcp__plugin_test-writing_test-rules__list_rules,
  mcp__plugin_test-writing_test-rules__get_rules
---

# Team-Based PHPUnit Unit Test Review

Three independent reviewers analyze a test file, debate their findings, and reach consensus. You (the skill executor) act as team lead: you orchestrate the team lifecycle, manage the debate, make final verdicts, and produce the report.

## Phase 0: Prerequisites Check

Run via Bash:

```bash
printenv CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
```

If the output is NOT exactly `1`, output the following and **stop immediately**:

```
Agent Teams is not enabled. Team-based review requires the experimental Agent Teams feature.

To enable it, add the following to the "env" section of ~/.claude/settings.json:

  "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"

Then restart Claude Code and try again.
```

Then ask via `AskUserQuestion`: "Would you like to use the standard single-reviewer instead?"

**Do not proceed to Phase 1.**

## Phase 1: Input Validation

1. Verify the input is a single file path
2. Verify the file exists
3. Verify it ends with `*Test.php` and is in `tests/unit/`
4. Read the test file
5. Find the `#[CoversClass(...)]` attribute to identify the source class
6. Read the source class
7. Detect the test category (A-E):

```
Has constructor dependencies?
├── No → Is it an Exception class?
│   ├── Yes → Category E
│   └── No → Category A (DTO)
└── Yes → Uses EntityRepository?
    ├── Yes → Category D (DAL)
    └── No → Implements EventSubscriberInterface or FlowAction?
        ├── Yes → Category C (Flow/Event)
        └── No → Category B (Service)
```

If validation fails, return immediately:

```
# PHPUnit Team Review: FAILED

**Reason**: {reason}
**Input**: {input}
```

## Phase 2: Team Setup

1. Call `TeamCreate(team_name: "test-review", description: "PHPUnit test review — 3 reviewers + lead")`

2. Read the debate protocol from [{baseDir}/references/debate-protocol.md]({baseDir}/references/debate-protocol.md)

3. Spawn all 3 reviewers in a **single message** (parallel). For each reviewer, call the Agent tool with:

```
Agent(
  subagent_type: "general-purpose",
  team_name: "test-review",
  name: "reviewer-{n}",
  prompt: <assembled spawn prompt — see below>
)
```

### Spawn Prompt Template

Assemble the following for each reviewer, replacing `{n}`, `{test_path}`, `{source_path}`, `{category}`, and `{debate_protocol}`:

```
You are reviewer-{n} in a team-based PHPUnit test review, part of team "test-review".

## Phase 1: Independent Review

Invoke Skill(test-writing:phpunit-unit-test-reviewing) for the test file at {test_path}.
The skill will produce a structured review report with findings (errors, warnings, informational).

After the skill completes, extract ALL findings from the report and send a single
SendMessage with type: findings to team-lead (see format below). Then go idle.

## Phase 2: Debate

Each new message from team-lead advances you to the next phase. When team-lead sends
you combined findings from all reviewers, respond with type: debate (not type: findings):
1. Compare peer findings against your own
2. For each peer finding you did NOT report: challenge with reasoning citing the
   rule's detection algorithm, OR concede acknowledging it is valid
3. For each finding only you reported: justify with specific code evidence and
   the rule's detection algorithm
4. Send a single SendMessage with type: debate to team-lead. Then go idle.

## Phase 3: Final Stance

When team-lead asks for your final stance, respond with type: final_stance
(not type: debate):
1. Revise your findings based on debate arguments
2. Include all findings you still stand by (with code snippets and suggested fixes)
3. List all withdrawn findings with reasons
4. Send a single SendMessage with type: final_stance to team-lead. Then go idle.

## Debate Protocol

{debate_protocol}

## Findings Format (Phase 1)

type: findings
reviewer: reviewer-{n}
findings:
  - rule_id: CONV-001
    enforce: must-fix
    location: ClassTest.php:45
    summary: "Description of violation"
    current: |
      # problematic code
    suggested: |
      # fixed code

## Debate Response Format (Phase 2)

type: debate
reviewer: reviewer-{n}
endorsements:
  - rule_id: CONV-001
    from: reviewer-2
    comment: "Agree — reason"
challenges:
  - rule_id: DESIGN-003
    from: reviewer-3
    reason: "Evidence from detection algorithm"
justifications:
  - rule_id: UNIT-003
    reason: "Evidence from code and detection algorithm"
concessions:
  - rule_id: ISOLATION-003
    reason: "Peer's argument is correct because..."

## Final Stance Format (Phase 3)

type: final_stance
reviewer: reviewer-{n}
findings:
  - rule_id: CONV-001
    enforce: must-fix
    location: ClassTest.php:45
    current: |
      # code
    suggested: |
      # fix
withdrawn:
  - rule_id: ISOLATION-003
    reason: "Conceded after reviewer-2's argument"

## Rules
- Do NOT modify any files — read-only
- Only communicate via SendMessage to team-lead
- One SendMessage per phase, then go idle. Each new message from team-lead = next phase.
- If you receive a shutdown request, respond approving shutdown
```

## Phase 3: Independent Review

- All 3 reviewers invoke `Skill(test-writing:phpunit-unit-test-reviewing)` independently
- Each extracts findings from the skill's report and sends them to `"team-lead"` via `SendMessage`
- Wait until all 3 reviewers have sent their findings
- If a reviewer goes idle without sending findings, send a `SendMessage` reminder:
  ```
  SendMessage(to: "reviewer-{n}", message: "Please send your review findings to team-lead using the Findings Format from your instructions.")
  ```
- If a reviewer goes idle a second time without findings, treat as failed (see Error Handling)

## Phase 4: Debate

1. Compile all three findings sets into a single combined YAML block, grouped by reviewer
2. Send to each reviewer individually via `SendMessage`:

```
SendMessage(to: "reviewer-{n}", message: "Here are all findings from the team review:

[combined findings YAML, grouped by reviewer name]

Compare these against your own findings following the Debate Protocol:
- For each peer finding you did NOT report: challenge with detection algorithm evidence, or concede
- For each finding only you reported: justify with code evidence
- Endorse findings you agree with

Send your debate response to team-lead.")
```

3. Wait for all 3 debate responses

## Phase 5: Final Stances

1. Compile all debate responses into a single combined message
2. Send to each reviewer via `SendMessage`:

```
SendMessage(to: "reviewer-{n}", message: "Here are all debate responses:

[combined debate YAML, grouped by reviewer name]

Revise your findings based on the debate arguments. Your final stance replaces your original findings — anything not included is considered withdrawn. Include withdrawn findings with reasons.

Send your final stance to team-lead.")
```

3. Wait for all 3 final stances

## Phase 6: Verdicts & Report

### Merge Final Stances

For each unique `(rule_id, location)` pair across all three final stances:

- **3-of-3 (UNANIMOUS)**: include in report, no dissent annotation
- **2-of-3 (MAJORITY)**: include in report, attach dissent annotation from the reviewer who did not include it (from their `withdrawn` list or absence)
- **1-of-3 (MINORITY)**: exclude from report, log as contested finding

**Location matching**: match by `rule_id` first, then treat locations within a 5-line range of the same method as the same finding. Use the location from the majority if ambiguous.

**Enforce level conflicts**: if reviewers agree a violation exists but disagree on enforce level, use the majority enforce level and note the disagreement in the dissent.

### Produce Report

Generate the report in this format:

```markdown
# PHPUnit Team Review: [TestClassName]

## Summary
- **File**: `{test_path}`
- **Status**: PASS | NEEDS_ATTENTION | ISSUES_FOUND
- **Category**: [A-E] ([Category Name])
- **Reviewers**: 3
- **Consensus**: {unanimous} unanimous, {majority} majority, {contested} contested

## Errors (Must Fix)

### [{RULE-ID}] {TITLE} — {UNANIMOUS|MAJORITY}
- **Location**: `TestFile.php:line`
- **Current Code**:
  ```php
  // problematic code
  ```
- **Suggested Fix**:
  ```php
  // corrected code
  ```
- **Dissent** (if MAJORITY): reviewer-{n}: "{reason for disagreement}"

## Warnings (Should Fix)

### [{RULE-ID}] {TITLE} — {UNANIMOUS|MAJORITY}
- **Location**: `TestFile.php:line`
- **Current Code**:
  ```php
  // current code
  ```
- **Suggested Fix**:
  ```php
  // improved code
  ```
- **Dissent** (if MAJORITY): reviewer-{n}: "{reason}"

## Informational

### [{RULE-ID}] {TITLE} — {UNANIMOUS|MAJORITY}
- **Location**: `TestFile.php:line`
- **Suggestion**: Optional improvement

## Contested Findings

Findings reported by only 1 reviewer (excluded from above):

### [{RULE-ID}] {TITLE}
- **Reported by**: reviewer-{n}
- **Reason**: "{why they flagged it}"
- **Not flagged by**: reviewer-{a}, reviewer-{b}
```

### Status Determination

Only count findings that reached majority (2-of-3 or 3-of-3):

- **PASS** — 0 majority errors, 0 majority warnings
- **NEEDS_ATTENTION** — 0 majority errors, 1+ majority warnings
- **ISSUES_FOUND** — 1+ majority errors

### Output Contract

```yaml
test_path: tests/unit/Path/To/ClassTest.php
status: PASS | NEEDS_ATTENTION | ISSUES_FOUND
category: A|B|C|D|E
errors:
  - rule_id: {rule_id}
    title: {title}
    enforce: must-fix
    location: ClassTest.php:45
    consensus: unanimous|majority
    current: |
      # code
    suggested: |
      # fix
    dissent: null | {reviewer: reason}
warnings:
  - rule_id: {rule_id}
    title: {title}
    enforce: should-fix
    location: ClassTest.php:78
    consensus: unanimous|majority
    current: |
      # code
    suggested: |
      # fix
    dissent: null | {reviewer: reason}
informational:
  - rule_id: {rule_id}
    title: {title}
    enforce: consider
    location: ClassTest.php:90
    consensus: unanimous|majority
    current: |
      # code
    suggested: |
      # fix
contested:
  - rule_id: {rule_id}
    title: {title}
    reported_by: reviewer-{n}
    reason: "description"
    not_flagged_by: [reviewer-{a}, reviewer-{b}]
consensus:
  reviewers: 3
  unanimous: {count}
  majority: {count}
  contested: {count}
```

### Cleanup

After producing the report:

1. Send shutdown requests to all 3 reviewers **in parallel** (single message, three SendMessage calls):
   ```
   SendMessage(to: "reviewer-1", message: "shutdown_request: Review complete, please shut down.")
   SendMessage(to: "reviewer-2", message: "shutdown_request: Review complete, please shut down.")
   SendMessage(to: "reviewer-3", message: "shutdown_request: Review complete, please shut down.")
   ```
2. Wait for shutdown responses
3. Call `TeamDelete`

## Error Handling

### Teammate Failures

| Scenario | Action |
|----------|--------|
| Any reviewer fails to produce findings | Abort team review. Shut down all reviewers, call `TeamDelete`. Inform user. |
| Reviewer idle without findings (after reminder) | Treat as failed. Abort team review. |

### Debate Failures

| Scenario | Action |
|----------|--------|
| Reviewer doesn't engage with all peer findings | Send specific `SendMessage` requesting engagement with the missed findings. |
| Reviewer adds new findings during debate | Ignore new findings. Notify reviewer: "Protocol rule 4: no new findings during debate." |
| Reviewer doesn't submit final stance | Use their debate-round position as final stance. |

### Team Lifecycle Failures

| Scenario | Action |
|----------|--------|
| `TeamCreate` fails | Inform user that Agent Teams may not be available. Stop. |
| `TeamDelete` fails | Log warning, return results anyway. |
| User interrupts | Send shutdown to all reviewers, then `TeamDelete`. |

On ALL exit paths (success, failure, interruption), ensure `TeamDelete` is called to clean up the team.
