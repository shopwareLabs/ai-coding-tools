# Mocking Strategy

## createStub() vs createMock() — The Distinction

PHPUnit provides two factory methods with different semantic intent:

| Method | Type | Use When |
|--------|------|----------|
| `createStub(Foo::class)` | `Foo&Stub` | Only need return values; no call-count verification |
| `createMock(Foo::class)` | `Foo&MockObject` | Need to verify interactions with `expects()` |

```php
use PHPUnit\Framework\MockObject\Stub;

// CORRECT - stub for return-value-only usage
private CartService&Stub $cartService;

protected function setUp(): void
{
    $this->cartService = $this->createStub(CartService::class);
    $this->cartService->method('getCart')->willReturn($this->cart);
}

// CORRECT - mock when expects() is required
private EventDispatcherInterface&MockObject $eventDispatcher;

public function testDispatchesEvent(): void
{
    $this->eventDispatcher
        ->expects($this->once())
        ->method('dispatch')
        ->with(static::isInstanceOf(ProductCreatedEvent::class));

    $this->service->create($data);
}
```

### Why This Matters

- `createStub()` communicates "I only care about what this returns, not how it's called"
- `createMock()` communicates "I will verify the interaction with `expects()`"
- Using `createMock()` without `expects()` is W012 — it signals wrong intent and adds overhead
- Using `createStub()` when you need `expects()` will throw an error — the type enforces the distinction

## Call-Count Over-Coupling Anti-Patterns

### Anti-Pattern: expects(once()) When Result Is Already Asserted

```php
// INCORRECT - E019: call count is proven by the outcome assertion
public function testLoadsProduct(): void
{
    $this->repository
        ->expects($this->once())          // Redundant
        ->method('search')
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');

    static::assertSame($this->product, $result);  // This already proves search() ran
}

// CORRECT - outcome assertion is sufficient
public function testLoadsProduct(): void
{
    $this->repository
        ->method('search')
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');

    static::assertSame($this->product, $result);
}
```

### When expects(once()) IS Legitimate

Use `expects(once())` only for **side-effect-only methods** where the call itself is the observable behavior:

```php
// CORRECT - no return value to assert; dispatch() side effect IS the behavior
$this->eventDispatcher
    ->expects($this->once())
    ->method('dispatch')
    ->with(static::isInstanceOf(OrderPlacedEvent::class));

// CORRECT - verifying a call does NOT happen
$this->emailService
    ->expects($this->never())
    ->method('send');

// CORRECT - file write has no return value in this test
$this->filesystem
    ->expects($this->once())
    ->method('write')
    ->with('output/report.csv', static::isString());
```

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
$filesystem->expects($this->once())
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
