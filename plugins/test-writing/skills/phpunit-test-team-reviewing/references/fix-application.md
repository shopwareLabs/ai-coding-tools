# Fix-Application Contract

Team review is read-only; it never applies a remediation itself. This contract governs whoever applies a team-review report's remediations in a fix phase.

## Remediation Fidelity

- Apply a finding's `suggested` field verbatim — the report's final value for that finding (the adversarial stage's, when it superseded the file's consensus-stage entry; the consensus stage's otherwise) — never a paraphrase, never a re-derivation from `current` and `summary`.
- A finding's remaining `suggested_variants` entries are alternatives for a human to choose between. Never apply one as a remediation in its place, and never drop it from what you show the human.

## Self-Review Before Committing

Before committing the fix diff, run a scoped self-review over it:

- **Redundancy.** Apply DESIGN-003 (data-provider consolidation for 3+ similar variations) and DESIGN-004 (unjustified case/method redundancy) across every file the fix touches together, not only the file the finding named.
- **Tautology.** For every test the fix adds, check that the assertion's expected value does not derive from the code under test or from the test's own fixture computation. An expected value computed the same way the SUT computes it passes on a broken SUT.
- **Static gates.** Run PHPStan (`mcp__plugin_dev-tooling_php-tooling__phpstan_analyze`) and php-cs-fixer (`mcp__plugin_dev-tooling_php-tooling__ecs_check` / `ecs_fix`) over the fix diff — the same gates the reviewed code passes through.

## Mutation Checks

A mutation-based check judges a mutant against the whole test suite, never against only the single test under discussion.

## Re-Verifying a Consensus-Only Must-Fix Finding

A finding whose `scrutiny` is `consensus-only` (report-format.md) and whose `enforce` is `must-fix` gets its factual premise re-verified — does the quoted defect exist as described in `current`, against the file on disk, right now — before its remediation is applied. A finding whose `scrutiny` is `adversary-tested` already survived that scrutiny in the adversarial stage and does not repeat this check.

## Verifying Landed Commits Before Reporting Completion

Before reporting the fix done, verify every commit the report names as landed is an ancestor of the branch it names: `git merge-base --is-ancestor <commit> <branch>`. A failed check reports that branch/commit pair as unverified — never as landed.
