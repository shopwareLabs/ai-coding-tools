# Writing Style

## Target Audience

Shopware developers familiar with the codebase. Do not explain basic concepts: DAL, Symfony, Vue, Criteria, SalesChannelContext, Entity definitions, Storefront plugins, App System, Flow Builder.

## Voice

Write like you're explaining a decision to a colleague. The best ADRs have a direct, informal, developer-to-developer voice:

> "With the last benchmarks it became clear how cost intensive the loading and saving of the shopping cart to and from the database is. A detailed analysis revealed two problems:"
> — Redis Cart Persister (2022)

> "Having to rely on Reflection in your test cases to reset data is a major red flag now!"
> — Reset Interface (2022)

> "Considering there is little risk to using UUIDv7, as v4 and v7 share the same length and are indistinguishable for shopware, we can switch to v7 without any risk of breaking anything."
> — UUIDv7 (2023)

State facts and let readers draw conclusions. Factual qualitative descriptions are good — "simplifies the caching logic", "removes the need for manual transaction handling", "makes the code more concise". These describe what actually changes.

**Quantitative claims** (percentages, timings, counts) are only acceptable when the author provides explicit data from benchmarks, profiling, or measurements. Never estimate, guess, or fabricate numbers. If the author says "benchmarks show 8% improvement", include it. If no data exists, describe the expected effect qualitatively.

**Avoid promotional language**: "greatly improved", "enhancing usability and customization", "stands to benefit significantly", "powerful new capability". These phrases add no information and read like marketing copy, not technical decisions.

## Prose vs Lists

**Use prose** when:
- Reasoning through trade-offs
- Explaining why a decision was made
- Describing how things connect
- The reader needs to follow your thinking, not scan items

**Use plain bullets** when enumerating discrete, independent items:

```markdown
* All CSRF implementations in the Storefront will be removed.
```

```markdown
* In the Store API
    * Data selected and returned via Store API must be extensible by third party developers.
    * Requests against the Store API should always allow additional data to be loaded.
```

The **Problems/Solutions** pattern works well for domain-by-domain ADRs:

```markdown
**Problems:**
* We are unsure which data will the app event provide

**Solution:**
* We create an interface CustomAppAware that will use as implementation
  for the custom event from the app.
```

## Anti-Pattern: Numbered Lists With Bold Labels

This pattern categorizes rather than explains. It does not appear in pre-2023 ADRs and should be avoided:

```markdown
<!-- DON'T write this -->
1. **Non-Deterministic Builds**: different developers or CI runs may install
   different versions, leading to "works on my machine" issues
2. **Security Risk Window**: malicious packages can be introduced through
   automatic version updates without explicit review
```

```markdown
<!-- DO write this instead -->
NPM dependencies with range specifiers allow automatic updates to newer
versions during installation. Different developers or CI runs may end up
with different versions, and malicious packages can slip in through automatic
updates without explicit review.
```

The prose version is shorter, reads naturally, and conveys the same information.

## Tables

Use tables for structured reference data — affected areas, class/purpose mappings, configuration options:

```markdown
| Area                  | Explanation                                               |
|-----------------------|-----------------------------------------------------------|
| Shopping cart summary | Asterisk removed. Info is already part of the summary.    |
| Product-box (listing) | Info displayed as text when allowBuyInListing is enabled. |
```

Tables work when readers need to look up specific items, not when they need to understand reasoning.

## Diagrams

Mermaid diagrams are effective for:
- Hierarchical relationships (e.g., language fallback chains)
- Data flows between components
- Before/after architecture changes

Keep diagrams focused on the decision at hand. One diagram illustrating the key concept is better than multiple diagrams covering every detail.

## General Principles

- **Rationale is king**: The "why" is the most valuable part. Decisions without context become meaningless over time.
- **One decision per ADR**: Don't bundle multiple decisions. If two decisions are related, write two ADRs and cross-reference them.
- **Context before solution**: Always explain the problem and constraints before presenting the decision.
- **Immutability**: Once an ADR is accepted, don't alter the reasoning. If the decision changes, supersede it with a new ADR.
