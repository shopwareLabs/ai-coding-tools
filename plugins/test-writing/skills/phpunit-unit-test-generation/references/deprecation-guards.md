# Deprecation Guards

When the source class contains `@deprecated` tags, `Feature::triggerDeprecationOrThrow()`, `Feature::silent()`, or `Feature::callSilentIfInactive()`, tests must use the correct guard. The `FeatureFlagExtension` activates all flags in CI — unguarded deprecated calls throw `FeatureException`.

## Test Verifies Deprecated Behavior

Use `#[DisabledFeatures]` or `Feature::skipTestIfActive()` — the test only runs when the flag is inactive:

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

Use `Feature::skipTestIfInActive()` — the test only runs when the flag is active:

```php
public function testReturnsNullAfterRemoval(): void
{
    Feature::skipTestIfInActive('v6.8.0.0', $this);

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
