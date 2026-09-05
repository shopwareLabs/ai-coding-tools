---
id: UNIT-001
title: Behavior Not Implementation, Trivial, or Private
group: unit
enforce: must-fix
test-types: unit
test-categories: A,B,C,D,E
scope: general
review-unit: method
scoped-review: include
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

The members below are not tested **unless** `### When Constructor/Accessor Tests ARE Valid` applies to the member under review. Check that section before flagging one of them.

- Logic-free constructors (only parameter-to-property assignment, including parameter/property defaults like `= ''`/`= 0`/`= []`; a constructor whose body computes a default, normalizes input, or enforces an invariant is NOT logic-free — test that)
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
- A default the constructor computes or enforces in its body (`$x ?? new DateTime()`, a clamp, a normalization, an invariant it checks) is testable behavior — but the discriminator is logic in the constructor body, not the presence of a default: a bare parameter or property default (`= ''` / `= 0` / `= []`) with no body logic is a trivial accessor (flag under UNIT-001), not a carve-out
- A method whose body is a single assignment or a plain return is testable behavior when it is a documented extension point on a public, soft-final class, because its contract is the API surface

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

### Name the Enforcing Mechanism

A finding that calls an assertion trivial states which mechanism enforces the property being asserted, so the claim is checkable before any assertion is removed. A compound property can be half-enforced — flagging the whole assertion trivial when only one half has a mechanism behind it removes real coverage. Name the specific mechanism, from this vocabulary where it applies:

- **Return types** — a method with a single non-nullable return type already guarantees what an `assertInstanceOf`/`assertIsArray`/etc. against that exact type would re-check (see "When Type Assertions ARE Valid" above for the narrowing exception). This is the exact declared type only: a return type that is a base class or an interface does not guarantee a narrower concrete type (an `EntityDefinition`-typed return does not guarantee `ProductDefinition`), so an assertion narrowing to a specific subtype is not covered by this mechanism
- **PHPStan level** — a null-safety or type-coercion property the configured PHPStan level already rejects at compile time
- **Constructor contract** — a property-assignment constructor with no validation logic, whose invariant is the parameter's own type
- **`NoCreateMockWithoutExpectationsRule`** — guarantees a `createMock()` double is never left without an `->expects()`; an assertion re-checking "was this mock called" duplicates what the PHPStan rule already guarantees in Shopware's unit/DevOps test namespaces
- **`CodeCoverageIgnoreEvaluationRule`** — guarantees a method annotated `@codeCoverageIgnore` is truly pass-through (no branching, mutation, or side-effecting calls) *when no `@see` to a dedicated integration/DevOps test lifts the check*; a `@see` present on the annotation means the rule no longer enforces pass-through-only, so this mechanism does not apply and an assertion proving the method's actual behavior is not redundant
- **`TestPackageMatchRule`** — guarantees a test's `#[Package]` attribute matches its covered class's package; an assertion re-checking that pairing duplicates the PHPStan rule
- **`shopware.reflectionOnNonPublicMethod`** — guarantees reflective access to a non-public method of a Shopware class is rejected; an assertion whose only purpose is proving such access is unreachable duplicates that rule

A finding naming one of these mechanisms for only part of a compound assertion states which part remains unenforced, rather than treating the whole assertion as covered.

### Deletion Safety

- A finding that deletes a test names, per removed assertion, the surviving test that covers it, or states that nothing does.
- A deletion never brings a test class to zero test methods. PHPUnit reports `No tests found in class` and exits non-OK.
- An assertion that reads the input object after the call verifies a different contract — non-mutation — than one that reads the return value, even where both follow the same call with the same setup. Which object an assertion reads is established before the two are treated as duplicates.
