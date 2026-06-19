---
name: phpunit-unit-test-team-reviewing
version: 3.8.0
description: Use this skill when the user asks for a team-based, consensus, multi-reviewer, or red-team review of Shopware PHPUnit tests — trigger phrases like "team review these tests", "consensus review the tests in PR #N", "red-team this test suite", "multi-reviewer audit of tests/unit/...". Accepts file paths, directories, commits, branches, and PRs as input. For a single-reviewer pass, use phpunit-unit-test-writing instead.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Workflow, mcp__plugin_gh-tooling_gh-tooling
---

# Team-Based PHPUnit Unit Test Review

Resolve the input into a test-file manifest, author a multi-agent review Workflow adapted to that manifest, launch it, and render its result. The review runs as a Workflow: deterministic orchestration over fresh, schema-constrained agents that invoke the project's review sub-skills.

```dot
digraph team_review {
  "Team review requested" [shape=doublecircle];
  "Confirm scope + cost" [shape=diamond];
  "Offer single-reviewer, stop" [shape=octagon, style=filled, fillcolor=red];
  "Resolve input to manifest" [shape=box];
  "Manifest empty?" [shape=diamond];
  "Abort: no valid test files" [shape=octagon, style=filled, fillcolor=red];
  "Author Workflow per design, manifest baked in as constants" [shape=box];
  "Launch via Workflow tool (script inline)" [shape=box];
  "Render report from returned object" [shape=doublecircle];

  "Team review requested" -> "Confirm scope + cost";
  "Confirm scope + cost" -> "Offer single-reviewer, stop" [label="declined"];
  "Confirm scope + cost" -> "Resolve input to manifest" [label="proceed"];
  "Resolve input to manifest" -> "Manifest empty?";
  "Manifest empty?" -> "Abort: no valid test files" [label="yes"];
  "Manifest empty?" -> "Author Workflow per design, manifest baked in as constants" [label="no"];
  "Author Workflow per design, manifest baked in as constants" -> "Launch via Workflow tool (script inline)";
  "Launch via Workflow tool (script inline)" -> "Render report from returned object";
}
```

## Phase 0: Confirm Scope & Cost

This review spawns many parallel agents and consumes substantially more tokens than a single-reviewer pass. Ask via `AskUserQuestion` whether to proceed with the team review or run the standard single-reviewer (`phpunit-unit-test-writing`) instead. Proceed only on confirmation.

## Phase 1: Resolve Input to a Manifest

`Read` references/input-resolution.md, then follow its strategies to build the file manifest. Resolve all interactive ambiguity here — base branch, unclear scope — using `AskUserQuestion`. The Workflow cannot ask the user once launched, so nothing ambiguous may reach it.

Output: a manifest of validated test files, each with a method scope (changed methods, or full class). Let N = number of files. If the manifest is empty, abort per references/error-handling.md.

## Phase 2: Author the Workflow

`Read` all of the following, then author one Workflow script implementing the design:

- references/workflow-design.md — base wave shape, adaptation points, authoring constraints, returned-object shape
- references/reviewer-allocation.md — how many reviewers and adversaries, and how files are packed per agent
- references/agent-guardrails.md — the prompt contract for every spawned agent
- references/red-team-context.md — red-team skip conditions and the context package adversaries receive
- references/consensus-and-verdicts.md — consensus merge, cross-file consistency wave, status, adversary-impact

Bake the resolved manifest and the counts derived from it into the script as constants. Do not pass them as workflow args.

## Phase 3: Launch

Launch the authored script with the `Workflow` tool, passing the script inline. The Workflow runs in the background and returns a single object matching the returned-object shape in references/workflow-design.md.

## Phase 4: Render the Report

`Read` references/report-format.md and render the returned object into the report.

## Error Handling

For input-resolution failures, workflow launch or run failures, partial-wave outcomes, and consensus edge cases, `Read` references/error-handling.md.
