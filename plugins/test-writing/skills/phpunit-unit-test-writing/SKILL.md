---
name: phpunit-unit-test-writing
version: 3.2.2
description: |
  This skill should be used when the user asks to "write unit tests for", "generate tests for", "create PHPUnit tests", "add test coverage", "test this class", "cover this with tests", "I need tests for", "unit test this", "SW6 unit tests", "Shopware unit tests", "PHPUnit tests for Shopware", or mentions PHPUnit test generation for Shopware 6. Provides automated test generation with review-fix cycles that validate tests until they pass. Should NOT be used for integration tests, e2e tests, or non-PHP testing.
allowed-tools: Skill, Edit, Read, Glob, TodoWrite, AskUserQuestion, mcp__plugin_dev-tooling_php-tooling
---

# PHPUnit Unit Test Writing

Orchestrates the complete workflow for generating and reviewing Shopware 6 unit tests.

## Core Principle

Execute immediately. Report work AFTER completion, never before.

---

## Execution Strategy

### Single File Input
Process the complete workflow (Generate → Coverage Exclusion → Review → Fix → Report) for that one file.

### Multiple Files / Directory Input
Process files sequentially — one file at a time:

```
FOR EACH source file:
  1. Generate test (wait for completion)
  2. Review test (wait for completion)
  3. Fix loop if needed (wait for completion)
  4. Mark file complete
  5. Collapse intermediate state to compact summary
  THEN proceed to next file
```

After each file completes all phases, collapse intermediate state (generation details, review iterations, fix attempts) to a compact summary before proceeding to the next file. This prevents context growth on multi-file runs.

---

## Autonomous Execution Rules

- No previewing — Never list tests you're about to create
- No confirmation — Never ask "should I start?" or "should I proceed?"
- Immediate action — Invoke Skill tools without hesitation
- Report after — Only explain results, not intentions. This applies to communication only — never skip workflow phases
- No phase skipping — Every phase whose entry condition is met MUST execute

---

## File Write Restrictions

- Generation: handled by generation skill (Write tool in forked context)
- Fix loop: handled by orchestrator (Edit tool for targeted fixes)
- Coverage config: handled by orchestrator (Edit tool, Phase 2 only, user-confirmed)

Never modify:
- `src/**` — Source code
- `tests/integration/**` — Integration tests (out of scope)
- Any directory other than `tests/unit/**`

Conditional modification (user confirmation required):
- `phpunit.xml.dist` — Only adding `<file>` entries to `<exclude>` section, only during Phase 2

---

## Workflow Phases

### Phase 1: Test Generation

1. **Identify** the source class requiring tests

2. **Invoke generation skill**:
   ```
   Skill(test-writing:phpunit-unit-test-generation) with source: {source_class_path}
   ```

3. **Parse response** for:
   - `test_path`: Location of generated test file
   - `status`: SUCCESS | PARTIAL | FAILED | SKIPPED
   - `category`: A | B | C | D | E (test complexity category)
   - `skip_type`: `coverage_excluded` | `no_logic` (only when SKIPPED)

4. **Decision**:
   - FAILED → Report reason to user, end workflow
   - SKIPPED with `skip_type: coverage_excluded` → Report reason to user, end workflow
   - SKIPPED with `skip_type: no_logic` → Proceed to Phase 2 (Coverage Exclusion Offer)
   - SUCCESS or PARTIAL → Proceed to Phase 3

5. **Update workflow state** on SUCCESS/PARTIAL:
   ```
   TodoWrite([
     {content: "Generate unit tests", status: "completed", activeForm: "Generating unit tests"},
     {content: "Review unit tests", status: "in_progress", activeForm: "Reviewing unit tests"}
   ])
   ```

### Phase 2: Coverage Exclusion Offer

Entry condition: Generator returned SKIPPED with `skip_type: no_logic`.

Source files with no testable logic still appear as 0% in coverage reports unless excluded. This phase offers to add them to `phpunit.xml.dist` so coverage reports only show files that actually need testing.

#### Single-File Mode

1. **Read** `phpunit.xml.dist` from the project root (fallback: `phpunit.xml`)
2. If not found → report SKIPPED normally, end workflow
3. **Locate** the `<exclude>` section within `<coverage>/<source>` (or `<source>`)
4. **Verify** the source file is not already excluded (guard check)
5. **Ask** via AskUserQuestion:
   ```
   {source_path} was skipped — no testable logic detected ({reason}).

   Add it to phpunit.xml.dist coverage exclusions so it doesn't show as uncovered?
   ```
   Options: "Yes, exclude from coverage" / "No, skip"
6. **If approved**:
   - If `<exclude>` section exists → Use Edit to add `<file>{relative_path}</file>` before `</exclude>`
   - If no `<exclude>` section → Use Edit to insert `<exclude><file>{relative_path}</file></exclude>` before `</source>`
   - Record: `coverage_excluded: true`
7. **If declined** → Record: `coverage_excluded: false`
8. Report SKIPPED with coverage action taken, end workflow

#### Multi-File Mode

Do NOT prompt per file. Instead, collect all `skip_type: no_logic` files across the batch. After all files complete their workflow phases, present a single batch prompt:

```
X files were skipped — no testable logic detected.

Add them to phpunit.xml.dist coverage exclusions?

- src/Core/Content/Product/ProductEntity.php (Pure accessor)
- src/Core/Content/Category/CategoryCollection.php (Simple collection)
```

Options: "Yes, exclude all from coverage" / "No, skip"

If approved, add all `<file>` entries in a single Edit operation.

---

### Phase 3: Review

MUST execute when generator returned SUCCESS or PARTIAL. Never skip.

1. **Invoke reviewing skill**:
   ```
   Agent(
     agent: "test-writing:test-reviewer",
     prompt: "Invoke Skill(test-writing:phpunit-unit-test-reviewing) for {test_path}. Return the structured report."
   )
   ```

2. **Parse response**:
   - `status`: PASS | NEEDS_ATTENTION | ISSUES_FOUND | FAILED
   - `errors`: Remaining must-fix rules (mandatory compliance failures)
   - `warnings`: Remaining should-fix rules (optional improvements)

3. **Decision**:

| Status | Action |
|--------|--------|
| PASS | Proceed to Phase 6 (Final Report) with status COMPLIANT |
| NEEDS_ATTENTION | Proceed to Phase 4 (Fix Loop) for warnings, then Phase 5 for any unresolved |
| ISSUES_FOUND | Proceed to Phase 4 (Fix Loop) |
| FAILED | Report failure reason, end workflow |

### Phase 4: Fix Loop (max 4 iterations)

Entry condition: Review returned ISSUES_FOUND (has must-fix errors).

The loop continues until ALL errors are resolved — both tool validation errors AND semantic review errors (must-fix rules from reviewing skill).

```
FOR iteration 1 to 4:
    1. Apply ALL fixes from review report errors (Edit tool)
    2. Run validation tools (code style, static analysis, tests)
    3. Re-invoke reviewing skill to check for remaining issues
    4. Track issue history for oscillation
    5. Check exit conditions (PASS = 0 errors from review AND tools)
    ↓
Return final result
```

#### Step 1: Apply Fixes

For each must-fix rule with suggested fix from the review report:
1. Read current file content
2. Apply fix using Edit tool
3. Log: `{rule_id, location, attempted: true, applied: true/false, reason: null}`

Priority order when fixes conflict:
1. Structural errors (conditionals, class structure) — often require major changes
2. Redundancy errors — may remove/merge tests
3. Ordering errors — reorder test methods
4. Other must-fix rules in code order

#### Step 2: Validate

Run code style fix, static analysis, and tests on `{test_path}`. Fix any errors before continuing.

#### Step 3: Re-invoke Reviewing Skill

```
Agent(
  agent: "test-writing:test-reviewer",
  prompt: "Invoke Skill(test-writing:phpunit-unit-test-reviewing) for {test_path}. Return the structured report."
)
```

Spawns test-reviewer agent → returns updated report with errors/warnings.

#### Step 4: Track Issue History

Maintain issue history for oscillation detection:

```yaml
issue_history:
  - iteration: 1
    issues: ["{rule_id}:45", "{rule_id}:67"]
  - iteration: 2
    issues: ["{rule_id}:12"]
  - iteration: 3
    issues: ["{rule_id}:45"]  # same rule:line returned — oscillation!
```

Oscillation Detection:
- Track `{rule_id}:{line_number}` per iteration
- If same issue appears in non-consecutive iterations → oscillation detected
- Example: {rule_id}:45 in iter 1, fixed in iter 2, returns in iter 3 = oscillation

#### Step 5: Exit Conditions

| Condition | Action |
|-----------|--------|
| Review returns 0 errors AND tools pass | Exit with `status: PASS` |
| Oscillation detected | Handle per [references/oscillation-handling.md](references/oscillation-handling.md) |
| Same errors 2x consecutively | Exit as stuck loop with remaining errors |
| Iteration 4 reached with errors remaining | Exit with `status: ISSUES_FOUND` |

PASS Criteria (all must be met):
- Static analysis: 0 errors
- Tests: all passing
- Code style: no fixable violations
- Reviewing skill: 0 must-fix rules

ISSUES_FOUND means must-fix rules could not be resolved within 4 iterations — these are mandatory compliance failures.

### Phase 5: User Decision on Warnings

If warnings remain after error correction:

1. Present warnings with suggested fixes
2. Ask via AskUserQuestion: "Would you like me to apply the suggested fixes for these warnings?"
3. Apply fixes if user approves (Edit tool for targeted fixes, then re-run review)

### Phase 6: Final Report

Provide comprehensive summary. See [references/report-formats.md](references/report-formats.md) for templates.

Include:
- Test file path
- Final status (COMPLIANT or NON-COMPLIANT)
- Category (A-E)
- Iterations used in fix loop
- Fixes applied (list with codes)
- Remaining issues (if any)
- Warnings (if any)

---

## Constraints

- Fix loop runs inline (max 4 iterations) with oscillation detection
- Orchestrator handles user escalation when oscillation detected
- Must-fix rules are mandatory compliance failures; should-fix rules are optional
- User input only for: Phase 2 coverage exclusion offer, Phase 5 warnings (should-fix rules), oscillation escalation
- No manual fallback — If skill invocation fails, abort workflow entirely
- Unit tests only — Do not generate or review integration tests

---

## Error Handling

If skill invocation fails:
```
Workflow Aborted
Required skill `[name]` could not be invoked.
Please ensure the plugin is properly configured and try again.
```

Do not attempt to manually generate or review tests if skills fail.

### Generation Skill Failure

If `test-writing:phpunit-unit-test-generation` returns FAILED:
1. Report the reason to user
2. Do not proceed to Phase 3
3. End workflow with failure status

If SKIPPED with `skip_type: coverage_excluded`:
1. Report the reason to user, end workflow

If SKIPPED with `skip_type: no_logic`:
1. Proceed to Phase 2 (Coverage Exclusion Offer)

Common failure reasons:
- Source file not found
- File is interface/trait (not testable class)
- File not in `src/` directory

### Fix Loop Failure

If fix loop exits with ISSUES_FOUND after max iterations:
1. Report remaining must-fix rules with rule IDs and locations
2. Report fixes that were applied
3. Report oscillation if detected
4. Present current test state

Common failure reasons:
- MCP tools unavailable (PHPStan/PHPUnit/ECS)
- Test file syntax error
- Oscillation detected (handled via oscillation-handling reference)
