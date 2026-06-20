---
name: phpunit-unit-test-team-reviewing
version: 3.8.6
description: Use this skill when the user asks for a team-based, consensus, multi-reviewer, or red-team review of Shopware PHPUnit tests — trigger phrases like "team review these tests", "consensus review the tests in PR #N", "red-team this test suite", "multi-reviewer audit of tests/unit/...". Accepts file paths, directories, commits, branches, and PRs as input. For a single-reviewer pass, use phpunit-unit-test-writing instead.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Workflow, mcp__plugin_gh-tooling_gh-tooling
---

# Team-Based PHPUnit Unit Test Review

Resolve the input into a test-file manifest, compose a multi-agent review adapted to that manifest, run it, and render its result. The review runs as a multi-agent workflow: fresh agents that each invoke the project's review sub-skills, coordinated across waves with no agent-to-agent messaging — each wave's outputs feed the next wave's prompts.

```dot
digraph team_review {
  "Team review requested" [shape=doublecircle];
  "Confirm scope + cost" [shape=diamond];
  "Offer single-reviewer, stop" [shape=octagon, style=filled, fillcolor=red];
  "Resolve input to manifest" [shape=box];
  "Manifest empty?" [shape=diamond];
  "Abort: no valid test files" [shape=octagon, style=filled, fillcolor=red];
  "Compose review per design (manifest fixed)" [shape=box];
  "Run via Workflow tool" [shape=box];
  "Render report from result" [shape=doublecircle];

  "Team review requested" -> "Confirm scope + cost";
  "Confirm scope + cost" -> "Offer single-reviewer, stop" [label="declined"];
  "Confirm scope + cost" -> "Resolve input to manifest" [label="proceed"];
  "Resolve input to manifest" -> "Manifest empty?";
  "Manifest empty?" -> "Abort: no valid test files" [label="yes"];
  "Manifest empty?" -> "Compose review per design (manifest fixed)" [label="no"];
  "Compose review per design (manifest fixed)" -> "Run via Workflow tool";
  "Run via Workflow tool" -> "Render report from result";
}
```

## Phase 0: Confirm Scope & Cost

This review spawns many parallel agents and consumes substantially more tokens than a single-reviewer pass. Ask via `AskUserQuestion` whether to proceed with the team review or run the standard single-reviewer (`phpunit-unit-test-writing`) instead. Proceed only on confirmation.

## Phase 1: Resolve Input to a Manifest

`Read` references/input-resolution.md, then follow its strategies to build the file manifest. Resolve all interactive ambiguity here — base branch, unclear scope — using `AskUserQuestion`. The review cannot ask the user once it is running, so nothing ambiguous may reach it.

Output: a manifest of validated test files, each with a method scope (changed methods, or full class) and its decomposition measurements (source path, test/source line counts, method count — see references/input-resolution.md). Let N = number of files. If the manifest is empty, abort per references/error-handling.md.

## Phase 2: Compose the Review Design

`Read` all of the following and assemble the review design from them:

- references/workflow-design.md — base wave shape, adaptation points, design constraints, result shape
- references/reviewer-allocation.md — how many reviewers and adversaries, and how files are packed per agent
- references/agent-guardrails.md — the prompt contract for every spawned agent
- references/red-team-context.md — red-team skip conditions and the context package adversaries receive
- references/consensus-and-verdicts.md — consensus merge, cross-file consistency wave, status, adversary-impact

The review is composed fresh for this manifest and the counts derived from it; those are fixed before it runs.

## Phase 3: Run the Review

Run the review with the `Workflow` tool. It runs in the background and returns a single result matching the result shape in references/workflow-design.md.

## Phase 4: Render the Report

`Read` references/report-format.md and render the result into the report.

## Error Handling

For input-resolution failures, review start-up or run failures, partial-wave outcomes, and consensus edge cases, `Read` references/error-handling.md.
