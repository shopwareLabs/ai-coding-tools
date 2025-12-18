---
name: phpunit-unit-test-writing
version: 1.2.1
description: |
  This skill should be used when the user asks to "write unit tests for", "generate tests for", "create PHPUnit tests", "add test coverage", "test this class", "cover this with tests", "I need tests for", "unit test this", "SW6 unit tests", "Shopware unit tests", "PHPUnit tests for Shopware", or mentions PHPUnit test generation for Shopware 6. Provides automated test generation with review-fix cycles that validate tests until they pass. Should NOT be used for integration tests, e2e tests, or non-PHP testing.
allowed-tools: Task, TodoWrite, AskUserQuestion, Read, Glob
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
Process the complete workflow (Generate → Review/Fix → Report) for that one file.

### Multiple Files / Directory Input
Process files **STRICTLY SEQUENTIALLY** - one file at a time:

```
FOR EACH source file:
  1. Generate test (wait for completion)
  2. Review and fix test (wait for completion)
  3. Mark file complete
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
- **IMMEDIATE ACTION** - Invoke Task tools without hesitation
- **REPORT AFTER** - Only explain results, not intentions

---

## File Write Restrictions

File writes are handled by subagents, restricted to:
- `tests/unit/**` - Unit test files

NEVER modify:
- `src/**` - Source code
- `tests/integration/**` - Integration tests (out of scope)
- Any other directory

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

### Phase 2: Review and Fix

**ENTRY CONDITION**: Generator returned SUCCESS or PARTIAL.

The fixer agent handles all fix iterations internally (max 4).

#### Step 1: Invoke Fixer Agent

```
Task {
  subagent_type: "test-writing:phpunit-unit-test-reviewer-fixer",
  prompt: "Review and fix test at {test_path}",
  description: "Review and fix unit test"
}
```

#### Step 2: Parse Response

Parse the extended output contract:

- `status`: PASS | NEEDS_ATTENTION | ISSUES_FOUND | FAILED
- `iterations_used`: Number of internal fix iterations performed
- `fixes_applied`: List of applied fixes (code, location)
- `oscillation_detected`: Boolean indicating if oscillation occurred
- `issue_history`: Per-iteration issue tracking (for debugging)
- `errors`: Remaining unfixed errors (if any)
- `warnings`: Non-critical improvements (list)

#### Step 3: Handle Oscillation

If `oscillation_detected: true`:

1. **Present oscillation details to user**:
   ```
   Oscillation Detected

   The following issue keeps recurring after being fixed:
   - {error_code} at {location}

   Issue History:
   - Iteration 1: {issues}
   - Iteration 2: {issues}
   - Iteration 3: {issues} ← Recurrence

   This may indicate a conflict between fixes or an edge case in the test.
   ```

2. **Ask user** via AskUserQuestion: "Would you like to continue with the remaining issues, or abort and investigate manually?"

3. **Decision**:
   - Continue → Proceed to Phase 3 or 4 based on remaining status
   - Abort → End workflow with current state

#### Step 4: Decision

| Status | Action |
|--------|--------|
| PASS | Proceed to Phase 4 (Final Report) |
| NEEDS_ATTENTION (warnings only) | Proceed to Phase 3 (User Decision) |
| ISSUES_FOUND (errors remain) | Report remaining issues, proceed to Phase 4 |
| FAILED | Report failure reason, end workflow |

### Phase 3: User Decision on Warnings

If warnings remain after error correction:

1. **Present warnings**:
   ```
   Remaining Warnings:
   1. [Warning description] - Suggested fix: [fix]
   2. [Warning description] - Suggested fix: [fix]
   ```

2. **Ask user** via AskUserQuestion: "Would you like me to apply the suggested fixes for these warnings?"

3. **Apply** fixes if user approves (invoke fixer agent again with specific warnings)

### Phase 4: Final Report

Provide comprehensive summary including:
- Test file path
- Final status
- Category (A-E)
- Iterations used by fixer agent
- Fixes applied (list with codes)
- Remaining issues (if any)
- Warnings (if any)

For report templates: [references/report-formats.md](references/report-formats.md)

---

## Constraints

- **Fixer agent handles fix iterations internally** (max 4)
- **Fixer agent detects oscillation and stuck loops** internally
- **Orchestrator handles user escalation** when oscillation detected
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

### Generator Agent Failure

If `test-writing:phpunit-unit-test-generator` returns FAILED or SKIPPED:
1. Report the reason to user
2. Do NOT proceed to Phase 2
3. End workflow with failure status

Common failure reasons:
- Source file not found
- File is interface/trait (not testable class)
- File not in `src/` directory

### Fixer Agent Failure

If `test-writing:phpunit-unit-test-reviewer-fixer` returns FAILED:
1. Report the failure reason
2. Present current test state (if any)
3. Ask user for manual intervention

Common failure reasons:
- MCP tools unavailable (PHPStan/PHPUnit/ECS)
- Test file syntax error
- Oscillation detected (handled separately in Phase 2 Step 3)

---

## Communication Style

- Report progress at each phase transition
- Be specific about what was changed and why
- Present issues in actionable format with clear fix suggestions
- Ask for user input only when necessary (Phase 3 warnings, oscillation escalation)
