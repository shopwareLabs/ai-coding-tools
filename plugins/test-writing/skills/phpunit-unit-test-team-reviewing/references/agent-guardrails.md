# Agent Guardrails — Adaptation Guide

Every spawned agent's prompt carries the universal guardrails below plus a role-specific section. The role prompt text and each role's StructuredOutput schema live in the workflow script (`GUARD` + the `*Prompt` builders + the `*_SCHEMA` constants); this reference owns the universal guardrail text and the adaptation surface.

## Universal guardrails (every agent prompt)

- **Read-only.** Do not modify files, apply fixes, or run PHPStan/PHPUnit/ECS.
- **Rules are inline and complete for your task.** Every rule you must evaluate is in this prompt under `## RULES`, scoped to your role; look up any rule_id there. `Read` and `Grep` the **test file and its source class** as needed, but **never** read, search, or locate a **rule file** by any means — no `Read`/`Grep`/`Glob`, no `cat`/`grep`/`ugrep`/`find`/`bfs`, no `get_rules`. The `## RULES` block is the only rule source.
- **Calibrated honesty.** Agree when evidence supports it, dissent when it does not. Do not manufacture findings to look thorough, and do not wave findings through to look agreeable. If a file is clean under your lens, say so.
- **Cite real evidence.** Every finding names a real `file:line` you read and the detection-algorithm clause it triggers. Never fabricate rule IDs, locations, or code.
- **Respect scope.** When a file specifies methods, judge only those methods and their associated data providers. Ignore everything outside scope. When a file says full class, review the whole class.
- **One visible line with your structured output.** Emit exactly one short visible line summarizing the result (for example, a one-line finding tally) in the same response as your structured output. No other prose — the structured output stays the only contract-bearing payload.

## What you can adapt

- **The universal guardrails above** — change the prose here and in the script's `GUARD` constant together.
- **Per-role `## RULES` scoping** — Wave-0 reviewers carry their `review_unit` track (plus `scoped_review` for changed-method scopes); the Wave-2 red team carries the category-scoped catalog; the Wave-1/Wave-3 reconcilers and the arbiter carry only the finding-referenced rule subset. The script slices each from the one full catalog.
- **A role's output contract** — edit its `*_SCHEMA` in the script; the agent's structured output is validated against it.

## Already handled — do not re-adapt

- **Agents never fetch rules** — the no-rule-file prohibition plus the inline `## RULES` block is the structural guarantee. Do not add a rule-loading path.
- **Read-only enforcement** — reviewers and adversaries spawn through the read-only agent types; they cannot write files.
- **One contract-bearing payload per agent** — the structured output is the only contract; the single visible line is a tally, not a second output channel.
