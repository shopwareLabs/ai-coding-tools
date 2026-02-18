# Shopware Test Stubs

Preferred stubs for Shopware unit tests. Use these instead of mocks for better test reliability.

## StaticEntityRepository

Use for repository operations instead of mocking `EntityRepository`.

```php
use Shopware\Core\Test\Stub\DataAbstractionLayer\StaticEntityRepository;

// Queue responses for sequential search() calls
$repo = new StaticEntityRepository([
    new ProductCollection([$entity]),  // First search()
    new ProductCollection([]),         // Second search()
]);

// With callable for criteria validation
/** @var StaticEntityRepository<ProductCollection> $repo */
$repo = new StaticEntityRepository([
    static function (Criteria $criteria, Context $context): ProductCollection {
        static::assertCount(1, $criteria->getFilters());
        return new ProductCollection([]);
    }
]);

// Track write operations
static::assertCount(1, $repo->creates);
static::assertCount(1, $repo->updates);
static::assertCount(1, $repo->deletes);
```

### Multi-Response Queue Pattern

For services making multiple repository calls:

```php
$repo = new StaticEntityRepository([
    new ProductCollection([$product1]),  // First search
    new ProductCollection([]),           // Second search
    new ProductCollection([$product2]),  // Third search
]);
```

### Criteria Validation

Use callable to validate Criteria construction:

```php
$repo = new StaticEntityRepository([
    static function (Criteria $criteria, Context $context): ProductCollection {
        // Validate filters
        static::assertCount(1, $criteria->getFilters());

        $filter = $criteria->getFilters()[0];
        static::assertInstanceOf(EqualsFilter::class, $filter);
        static::assertSame('active', $filter->getField());
        static::assertTrue($filter->getValue());

        // Validate associations
        static::assertTrue($criteria->hasAssociation('manufacturer'));

        return new ProductCollection([]);
    }
]);
```

## StaticSystemConfigService

Use for system configuration instead of mocking `SystemConfigService`.

```php
use Shopware\Core\Test\Stub\SystemConfigService\StaticSystemConfigService;

$config = new StaticSystemConfigService([
    'core.listing.productsPerPage' => 24,
    'core.cart.maxQuantity' => 100,
    'MyPlugin.config.enabled' => true,
]);
```

### With Sales Channel Scope

```php
$config = new StaticSystemConfigService([
    'core.listing.productsPerPage' => [
        '' => 24,                    // Default
        'salesChannelId123' => 48,   // Specific channel
    ],
]);
```

## Generator

Use for creating test contexts and entities.

```php
use Shopware\Core\Test\Generator;

// Preferred method for SalesChannelContext
$context = Generator::generateSalesChannelContext();

// With custom components
$context = Generator::generateSalesChannelContext(
    salesChannel: $salesChannel,
    currency: $currency,
    customer: $customer,
);

// For Context (non-sales-channel)
$context = Context::createDefaultContext();
```

**Note:** Prefer `Generator::generateSalesChannelContext()` over the legacy `Generator::createSalesChannelContext()`.

## When to Use Stubs vs Mocks

| Scenario | Use |
|----------|-----|
| Repository operations | `StaticEntityRepository` |
| System configuration | `StaticSystemConfigService` |
| Sales channel context | `Generator::generateSalesChannelContext()` |
| HTTP client | PHPUnit mock |
| Filesystem operations | PHPUnit mock |
| External API calls | PHPUnit mock |
| Simple value objects | Real implementation |
| Entities | Real implementation |
