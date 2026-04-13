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

Tests that exercise deprecated APIs MUST declare their relationship to the deprecation using the correct mechanism. In unit tests, the only mechanism that actually deactivates a feature flag is the `#[DisabledFeatures]` attribute.

### Why Guards Are Required

The `FeatureFlagExtension` (registered in `phpunit.xml.dist`) force-activates **all** registered feature flags before every unit test in the `Shopware\Tests\Unit` namespace, regardless of their `default` value in `feature.yaml`. The only way to make a flag inactive in a unit test is the `#[DisabledFeatures]` attribute at class or method level — it is the sole input the extension reads when deciding which flags stay off.

When a flag is active, `Feature::triggerDeprecationOrThrow()` throws `FeatureException` instead of emitting a deprecation notice. Tests that call deprecated code without `#[DisabledFeatures]` will fail in CI with an unexpected exception.

Because flags are always on by default, the `Feature::skipTestIf*()` helpers behave in non-obvious ways inside unit tests:

| Call | Behavior in unit tests | Verdict |
|---|---|---|
| `Feature::skipTestIfActive('flag', $this)` | Always skips (flag is active) — test body never runs | Broken without `#[DisabledFeatures]`; redundant with it. Delete the call, rely on `#[DisabledFeatures]` alone. |
| `Feature::skipTestIfInActive('flag', $this)` | Never skips (flag is active) — guard is dead code | Delete the call. The test already runs unconditionally because the flag is always active. |

Both helpers still make sense in **integration** tests, which respect `feature.yaml` defaults. In unit tests they are either broken or dead.

### Decision Table

| Scenario | Required Pattern |
|---|---|
| Test verifies deprecated/old behavior (single method) | `#[DisabledFeatures(['flag'])]` on the method |
| Test verifies deprecated/old behavior (entire class) | `#[DisabledFeatures(['flag'])]` on the class |
| Test verifies new behavior only available after flag | No guard — write the test plainly; the flag is already active |
| Paired old/new behavior in same class | `#[DisabledFeatures]` on the old-behavior method(s); no guard on the new-behavior method(s) |
| Source uses `Feature::silent()` for an incidental deprecated call | `Feature::silent('flag', fn () => ...)` wrapping the same call in the test |
| Source uses `Feature::callSilentIfInactive()` for a deprecated call | `Feature::callSilentIfInactive('flag', fn () => ...)` wrapping the same call in the test |

### Detection Algorithm

1. Read the source class referenced by `#[CoversClass]`. Scan for:
   - `@deprecated` PHPDoc tags on the class, methods, or properties
   - `Feature::triggerDeprecationOrThrow()` calls — extract flag names (e.g., `'v6.8.0.0'`)
   - `Feature::silent()` or `Feature::callSilentIfInactive()` calls — extract flag names
2. If source has no deprecation markers → rule does not apply, skip.
3. For each test method in the test class, classify every deprecation-related construct:

   **Missing guard** — test instantiates or calls deprecated API, but no `#[DisabledFeatures(['flag'])]` attribute exists on either the method or the declaring class, and no matching `Feature::silent()`/`callSilentIfInactive()` wrap is present. Violation: add `#[DisabledFeatures(['flag'])]` on the method (or class).

   **Silently-skipped unit test** — `Feature::skipTestIfActive('flag', $this)` is present without `#[DisabledFeatures(['flag'])]` on the same method or declaring class. The call always fires in unit tests and marks the test skipped before the body runs. Violation: delete the `skipTestIfActive` line and add `#[DisabledFeatures(['flag'])]` on the method (or class).

   **Dead deprecation guard** — `Feature::skipTestIfInActive('flag', $this)` is present in a unit test method. The flag is always active, so the guard never fires; it is dead code. Violation: delete the guard line. No other change is required — the test already exercises the post-flag code path.

   **Redundant guard** — `Feature::skipTestIfActive('flag', $this)` is present **and** `#[DisabledFeatures(['flag'])]` is present on the same method or declaring class. The flag is already inactive, so the guard never fires. Violation: delete the `skipTestIfActive` line.

4. For tests with a valid `#[DisabledFeatures]` guard, verify direction matches test intent:
   - Test asserts new/post-flag behavior but is wrapped in `#[DisabledFeatures]` → **violation (wrong direction)**. Fix: remove the attribute.
   - Test asserts old/deprecated behavior but has no `#[DisabledFeatures]` → handled by "Missing guard" above.
5. For tests using `Feature::silent()` or `Feature::callSilentIfInactive()`:
   - If source does NOT use the same wrapper for the same call → **violation (wrong guard type)** — these wrappers are only correct when mirroring the source pattern.

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

### Fix — Missing Guard

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

### Detection — Silently-Skipped Unit Test

```php
// INCORRECT - skipTestIfActive without #[DisabledFeatures] always fires in unit tests.
// The test body never runs; the green bar hides zero coverage.
public function testProductStatesChangedEvent(): void
{
    Feature::skipTestIfActive('v6.8.0.0', $this);

    $event = new ProductStatesChangedEvent($updatedStates, $context);
    static::assertSame($updatedStates, $event->getUpdatedStates());
}
```

### Fix — Silently-Skipped Unit Test

```php
// CORRECT - replace the skipTestIfActive call with #[DisabledFeatures]
#[DisabledFeatures(['v6.8.0.0'])]
public function testProductStatesChangedEvent(): void
{
    $event = new ProductStatesChangedEvent($updatedStates, $context);
    static::assertSame($updatedStates, $event->getUpdatedStates());
}
```

### Detection — Dead Deprecation Guard

```php
// INCORRECT - skipTestIfInActive is dead code in unit tests.
// The flag is always active, so the guard never fires. Delete the line.
public function testReturnsNullAfterDeprecationRemoval(): void
{
    Feature::skipTestIfInActive('v6.8.0.0', $this);

    $accessor = new ThemeConfigValueAccessor(...);
    static::assertNull($accessor->get('breakpoint'));
}
```

### Fix — Dead Deprecation Guard

```php
// CORRECT - unguarded, exercises the post-flag code path directly
public function testReturnsNullAfterDeprecationRemoval(): void
{
    $accessor = new ThemeConfigValueAccessor(...);
    static::assertNull($accessor->get('breakpoint'));
}
```

### Paired Old/New Behavior

When a class needs tests for both the deprecated and replacement behavior, gate only the old-behavior test with `#[DisabledFeatures]`. The new-behavior test runs unguarded because the flag is already active.

```php
// OLD behavior — flag inactivated via attribute
#[DisabledFeatures(['v6.8.0.0'])]
public function testGetWithoutThemeId(): void
{
    $result = $this->accessor->get('breakpoint');
    static::assertSame('lg', $result);
}

// NEW behavior — no guard, flag is already active in unit tests
public function testGetWithoutThemeIdPostV68(): void
{
    $result = $this->accessor->get('breakpoint');
    static::assertNull($result);
}
```

### Class-Level Guard (Entire Class Deprecated)

When the source class itself is deprecated and all tests verify legacy behavior, apply `#[DisabledFeatures]` at class level. Do NOT use `Feature::skipTestIfActive()` in `setUp()` as an alternative — it would silently skip every test in the class.

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

### Multiple Flags

When deprecated code is gated behind multiple flags, list all of them in a single `#[DisabledFeatures]` attribute:

```php
#[DisabledFeatures(['FLOW_EXECUTION_AFTER_BUSINESS_PROCESS', 'v6.8.0.0'])]
public function testNestedTransactionExceptions(): void
{
    // ...
}
```

### Feature::silent (Incidental Deprecated Call)

When the source code wraps a deprecated call in `Feature::silent()`, the test mirrors that pattern. Unlike `#[DisabledFeatures]` (which disables the flag for the whole test), `Feature::silent()` suppresses the deprecation for a specific closure only — the flag stays active, and the rest of the test runs normally.

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

// INCORRECT - using #[DisabledFeatures] disables the entire test's flag state,
// but the source code runs this path regardless of flag state via Feature::silent
#[DisabledFeatures(['v6.8.0.0'])]
public function testFinalizeTransactionRedirectsToFinishUrl(): void
{
    $fakeTokenStruct = new TokenStruct();
    // ...
}
```

### Integration Test Scope

This rule applies to unit tests (`tests/unit/**`) only. Integration tests respect `feature.yaml` defaults and do not get the blanket force-enable treatment, so `Feature::skipTestIfActive()` and `Feature::skipTestIfInActive()` behave as their names suggest there. Do not carry assumptions across suites.

### Do NOT Flag

- Source class has no `@deprecated` tags, no `Feature::triggerDeprecationOrThrow()` calls, and no `Feature::silent()`/`Feature::callSilentIfInactive()` calls
- Test already has `#[DisabledFeatures]` matching its intent
- Test uses `Feature::silent()`/`Feature::callSilentIfInactive()` mirroring the source pattern
- Test is in the Feature framework itself (`FeatureTest`, `FeatureFlagCallTokenParserTest`) and directly tests `triggerDeprecationOrThrow` behavior
