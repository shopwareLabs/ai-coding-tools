# Implementation Workflow

Index: frame, inspect, extension point, chunking, safeguards, validation, regression scan, reporting, PR/QA template.

## Step 1: Frame the Task

- Identify the target version and active extension surface.
- Decide whether the task is implementation, refactor, migration, or review.
- Name the hot path if one exists: cart, checkout, login, account, admin list, search, webhook, queue worker.

## Step 2: Inspect Before Editing

Read only what is necessary:

- nearest repo-local overlay files such as `AGENTS.md` or `CLAUDE.md` if the repo uses them
- the relevant `composer.json` files
- the existing service, route, subscriber, Twig block, admin module, or payment handler that owns the behavior
- the relevant reference file from this skill

Do not jump from a bug report straight to a rewrite.

## Step 3: Choose the Extension Point

Choose the least invasive supported mechanism that owns the behavior; this is not a universal ranking:

1. event subscription
2. service decoration
3. DAL entity extension or custom entity
4. Store API/Admin API route or page loader
5. Twig block extension

Avoid direct core overrides, copied templates without a block-based reason, or ad hoc service lookups in runtime code.

## Step 4: Plan One Concern Per Chunk

Good chunks:

- add a migration and repository usage
- add one Store API route and its service
- refactor one payment webhook flow to be idempotent
- move one heavy storefront computation into a page loader
- harden one admin action with ACL and backend validation

Bad chunks:

- unrelated migration, admin redesign, and caching changes
- independent payment, saved-method, and refund fixes without shared authority or validation needs
- unrelated storefront redesign mixed with backend query refactors

Use the smallest coherent safe change, not the mechanically smallest diff:

- reuse or widen one existing helper when the behavior is genuinely shared
- allow a local refactor that removes obvious duplication
- do not clone a second near-identical function or service just to keep the touched lines isolated

## Step 5: Implement Safely

Guardrails:

- keep controllers, handlers, subscribers, and Twig thin
- keep the code DRY and KISS unless the project intentionally chose a different local standard
- use constructor injection
- load only the data needed
- do not edit already executed migration classes; add a new migration unless the repo explicitly has a safe local-only migration policy
- avoid repository calls inside loops
- queue heavy work and external I/O when it is not request-critical
- do not trust client-supplied payment or authorization state
- do not add cookies, headers, or invalidations casually on cacheable routes
- add safeguards only for a concrete failure mode in the current code path
- do not add redundant `trim((string) ...)`, repeated null guards, or extra normalization when types, DAL contracts, validated input, or config contracts already guarantee the value
- ask about unresolved choices that materially change persistence flow, entity modeling, native-component reuse, or admin/storefront UX; do not reopen a direction the request or repository already specifies

## Step 6: Validate the Smallest Useful Surface

Pick checks that match the change:

- PHP backend: static analysis, unit/integration tests, targeted console commands
- migrations: verify normal versus explicitly invoked destructive steps, data retention, index coverage, and the deployment trigger for already-installed shops (see `26-plugin-lifecycle-and-activation.md`)
- storefront: template rendering path, JS build or lint if present, accessibility and SEO sanity
- administration: build/test path used by the repo, ACL behavior, API responses
- payments: redirect/finalize flow, webhook verification, idempotency, retry safety
- distributable extensions: translation filename validation, snippet validation, extension quality checks, and any `shopware-cli` validation the project already relies on

If checks cannot run, say so and explain what remains unverified.

## Step 7: Run a Regression Scan

Ask explicitly:

- What existing extension point might this change break?
- What gets slower at scale?
- What changes cache tags, invalidation frequency, queue load, or DB access patterns?
- If the change touches storefront caching, what happens to cache hit rate, cache-key permutations, and `sw-cache-hash` separation?
- What part of the feature remains version-sensitive?

## Step 8: Report the Outcome

Always capture:

- target Shopware version
- files or surfaces changed
- validation performed
- remaining risk or follow-up chunk

For review work, use `08-analysis-and-reviews.md` instead of this file's delivery format.

When implementing from review findings:

- fix one finding at a time unless the findings are tightly coupled
- run a narrow regression pass after each fix
- re-scan the changed surface first before reopening the full review scope

## Step 9: Write PR Descriptions By Default

For PR or merge-request descriptions, use the detailed structure below unless the request, repository template, or applicable contributor-writing workflow specifies another format. Do not apply it to ordinary answers or findings-only reviews.

Expected sections:

1. `Description`
2. `Problem`
3. `Why this is critical` or `Why this matters`
4. `Implementation`
5. `Affected plugin areas`
6. `Risk and regression assessment`
7. `Validation performed`
8. `QA notes`

Guidance for each section:

- `Problem`
  Explain the concrete failure or deficiency in plain language. State the real trust boundary, broken flow, scale issue, or business impact.
- `Why this is critical` or `Why this matters`
  Explain the risk, exploitability, regression surface, or operational impact. This should justify priority, not repeat the problem statement.
- `Implementation`
  Describe what changed in enough detail that a reviewer can understand the fix path without reopening every file immediately.
- `Affected plugin areas`
  Use a flat bullet list of the touched subsystems, flows, or boundaries, not a raw file dump.
- `Risk and regression assessment`
  State the realistic regression level and the main condition that could still fail after rollout.
- `Validation performed`
  List the exact checks, commands, or manual validations actually run. Do not imply coverage that was not executed.
- `QA notes`
  Write this as a mini test guide. Call out environment-specific setup, happy path, failure path, and the main regression checks QA must perform.

Style expectations:

- Be more detailed than the default final answer.
- Write in complete sentences, not terse changelog fragments.
- Focus on behavior, risk, and validation, not just edited files.
- Keep the narrative readable by engineering, product, and QA.
- If the change is security-sensitive or payment-sensitive, make the trust boundary and negative-path testing explicit.

Default QA coverage should include:

- required configuration or environment notes
- primary success path
- primary failure or rejection path
- regression checks for adjacent flows
- any production vs sandbox differences

If a section is truly not applicable, say so briefly rather than deleting the section. The default is completeness.

Literal template:

```md
## Description

### Problem

[Explain the concrete defect, risk, missing capability, or regression surface.]

### Why this is critical

[Explain the trust boundary, operational impact, production blast radius, or customer-visible failure.]

### Implementation

[Describe the actual change path in complete sentences. Mention the real control flow, persistence changes, and any new validation.]

### Affected plugin areas

- [surface or subsystem]
- [surface or subsystem]

### Risk and regression assessment

[State the realistic rollout risk and the main remaining failure condition.]

### Validation performed

- [exact command or targeted manual validation]
- [exact command or targeted manual validation]

### QA notes

[Environment or config notes.]

[Primary success-path guide.]

[Primary failure-path or rejection-path guide.]

[Adjacent regression checks.]
```

Literal QA-guide mini template:

```md
QA notes:

- Config: [sandbox vs production, flags, credentials, snippets, indexes, caches]
- Happy path: [exact path to verify]
- Negative path: [invalid payload, missing signature, ACL denial, empty state, etc.]
- Regression checks: [adjacent flow that could break]
- Version caveat: [6.6 vs 6.7 or migration split if relevant]
```
