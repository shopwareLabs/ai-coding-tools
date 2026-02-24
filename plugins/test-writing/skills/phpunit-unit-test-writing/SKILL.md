---
name: phpunit-unit-test-writing
version: 1.2.8
description: |
  This skill should be used when the user asks to "write unit tests for", "generate tests for", "create PHPUnit tests", "add test coverage", "test this class", "cover this with tests", "I need tests for", "unit test this", "SW6 unit tests", "Shopware unit tests", "PHPUnit tests for Shopware", or mentions PHPUnit test generation for Shopware 6. Provides automated test generation with review-fix cycles that validate tests until they pass. Should NOT be used for integration tests, e2e tests, or non-PHP testing.
allowed-tools: Task, TodoWrite, AskUserQuestion, Read, Glob
---

# PHPUnit Unit Test Writing

Orchestrates the complete workflow for generating and reviewing Shopware 6 unit tests.

## Core Principle

Execute immediately. Report work AFTER completion, never before.

---

## Execution Strategy

### Single File Input
Process the complete workflow (Generate → Review/Fix → Report) for that one file.

### Multiple Files / Directory Input
Process files sequentially - one file at a time:

```
FOR EACH source file:
  1. Generate test (wait for completion)
  2. Review and fix test (wait for completion)
  3. Mark file complete
  THEN proceed to next file
```

---

## Autonomous Execution Rules

- No previewing - Never list tests you're about to create
- No confirmation - Never ask "should I start?" or "should I proceed?"
- Immediate action - Invoke Task tools without hesitation
- Report after - Only explain results, not intentions

---

## File Write Restrictions

File writes are handled by subagents, restricted to:
- `tests/unit/**` - Unit test files

Never modify:
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
   - SUCCESS or PARTIAL → Proceed to Phase 2

5. **Update workflow state** on SUCCESS/PARTIAL:
   ```
   TodoWrite([
     {content: "Generate unit tests", status: "completed", activeForm: "Generating unit tests"},
     {content: "Review unit tests", status: "in_progress", activeForm: "Reviewing unit tests"}
   ])
   ```

### Phase 2: Review and Fix

Entry condition: Generator returned SUCCESS or PARTIAL.

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

Parse the output contract:

- `status`: PASS | NEEDS_ATTENTION | ISSUES_FOUND | FAILED
- `iterations_used`: Number of internal fix iterations performed
- `fix_attempts`: List of fix attempts with `{code, location, attempted, applied, reason}`
- `oscillation_detected`: Boolean indicating if oscillation occurred
- `errors`: Remaining E-codes (mandatory compliance failures)
- `warnings`: Remaining W-codes (optional improvements)

#### Step 3: Handle Oscillation

If `oscillation_detected: true`:

1. Present oscillation details to user
2. Ask via AskUserQuestion: "Would you like to continue with the remaining issues, or abort and investigate manually?"
3. Continue → Proceed to Phase 3 or 4 based on remaining status
4. Abort → End workflow with current state

#### Step 4: Decision

| Status | Action |
|--------|--------|
| PASS | Proceed to Phase 4 with status COMPLIANT |
| NEEDS_ATTENTION | Proceed to Phase 3 (User Decision on Warnings) |
| ISSUES_FOUND | Proceed to Phase 4 with status NON-COMPLIANT |
| FAILED | Report failure reason, end workflow |

**Re-invocation option**: If `iterations_used < 4` AND no oscillation detected AND `fix_attempts` shows some fixes were `applied: false` due to dependencies, you may re-invoke the fixer agent once with the remaining errors.

### Phase 3: User Decision on Warnings

If warnings remain after error correction:

1. Present warnings with suggested fixes
2. Ask via AskUserQuestion: "Would you like me to apply the suggested fixes for these warnings?"
3. Apply fixes if user approves (invoke fixer agent again with specific warnings)

### Phase 4: Final Report

Provide comprehensive summary. See [references/report-formats.md](references/report-formats.md) for templates.

Include:
- Test file path
- Final status (COMPLIANT or NON-COMPLIANT)
- Category (A-E)
- Iterations used by fixer agent
- Fixes applied (list with codes)
- Remaining issues (if any)
- Warnings (if any)

---

## Constraints

- Fixer agent handles fix iterations internally (max 4)
- Fixer agent detects oscillation and stuck loops internally
- Orchestrator handles user escalation when oscillation detected
- E-codes are mandatory compliance failures; W-codes are optional
- User input only for: Phase 3 warnings (W-codes), oscillation escalation
- No manual fallback - If subagent fails, abort workflow entirely
- Unit tests only - Do not generate or review integration tests
- All edits go through subagents; orchestrator only coordinates

---

## Error Handling

If subagent invocation fails:
```
Workflow Aborted
Required subagent `[name]` could not be invoked.
Please ensure the subagent is properly configured and try again.
```

Do not attempt to manually generate or review tests if subagents fail.

### Generator Agent Failure

If `test-writing:phpunit-unit-test-generator` returns FAILED or SKIPPED:
1. Report the reason to user
2. Do not proceed to Phase 2
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
