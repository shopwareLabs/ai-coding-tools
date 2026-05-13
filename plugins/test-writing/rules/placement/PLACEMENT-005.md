---
id: PLACEMENT-005
title: Collaborator graph — how many real collaborators does the assertion traverse?
group: placement
enforce: consider
test-types: integration
test-categories: all
scope: shopware
---

## Collaborator graph — how many real collaborators does the assertion traverse?

**Scope**: all | **Enforce**: Consider (reasoning prompt; loaded only by `phpunit-integration-to-unit-migrating`)

A real integration test asserts behavior that emerges from the **interaction** of multiple real collaborators. A test where only the SUT and a single stateless helper are actually exercised by the assertion is unit-shape — the apparatus around it is decoration.

### Worked deliberation

For each test method:

1. **Trace the call graph from the test's act-step to the assertion.** What concrete classes does control pass through?
2. **Mark each node:**
   - `M` mocked
   - `S` stateless helper (constructor takes only value objects or stateless services)
   - `R` real, stateful, non-trivial collaborator (has DB, cache, queue, scoped state, or coordinates >1 service)
3. **Count the `R` nodes** the assertion actually depends on (i.e. removing the `R` would change the assertion result).

### Verdict

| `R` count | Verdict |
|---|---|
| 0 | The test is unit-shape — no real collaborator beyond the SUT participates in the assertion. Strong migration candidate. |
| 1 | The SUT + one stateful collaborator. Could be either; combine with PLACEMENT-001..004 verdicts. |
| ≥ 2 with non-trivial interaction | Legitimate integration. Keep. |

### Examples

```php
// R-count = 0 - SUT plus pure helpers
$service = static::getContainer()->get(MyService::class);  // M=0, S=collaborators are stateless
$result = $service->doThing(42);
static::assertSame(43, $result);
// → migrate.

// R-count = 2 - DAL + indexer + event dispatcher all participate
$this->productRepository->create([['id' => $id, 'stock' => 5, ...]], $context);
// participates: EntityWriter (R), StockIndexer (R), EventDispatcher (R)

$stock = $this->connection->fetchOne('SELECT available_stock FROM product WHERE id = ?', [Uuid::fromHexToBytes($id)]);
static::assertSame(5, (int) $stock);
// → keep. Indexer running after DAL write is the integration.
```

### Anti-pattern: one-collaborator integration tests

Most "this test takes 30 seconds to run and asserts a return value" smells reduce to R-count = 0 or 1 with a single non-mocked DAL call that's actually a materializer (see PLACEMENT-002).
