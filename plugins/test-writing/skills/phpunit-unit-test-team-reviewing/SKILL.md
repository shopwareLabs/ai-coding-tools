---
name: phpunit-unit-test-team-reviewing
version: 2.3.2
description: >
  Team-based PHPUnit test review with 3-5 independent reviewers reaching consensus
  through structured debate. Accepts flexible input (file paths, commits, branches,
  PRs, directories) and resolves to a list of test files. Each file is reviewed by
  3 reviewers from a variable-size pool with balanced overlap. Cross-file consistency
  analysis identifies pattern divergences across files.
allowed-tools: >
  Bash, TeamCreate, TeamDelete, Agent, SendMessage,
  Read, Glob, Grep, AskUserQuestion,
  mcp__plugin_test-writing_test-rules__list_rules,
  mcp__plugin_test-writing_test-rules__get_rules,
  mcp__plugin_gh-tooling_gh-tooling__pr_files
---

# Team-Based PHPUnit Unit Test Review

Independent reviewers analyze test files, debate their findings, and reach consensus. You (the skill executor) act as team lead: you resolve input, allocate reviewers, orchestrate the debate, merge verdicts, and produce the report.

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

## Phase 1: Input Resolution

`Read` references/input-resolution.md first — then follow its resolution strategies to build the file manifest. Do not run any git or file discovery commands before reading it.

Output: `[{path}]` — each entry is a validated test file. Let N = number of files in the manifest.

## Phase 2: Team Setup

1. Calculate reviewer count R:

   ```
   if N == 1: R = 3
   else:      R = min(5, max(4, ceil(N * 3 / 5)))
   ```

2. Compute file assignments per reviewer using round-robin per references/reviewer-allocation.md

3. Call `TeamCreate(team_name: "test-review", description: "PHPUnit test review — {R} reviewers + lead")`

4. Spawn all R reviewers in a **single message** (parallel). For each reviewer, call:

   ```
   Agent(
     subagent_type: "general-purpose",
     team_name: "test-review",
     name: "reviewer-{n}",
     prompt: <assembled spawn prompt>
   )
   ```

   Assemble each reviewer's prompt per references/spawn-prompt.md, substituting their assigned file paths, categories, the debate protocol content, and the message formats content.

## Phase 3: Independent Review

- All R reviewers invoke `Skill(test-writing:phpunit-unit-test-reviewing)` for each of their assigned files independently
- Each sends **one** combined findings message to team-lead covering all their files, grouped by file path
- Wait until all R reviewers have sent their findings
- If a reviewer goes idle without sending findings, send a `SendMessage` reminder:

  ```
  SendMessage(to: "reviewer-{n}", message: "Please send your review findings for all assigned files to team-lead using the batched Findings Format from your instructions.")
  ```

- If a reviewer goes idle a second time without findings, treat as failed (see references/error-handling.md)

## Phase 4: Debate

1. For each reviewer, compile findings from their co-reviewers on shared files. For each file assigned to reviewer-{n}, gather the findings from the other 2 reviewers assigned to that file.

2. Send to each reviewer individually via `SendMessage`:

   ```
   SendMessage(to: "reviewer-{n}", message: "Here are findings from your co-reviewers on your assigned files:

   [per-file findings from co-reviewers, grouped by file path]

   For each file, compare these against your own findings:
   - Challenge or concede each peer finding you did NOT report (cite detection algorithm)
   - Justify findings only you reported (cite code evidence)
   - You may reference patterns from other files you reviewed (cross_file_references)
   - Endorse findings you agree with

   Send your combined debate response to team-lead.")
   ```

3. Wait for all R debate responses

## Phase 5: Final Stances

1. For each reviewer, compile all debate responses relevant to their assigned files

2. Send to each reviewer via `SendMessage`:

   ```
   SendMessage(to: "reviewer-{n}", message: "Here are all debate responses for your assigned files:

   [per-file debate responses from co-reviewers]

   Revise your findings based on the debate arguments. Your final stance replaces your original findings — anything not included is considered withdrawn. Include withdrawn findings with reasons.

   Send your combined final stance to team-lead.")
   ```

3. Wait for all R final stances

## Phase 6: Verdicts & Report

### Per-File Consensus Merge

For each file, extract the 3 final stances from its assigned reviewers. For each unique `(rule_id, location)` pair:

- **3-of-3 (UNANIMOUS)**: include in report, no dissent annotation
- **2-of-3 (MAJORITY)**: include in report, attach dissent annotation from the reviewer who did not include it
- **1-of-3 (MINORITY)**: exclude from report, log as contested finding

**Location matching**: match by `rule_id` first, then treat locations within a 5-line range of the same method as the same finding. Use the location from the majority if ambiguous.

**Enforce level conflicts**: if reviewers agree a violation exists but disagree on enforce level, use the majority enforce level and note the disagreement.

### Cross-File Consistency Analysis

After all per-file verdicts, scan for pattern divergences:

1. Collect `cross_file_references` from all debate responses
2. Compare per-file reports for divergent approaches (setUp strategies, mocking, assertions, data providers, attribute ordering)
3. Where multiple files have the same violation, ensure suggested fixes use the same pattern

Consistency findings are `should-fix` (warnings) — they count toward NEEDS_ATTENTION but not ISSUES_FOUND.

### Status Determination

- **PASS** — all files PASS and no consistency findings
- **NEEDS_ATTENTION** — 0 errors across all files, but 1+ warnings or consistency findings
- **ISSUES_FOUND** — 1+ errors in any file

Generate the report per references/report-format.md.

## Cleanup

After producing the report:

1. Send shutdown requests to all R reviewers **in parallel** (single message, R SendMessage calls):

   ```
   SendMessage(to: "reviewer-{n}", message: "shutdown_request: Review complete, please shut down.")
   ```

2. Wait for shutdown responses
3. Call `TeamDelete`

On ALL exit paths (success, failure, interruption), ensure `TeamDelete` is called.

## Error Handling

For all error scenarios and recovery actions, see references/error-handling.md.
