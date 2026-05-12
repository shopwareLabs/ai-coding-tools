---
id: PLACEMENT-001
title: Container intent — service locator or system under test?
group: placement
enforce: consider
test-types: integration
test-categories: all
scope: shopware
---

## Container intent — service locator or system under test?

**Scope**: all | **Enforce**: Consider (reasoning prompt; loaded only by `phpunit-integration-to-unit-migrating`)

For every `$this->getContainer()->get(X)` (or `static::getContainer()->get(X)`) in the test, decide whether the container is acting as a **service locator** (a convenient way to get a pre-built instance whose collaborators could be constructed manually) or as the **system under test** (the assertion is about the wired graph itself).

Default suspicion: container usage is incidental. The container is only load-bearing when the assertion depends on what the container *did to* the service — compiler-pass output, autowired dependency identity, service tags, scoped instances, parameter injection.

### Worked deliberation

For each container fetch, answer in writing:

1. **What is X?** Class name and role (service, factory, subscriber, etc.).
2. **What does X depend on?** List X's constructor signature.
3. **Could `new X(...explicit collaborators...)` produce the same instance for the test's purpose?** Yes / no / unclear.
4. **What about X's wiring is the assertion checking?**
   - "Nothing — the assertion is about X's method return value" → service locator (migrate)
   - "X has compiler-pass-applied state (tags, decorations, scoped service)" → SUT (keep)
   - "X is autowired with concrete implementations the test depends on by identity" → SUT (keep, unless the implementations are mockable boundaries)

### Verdict

- All container fetches resolve as **service locator** → integration apparatus is not load-bearing; proceed to PLACEMENT-004.
- One or more container fetches resolve as **SUT** → record which, the test stays in integration. Stop the migration audit unless the SUT-wiring assertions can be replaced (rare).

### Examples

```php
// SERVICE LOCATOR - X has no compiler-pass-applied state, no scoped wiring
$factory = static::getContainer()->get(ActionButtonResponseFactory::class);
$response = $factory->build(...);
static::assertSame(200, $response->getStatusCode());
// → migrate. new ActionButtonResponseFactory(...) with explicit collaborators is equivalent.

// SUT - assertion depends on compiler-pass-applied template loader collection
$twig = static::getContainer()->get('twig');
$loaders = $twig->getLoader()->getLoaders();
static::assertContainsOnlyInstancesOf(BundleLoader::class, $loaders);
// → keep. The wired loader collection is the SUT.
```
