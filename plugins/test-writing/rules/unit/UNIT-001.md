---
id: UNIT-001
title: Behavior Not Implementation, Trivial, or Private
group: unit
enforce: must-fix
test-types: unit
test-categories: A,B,C,D,E
scope: general
---

## Behavior Not Implementation, Trivial, or Private

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Tests MUST verify behavior, not implementation details, trivial code without meaningful logic, or private members via reflection.

### What to Test

- Return values
- Exceptions thrown
- Public API state changes
- Side effects (events dispatched, data persisted)
- Computed/derived values
- Validation logic

### What NOT to Test

- Internal method calls
- Private properties
- Private methods via reflection
- Algorithms/logic order
- Framework internals
- Cache keys
- Logic-free constructors (only parameter to property assignment)
- Trivial getters (return property value)
- Trivial setters (assign parameter to property)
- Trivial issers (return boolean property)
- Public readonly property access
- Pure delegation (method only forwards to a dependency without transformation)

### Detection — Reflection Access

```php
// INCORRECT - using reflection to test private method
public function testPrivateMethod(): void
{
    $reflection = new \ReflectionMethod($this->service, 'privateHelper');
    $reflection->setAccessible(true);
    $result = $reflection->invoke($this->service, 'input');
    static::assertEquals('expected', $result);
}
```

If private method cannot be tested through public API, consider:
1. The private method may not need testing
2. The class may need refactoring to expose behavior

### Detection — Call-Count on Non-Side-Effect Methods

```php
// INCORRECT - call count verified but return value also asserted
public function testLoadsProduct(): void
{
    $this->repository
        ->expects($this->once())       // Redundant: result already checked below
        ->method('search')
        ->willReturn(new ProductCollection([$product]));

    $result = $this->service->loadProduct('product-id');

    static::assertSame($product, $result);  // Outcome fully verifies the behavior
}
```

### Detection — Trivial Code

```php
// INCORRECT - testing logic-free constructor
public function testConstructorSetsProperties(): void
{
    $entity = new ProductEntity('name', 100);
    static::assertEquals('name', $entity->getName());
    static::assertEquals(100, $entity->getPrice());
}

// INCORRECT - testing trivial getter/setter
public function testGettersAndSetters(): void
{
    $entity = new ProductEntity();
    $entity->setName('test');
    static::assertEquals('test', $entity->getName());
}

// INCORRECT - testing pure delegation
public function testGetProductsDelegatesToRepository(): void
{
    $this->repository->method('findAll')->willReturn($products);
    $result = $this->service->getProducts();
    static::assertSame($products, $result);
}
```

### When Type Assertions ARE Valid — PHPStan Type Narrowing

`assertIsArray`, `assertIsString`, `assertInstanceOf`, etc. are NOT trivially true when they narrow a PHPStan union type for a subsequent assertion.

```php
// CORRECT — assertIsArray narrows array|ArrayAccess to array for PHPStan
$history = [];
$handlerStack->push(Middleware::history($history));  // by-reference widens to array|ArrayAccess<int, array>
// ...
static::assertIsArray($history);    // PHPStan type narrowing — assertCount requires Countable|iterable
static::assertCount(1, $history);   // would fail PHPStan without the narrowing above
```

Before flagging `assertIs*` as trivially true, check whether the variable's type was widened (by-reference passing, mixed returns, union-typed APIs) and whether the next assertion requires the narrower type.

Conversely, `assertInstanceOf` on a method with a single non-nullable return type IS trivially true — the method cannot return anything else.

```php
// INCORRECT — getByClassOrEntityName returns EntityDefinition (single type, throws on miss)
$definition = $registry->getByClassOrEntityName('product');
static::assertInstanceOf(ProductDefinition::class, $definition);  // trivially true or test already crashed
```

### When Constructor/Accessor Tests ARE Valid

- Constructor contains validation logic (throws exceptions)
- Constructor transforms input (normalizes, calculates)
- Getter computes derived value
- Setter has side effects or validation
- Delegation transforms input or output
- Delegation includes conditional logic (e.g., early return, fallback)

### Fix — Behavior Focus

```php
// CORRECT - testing observable behavior
public function testCachesProductData(): void
{
    $product = new Product('123', 'Test');
    $this->cache->store($product);
    static::assertEquals($product, $this->cache->get('123'));
}

// CORRECT - constructor has validation logic worth testing
public function testConstructorRejectsNegativePrice(): void
{
    $this->expectException(InvalidArgumentException::class);
    new ProductEntity('name', -100);
}

// CORRECT - getter computes derived value
public function testFullNameCombinesFirstAndLastName(): void
{
    $user = new User('John', 'Doe');
    static::assertEquals('John Doe', $user->getFullName());
}
```
