# Mocking Strategy

## Core Principle: Behavior-Focused Testing

| Aspect | DO Test | DON'T Test |
|--------|---------|------------|
| Focus | Return values, exceptions, state changes | Internal method calls, private properties |
| Level | Public API behavior | Implementation algorithms |
| Coupling | Business outcomes | Framework internals |
| Granularity | Observable effects | Cache keys, log formats |

## Stub-First Mocking Philosophy

Three-tier dependency substitution hierarchy:

| Priority | Strategy | When to Use |
|----------|----------|-------------|
| 1 | Real Implementation | Easy to create, no side effects |
| 2 | Hand-crafted Stub | `StaticEntityRepository`, `StaticSystemConfigService` |
| 3 | PHPUnit Mock | Only when real/stub not available |

## Mocking Decision Matrix

| Scenario | Use Real | Use Stub | Use Mock |
|----------|----------|----------|----------|
| Simple value objects | ✓ | - | - |
| Entity repositories | - | ✓ (StaticEntityRepository) | - |
| System config | - | ✓ (StaticSystemConfigService) | - |
| External HTTP calls | - | - | ✓ |
| File system operations | - | - | ✓ |
| Database writes | - | ✓ | - |
| Event dispatcher | ✓ | ✓ | - |

### Valid Mock Patterns

```php
// HTTP client - external dependency
$client = $this->createMock(HttpClientInterface::class);
$client->method('request')->willReturn(new Response(200, [], '{}'));

// File system - side effects
$filesystem = $this->createMock(FilesystemInterface::class);
$filesystem->expects(static::once())
    ->method('write')
    ->with('path/file.txt', 'content');
```

### Invalid Mock Patterns (E012)

```php
// WRONG - should use StaticEntityRepository
$repo = $this->createMock(EntityRepository::class);
$repo->method('search')->willReturn(...);

// WRONG - should use real implementation
$collection = $this->createMock(ProductCollection::class);
$collection->method('count')->willReturn(5);
```

## Intersection Type Mocks (PHP 8.1+)

For type-safe mock declarations:

```php
private CartService&MockObject $cartService;
private EventDispatcherInterface&MockObject $eventDispatcher;
private AbstractProductListRoute&MockObject $productListRoute;

protected function setUp(): void
{
    $this->cartService = $this->createMock(CartService::class);
    $this->eventDispatcher = $this->createMock(EventDispatcherInterface::class);
}
```

**Benefits**:
- Full type safety for both original class and MockObject methods
- No casting required when using mock methods
- IDE autocompletion for both interfaces
