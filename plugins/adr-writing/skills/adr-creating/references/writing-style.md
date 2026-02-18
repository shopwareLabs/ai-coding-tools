# Writing Style

## Voice Examples

The best ADRs sound like a developer explaining a decision to a colleague:

> "With the last benchmarks it became clear how cost intensive the loading and saving of the shopping cart to and from the database is. A detailed analysis revealed two problems:"
> — Redis Cart Persister (2022)

> "Having to rely on Reflection in your test cases to reset data is a major red flag now!"
> — Reset Interface (2022)

> "Considering there is little risk to using UUIDv7, as v4 and v7 share the same length and are indistinguishable for shopware, we can switch to v7 without any risk of breaking anything."
> — UUIDv7 (2023)

## Prose vs Lists

**Prose** for reasoning, trade-offs, explaining connections — when the reader needs to follow your thinking.

**Plain bullets** for discrete, independent items:

```markdown
* In the Store API
    * Data selected and returned via Store API must be extensible by third party developers.
    * Requests against the Store API should always allow additional data to be loaded.
```

**Problems/Solutions** pattern for domain-by-domain ADRs:

```markdown
**Problems:**
* We are unsure which data will the app event provide

**Solution:**
* We create an interface CustomAppAware that will use as implementation
  for the custom event from the app.
```

## Anti-Pattern: Numbered Lists With Bold Labels

Categorizes rather than explains — avoid this:

```markdown
<!-- DON'T -->
1. **Non-Deterministic Builds**: different developers or CI runs may install
   different versions, leading to "works on my machine" issues
2. **Security Risk Window**: malicious packages can be introduced through
   automatic version updates without explicit review
```

```markdown
<!-- DO -->
NPM dependencies with range specifiers allow automatic updates to newer
versions during installation. Different developers or CI runs may end up
with different versions, and malicious packages can slip in through automatic
updates without explicit review.
```

## Tables

Use for structured reference data — affected areas, class/purpose mappings, configuration options:

```markdown
| Area                  | Explanation                                               |
|-----------------------|-----------------------------------------------------------|
| Shopping cart summary | Asterisk removed. Info is already part of the summary.    |
| Product-box (listing) | Info displayed as text when allowBuyInListing is enabled. |
```

Tables for lookup, not for reasoning.

## Diagrams

Mermaid diagrams work well for hierarchical relationships, data flows, and before/after architecture changes. One focused diagram per concept.

## Immutability

Once an ADR is accepted, do not alter the reasoning. If the decision changes, supersede it with a new ADR.
