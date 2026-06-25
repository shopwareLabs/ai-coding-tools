---
name: phpunit-unit-test-team-reviewing
version: 3.8.16
description: Use this skill when the user asks for a team-based, consensus, multi-reviewer, or red-team review of Shopware PHPUnit unit tests (in tests/unit/) — trigger phrases like "team review these unit tests", "consensus review the unit tests in PR #N", "red-team this unit test suite", "multi-reviewer audit of tests/unit/...". Accepts file paths, directories, commits, branches, and PRs as input. Unit tests only — not for integration tests in tests/integration/. For a single-reviewer pass, use phpunit-unit-test-writing instead.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Workflow, mcp__plugin_gh-tooling_gh-tooling, mcp__plugin_test-writing_test-rules__build_rule_package
---

# Team-Based PHPUnit Unit Test Review

Resolve the input into a test-file manifest, build the run input from it, launch the committed review workflow script, and render its result. The review runs as a multi-agent workflow: fresh agents that each invoke the project's review sub-skills, coordinated across waves with no agent-to-agent messaging.

```dot
digraph team_review {
  "Team review requested" [shape=doublecircle];
  "Confirm scope + cost" [shape=diamond];
  "Offer single-reviewer, stop" [shape=octagon, style=filled, fillcolor=red];
  "Resolve input to file manifest" [shape=box];
  "Manifest empty?" [shape=diamond];
  "Abort: no valid test files" [shape=octagon, style=filled, fillcolor=red];
  "Assemble run input (rule package + collect)" [shape=box];
  "Launch committed workflow script (args = manifest)" [shape=box];
  "Render report from result" [shape=doublecircle];

  "Team review requested" -> "Confirm scope + cost";
  "Confirm scope + cost" -> "Offer single-reviewer, stop" [label="declined"];
  "Confirm scope + cost" -> "Resolve input to file manifest" [label="proceed"];
  "Resolve input to file manifest" -> "Manifest empty?";
  "Manifest empty?" -> "Abort: no valid test files" [label="yes"];
  "Manifest empty?" -> "Assemble run input (rule package + collect)" [label="no"];
  "Assemble run input (rule package + collect)" -> "Launch committed workflow script (args = manifest)";
  "Launch committed workflow script (args = manifest)" -> "Render report from result";
}
```

## Execution posture

This skill launches a committed script that spawns a large agent fleet — normal operation. Three standing disciplines are suspended for a normal run:

- **Launch directly without an advisor pre-flight.** Consult the advisor only after a run fails for a reason you cannot identify.
- **Run `workflow/team-review.workflow.mjs`; do not compose, write, or search for an alternative orchestration.** Any leftover script from a prior run is stale.
- **Do not audit the skill's design or sub-skill contracts** — they are authoritative. Do confirm the resolved inputs fit the target: unit tests in `tests/unit/` (not integration tests, which this skill cannot serve) with existing source paths.

## Phase 0: Confirm Scope & Cost

This review spawns many parallel agents and consumes substantially more tokens than a single-reviewer pass. Ask via `AskUserQuestion` whether to proceed with the team review or run the standard single-reviewer (`phpunit-unit-test-writing`) instead. Proceed only on confirmation.

## Phase 1: Resolve Input to a Manifest

`Read` references/input-resolution.md, then follow its strategies to build the file manifest. Resolve all interactive ambiguity here — base branch, unclear scope — using `AskUserQuestion`. The review cannot ask the user once it is running, so nothing ambiguous may reach it.

Output: a manifest of validated test files, each with a method scope (changed methods, or full class), the full test-method name list, and decomposition measurements (source path, test/source line counts, method count — see references/input-resolution.md). Let N = number of files. If the manifest is empty, abort per references/error-handling.md.

## Phase 2: Assemble the Run Input

The script runs sandboxed and reads only its `args`. Assemble that input:

1. **Rule catalog.** Call `build_rule_package` with no arguments, then `Read` the returned path to obtain the rendered catalog text. This single full catalog is the run's only rule source; do not build per-track packages. If the build fails or reports zero rules, abort (references/error-handling.md).
2. **Pre-Run Collect.** Perform references/workflow-design.md §Pre-Run Collect with your own `Read`/`Grep`: compute each file's cross-file `fingerprint`; for each file whose combined lines exceed `C`, extract the body-free structural `digest`.
3. **Manifest object.** Build `{ files: [ <Phase-1 entries> + fingerprint + (digest when L > C) ], rule_packages: { full: <rendered catalog> }, base: <base ref if any> }`.

The manifest is fixed here, before the run — nothing ambiguous may reach it.

## Phase 3: Launch the Review

Launch the committed script with the `Workflow` tool, passing `scriptPath: ${CLAUDE_SKILL_DIR}/workflow/team-review.workflow.mjs` and the Phase-2 manifest as `args`. It runs in the background and returns a single result matching the result shape in references/report-format.md.

## Phase 4: Render the Report

`Read` references/report-format.md and render the result into the report.

## Error Handling

For input-resolution failures, review start-up or run failures, partial-wave outcomes, and consensus edge cases, `Read` references/error-handling.md.
