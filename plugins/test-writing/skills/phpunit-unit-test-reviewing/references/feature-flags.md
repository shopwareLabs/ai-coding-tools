# Feature Flag Testing

## Major Feature Flags Default Active

Unit tests in `Shopware\Tests\Unit` namespace run with **all major feature flags activated by default**. This ensures tests validate forward-compatible behavior.

```php
// In unit tests, major flags are automatically active
// Tests run against NEW behavior by default
public function testNewBehavior(): void
{
    // This tests the upcoming major version behavior
    $result = $this->service->process($data);
    static::assertSame('new-format', $result);
}
```

## Testing Legacy Behavior

For tests that verify deprecated/legacy behavior, use `#[DisabledFeatures]`:

```php
use Shopware\Core\Test\Annotation\DisabledFeatures;

#[DisabledFeatures(['v6.8.0.0'])]
public function testLegacyBehavior(): void
{
    // This tests the old behavior with feature flag disabled
    $result = $this->service->process($data);
    static::assertSame('old-format', $result);
}
```

## Feature Flag Skip Patterns

For conditional test execution based on feature flags:

```php
use Shopware\Core\Framework\Feature;

// Skip test if new behavior is active
protected function setUp(): void
{
    Feature::skipTestIfActive('v6.8.0.0', $this);
    // ... rest of setup
}

// Skip test if new behavior is NOT active
protected function setUp(): void
{
    Feature::skipTestIfInActive('FEATURE_NEXT_12345', $this);
    // ... rest of setup
}
```

## When to Use Each Pattern

| Scenario | Pattern |
|----------|---------|
| Testing new/current behavior | Default (no annotation) |
| Testing deprecated behavior | `#[DisabledFeatures(['v6.X.0.0'])]` |
| Test only runs for old behavior | `Feature::skipTestIfActive()` |
| Test only runs for new behavior | `Feature::skipTestIfInActive()` |

## Feature Flag Extension for Plugins

Plugins can enable major feature flags in their unit test namespaces:

```php
// In plugin's phpunit bootstrap file
FeatureFlagExtension::addNamespace('MyPlugin\\Tests\\Unit');
```

**Default Allowlist**: `Shopware\Tests\Unit` namespace automatically gets major feature flags enabled.

**Use Case**: Testing behavior that depends on upcoming major features while keeping integration tests on current behavior.

## Test Behavior Traits

**Note**: Unit tests should NOT use integration test traits (`IntegrationTestBehaviour`, `SalesChannelFunctionalTestBehaviour`, etc.). These are for integration tests only. Unit tests rely on `StaticEntityRepository` and other stubs instead.
