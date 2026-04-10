---
name: phpunit-unit-test-team-reviewing
version: 3.3.0
description: >
  Team-based PHPUnit test review using wave-based Agent Teams orchestration.
  4 waves: independent review, peer-to-peer debate, adversarial red team, defense.
  Each wave spawns fresh agents with single-task instructions. Agents complete
  and return after each wave. Peer-to-peer debate via SendMessage in Wave 1.
allowed-tools: >
  Bash, TeamCreate, TeamDelete, Agent, SendMessage,
  Read, Glob, Grep, AskUserQuestion,
  mcp__plugin_test-writing_test-rules__get_rules,
  mcp__plugin_gh-tooling_gh-tooling
---

# Team-Based PHPUnit Unit Test Review

Wave-based orchestration: spawn agents per wave, collect outputs, assemble inputs for the next wave. You (the skill executor) act as team lead.

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

2. Calculate adversary count A per references/reviewer-allocation.md

3. Compute file assignments for reviewers (round-robin per references/reviewer-allocation.md) and adversaries (partitioning per references/reviewer-allocation.md)

4. Call `TeamCreate(team_name: "test-review", description: "PHPUnit test review — {R} reviewers + {A} adversaries")`

No agents spawned yet. Agents are spawned per wave.

## Phase 3: Wave 0 — Independent Analysis

Spawn R reviewer agents + A adversary agents in a **single message** (parallel).

Agent names include the wave number as suffix (`reviewer-{n}-{wave}`) to avoid collisions within the team. Use the same `reviewer-{n}` identity in output contracts and co-reviewer references across waves.

For each reviewer:

```
Agent(
  agent: "test-writing:test-reviewer",
  team_name: "test-review",
  name: "reviewer-{n}-0",
  prompt: "Invoke Skill(test-writing:phpunit-unit-test-reviewing) for each of your assigned files.
           Assigned files:
           {for each file: - {path} (Category {category}, methods: [{methods}] | full class)}

           When a file specifies methods, pass them to the reviewing skill as the methods scope.
           When a file says 'full class', invoke the reviewing skill without a methods scope.

           After ALL reviews complete, return your combined findings for all files
           using this format:

           type: findings
           reviewer: reviewer-{n}
           files:
             - path: {path}
               category: {category}
               scope: {methods list or 'full class'}
               findings: [{rule_id, enforce, location, summary, current, suggested}]"
)
```

For each adversary:

```
Agent(
  agent: "test-writing:test-adversary",
  team_name: "test-review",
  name: "adversary-{n}-0",
  prompt: "Read your assigned test files and their source classes (from #[CoversClass]).
           Form intuitive impressions — what concerns you about these tests?
           Assigned files:
           {for each file: - {path} (Category {category}, methods: [{methods}] | full class)}

           When a file specifies methods, focus your impressions on those methods only.
           Ignore concerns outside the scoped methods.

           Use these heuristic lenses (do NOT use MCP rule tools):
           - Absence detection: what's NOT tested that you'd expect?
           - Consequence weighting: which gaps would cause the most production damage?
           - Dependency fan-out: which shared assumptions could mask bugs?
           - Pattern anomalies: inconsistencies in style, mocking, assertions?
           - The 'surprised?' test: if the test passed but behavior was broken, would you be surprised?

           Return your impressions per file:
           impressions:
             - file_path: {path}
               scope: {methods list or 'full class'}
               concerns:
                 - area: 'description'
                   severity: high | medium | low"
)
```

Wait for all agents to complete. Collect findings and impressions.

## Phase 4: Wave 1 — Debate

For each reviewer, assemble:
- Own findings (from that reviewer's Wave 0 output)
- Peer findings (from co-reviewers' Wave 0 outputs for shared files)
- Co-reviewer names and shared files

Spawn R reviewer agents in a **single message** (parallel):

```
Agent(
  agent: "test-writing:test-reviewer",
  team_name: "test-review",
  name: "reviewer-{n}-1",
  prompt: "Invoke Skill(test-writing:phpunit-unit-test-debating) with this input.

           Own findings:
           [reviewer's Wave 0 findings]

           Peer findings:
           [per co-reviewer, their findings on shared files]

           Co-reviewers (use these names for SendMessage):
           [list of {name: reviewer-{m}-1, shared_files}]

           Scope per file:
           [per file: {path} → methods: [{methods}] | full class]

           Only debate findings within the scoped methods for each file.
           Discard any peer findings outside this scope.

           Debate with your co-reviewers via SendMessage, then return your final stance."
)
```

Wait for all agents to complete. Collect final stances.

## Phase 5: Red Team Skip Evaluation

Evaluate skip conditions per references/red-team-context.md using Wave 1 final stances:

1. **Zero findings** — all reviewers reported 0 findings across all files. Skip to Phase 8.
2. **Substantive debate** — team lead judges from Wave 1 debate that challenges outnumbered concessions. Skip conditions apply per references/red-team-context.md.

If skipped, proceed directly to Phase 8. Use Wave 1 final stances as binding input.

## Phase 6: Wave 2 — Red Team

1. For each file, merge Wave 1 final stances into a preliminary consensus (same logic as Phase 8 merge, but intermediate)

2. Assemble context package for each adversary per references/red-team-context.md — consensus findings, withdrawn findings with reasons, and debate evidence per file

3. Spawn A adversary agents:

```
Agent(
  agent: "test-writing:test-adversary",
  team_name: "test-review",
  name: "adversary-{n}-2",
  prompt: "Invoke Skill(test-writing:phpunit-unit-test-adversarial-reviewing) with this input.

           Consensus package:
           [per-file context package as YAML]

           Impressions from Wave 0:
           [this adversary's Wave 0 impressions]

           Scope per file:
           [per file: {path} → methods: [{methods}] | full class]

           Limit your challenges to findings within the scoped methods for each file.

           Return your challenges."
)
```

Wait. Collect challenges.

## Phase 7: Wave 3 — Defense

For each reviewer with files that received adversary challenges, assemble:
- Own final stance (from Wave 1)
- Adversary challenges for their files (from Wave 2)

Spawn R reviewer agents:

```
Agent(
  agent: "test-writing:test-reviewer",
  team_name: "test-review",
  name: "reviewer-{n}-3",
  prompt: "Invoke Skill(test-writing:phpunit-unit-test-defending) with this input.

           Own final stance:
           [reviewer's Wave 1 final stance]

           Adversary challenges:
           [adversary challenges for this reviewer's files]

           Scope per file:
           [per file: {path} → methods: [{methods}] | full class]

           Only defend findings within the scoped methods for each file.
           Dismiss adversary challenges targeting out-of-scope code.

           Return your defense stance."
)
```

Wait. Collect defense stances.

## Phase 8: Verdicts & Report

If the red team round ran (Phases 6-7), use Wave 3 defense stances as input. If skipped, use Wave 1 final stances.

### Per-File Consensus Merge

For each file, extract the 3 binding stances from its assigned reviewers. For each unique `(rule_id, location)` pair:

- **3-of-3 (UNANIMOUS)**: include in report, no dissent annotation
- **2-of-3 (MAJORITY)**: include in report, attach dissent annotation from the reviewer who did not include it
- **1-of-3 (MINORITY)**: exclude from report, log as contested finding

**Location matching**: match by `rule_id` first, then treat locations within a 5-line range of the same method as the same finding. Use the location from the majority if ambiguous.

**Enforce level conflicts**: if reviewers agree a violation exists but disagree on enforce level, use the majority enforce level and note the disagreement.

### Cross-File Consistency Analysis

After all per-file verdicts, scan for pattern divergences:

1. Collect `cross_file_references` from all debate outputs
2. Compare per-file reports for divergent approaches (setUp strategies, mocking, assertions, data providers, attribute ordering)
3. Where multiple files have the same violation, ensure suggested fixes use the same pattern

Consistency findings are `should-fix` (warnings) — they count toward NEEDS_ATTENTION but not ISSUES_FOUND.

### Adversary Impact Tracking

For each finding in the final report, assign an `adversary_impact` tag:

- **UNCHANGED** — not challenged by adversary, stable across both rounds
- **ADVERSARY_CHALLENGED (defended)** — challenged by adversary, survived defense
- **ADVERSARY_CHALLENGED (overturned)** — challenged by adversary, withdrawn in defense round
- **ADVERSARY_RESURRECTED** — withdrawn in round 1, resurrected by adversary, re-adopted in defense round
- **ADVERSARY_INTRODUCED** — new finding from adversary, adopted by majority in defense round

When the red team round was skipped, all findings receive `adversary_impact: unchanged`.

### Status Determination

- **PASS** — all files PASS and no consistency findings
- **NEEDS_ATTENTION** — 0 errors across all files, but 1+ warnings or consistency findings
- **ISSUES_FOUND** — 1+ errors in any file

Generate the report per references/report-format.md.

## Phase 9: Cleanup

Call `TeamDelete` directly. Do NOT send SendMessage to any agent or broadcast to `"*"`. Agents already completed and returned after each wave. There is nothing to shut down.

On ALL exit paths (success, failure, partial failure), ensure `TeamDelete` is called.

## Error Handling

For all error scenarios and recovery actions, see references/error-handling.md.
