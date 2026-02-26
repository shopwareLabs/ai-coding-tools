---
id: UNIT-007
title: DisabledFeatures for Legacy Tests
group: unit
enforce: consider
test-types: unit
test-categories: A,B,C,D,E
scope: shopware
---

## DisabledFeatures for Legacy Tests

**Scope**: A,B,C,D,E | **Enforce**: Consider

Unit tests in `Shopware\Tests\Unit` namespace run with **all major feature flags activated by default**. Tests for legacy behavior must explicitly disable flags.

### When to Suggest

Test appears to verify behavior that only applies to older versions, or contains comments about deprecation.

### Feature Flag Patterns

| Scenario | Pattern |
|----------|---------|
| Testing new/current behavior | Default (no annotation) |
| Testing deprecated behavior | `#[DisabledFeatures(['v6.X.0.0'])]` |
| Test only runs for old behavior | `Feature::skipTestIfActive()` |
| Test only runs for new behavior | `Feature::skipTestIfInActive()` |

### Example

```php
use Shopware\Core\Test\Annotation\DisabledFeatures;

// Test for legacy behavior (flag disabled)
#[DisabledFeatures(['v6.8.0.0'])]
public function testLegacyBehavior(): void
{
    $result = $this->service->process($data);
    static::assertSame('old-format', $result);
}
```

### Feature Flag Skip Patterns

```php
use Shopware\Core\Framework\Feature;

// Skip test if new behavior is active
protected function setUp(): void
{
    Feature::skipTestIfActive('v6.8.0.0', $this);
}

// Skip test if new behavior is NOT active
protected function setUp(): void
{
    Feature::skipTestIfInActive('FEATURE_NEXT_12345', $this);
}
```

### Feature Flag Extension for Plugins

Plugins can enable major feature flags in their unit test namespaces:

```php
// In plugin's phpunit bootstrap file
FeatureFlagExtension::addNamespace('MyPlugin\\Tests\\Unit');
```

**Default Allowlist**: `Shopware\Tests\Unit` namespace automatically gets major feature flags enabled.

**Note**: Unit tests should NOT use integration test traits (`IntegrationTestBehaviour`, `SalesChannelFunctionalTestBehaviour`, etc.). These are for integration tests only.
