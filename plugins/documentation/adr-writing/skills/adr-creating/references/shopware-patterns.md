# Shopware-Specific Patterns

## Feature Flag Gating

State the flag name early when behavior is toggled, experimental, or opt-in breaking:

> "The following is all experimental and only takes effect if the associated feature flag `FLOW_EXECUTION_AFTER_BUSINESS_PROCESS` is enabled"
> — Move Flow Execution (2025)

> "All the breaking changes (and caching benefits) can be already used by opting in and enabling the `CACHE_REWORK` feature flag."
> — Improved HTTP Cache (2025)

Include: flag name, behavior when enabled vs disabled, timeline for becoming default (if known).

## Cross-References

Link related ADRs to prevent duplication:

> "For detailed documentation on why and how we added support for the store-api
> caching, refer to the specific store-api caching ADR."
> — Improved HTTP Cache (2025)

**Format:**
```markdown
See [ADR title](./YYYY-MM-DD-filename.md) for [what it covers].
```

## Superseding ADRs

When a new ADR replaces an older one:
1. State in the new ADR: "This supersedes [old ADR](./path)"
2. Move old ADR to `adr/_superseded/`
3. Add `status: superseded` to old ADR's front matter

## Consequences by Audience

Split consequences when platform and third-party developers are affected differently (different APIs, migration effort, or plugin compatibility):

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
