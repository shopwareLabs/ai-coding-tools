---
id: PLACEMENT-002
title: Persistence intent — DAL behavior or convenient materializer?
group: placement
enforce: consider
test-types: integration
test-categories: all
scope: shopware
review-unit: class-bodies
scoped-review: include
---

## Persistence intent — DAL behavior or convenient materializer?

**Scope**: all | **Enforce**: Consider (reasoning prompt; loaded only by `phpunit-integration-to-unit-migrating`)

For every DAL operation in the test (`EntityRepository::create()`, `update()`, `upsert()`, `delete()`, `search()`, `searchIds()`), decide whether the assertion is about **DAL behavior** (a write was persisted, an indexer fired, version pinning worked, an entity event was dispatched) or whether the DAL is being used as a **materializer** — a convenient way to obtain an entity instance that the test then feeds into pure logic.

The materializer pattern is the most common "looks integration, is actually unit" trap: setUp creates a `ProductEntity` through `$repository->create()`, the test reads it back, then calls a pure method on it and asserts a return value. The DAL round-trip adds nothing the assertion verifies — `new ProductEntity()` with setters produces an equivalent input.

### Worked deliberation

For each DAL call, answer in writing:

1. **What did the call do?** Write / read / search / delete.
2. **What does the test assert about the call's effect?**
   - "Nothing — it just returns an entity I then call methods on" → materializer (migrate)
   - "The entity is re-read later and a persisted field is asserted" → DAL behavior (keep)
   - "An entity event / indexer / version is asserted" → DAL behavior (keep)
   - "The assertion is on a column the test wrote, re-read through DAL" → DAL behavior (keep)
3. **If materializer: can the same entity be constructed in-memory?** Almost always yes — Shopware entities are POPOs with setters.

### Verdict

- All DAL calls are materializers → DAL is not load-bearing; proceed to PLACEMENT-004.
- One or more DAL calls verify persistence behavior → test stays in integration.

### Examples

```php
// MATERIALIZER - DAL is just providing an entity instance
$this->productRepository->create([['id' => $id, 'name' => 'foo', ...]], $context);
$product = $this->productRepository->search(new Criteria([$id]), $context)->first();

static::assertSame('foo', $product->translate('name'));
// → migrate. $product = (new ProductEntity())->setName('foo'); is equivalent for the assertion.

// DAL BEHAVIOR - assertion verifies write + indexer effect
$this->productRepository->create([['id' => $id, 'name' => 'foo', 'stock' => 5]], $context);

$indexed = $this->connection->fetchOne('SELECT available_stock FROM product WHERE id = ?', [Uuid::fromHexToBytes($id)]);
static::assertSame(5, (int) $indexed);
// → keep. Asserts that the stock indexer ran on the persisted row.
```
