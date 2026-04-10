---
id: UNIT-007
title: Deprecation Guard Required
group: unit
enforce: must-fix
test-types: unit
test-categories: A,B,C,D,E
scope: shopware
---

## Deprecation Guard Required

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Tests that exercise deprecated APIs MUST declare their relationship to the deprecation using the correct guard mechanism.

### Why Guards Are Required

The `FeatureFlagExtension` (registered in `phpunit.xml.dist`) activates all registered feature flags before every unit test in the `Shopware\Tests\Unit` namespace. When a flag is active, `Feature::triggerDeprecationOrThrow()` throws `FeatureException` instead of emitting a deprecation notice. Tests that call deprecated code without a guard will fail in CI with an unexpected exception.

The `TESTS_RUNNING` silent-return path inside `triggerDeprecationOrThrow()` only executes when the flag is explicitly inactive — which requires either `#[DisabledFeatures]` or `Feature::skipTestIfActive()` to override the extension's default activation.

### Decision Table

| Scenario | Required Pattern |
|---|---|
| Test verifies deprecated/old behavior (single method) | `Feature::skipTestIfActive('flag', $this)` at method start, OR `#[DisabledFeatures(['flag'])]` on method |
| Test verifies deprecated/old behavior (entire class) | `#[DisabledFeatures(['flag'])]` on class, OR `Feature::skipTestIfActive('flag', $this)` in `setUp()` |
| Test verifies new behavior only available after flag | `Feature::skipTestIfInActive('flag', $this)` at method start |
| Paired old/new behavior in same class | `skipTestIfActive` on old method + `skipTestIfInActive` on new method |
| Source uses `Feature::silent()` for an incidental deprecated call | `Feature::silent('flag', fn () => ...)` wrapping the same call in the test |
| Source uses `Feature::callSilentIfInactive()` for a deprecated call | `Feature::callSilentIfInactive('flag', fn () => ...)` wrapping the same call in the test |

### Detection Algorithm

1. Read source class referenced by `#[CoversClass]`. Scan for:
   - `@deprecated` PHPDoc tags on the class, methods, or properties
   - `Feature::triggerDeprecationOrThrow()` calls — extract flag names (e.g., `'v6.8.0.0'`)
   - `Feature::silent()` or `Feature::callSilentIfInactive()` calls — extract flag names
2. If source has no deprecation markers → rule does not apply, skip.
3. For each test method that instantiates or calls deprecated API:
   - Check for **method-level** guard: `#[DisabledFeatures]` attribute, `Feature::skipTestIfActive()`, `Feature::skipTestIfInActive()`, `Feature::silent()`, or `Feature::callSilentIfInactive()`
   - Check for **class-level** guard: `#[DisabledFeatures]` on class declaration, or `Feature::skipTestIfActive()` in `setUp()`
   - No guard found → **violation (missing guard)**
4. If guard is present, verify direction matches test intent:
   - Test asserts old/deprecated behavior but uses `skipTestIfInActive` → **violation (wrong direction)**
   - Test asserts new behavior but uses `skipTestIfActive` or `#[DisabledFeatures]` → **violation (wrong direction)**
   - Test uses `Feature::silent()` but source does NOT use `Feature::silent()` for the same call → **violation (wrong guard type)** — `Feature::silent` is only correct when mirroring the source pattern

### Detection — Missing Guard

```php
use Shopware\Core\Content\Product\Events\ProductStatesChangedEvent;

// INCORRECT - deprecated event constructed without guard; throws FeatureException in CI
public function testProductStatesChangedEvent(): void
{
    $event = new ProductStatesChangedEvent($updatedStates, $context);
    static::assertSame($updatedStates, $event->getUpdatedStates());
}
```

### Fix — Missing Guard (skipTestIfActive)

```php
use Shopware\Core\Framework\Feature;

// CORRECT - test skipped when flag is active (deprecated behavior no longer exists)
public function testProductStatesChangedEvent(): void
{
    Feature::skipTestIfActive('v6.8.0.0', $this);

    $event = new ProductStatesChangedEvent($updatedStates, $context);
    static::assertSame($updatedStates, $event->getUpdatedStates());
}
```

### Fix — Missing Guard (DisabledFeatures)

```php
use Shopware\Core\Test\Annotation\DisabledFeatures;

// CORRECT - flag explicitly disabled, triggerDeprecationOrThrow silently returns
#[DisabledFeatures(['v6.8.0.0'])]
public function testProductStatesChangedEvent(): void
{
    $event = new ProductStatesChangedEvent($updatedStates, $context);
    static::assertSame($updatedStates, $event->getUpdatedStates());
}
```

### Detection — Wrong Guard Direction

```php
// INCORRECT - test verifies NEW behavior but disables the flag (runs against old code path)
#[DisabledFeatures(['v6.8.0.0'])]
public function testReturnsNullAfterDeprecationRemoval(): void
{
    $accessor = new ThemeConfigValueAccessor(...);
    static::assertNull($accessor->get('breakpoint'));
}
```

### Fix — Wrong Guard Direction

```php
// CORRECT - new behavior requires flag to be active
public function testReturnsNullAfterDeprecationRemoval(): void
{
    Feature::skipTestIfInActive('v6.8.0.0', $this);

    $accessor = new ThemeConfigValueAccessor(...);
    static::assertNull($accessor->get('breakpoint'));
}
```

### Paired Old/New Behavior

When a class needs tests for both the deprecated and replacement behavior:

```php
// OLD behavior — runs only when flag is inactive
public function testGetWithoutThemeId(): void
{
    Feature::skipTestIfActive('v6.8.0.0', $this);

    $result = $this->accessor->get('breakpoint');
    static::assertSame('lg', $result);
}

// NEW behavior — runs only when flag is active
public function testGetWithoutThemeIdPostV68(): void
{
    Feature::skipTestIfInActive('v6.8.0.0', $this);

    $result = $this->accessor->get('breakpoint');
    static::assertNull($result);
}
```

### Class-Level Guard (Entire Class Deprecated)

When the source class itself is deprecated and all tests verify legacy behavior:

```php
/**
 * @deprecated tag:v6.8.0 - Can be removed as the tested class will be removed
 */
#[CoversClass(StoreApiRouteCacheKeyEvent::class)]
#[DisabledFeatures(['v6.8.0.0'])]
class StoreApiRouteCacheKeyEventTest extends TestCase
{
    // All methods run with flag disabled — no per-method guards needed
}
```

Or using `setUp()`:

```php
protected function setUp(): void
{
    Feature::skipTestIfActive('v6.8.0.0', $this);
    $this->rule = new LineItemProductStatesRule();
}
```

### Multiple Flags

When deprecated code is gated behind multiple flags, all relevant flags must be guarded:

```php
public function testNestedTransactionExceptions(): void
{
    Feature::skipTestIfActive('FLOW_EXECUTION_AFTER_BUSINESS_PROCESS', $this);
    Feature::skipTestIfActive('v6.8.0.0', $this);
    // ...
}
```

### Feature::silent (Incidental Deprecated Call)

When the source code wraps a deprecated call in `Feature::silent()`, the test mirrors that pattern. Unlike `#[DisabledFeatures]` or `skipTestIfActive` (which disable the flag or skip the test), `Feature::silent` suppresses the deprecation for a specific closure only — the flag stays active, and the rest of the test runs normally.

Use this when the deprecated call is **incidental** to the behavior being tested — not the subject of the test.

```php
// Source code uses Feature::silent to construct a deprecated object:
// $tokenStruct = Feature::silent('v6.8.0.0', fn () => new TokenStruct());

// CORRECT - test mirrors the source pattern
public function testFinalizeTransactionRedirectsToFinishUrl(): void
{
    Feature::silent('v6.8.0.0', static function () use (&$fakeTokenStruct): void {
        $fakeTokenStruct = new TokenStruct();
    });

    $this->paymentProcessor->method('finalize')->willReturn($fakeTokenStruct);
    $response = $this->controller->finalizeTransaction($request);
    static::assertInstanceOf(RedirectResponse::class, $response);
}

// INCORRECT - using skipTestIfActive skips the entire test when the flag is active,
// but the source code runs this path regardless of flag state via Feature::silent
public function testFinalizeTransactionRedirectsToFinishUrl(): void
{
    Feature::skipTestIfActive('v6.8.0.0', $this);

    $fakeTokenStruct = new TokenStruct();
    // ...
}
```

### Do NOT Flag

- Source class has no `@deprecated` tags, no `Feature::triggerDeprecationOrThrow()` calls, and no `Feature::silent()`/`Feature::callSilentIfInactive()` calls
- Test already has the correct guard for its intent
- Test is in the Feature framework itself (`FeatureTest`, `FeatureFlagCallTokenParserTest`) and directly tests `triggerDeprecationOrThrow` behavior
