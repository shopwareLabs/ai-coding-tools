---
name: phpunit-unit-test-writing
version: 1.1.0
description: |
  This skill should be used when the user asks to "write unit tests for", "generate tests for", "create PHPUnit tests", "add test coverage", "test this class", "cover this with tests", "I need tests for", "unit test this", or mentions PHPUnit test generation for Shopware 6. Provides automated test generation with review-fix cycles that validate tests until they pass. Should NOT be used for integration tests, e2e tests, or non-PHP testing.
allowed-tools: Task, TodoWrite, AskUserQuestion, Read, Glob, mcp__plugin_php-tooling_php-tooling__phpunit_run, mcp__plugin_php-tooling_php-tooling__phpstan_analyze, mcp__plugin_php-tooling_php-tooling__ecs_check, mcp__plugin_php-tooling_php-tooling__ecs_fix
---

# PHPUnit Unit Test Writing

Orchestrates the complete workflow for generating and reviewing Shopware 6 unit tests.

---

## CRITICAL: Workflow Completion Requirements

**MUST execute BOTH phases** - The workflow is NOT complete until Phase 2 review finishes.

- MUST invoke reviewer subagent after generator returns SUCCESS/PARTIAL
- MUST NOT report to user until review loop completes
- MUST NOT skip Phase 2 under any circumstances
- NEVER consider test generation alone as "done"

**Incomplete workflow = workflow failure**

---

## Execution Strategy

### Single File Input
Process the complete workflow (Generate → Review → Fix loop → Report) for that one file.

### Multiple Files / Directory Input
Process files **STRICTLY SEQUENTIALLY** - one file at a time:

```
FOR EACH source file:
  1. Generate test (wait for completion)
  2. Review test (wait for completion)
  3. Fix loop if needed (wait for completion)
  4. Mark file complete
  THEN proceed to next file
```

**NEVER invoke multiple generator or reviewer subagents in parallel.**

---

## Core Principle

Execute immediately. Report work AFTER completion, never before.

---

## Autonomous Execution Rules

- **NO PREVIEWING** - Never list tests you're about to create
- **NO CONFIRMATION** - Never ask "should I start?" or "should I proceed?"
- **IMMEDIATE ACTION** - Invoke Task/Edit tools without hesitation
- **REPORT AFTER** - Only explain results, not intentions

---

## File Write Restrictions

File writes are restricted to:
- `tests/unit/**` - Unit test files

NEVER modify:
- `src/**` - Source code
- `tests/integration/**` - Integration tests (out of scope)
- Any other directory

---

## Tool Usage Restrictions

**CRITICAL**: NEVER use shell commands for PHP validation tools.

**FORBIDDEN** (via Bash):
- `vendor/bin/phpstan` - Static analysis
- `vendor/bin/phpunit` - Test execution
- `vendor/bin/ecs` - Code style checking
- `composer phpstan:*`, `composer test:*`, `composer ecs:*`
- Any shell invocation of these tools

**REQUIRED** (via MCP):
- `mcp__plugin_php-tooling_php-tooling__phpstan_analyze` - PHPStan analysis
- `mcp__plugin_php-tooling_php-tooling__phpunit_run` - PHPUnit execution
- `mcp__plugin_php-tooling_php-tooling__ecs_check` - ECS style check
- `mcp__plugin_php-tooling_php-tooling__ecs_fix` - ECS style fix

MCP tools provide consistent environment handling, error formatting, and integration with the plugin ecosystem.

---

## Workflow Phases

### Phase 1: Test Generation

1. **Identify** the source class requiring tests

2. **Invoke generator** subagent:
   ```
   Task {
     subagent_type: "test-writing:phpunit-unit-test-generator",
     prompt: "Generate unit tests for {source_class_path}",
     description: "Generate unit tests"
   }
   ```

3. **Parse response** for:
   - `test_path`: Location of generated test file
   - `status`: SUCCESS | PARTIAL | FAILED | SKIPPED
   - `category`: A | B | C | D | E (test complexity category)

4. **Decision**:
   - FAILED or SKIPPED → Report reason to user, end workflow
   - SUCCESS or PARTIAL → **MUST IMMEDIATELY proceed to Phase 2**

5. **Update workflow state** on SUCCESS/PARTIAL:
   ```
   TodoWrite([
     {content: "Generate unit tests", status: "completed", activeForm: "Generating unit tests"},
     {content: "Review unit tests", status: "in_progress", activeForm: "Reviewing unit tests"}
   ])
   ```

### Phase 2: Review Loop

**ENTRY CONDITION**: Generator returned SUCCESS or PARTIAL.

Execute up to 4 review iterations:

#### Step 1: Invoke Reviewer

```
Task {
  subagent_type: "test-writing:phpunit-unit-test-reviewer",
  prompt: "Review unit test at {test_path}",
  description: "Review unit test"
}
```

#### Step 2: Parse Response

- `status`: PASS | NEEDS_ATTENTION | ISSUES_FOUND
- `errors`: Critical issues requiring fixes (list with code, location, suggested fix)
- `warnings`: Non-critical improvements (list)

#### Step 3: Check for Oscillation

If the same issue (identical error code at the same location) reappears in a non-consecutive iteration **within the current review session**, escalate to user rather than continuing to fix.

Pattern: Issue in iteration 1 → fixed in iteration 2 → returns in iteration 3 = oscillation.

See [references/oscillation-handling.md](references/oscillation-handling.md) for escalation formats.

#### Step 4: Stuck Loop Detection

If identical errors appear in 2 consecutive iterations → exit loop with warning.

#### Step 5: Apply Fixes (if ISSUES_FOUND with errors > 0)

1. **Apply** each suggested fix using the Edit tool
2. **Log** which fixes were applied
3. **Re-validate** with MCP tools:
   - Run `mcp__plugin_php-tooling_php-tooling__phpstan_analyze` with `{"paths": ["{test_path}"], "error_format": "json"}`
   - Run `mcp__plugin_php-tooling_php-tooling__phpunit_run` with `{"paths": ["{test_path}"]}`
   - If validation fails, fix errors before proceeding
4. **Resume** reviewer: "Applied fixes for [list]. Review again."
5. **Increment** iteration counter

#### Exit Conditions

- `PASS` → Proceed to Phase 4
- `NEEDS_ATTENTION` (warnings only) → Proceed to Phase 3
- Oscillation escalated → Proceed to Phase 4
- Max iterations (4) reached → Proceed to Phase 3

### Phase 3: User Decision on Warnings

If warnings remain after error correction:

1. **Present warnings**:
   ```
   Remaining Warnings:
   1. [Warning description] - Suggested fix: [fix]
   2. [Warning description] - Suggested fix: [fix]
   ```

2. **Ask user** via AskUserQuestion: "Would you like me to apply the suggested fixes for these warnings?"

3. **Apply** fixes if user approves

### Phase 4: Final Report

Provide comprehensive summary with test file, status, category, iterations, and applied fixes.

For report templates: [references/report-formats.md](references/report-formats.md)

---

## Constraints

- **MAXIMUM 4 review iterations** - Do not exceed this limit
- **Stuck loop** - If identical errors appear twice in a row, exit loop
- **Oscillation** - If same issue recurs in non-consecutive iterations, escalate to user
- **ALWAYS present warnings to user** - Never silently ignore warnings
- **No manual fallback** - If subagent fails, abort workflow entirely
- **Unit tests only** - Do not generate or review integration tests

---

## Error Handling

If subagent invocation fails:
```
Workflow Aborted
Required subagent `[name]` could not be invoked.
Please ensure the subagent is properly configured and try again.
```

Do NOT attempt to manually generate or review tests if subagents fail.

---

## Communication Style

- Report progress at each phase transition
- Be specific about what was changed and why
- Present issues in actionable format with clear fix suggestions
- Ask for user input only when necessary (Phase 3 warnings)
