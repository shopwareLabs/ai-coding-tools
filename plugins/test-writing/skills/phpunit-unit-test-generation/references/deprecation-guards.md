# Deprecation Guards

When the source class contains `@deprecated` tags, `Feature::triggerDeprecationOrThrow()`, `Feature::silent()`, or `Feature::callSilentIfInactive()`, tests must use the correct mechanism. The `FeatureFlagExtension` force-activates all registered flags before every unit test — unguarded deprecated calls throw `FeatureException`.

In unit tests, the **only** mechanism that actually deactivates a flag is the `#[DisabledFeatures]` attribute. `Feature::skipTestIfActive()` silently skips the test body (flag is always active → always fires), and `Feature::skipTestIfInActive()` is dead code (flag is always active → never fires). See UNIT-007 for full rules and detection algorithm.

## Test Verifies Deprecated Behavior

Apply `#[DisabledFeatures]` to the method:

```php
use Shopware\Core\Test\Annotation\DisabledFeatures;

#[DisabledFeatures(['v6.8.0.0'])]
public function testLegacyEventReturnsStates(): void
{
    $event = new ProductStatesChangedEvent($states, $context);
    static::assertSame($states, $event->getUpdatedStates());
}
```

## Test Verifies New Behavior

Write the test plainly. The flag is already active in unit tests — no guard needed:

```php
public function testReturnsNullAfterRemoval(): void
{
    $result = $this->accessor->get('breakpoint');
    static::assertNull($result);
}
```

## Source Uses Feature::silent (Incidental Deprecated Call)

When the source wraps a deprecated call in `Feature::silent()`, mirror that in the test. The flag stays active — only the specific closure is silenced:

```php
// Source: $token = Feature::silent('v6.8.0.0', fn () => new TokenStruct());
Feature::silent('v6.8.0.0', static function () use (&$fakeTokenStruct): void {
    $fakeTokenStruct = new TokenStruct();
});

$this->processor->method('finalize')->willReturn($fakeTokenStruct);
$response = $this->controller->finalizeTransaction($request);
static::assertInstanceOf(RedirectResponse::class, $response);
```

## Entire Class Deprecated

Apply `#[DisabledFeatures]` at class level:

```php
/**
 * @deprecated tag:v6.8.0 - Can be removed as the tested class will be removed
 */
#[CoversClass(LegacyEvent::class)]
#[DisabledFeatures(['v6.8.0.0'])]
class LegacyEventTest extends TestCase
{
    // All methods run with flag disabled — no per-method guards needed
}
```
