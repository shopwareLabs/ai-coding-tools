---
id: PLACEMENT-003
title: Kernel intent — kernel state under test or paying for getContainer()?
group: placement
enforce: consider
test-types: integration
test-categories: all
scope: shopware
---

## Kernel intent — kernel state under test or paying for getContainer()?

**Scope**: all | **Enforce**: Consider (reasoning prompt; loaded only by `phpunit-integration-to-unit-migrating`)

The kernel boot exists to provide route resolution, bundle wiring, environment-aware config, migration state, and the populated container. Decide whether the assertion targets any of those things directly, or whether the kernel boot is just the price paid to call `getContainer()`.

In the common case, this rule collapses into PLACEMENT-001 — kernel paying for `getContainer()` means the container question dominates. PLACEMENT-003 is its own rule because some integration tests use kernel features the container does not represent (route resolution against the routing component, bundle event subscribers, environment-specific Symfony parameters, applied database migrations).

### Worked deliberation

Answer in writing:

1. **What kernel-level features does the test exercise?** Pick all that apply:
   - Route resolution / controller dispatch
   - Bundle wiring (event subscribers registered via bundle Extension)
   - `%env(...)%` / `%kernel.environment%` parameter resolution
   - Applied database migrations (schema state)
   - None — the only kernel use is `getContainer()`
2. **Does the assertion depend on any of those features?** If yes, the kernel is load-bearing. If no, the kernel is just `getContainer()`'s host — fall through to PLACEMENT-001.

### Verdict

- Kernel features exercised AND asserted → keep in integration.
- Kernel used only to reach the container → defer to PLACEMENT-001.

### Examples

```php
// KERNEL UNDER TEST - asserts route resolution
$client = static::createClient();
$client->request('GET', '/api/_action/foo');
static::assertSame(200, $client->getResponse()->getStatusCode());
// → keep. Route resolution + controller dispatch is the SUT.

// KERNEL JUST PAYING FOR getContainer()
$service = static::getContainer()->get(MyService::class);
static::assertSame('expected', $service->doThing());
// → defer to PLACEMENT-001.
```
