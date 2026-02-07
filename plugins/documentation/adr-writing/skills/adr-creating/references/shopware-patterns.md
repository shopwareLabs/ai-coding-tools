# Shopware-Specific Patterns

## Feature Flag Gating

When a decision is gated behind a feature flag, state this clearly and early:

> "The following is all experimental and only takes effect if the associated feature flag `FLOW_EXECUTION_AFTER_BUSINESS_PROCESS` is enabled"
> — Move Flow Execution (2025)

> "All the breaking changes (and caching benefits) can be already used by opting in and enabling the `CACHE_REWORK` feature flag."
> — Improved HTTP Cache (2025)

**When to mention feature flags:**
- The change introduces new behavior that can be toggled
- The change is experimental or phased
- Breaking changes are opt-in before becoming default

**How to mention them:**
- State the flag name explicitly
- Explain what happens when enabled vs disabled
- Mention the expected timeline for making it default (if known)

## Cross-References

Link to related ADRs when they exist. This prevents duplication and builds context:

> "For detailed documentation on why and how we added support for the store-api
> caching, refer to the specific store-api caching ADR."
> — Improved HTTP Cache (2025)

**Format:**
```markdown
See [ADR title](./YYYY-MM-DD-filename.md) for [what it covers].
```

Cross-reference when:
- A related decision was made separately
- The current ADR builds on or extends a previous one
- Background context exists in another ADR

## Superseding ADRs

When a new ADR replaces an older one:
1. State this in the new ADR: "This supersedes [old ADR](./path)"
2. Move the old ADR to `adr/_superseded/`
3. Add `status: superseded` to the old ADR's front matter

## Consequences by Audience

When a decision affects platform developers and third-party developers differently, split the consequences:

```markdown
## Consequences

### For the platform
- Querying by digital/physical becomes trivial (`product.type = 'digital'`)
- Existing states migration handled by background indexer

### For third-party developers
- You can now register new product types by overriding `shopware.product.allowed_types`
- State-based checks should migrate to type-based checks before v7.0
```

**When to split:**
- The decision introduces APIs that third-party developers will use
- Migration effort differs between platform and extension developers
- Behavioral changes affect plugin compatibility

**Example from a real ADR (introducing product types):**

```markdown
## Consequences

### For the platform
- Querying by digital/physical becomes trivial (`product.type = 'digital'`),
  improving DAL and search performance and clarity.
- The core will migrate existing `product.states` to `product.type`.
- Rule conditions must be updated to reference `cartLineItemProductType`;
  existing rules referencing `cartLineItemProductStates` will continue to work
  until 6.8 but should be migrated.

### For third-party developers
- You can now register new product types by overriding
  `shopware.product.allowed_types` in your `config/packages/shopware.yaml`.
- If you have existing code that relies on `product.states`, you should plan
  to migrate to the new `product.type` field.
- Backwards compatibility must be maintained for 6.7, but in 6.8 the `states`
  fields should disappear entirely.
```
