# Structure Patterns

When in doubt, start with Simple. Upgrade to Multi-Domain if you find yourself describing changes in more than two separate areas of the system.

---

## Simple Structure Examples

**Concise, pure prose, clear reasoning (34 lines):**

```markdown
---
title: Make Rule classes internal
date: 2025-01-29
area: core
tags: [core, rules]
---

## Context
The existing rule system is flexible but complex, making it difficult to evolve
and maintain. Allowing unrestricted extensions of rule classes slows down
improvements and increases the complexity of the system.

## Decision
We will mark existing rule classes as internal, limiting direct usage by third
parties. Developers should create new rule classes instead of modifying existing
ones.

Nearly all rule classes will be marked as internal, with a few exceptions:
LineItemOfTypeRule, LineItemProductStatesRule, PromotionCodeOfTypeRule,
ZipCodeRule, BillingZipCodeRule, ShippingZipCodeRule.

These classes will remain public for now, because they rely on configuration
which is reasonably expected to be extended by third-party developers.

## Consequences
* Faster evolution of the rule system
* Clearer extension mechanisms for developers
* Potential migration efforts for third-party developers currently extending rule classes
```

**Measurable impact, developer-to-developer voice:**

```markdown
---
title: Switch to UUIDv7
date: 2023-05-22
area: core
tags: [DAL]
---

## Context
Using UUIDs as primary keys eases the integration of several different data sources,
but it also brings some performance issues. Currently, we're using UUIDv4, which is
a random UUID — the completely random prefix means that the B-tree indexes of the
database are not very efficient.

UUIDv7 time-based prefix is less spread than that of UUIDv4, this helps the database
to keep the index more compact.

## Decision
Considering there is little risk to using UUIDv7, as v4 and v7 share the same
length and are indistinguishable for shopware, we can switch to v7 without any risk
of breaking anything.

The effort is also very low as we only need to change the implementation of the
`Uuid` class. As using UUIDv7 will improve the speed of bulk product inserts by
about 8%, we think the effort is worth the measurable and theoretical gain.

## Consequences
We will switch to UUIDv7 as default and add performance guides promoting v7.
```

---

## Multi-Domain Structure

Template with audience-split consequences:

```markdown
---
title: Short descriptive title
date: YYYY-MM-DD
area: checkout
tags: [relevant, tags]
---

## Context

[Brief overview of the decision and why it spans multiple domains.]

## [Domain Name 1]

[1-2 sentences: why this domain is relevant.]

**Problems:**
* [What logic has to be touched and why — not how]

**Solution:**
* [How you want to change the above logic]

\`\`\`php
// interface, class signature, or key logic
\`\`\`

## [Domain Name 2]

[Same pattern: relevance, problems, solution, pseudocode]

## Extendability

[How developers extend the system. What business cases you see.]

## Consequences

### For the platform
### For third-party developers
```

**Example — domain-by-domain with Problems/Solutions and pseudocode:**

```markdown
---
title: Introducing tax providers
date: 2022-04-28
area: checkout
tags: [tax, tax-provider, checkout]
---

## Context
In other countries like the USA, there are different tax rates for different states
and counties, leading to thousands of different tax rates. For this purpose, tax
providers exist like TaxJar, Vertex or AvaTax.

## Decision
We want to implement an interface which is called after the cart is calculated and
is able to overwrite the taxes.

## New entity `tax_provider`
We create a new entity called `tax_provider` which registers available tax providers
and defines rules.

## Location and prioritization
The `TaxProviderProcessor` is called in the `CartRuleLoader`, after the whole cart
has been calculated.

The tax provider will only be called if:
* A customer is logged in
* The availability rule matches

## Calling the tax provider

**Problems:**
* Apps need to call external tax providers but there is no hook for this.

**Solution:**
* The Processor calls a class tagged `shopware.tax.provider` implementing
  `TaxProviderInterface`. If the class does not exist, a `TaxProviderHook`
  is dispatched for app scripting.

\`\`\`php
interface TaxProviderInterface
{
    public function provideTax(Cart $cart, SalesChannelContext $context): TaxProviderStruct;
}
\`\`\`

## Return & Processing
If any values of the TaxProviderStruct are filled, no more providers are called.
Line items / shipping costs / total tax are overwritten before the cart is persisted.

\`\`\`php
class TaxProviderStruct extends Struct
{
    protected ?array $lineItemTaxes = null;   // key: line item id
    protected ?array $deliveryTaxes = null;   // key: delivery id
    protected ?CalculatedTaxCollection $cartPriceTaxes = null;
}
\`\`\`
```

---

## Additional Sections

| Section | When to use |
|---------|-------------|
| Extendability | New APIs or extension points |
| Considered Alternatives | Multiple viable approaches — explain rejection reasons |
| Backward Compatibility | Migration paths, deprecation timelines |
| Security Considerations | Trust boundaries, auth implications |
| Implementation Details | Technical detail beyond pseudocode |
| Database Migration | Schema changes |

**Considered Alternatives example:**

```markdown
## Considered alternatives

1. Keep using cookies for context differentiation similarly to Storefront:
   - Less explicit for the clients, cache can be used unintentionally.
   - More complex configuration for reverse proxies.
   Rejected in favor of explicit request headers.

2. Cache POST requests with big payloads if possible:
   - Not aligned with HTTP semantics (POST is not cacheable by default).
   - More complex configuration for reverse proxies and CDNs.
   Rejected in favor of alignment with HTTP semantics.

3. Two-step flow: POST returns a request hash; GET retrieves cached data by hash:
   - More complex implementation for clients (changed workflow).
   - Additional round-trip for the requests.
   Rejected in favor of simplicity and minimal changes on clients side.
```

**Affected areas table example:**

```markdown
| Area                                       | Explanation                                                                 |
|--------------------------------------------|-----------------------------------------------------------------------------|
| Shopping cart and order line items          | Asterisk removed. Info is already shown in the cart summary.                |
| Shopping cart summary                       | Asterisk removed. Info is already part of the cart summary itself.          |
| Product-box (listing, product slider etc.)  | Info is displayed as text when `allowBuyInListing` is enabled.             |
| Buy-widget on product detail page           | Info is already shown underneath the price.                                |
```

**Extension points example:**

```markdown
## Consequences
* The cache needs to be invalidated whenever a category is written or deleted.
* We encode salesChannelId, language, root category id and depth in the cache key.
* We will add a `CategoryLevelLoaderCacheKeyEvent` so that plugins can modify
  the cache key if they dynamically influence which categories should be loaded.
```
