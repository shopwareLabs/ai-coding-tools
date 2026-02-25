---
id: UNIT-006
title: Legacy Generator Method
legacy: W006
group: unit
enforce: should-fix
test-types: unit
test-categories: B,C,D
scope: shopware
---

## Legacy Generator Method

**Scope**: B,C,D | **Enforce**: Should fix

Use `Generator::generateSalesChannelContext()` instead of the legacy `createSalesChannelContext()`.

### Detection

```php
// INCORRECT - legacy method
use Shopware\Core\Test\Generator;

$context = Generator::createSalesChannelContext();
```

### Fix

```php
// CORRECT - new method with full component support
use Shopware\Core\Test\Generator;

$context = Generator::generateSalesChannelContext(
    baseContext: $context,
    salesChannel: $salesChannel,
    currency: $currency,
    areaRuleIds: [RuleAreas::PRODUCT_AREA => $ruleIds],
    languageInfo: Generator::createLanguageInfo(Defaults::LANGUAGE_SYSTEM, 'Test')
);

// Or minimal usage with defaults
$context = Generator::generateSalesChannelContext();
```

### Why

| Method | Components Supported | Use Case |
|--------|---------------------|----------|
| `generateSalesChannelContext()` | All (including ShippingLocation) | New tests, complex scenarios |
| `createSalesChannelContext()` | Limited | Legacy tests, simple scenarios |

Prefer `generateSalesChannelContext()` for new unit tests.
