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

### Detection Algorithm

1. Read source class referenced by `#[CoversClass]`. Scan for:
   - `@deprecated` PHPDoc tags on the class, methods, or properties
   - `Feature::triggerDeprecationOrThrow()` calls — extract flag names (e.g., `'v6.8.0.0'`)
2. If source has no deprecation markers → rule does not apply, skip.
3. For each test method that instantiates or calls deprecated API:
   - Check for **method-level** guard: `#[DisabledFeatures]` attribute, `Feature::skipTestIfActive()`, or `Feature::skipTestIfInActive()`
   - Check for **class-level** guard: `#[DisabledFeatures]` on class declaration, or `Feature::skipTestIfActive()` in `setUp()`
   - No guard found → **violation (missing guard)**
4. If guard is present, verify direction matches test intent:
   - Test asserts old/deprecated behavior but uses `skipTestIfInActive` → **violation (wrong direction)**
   - Test asserts new behavior but uses `skipTestIfActive` or `#[DisabledFeatures]` → **violation (wrong direction)**

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

### Do NOT Flag

- Source class has no `@deprecated` tags and no `Feature::triggerDeprecationOrThrow()` calls
- Test already has the correct guard for its intent
- Test is in the Feature framework itself (`FeatureTest`, `FeatureFlagCallTokenParserTest`) and directly tests `triggerDeprecationOrThrow` behavior
