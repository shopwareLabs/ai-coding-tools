---
id: UNIT-003
title: Over-Mocking / Prefer Shopware Stubs
group: unit
enforce: must-fix
test-types: unit
test-categories: B,C,D
scope: shopware
---

## Over-Mocking / Prefer Shopware Stubs

**Scope**: B,C,D | **Enforce**: Must fix

### Stub-First Mocking Philosophy

Three-tier dependency substitution hierarchy:

| Priority | Strategy | When to Use |
|----------|----------|-------------|
| 1 | Real Implementation | Easy to create, no side effects |
| 2 | Hand-crafted Stub | `StaticEntityRepository`, `StaticSystemConfigService` |
| 3 | PHPUnit Mock | Only when real/stub not available |

### createStub() vs createMock()

| Method | Type | Use When |
|--------|------|----------|
| `createStub(Foo::class)` | `Foo&Stub` | Only need return values; no call-count or argument verification |
| `createMock(Foo::class)` | `Foo&MockObject` | Need to verify interactions with `expects()`, or verify arguments with `->with(static::callback(...))` |

- `createStub()` communicates "I only care about what this returns, not how it's called"
- `createMock()` communicates "I will verify the interaction via `expects()` or argument callbacks"
- `->with(static::callback(...))` requires `expects()` to be present — without it, PHPUnit silently ignores the `->with()` constraint and the callback never fires. Use `expects($this->atLeastOnce())` to guarantee the callback fires while removing exact-count coupling

### Mocking Decision Matrix

| Scenario | Use Real | Use Stub | Use Mock |
|----------|----------|----------|----------|
| Simple value objects | Yes | - | - |
| Entity repositories | - | Yes (StaticEntityRepository) | - |
| System config | - | Yes (StaticSystemConfigService) | - |
| External HTTP calls | - | - | Yes |
| File system operations | - | - | Yes |
| Database writes | - | Yes | - |
| Event dispatcher | Yes | Yes | - |

### Behavior-Focused Testing

| Aspect | DO Test | DON'T Test |
|--------|---------|------------|
| Focus | Return values, exceptions, state changes | Internal method calls, private properties |
| Level | Public API behavior | Implementation algorithms |
| Coupling | Business outcomes | Framework internals |
| Granularity | Observable effects | Cache keys, log formats |

---

Tests MUST prefer real implementations and Shopware stubs over PHPUnit mocks. Using mocks instead of stubs couples tests to implementation details, making them brittle and harder to maintain.

### Why

- PHPUnit mocks couple tests to implementation: test depends on exactly which methods are called and in what order
- Shopware stubs are deterministic: `StaticEntityRepository` and `StaticSystemConfigService` provide predictable, implementation-agnostic behavior
- Mocks fail silently on refactoring: renaming a method breaks mock-based tests even when behavior is unchanged
- Stubs encourage behavior testing: forces thinking about what data goes in and comes out

### Detection

```php
// INCORRECT - excessive mocking
public function testProductService(): void
{
    $repo = $this->createMock(EntityRepository::class);
    $repo->method('search')->willReturn(new EntitySearchResult(...));

    $config = $this->createMock(SystemConfigService::class);
    $config->method('get')->willReturn('value');
}
```

### Fix

```php
use Shopware\Core\Test\Stub\DataAbstractionLayer\StaticEntityRepository;
use Shopware\Core\Test\Stub\SystemConfigService\StaticSystemConfigService;

public function testProductService(): void
{
    $repo = new StaticEntityRepository([
        new ProductCollection([new ProductEntity()])
    ]);

    $config = new StaticSystemConfigService([
        'core.setting' => 'value'
    ]);
}
```

### When Mocking Is Acceptable

1. Object creation requires many nested dependencies irrelevant to the test
2. Class produces side effects (external API calls, file writes)
3. Testing error paths that real implementation won't trigger
4. Third-party interfaces without Shopware stubs

### Callback Pattern for Criteria Validation

```php
/** @var StaticEntityRepository<PaymentMethodCollection> $repo */
$repo = new StaticEntityRepository([
    function (Criteria $criteria, Context $context) use ($baseContext) {
        static::assertCount(2, $criteria->getFilters());
        static::assertEquals([
            new EqualsFilter('active', 1),
            new EqualsFilter('salesChannels.id', $baseContext->getSalesChannelId()),
        ], $criteria->getFilters());

        return new PaymentMethodCollection();
    },
], new PaymentMethodDefinition());
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

### StaticSalesChannelRepository

Use for sales channel context tests (takes `SalesChannelContext` instead of `Context`):

```php
use Shopware\Core\Test\Stub\DataAbstractionLayer\StaticSalesChannelRepository;

$repo = new StaticSalesChannelRepository([
    new ProductCollection([...])
]);

$result = $repo->search($criteria, $salesChannelContext);
```

**Limitation**: `aggregate()` throws exception (not implemented in stub).

### StaticSystemConfigService

```php
use Shopware\Core\Test\Stub\SystemConfigService\StaticSystemConfigService;

$config = new StaticSystemConfigService([
    'core.listing.productsPerPage' => 24,
    'core.cart.maxQuantity' => 100,
]);
```

### Available Shopware Test Stubs

| Stub | Use Case |
|------|----------|
| `StaticEntityRepository` | DAL repository with `Context` |
| `StaticSalesChannelRepository` | DAL repository with `SalesChannelContext` |
| `StaticSystemConfigService` | System configuration values |
| `Generator` | Test entity creation |
