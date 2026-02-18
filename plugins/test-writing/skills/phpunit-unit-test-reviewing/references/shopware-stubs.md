# Shopware Test Stubs

## StaticEntityRepository

Use instead of mocking `EntityRepository`:

```php
use Shopware\Core\Test\Stub\DataAbstractionLayer\StaticEntityRepository;

$repo = new StaticEntityRepository([
    // First search() call returns this
    new ProductCollection([
        (new ProductEntity())->assign(['id' => 'abc', 'name' => 'Product'])
    ]),
    // Second search() call returns this
    new ProductCollection([]),
]);

$result = $repo->search(new Criteria(), $context);
```

### Callback-Based Dynamic Responses

Use callables for criteria validation and dynamic results:

```php
/** @var StaticEntityRepository<ProductCollection> $repo */
$repo = new StaticEntityRepository([
    function (Criteria $criteria, Context $context) {
        // Assert criteria was built correctly
        static::assertCount(1, $criteria->getFilters());
        static::assertInstanceOf(EqualsFilter::class, $criteria->getFilters()[0]);

        return new ProductCollection([$entity]);
    }
], new ProductDefinition());
```

### Advanced Callable Pattern: Inline Assertions

```php
$repo = new StaticEntityRepository([
    static function (Criteria $criteria, Context $context) use ($salesChannelEntity) {
        // Validate filter count
        static::assertCount(1, $criteria->getFilters());

        // Validate specific filter type and value
        static::assertEquals([
            new NotEqualsFilter('typeId', Defaults::SALES_CHANNEL_TYPE_PRODUCT_COMPARISON),
        ], $criteria->getFilters());

        // Validate criteria IDs
        static::assertContains('red', $criteria->getIds());
        static::assertContains('green', $criteria->getIds());

        return new EntitySearchResult(
            SalesChannelDefinition::ENTITY_NAME,
            1,
            new SalesChannelCollection([$salesChannelEntity]),
            null,
            $criteria,
            $context
        );
    }
], new SalesChannelDefinition());
```

### Multi-Response Queue Pattern

```php
$repo = new StaticEntityRepository([
    // First search() call returns tax entity
    new EntitySearchResult(TaxEntity::class, 1, new TaxCollection([$taxEntity]), null, new Criteria(), Context::createDefaultContext()),

    // Second searchIds() call returns ID array
    [$mediaId1, $mediaId2, $mediaId3],

    // Third search() call returns download IDs
    [$downloadId1, $downloadId2, $downloadId3],
]);

// Each repository call consumes the next queued response in order
```

### Empty-Then-Populated Pattern

For testing state transitions:

```php
$recoveryRepo = new StaticEntityRepository([
    new UserRecoveryCollection([]),           // First call: empty (not found)
    new UserRecoveryCollection([$recovery])   // Second call: populated (created)
], new UserRecoveryDefinition());
```

### Write Operation Tracking

Track repository mutations via public arrays:

```php
$repo = new StaticEntityRepository([new ProductCollection()]);

// Execute test
$service->createProduct($data);

// Verify write operations
static::assertCount(1, $repo->creates);
static::assertEquals(['id' => $expectedId, 'name' => 'Test'], $repo->creates[0]);

// Available: $repo->creates, $repo->updates, $repo->upserts, $repo->deletes
```

### Generic Type Annotations

Use PHPStan generics for type safety:

```php
/** @var StaticEntityRepository<ProductCollection> $productRepo */
$productRepo = new StaticEntityRepository([...]);

/** @var StaticEntityRepository<CustomerCollection> $customerRepo */
$customerRepo = new StaticEntityRepository([...], new CustomerDefinition());
```

## StaticSalesChannelRepository

Use for sales channel context tests (takes `SalesChannelContext` instead of `Context`):

```php
use Shopware\Core\Test\Stub\DataAbstractionLayer\StaticSalesChannelRepository;

$repo = new StaticSalesChannelRepository([
    new ProductCollection([...])
]);

// Usage with SalesChannelContext
$result = $repo->search($criteria, $salesChannelContext);
```

**Limitation**: `aggregate()` throws exception (not implemented in stub).

## Generator (Test Data Factory)

Use for creating valid test entities with all required fields populated:

```php
use Shopware\Core\Test\Generator;

// Preferred: generateSalesChannelContext() (added in 6.6.10.0)
$context = Generator::generateSalesChannelContext(
    baseContext: $context,
    salesChannel: $salesChannel,
    currency: $currency,
    areaRuleIds: [RuleAreas::PRODUCT_AREA => $ruleIds],
    languageInfo: Generator::createLanguageInfo(Defaults::LANGUAGE_SYSTEM, 'Test')
);

// Legacy: createSalesChannelContext() - limited component support
$context = Generator::createSalesChannelContext();

// Create customer entity with valid data
$customer = Generator::createCustomer();
```

### generateSalesChannelContext vs createSalesChannelContext

| Method | Components Supported | Use Case |
|--------|---------------------|----------|
| `generateSalesChannelContext()` | All (including ShippingLocation) | New tests, complex scenarios |
| `createSalesChannelContext()` | Limited | Legacy tests, simple scenarios |

**Prefer `generateSalesChannelContext()`** for new unit tests.

## StaticSystemConfigService

Use instead of mocking SystemConfigService:

```php
use Shopware\Core\Test\Stub\SystemConfigService\StaticSystemConfigService;

$config = new StaticSystemConfigService([
    'core.listing.productsPerPage' => 24,
    'core.cart.maxQuantity' => 100,
]);
```

## Available Stubs Summary

| Stub | Use Case |
|------|----------|
| `StaticEntityRepository` | DAL repository with `Context` |
| `StaticSalesChannelRepository` | DAL repository with `SalesChannelContext` |
| `StaticSystemConfigService` | System configuration values |
| `Generator` | Test entity creation |
