# Structural Error Code Details

Detailed explanations for structural errors: E001-E019.

## Table of Contents
- [E001 - Conditional Logic](#e001---conditional-logic)
- [E002 - Multiple Behaviors](#e002---multiple-behaviors)
- [E003 - Attribute Order](#e003---attribute-order)
- [E004 - Test Method Identification](#e004---test-method-identification)
- [E005 - Testing Implementation, Trivial Code, or Private Members](#e005---testing-implementation-trivial-code-or-private-members)
- [E006 - Ambiguous Names](#e006---ambiguous-names)
- [E007 - Missing Data Provider](#e007---missing-data-provider)
- [E008 - Instance Assertions](#e008---instance-assertions)
- [E009 - Test Redundancy](#e009---test-redundancy)
- [E010 - Test Method Ordering](#e010---test-method-ordering)
- [E011 - TestDox Phrasing](#e011---testdox-phrasing)
- [E012 - Over-Mocking](#e012---over-mocking)
- [E013 - Class Structure Order](#e013---class-structure-order)
- [E014 - Exception Expectation Order](#e014---exception-expectation-order)
- [E015 - Multiple Class Coverage](#e015---multiple-class-coverage)
- [E016 - Shared Mutable State (FIRST: Independent)](#e016---shared-mutable-state-first-independent)
- [E017 - Non-Deterministic Inputs (FIRST: Repeatable)](#e017---non-deterministic-inputs-first-repeatable)
- [E018 - Weak Exception Assertion](#e018---weak-exception-assertion)
- [E019 - Call-Count Over-Coupling](#e019---call-count-over-coupling)

## E001 - Conditional Logic

Tests MUST NOT contain conditional logic. Each test requires a single execution path.

### Prohibited Patterns
- `if/else` statements
- `switch/match` expressions
- Ternary operators (`?:`) for control flow
- Conditional assertions

### Detection
```php
// INCORRECT - conditional in test
public function testValidation($value, $shouldPass): void
{
    $result = $this->validator->validate($value);
    if ($shouldPass) {
        static::assertTrue($result->isValid());
    } else {
        static::assertFalse($result->isValid());
    }
}
```

### Fix Pattern - Split Methods
```php
#[TestWithJson('["valid@email.com"]')]
#[TestWithJson('["user.name@domain.org"]')]
#[TestDox('accepts valid email: $value')]
public function testAcceptsValidEmail(string $value): void
{
    $result = $this->validator->validate($value);
    static::assertTrue($result->isValid());
}

#[TestWithJson('["invalid-email"]')]
#[TestWithJson('["@nodomain"]')]
#[TestDox('rejects invalid email: $value')]
public function testRejectsInvalidEmail(string $value): void
{
    $result = $this->validator->validate($value);
    static::assertFalse($result->isValid());
}
```

## E002 - Multiple Behaviors

Each test method MUST test exactly one behavior.

### Violation Signs
- Method name contains "And"
- Comment sections separating test parts
- Multiple unrelated assertions
- Testing create, update, and delete in one method

### Detection
```php
// INCORRECT - multiple behaviors
public function testUserManagement(): void
{
    // creation
    $user = $this->createUser();
    static::assertNotNull($user->getId());

    // update
    $user->setName('NewName');
    $this->repo->update($user);
    static::assertEquals('NewName', $user->getName());

    // deletion
    $this->repo->delete($user);
    static::assertNull($this->repo->find($user->getId()));
}
```

### Fix Pattern - Split Methods
```php
public function testCreatesUserWithValidData(): void
{
    $user = $this->createUser();
    static::assertNotNull($user->getId());
}

public function testUpdatesUserName(): void
{
    $user = $this->createUser();
    $user->setName('NewName');
    $this->repo->update($user);
    static::assertEquals('NewName', $user->getName());
}

public function testDeletesUser(): void
{
    $user = $this->createUser();
    $this->repo->delete($user);
    static::assertNull($this->repo->find($user->getId()));
}
```

## E003 - Attribute Order

Attributes MUST follow strict ordering.

### Required Order
1. PHPDoc (`/** */`) - MUST BE FIRST if present
2. DataProviders (`#[DataProvider]`, `#[TestWithJson]`)
3. TestDox (`#[TestDox]`) - ALWAYS LAST

### Detection
```php
// INCORRECT - TestDox before DataProvider
#[TestDox('validates with $input')]
#[DataProvider('inputProvider')]
public function testInput($input): void
```

### Fix Pattern
```php
// CORRECT - proper order
/**
 * @param array<string, mixed> $config
 */
#[DataProvider('inputProvider')]
#[TestDox('validates with $input')]
public function testInput($input): void
```

### TestWithJson Example
```php
// CORRECT - TestWithJson with TestDox
#[TestWithJson('["",{"required":true},"Value cannot be empty"]')]
#[TestWithJson('[null,{"required":true},"Value cannot be null"]')]
#[TestDox('validates required field with $value')]
public function testRequiredFieldValidation($value, $config, $expectedError): void
```

## E004 - Test Method Identification

Test methods MUST use `test` prefix and MUST NOT use `#[Test]` attribute (Shopware convention).

### Rule
- Method name MUST start with `test` prefix
- Method MUST NOT have `#[Test]` attribute (even with `test` prefix - redundant)

### Detection - Missing Prefix
```php
// INCORRECT - missing prefix, relies on attribute
#[Test]
public function createsUser(): void
```

### Detection - Redundant Attribute
```php
// INCORRECT - redundant attribute with prefix
#[Test]
public function testCreatesUser(): void
```

### Fix Pattern
```php
// CORRECT - prefix only, no attribute
public function testCreatesUser(): void
```

## E005 - Testing Implementation, Trivial Code, or Private Members

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
- Logic-free constructors (only parameter → property assignment)
- Trivial getters (return property value)
- Trivial setters (assign parameter to property)
- Trivial issers (return boolean property)
- Public readonly property access

### Detection - Reflection Access (Private Members)
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

### Detection - Call-Count Verification on Non-Side-Effect Methods

Using `expects($this->once())` on a collaborator where the test already asserts the return value makes the call-count check redundant and couples the test to internal behavior.

```php
// INCORRECT - call count verified but return value also asserted (E005 + E019)
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

Use `expects(once())` ONLY for side-effect methods where no return value proves the call happened:

```php
// CORRECT - expects(once()) justified: dispatch() side effect not verifiable by return value
$this->eventDispatcher
    ->expects($this->once())
    ->method('dispatch')
    ->with(static::isInstanceOf(ProductCreatedEvent::class));
```

### Detection - Implementation Details
```php
// INCORRECT - testing internal cache key format
public function testInternalCacheKeyGeneration(): void
{
    $reflection = new \ReflectionMethod($this->cache, 'generateCacheKey');
    $reflection->setAccessible(true);
    $key = $reflection->invoke($this->cache, 'product', 123);
    static::assertEquals('product_123_v2', $key);
}
```

### Detection - Trivial Code
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

// INCORRECT - testing public property access
public function testPublicPropertyAccess(): void
{
    $dto = new ProductData(name: 'test');
    static::assertEquals('test', $dto->name);
}
```

### When Constructor/Accessor Tests ARE Valid
- Constructor contains validation logic (throws exceptions)
- Constructor transforms input (normalizes, calculates)
- Getter computes derived value
- Setter has side effects or validation

### Fix Pattern - Implementation Details
```php
// CORRECT - testing observable behavior
public function testCachesProductData(): void
{
    $product = new Product('123', 'Test');
    $this->cache->store($product);

    static::assertEquals($product, $this->cache->get('123'));
}
```

### Fix Pattern - Trivial Code
```php
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

// CORRECT - setter has validation
public function testSetEmailRejectsInvalidFormat(): void
{
    $user = new User();
    $this->expectException(InvalidEmailException::class);
    $user->setEmail('not-an-email');
}
```

## E006 - Ambiguous Names

Test names MUST be descriptive and follow naming convention.

### Naming Format
`test` + `Action` + `Condition` + `ExpectedResult`

### Ambiguous Names (Flag)
- `testEdgeCases()`
- `testValidation()`
- `testItWorks()`
- `testHelper()`

### BDD-Style Names (Flag)
- `testItLoadsProducts()`
- `testItCreatesOrder()`
- `testItThrowsException()`
- Any `testIt...` pattern

### Why BDD-Style is Forbidden
- Shopware convention uses action-based naming (98% of existing tests)
- BDD-style adds redundant "It" without semantic value
- Consistent naming improves codebase searchability

### Fix Pattern - BDD to Action-Based
```php
// INCORRECT - BDD-style
public function testItLoadsProducts(): void
public function testItCreatesOrderSuccessfully(): void

// CORRECT - Action-based
public function testLoadsProducts(): void
public function testCreatesOrderSuccessfully(): void
```

### Implementation-Coupled Names (Flag as W001)
- `testSymfonyValidatorIntegration()`
- `testDoctrineQueryBuilderUsage()`

### Good Names
- `testCreatesOrderWhenPaymentSucceeds()`
- `testRejectsLoginWithInvalidCredentials()`
- `testThrowsExceptionWhenProductNotFound()`
- `testAcceptsUnicodeCharactersInUsername()`

## E007 - Missing Data Provider

When 3+ tests verify similar variations, consolidate with data provider.

### Detection
```php
// INCORRECT - redundant similar tests
public function testAcceptsStandardEmail(): void
{
    static::assertTrue($this->validator->validate('user@example.com'));
}

public function testAcceptsEmailWithSubdomain(): void
{
    static::assertTrue($this->validator->validate('user@mail.example.com'));
}

public function testAcceptsEmailWithPlus(): void
{
    static::assertTrue($this->validator->validate('user+tag@example.com'));
}
```

### Fix Pattern - Data Provider
```php
public static function validEmailProvider(): iterable
{
    yield 'standard email' => ['user@example.com'];
    yield 'with subdomain' => ['user@mail.example.com'];
    yield 'with plus tag' => ['user+tag@example.com'];
}

#[DataProvider('validEmailProvider')]
#[TestDox('accepts valid email format: $email')]
public function testAcceptsValidEmail(string $email): void
{
    static::assertTrue($this->validator->validate($email));
}
```

### Fix Pattern - TestWithJson (PHPUnit 11.5+)

For small inline datasets (≤5 cases), prefer `#[TestWithJson]`:

```php
#[TestWithJson('["user@example.com"]')]
#[TestWithJson('["user@mail.example.com"]')]
#[TestWithJson('["user+tag@example.com"]')]
#[TestDox('accepts valid email format: $email')]
public function testAcceptsValidEmail(string $email): void
{
    static::assertTrue($this->validator->validate($email));
}
```

### When to Use Each Approach

| Approach | Best For | Example |
|----------|----------|---------|
| `#[TestWithJson]` | ≤5 simple inline cases | Email validation, simple type checks |
| `#[DataProvider]` | Large datasets, complex objects | Price calculations, entity variations |
| `#[DataProvider]` | Shared data across tests | Same fixtures used by multiple tests |
| `#[DataProvider]` | Dynamic data generation | UUIDs via `Uuid::randomHex()` |

**Tip**: `#[TestWithJson]` keeps test data visible inline, improving readability for simple cases.

## E008 - Instance Assertions

Use `static::` for all PHPUnit assertions, not `$this->`.

### Detection
```php
// INCORRECT - instance method calls
public function testCreatesProduct(): void
{
    $product = $this->service->create(['name' => 'Test']);

    $this->assertNotNull($product->getId());        // E008
    $this->assertEquals('Test', $product->getName()); // E008
    $this->assertTrue($product->isActive());         // E008
}
```

### Fix Pattern
```php
// CORRECT - static method calls
public function testCreatesProduct(): void
{
    $product = $this->service->create(['name' => 'Test']);

    static::assertNotNull($product->getId());
    static::assertEquals('Test', $product->getName());
    static::assertTrue($product->isActive());
}
```

### Common Method Calls: Wrong vs Correct

| WRONG                       | CORRECT                     |
|-----------------------------|-----------------------------|
| `$this->assertEquals()`     | `static::assertEquals()`    |
| `$this->assertSame()`       | `static::assertSame()`      |
| `$this->assertTrue()`       | `static::assertTrue()`      |
| `$this->assertFalse()`      | `static::assertFalse()`     |
| `$this->assertNull()`       | `static::assertNull()`      |
| `$this->assertNotNull()`    | `static::assertNotNull()`   |
| `$this->assertInstanceOf()` | `static::assertInstanceOf()`|
| `$this->assertCount()`      | `static::assertCount()`     |
| `$this->assertEmpty()`      | `static::assertEmpty()`     |

**Exception: Setup methods use `$this->`, not `static::`**

`expectException*()` methods are not assertions — they set up PHPUnit state before the throwing call. They MUST use `$this->`. Using `static::` on them is E008.

| WRONG | CORRECT |
|-------|---------|
| `static::expectException(Foo::class)` | `$this->expectException(Foo::class)` |
| `static::expectExceptionMessage('msg')` | `$this->expectExceptionMessage('msg')` |
| `static::expectExceptionObject($e)` | `$this->expectExceptionObject($e)` |

### Closures/Callbacks Example

```php
// static:: for assertions inside the callback; $this->once() for the invocation matcher
$eventDispatcher = $this->createMock(EventDispatcherInterface::class);
$eventDispatcher
    ->expects($this->once())
    ->method('dispatch')
    ->willReturnCallback(function (object $event): object {
        static::assertInstanceOf(OrderCriteriaEvent::class, $event);
        return $event;
    });
```

## E009 - Test Redundancy

Tests MUST NOT have redundant coverage. Every test case (in data providers) and every test method MUST cover a unique code path. The same justification rules apply to both data provider cases and separate test methods.

### Core Question

For each test case or method, ask: **"What unique code path does this cover?"**

### Valid Justifications

| Type | Description | Key Pattern |
|------|-------------|-------------|
| Code path | Exercises branch not covered by other cases | `'negative triggers error path'` |
| Boundary | Tests at exact threshold | `'exactly 100 hits limit'` |
| Regression | Prevents specific bug | `'unicode fix (bug #1234)'` |

### Detection

```php
// E009 - keys describe WHAT, not WHY
public static function timeProvider(): iterable
{
    yield 'A much greater than B' => [now + 1000, now];
    yield 'A greater than B' => [now + 100, now];
    yield 'A slightly greater than B' => [now + 1, now];
}
```

All three cases exercise the same `A > B` code path. Only one is justified.

### Fix Pattern

```php
// CORRECT - each case has unique justification
public static function timeProvider(): iterable
{
    yield 'future time triggers refresh' => [now + 1, now];  // A > B path
    yield 'same time uses cache' => [now, now];              // A == B path
    yield 'past time returns stale' => [now - 1, now];       // A < B path
}
```

### Relationship to W004

| Code | Checks | Fails On |
|------|--------|----------|
| W004 | Key is descriptive | `'case1'`, `'test_1'` |
| E009 | Key justifies existence | `'small positive'`, `'large positive'` |

A case can pass W004 (descriptive) but fail E009 (unjustified):

```php
// Passes W004, FAILS E009 - same code path
yield 'small positive number' => [1];
yield 'large positive number' => [1000];

// Passes BOTH - different code paths
yield 'positive triggers success' => [1];
yield 'negative triggers error' => [-1];
```

### Detection - Redundant Methods

Multiple test methods exercising the same code path:

```php
// INCORRECT - Both methods trigger root match path
public function testExtractsElementById(): void
{
    $result = $this->extractor->extract($root, 'root-id');
    static::assertSame('root-id', $result->getId());
}

public function testReturnedElementIsClone(): void
{
    $result = $this->extractor->extract($root, 'root-id');  // Same path!
    static::assertNotSame($root, $result);
}
```

### Fix Pattern - Merge Methods

```php
public function testExtractsElementByIdAndReturnsClone(): void
{
    $result = $this->extractor->extract($root, 'root-id');

    static::assertSame('root-id', $result->getId());
    static::assertNotSame($root, $result);
}
```

### Fix Pattern - Consolidate to Data Provider

```php
public static function extractionScenarioProvider(): iterable
{
    yield 'root element match' => ['root-id', true];
    yield 'nested element found' => ['child-id', true];
    yield 'missing element returns null' => ['nonexistent', false];
}

#[DataProvider('extractionScenarioProvider')]
#[TestDox('extract with $targetId returns expected result')]
public function testExtraction(string $targetId, bool $expectFound): void
{
    $result = $this->extractor->extract($root, $targetId);
    // assertions based on $expectFound
}
```

### When Multiple Similar Cases ARE Justified

Document the reason when cases appear similar:

```php
// JUSTIFIED - different internal handling
yield 'ASCII username (fast path)' => ['john', true];
yield 'Unicode username (NFD normalization)' => ['jöhn', true];

// JUSTIFIED - regression tests
yield 'plus in local part (bug #1234)' => ['user+tag@example.com', true];
yield 'consecutive dots (bug #5678)' => ['user..name@example.com', false];
```

## E010 - Test Method Ordering

Test methods MUST follow a logical progression pattern.

### Required Order
1. **Happy path tests** - core functionality with valid inputs
2. **Standard variations** - common alternative flows
3. **Configuration options** - optional features and flags
4. **Edge cases** - boundary conditions, special values
5. **Error cases** - failure scenarios, exceptions

### Detection
```php
// INCORRECT - error case before happy path
class ProductServiceTest extends TestCase
{
    public function testThrowsExceptionWhenInvalid(): void { ... }  // E010 - error case first
    public function testCreatesProduct(): void { ... }              // Should be first
    public function testCreatesProductWithOptions(): void { ... }   // Should be second
}
```

### Fix Pattern
```php
// CORRECT - logical progression
class ProductServiceTest extends TestCase
{
    // 1. Happy path
    public function testCreatesProduct(): void { ... }

    // 2. Standard variations
    public function testCreatesProductWithCustomName(): void { ... }
    public function testCreatesProductWithCategory(): void { ... }

    // 3. Configuration options
    public function testCreatesProductWithDebugMode(): void { ... }

    // 4. Edge cases
    public function testCreatesProductWithEmptyDescription(): void { ... }
    public function testCreatesProductWithMaxLengthName(): void { ... }

    // 5. Error cases
    public function testThrowsExceptionWhenNameEmpty(): void { ... }
    public function testThrowsExceptionWhenPriceNegative(): void { ... }
}
```

### Category Identification

| Category | Indicators |
|----------|------------|
| Happy path | No "edge", "empty", "null", "invalid", "throws", "exception" in name |
| Variation | Similar to happy path but with "with", "using", "for" modifiers |
| Config | Contains "mode", "option", "flag", "config", "setting" |
| Edge case | Contains "empty", "null", "zero", "max", "min", "boundary" |
| Error case | Contains "throws", "exception", "invalid", "rejects", "fails" |

## E011 - TestDox Phrasing

TestDox content MUST follow phrasing guidelines for consistent, readable documentation.

### Required Format

TestDox must be a **predicate phrase** with:
- **Active voice** (not passive)
- **Present tense** (not future)
- **Action verb start** (not "it", "should", "tests")
- **Third person** (implicit subject)

### Detection Patterns

| Pattern | Issue |
|---------|-------|
| `#[TestDox('It creates...')]` | BDD "it" prefix |
| `#[TestDox('Should create...')]` | BDD "should" prefix |
| `#[TestDox('Product is created')]` | Passive voice |
| `#[TestDox('Tests that...')]` | Redundant "tests" |
| `#[TestDox('Will return...')]` | Future tense |
| `#[TestDox('The product...')]` | Article start |

### Detection - Passive Voice
```php
// INCORRECT - passive voice (E011)
#[TestDox('product is created with valid data')]
#[TestDox('exception is thrown for invalid input')]
#[TestDox('email is validated correctly')]
```

### Fix Pattern - Active Voice
```php
// CORRECT - active voice
#[TestDox('creates product with valid data')]
#[TestDox('throws exception for invalid input')]
#[TestDox('validates email correctly')]
```

### Detection - BDD Style
```php
// INCORRECT - BDD prefixes (E011)
#[TestDox('It creates a product')]
#[TestDox('Should create a product')]
#[TestDox('it should validate email')]
```

### Fix Pattern - Action Verb Start
```php
// CORRECT - direct action verb
#[TestDox('creates product')]
#[TestDox('validates email')]
```

### Valid Examples
```php
#[TestDox('creates product with valid data')]
#[TestDox('returns null when product not found')]
#[TestDox('throws exception for negative price')]
#[TestDox('validates email format $email')]
#[TestDox('accepts unicode characters in name')]
#[TestDox('rejects duplicate entries')]
#[TestDox('has correct default values')]
#[TestDox('converts price to cents')]
```

### Relationship to E006 (Method Naming)

| Code | Validates | Example Pattern |
|------|-----------|-----------------|
| E006 | Method name | `testCreatesProductWithValidData` |
| E011 | TestDox content | `#[TestDox('creates product with valid data')]` |

Both should describe the same behavior but:
- E006: CamelCase method name format
- E011: Human-readable sentence format

## E012 - Over-Mocking

Tests MUST prefer real implementations and Shopware stubs over PHPUnit mocks. Using mocks instead of stubs couples tests to implementation details, making them brittle and harder to maintain.

### Why Error

- **PHPUnit mocks couple tests to implementation**: When you mock a repository, your test depends on exactly which methods are called and in what order
- **Shopware stubs are deterministic**: StaticEntityRepository and StaticSystemConfigService provide predictable, implementation-agnostic behavior
- **Mocks fail silently on refactoring**: Renaming a method breaks mock-based tests even when behavior is unchanged
- **Stubs encourage behavior testing**: Using stubs forces you to think about what data goes in and comes out, not how it's processed

### Detection
```php
// INCORRECT - excessive mocking (E012)
public function testProductService(): void
{
    $repo = $this->createMock(EntityRepository::class);
    $repo->method('search')->willReturn(new EntitySearchResult(...));

    $config = $this->createMock(SystemConfigService::class);
    $config->method('get')->willReturn('value');
}
```

### Fix Pattern
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

Mocking is still acceptable when:
1. Object creation requires many nested dependencies that are irrelevant to the test
2. Class produces side effects (external API calls, file writes)
3. Testing error paths that real implementation won't trigger
4. Third-party interfaces without Shopware stubs

### StaticSalesChannelRepository for Store API Tests

Use when testing code that requires `SalesChannelContext`:

```php
use Shopware\Core\Test\Stub\DataAbstractionLayer\StaticSalesChannelRepository;

$repo = new StaticSalesChannelRepository([
    new ProductCollection([...])
]);

// Takes SalesChannelContext instead of Context
$result = $repo->search($criteria, $salesChannelContext);
```

### Callback Pattern for Criteria Validation

Use callables to assert criteria construction:

```php
/** @var StaticEntityRepository<PaymentMethodCollection> $repo */
$repo = new StaticEntityRepository([
    function (Criteria $criteria, Context $context) use ($baseContext) {
        // Validate the service built the criteria correctly
        static::assertCount(2, $criteria->getFilters());
        static::assertEquals([
            new EqualsFilter('active', 1),
            new EqualsFilter('salesChannels.id', $baseContext->getSalesChannelId()),
        ], $criteria->getFilters());

        return new PaymentMethodCollection();
    },
], new PaymentMethodDefinition());
```

### Available Shopware Test Stubs

| Stub | Use Case |
|------|----------|
| `StaticEntityRepository` | DAL repository with `Context` |
| `StaticSalesChannelRepository` | DAL repository with `SalesChannelContext` |
| `StaticSystemConfigService` | System configuration values |
| `Generator` | Test entity creation |

## E013 - Class Structure Order

Test class members MUST follow consistent ordering. Inconsistent structure makes navigation difficult and hinders code reviews.

### Why Error

- **Consistency across codebase**: Developers can instantly find setUp, properties, or helpers
- **Objective check**: Order is deterministic—either correct or incorrect
- **Code review efficiency**: Reviewers don't waste time on structure debates
- **Merge conflict reduction**: Consistent ordering reduces conflicts when multiple developers modify the same test class

### Required Order

```php
class ProductServiceTest extends TestCase
{
    use SomeTrait;                           // 1. Traits

    public const TEST_PRODUCT_ID = '123';    // 2. Constants

    private ProductService $service;         // 3. Properties
    private StaticEntityRepository $repo;

    protected function setUp(): void         // 4. setUp/tearDown
    {
        $this->repo = new StaticEntityRepository([]);
        $this->service = new ProductService($this->repo);
    }

    public function testCreates(): void {}   // 5. Test methods
    public function testDeletes(): void {}

    private function createProduct(): Product // 6. Helper methods
    {
        return new Product('test');
    }
}
```

### Detection
```php
// INCORRECT - wrong order (E013)
class ProductServiceTest extends TestCase
{
    private function createProduct(): Product {}  // Helper before tests - WRONG

    public function testCreates(): void {}

    private ProductService $service;              // Property after tests - WRONG

    protected function setUp(): void {}           // setUp after tests - WRONG

    use SomeTrait;                                // Trait after everything - WRONG
}
```

### Fix Pattern

Reorder class members to follow the required order:
1. Traits (`use Trait;`)
2. Constants (`public const`)
3. Properties (`private $repo;`)
4. setUp/tearDown methods
5. Test methods (following E010 ordering)
6. Helper methods (private functions)

## E014 - Exception Expectation Order

Exception expectations MUST be set BEFORE the throwing call. Setting expectations after the throwing call is a functional bug.

### Why Error

- **PHPUnit requirement**: PHPUnit can only catch exceptions if it knows to expect them BEFORE they're thrown
- **Silent test failure**: If expectation is set after the throw, the exception is uncaught and the test fails for the wrong reason
- **Functional bug**: This is not a style issue—tests with wrong order do not correctly verify exception behavior

### Detection
```php
// INCORRECT - throwing call before expectations (E014)
public function testThrowsOnInvalidData(): void
{
    $this->service->validate(['name' => '']);  // Throws BEFORE expectations set!

    $this->expectException(InvalidProductException::class);
    $this->expectExceptionMessage('Product name cannot be empty');
}
```

### Fix Pattern
```php
// CORRECT - expectations BEFORE throwing call
public function testThrowsOnInvalidData(): void
{
    $this->expectException(InvalidProductException::class);
    $this->expectExceptionMessage('Product name cannot be empty');

    $this->service->validate(['name' => '']);  // Throwing call LAST
}
```

### Complete Exception Testing Pattern

```php
public function testThrowsExceptionForInvalidProduct(): void
{
    // 1. Set up expectations FIRST
    $this->expectException(ProductNotFoundException::class);
    $this->expectExceptionMessage('Product with ID "invalid-id" not found');

    // 2. Set up test data
    $repo = new StaticEntityRepository([
        new ProductCollection([])  // Empty - product not found
    ]);
    $service = new ProductService($repo);

    // 3. Call throwing method LAST
    $service->getById('invalid-id');
}
```

### Using expectExceptionObject

For exceptions created via factory methods:

```php
public function testThrowsCustomerNotLoggedInException(): void
{
    // Use factory method for complete exception matching
    $this->expectExceptionObject(OrderException::customerNotLoggedIn());

    $this->orderService->placeOrder($cart, $context);
}
```

## E015 - Multiple Class Coverage

Test class MUST cover exactly ONE production class. Covering multiple classes indicates an integration test disguised as a unit test.

### Why Error

- **Unit test definition**: By definition, a unit test verifies one unit (class) in isolation
- **Test scope creep**: Multiple CoversClass attributes indicate the test is verifying integration behavior
- **Failure diagnosis**: When a multi-class test fails, it's unclear which class caused the failure
- **Wrong test location**: Tests covering multiple classes belong in `tests/integration/`, not `tests/unit/`

### Detection
```php
// INCORRECT - covers multiple classes (E015)
#[CoversClass(ProductService::class)]
#[CoversClass(ProductRepository::class)]
#[CoversClass(ProductValidator::class)]
class ProductServiceTest extends TestCase
```

### Fix Pattern - Single Class
```php
// CORRECT - covers single class
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
```

### When Multiple Classes Seem Necessary

If you feel you need multiple `#[CoversClass]`:

1. **Check test location**: Should this be in `tests/integration/`?
2. **Review dependencies**: Are you testing the service or its dependencies?
3. **Use stubs**: Mock/stub collaborators instead of testing them directly
4. **Split tests**: Create separate test classes for each covered class

### Example Refactoring

**Before (E015 violation):**
```php
#[CoversClass(ProductService::class)]
#[CoversClass(ProductValidator::class)]
class ProductServiceTest extends TestCase
{
    public function testValidatesAndCreatesProduct(): void
    {
        $product = $this->service->create(['name' => 'Test']);
        static::assertNotNull($product->getId());
        static::assertTrue($product->isValid());
    }
}
```

**After (separate unit tests):**
```php
// ProductServiceTest.php
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
{
    public function testCreatesProduct(): void
    {
        $validator = $this->createStub(ProductValidator::class);
        $validator->method('validate')->willReturn(true);

        $service = new ProductService($validator);
        $product = $service->create(['name' => 'Test']);

        static::assertNotNull($product->getId());
    }
}

// ProductValidatorTest.php
#[CoversClass(ProductValidator::class)]
class ProductValidatorTest extends TestCase
{
    public function testValidatesProductData(): void
    {
        $validator = new ProductValidator();
        static::assertTrue($validator->validate(['name' => 'Test']));
    }
}
```

## E016 - Shared Mutable State

Class properties written in one test method and read in another.

### Detection

```php
// VIOLATION - E016
class ProductServiceTest extends TestCase
{
    private ?string $productId = null;

    public function testCreatesProduct(): void
    {
        $this->productId = $service->create([...])->getId();  // WRITE
    }

    public function testUpdatesProduct(): void
    {
        $service->update($this->productId, [...]);  // READ from previous test
    }
}
```

### Fix

Each test creates its own state:

```php
// CORRECT
public function testUpdatesProduct(): void
{
    $product = $this->service->create(['name' => 'Test']);  // Own setup
    $this->service->update($product->getId(), ['name' => 'Updated']);
    static::assertEquals('Updated', $this->service->get($product->getId())->getName());
}
```

Do NOT flag properties set only in `setUp()` or marked `readonly`.

## E017 - Non-Deterministic Inputs

Functions producing different results each run.

### Functions to Detect

| Flag | Skip |
|------|------|
| `new \DateTime()` (no argument) | `new \DateTime('2024-01-01')` |
| `time()`, `microtime()` | `$this->createMock(\DateTimeInterface::class)` |
| `random_int()`, `mt_rand()`, `rand()` | Data provider context |
| `uniqid()`, `uuid_create()` | |

### Detection

```php
// VIOLATION - E017
public function testGeneratesReport(): void
{
    $result = $this->service->generate(new \DateTime());  // Non-deterministic
}
```

### Fix

```php
// CORRECT - fixed date
public function testGeneratesReport(): void
{
    $date = new \DateTime('2024-01-15 10:00:00');
    $result = $this->service->generate($date);
}
```

## E018 - Weak Exception Assertion

Tests that verify exception type alone (`expectException(Foo::class)`) without verifying message, code, or the full exception object allow tests to pass even when the wrong exception message or parameters are produced.

### Why Error

- **Wrong messages pass silently**: A test using only `expectException(CartException::class)` will pass even if the wrong factory method is called or parameters are missing
- **Most pervasive issue found in practice**: Affected 13+ test files in one codebase; entire sweep required to add message verification
- **False confidence**: Type-only assertions only verify *something* was thrown, not *what* was communicated

### When to Flag

Trigger when ALL of these are true:
1. `expectException(SomeClass::class)` appears in the test
2. No companion `expectExceptionMessage()`, `expectExceptionCode()`, or `expectExceptionObject()` appears
3. The exception class has a parameterized constructor, message template, or factory methods (i.e., it communicates context)

Do NOT flag when:
- Exception has no meaningful message/parameters (bare `\RuntimeException('error')` for internal guards)
- `expectExceptionObject()` is already used (this is the strongest form)
- `expectExceptionMessage()` or `expectExceptionCode()` is already present

### Detection

```php
// INCORRECT - type-only assertion (E018)
public function testThrowsWhenNotFound(): void
{
    $this->expectException(ContentSystemException::class);  // What message? What parameters?

    $this->service->load('missing-id');
}
```

### Fix Pattern 1 — Factory-based exceptions (preferred)

```php
// CORRECT - full object match via factory method
public function testThrowsWhenNotFound(): void
{
    $this->expectExceptionObject(ContentSystemException::elementNotFound('missing-id'));

    $this->service->load('missing-id');
}
```

### Fix Pattern 2 — Direct exception assertions

```php
// CORRECT - type + message assertion minimum
public function testThrowsWhenNotFound(): void
{
    $this->expectException(ContentSystemException::class);
    $this->expectExceptionMessage('Element with id "missing-id" was not found');

    $this->service->load('missing-id');
}
```

### Data Provider Exception Testing

When testing multiple exception scenarios with a data provider:

```php
public static function exceptionProvider(): iterable
{
    yield 'missing element' => [
        'input' => 'missing-id',
        'exception' => ContentSystemException::elementNotFound('missing-id'),
    ];
    yield 'invalid type' => [
        'input' => 'wrong-type-id',
        'exception' => ContentSystemException::invalidElementType('wrong-type-id', 'cms_page'),
    ];
}

#[DataProvider('exceptionProvider')]
#[TestDox('throws correct exception for $input')]
public function testThrowsCorrectException(string $input, \Throwable $exception): void
{
    $this->expectExceptionObject($exception);

    $this->service->process($input);
}
```

## E019 - Call-Count Over-Coupling

Using `expects($this->once())` (or `never()`, `exactly()`) on collaborators that return values already verified by outcome assertions couples tests to implementation details and makes them brittle under refactoring.

### Why Error

- **Breaks on safe refactoring**: If a service is optimized to call a repository once instead of twice (or vice versa), tests with call-count assertions fail even though behavior is unchanged
- **Redundant verification**: When the test already asserts the result (`static::assertSame($expected, $result)`), the call happening is proven implicitly — counting it adds no new information
- **9 test files affected in practice**: Required a full sweep to remove unnecessary call-count expectations

### When to Flag

Trigger when ALL of these are true:
1. `->expects($this->once())` (or `never()`, `exactly(N)`) on a collaborator mock
2. The same collaborator also has `->willReturn($value)`
3. The test asserts the returned or computed value from the method under test

**Exception — do NOT flag** when:
- The method is a side-effect-only call (no meaningful return value that proves execution): `dispatch()`, `write()`, `send()`, `persist()`, `log()`
- The test is specifically verifying the call IS or IS NOT made (interaction test by design)
- The method returns `void` and the side effect cannot be asserted another way

### Detection

```php
// INCORRECT - call count + willReturn + outcome assertion = triple redundancy (E019)
public function testLoadsProduct(): void
{
    $this->repository
        ->expects($this->once())          // Redundant: result already proves the call
        ->method('search')
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');

    static::assertSame($this->product, $result);  // This already proves search() was called
}
```

### Fix Pattern

```php
// CASE 1: Chain has no ->with() — remove expects() entirely, outcome assertion is sufficient
public function testLoadsProduct(): void
{
    $this->repository
        ->method('search')
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');

    static::assertSame($this->product, $result);
}

// CASE 2: Chain has ->with(static::callback(...)) — replace expects(once()) with expects(atLeastOnce())
// Use atLeastOnce(), NOT any(): any() permits 0 calls, which would let assertion-containing callbacks silently never fire.
public function testLoadsProductWithCriteriaVerification(): void
{
    $this->repository
        ->expects($this->atLeastOnce())      // Changed from once() to atLeastOnce() — removes exact-count coupling while guaranteeing the callback fires
        ->method('search')
        ->with(static::callback(function (Criteria $criteria): bool {
            static::assertContains('translations', $criteria->getAssociations());
            return true;
        }))
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');

    static::assertSame($this->product, $result);
}
```

### Detection — Missing expects() on with(callback) chain

**Rule**: When `->with(static::callback(...))` is present on a mock chain, `->expects(...)` MUST also be present. Without it, PHPUnit silently ignores the `->with()` constraint and the callback never fires.

```php
// INCORRECT — callback never fires: no expects() means PHPUnit ignores the ->with() constraint
public function testLoadsProductWithCriteriaVerification(): void
{
    $this->repository
        ->method('search')
        ->with(static::callback(function (Criteria $criteria): bool {
            static::assertContains('translations', $criteria->getAssociations()); // Never executes!
            return true;
        }))
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');
    static::assertSame($this->product, $result);
}
```

```php
// CORRECT — expects() ensures the callback fires
public function testLoadsProductWithCriteriaVerification(): void
{
    $this->repository
        ->expects($this->once())
        ->method('search')
        ->with(static::callback(function (Criteria $criteria): bool {
            static::assertContains('translations', $criteria->getAssociations());
            return true;
        }))
        ->willReturn(new ProductCollection([$this->product]));

    $result = $this->service->loadProduct('product-id');
    static::assertSame($this->product, $result);
}
```

### Legitimate Uses of expects(once())

```php
// CORRECT - side-effect method: no return value to assert, dispatch IS the observable behavior
public function testDispatchesEventAfterCreation(): void
{
    $this->eventDispatcher
        ->expects($this->once())
        ->method('dispatch')
        ->with(static::isInstanceOf(ProductCreatedEvent::class));

    $this->service->create($data);
}

// CORRECT - verifying a call is NOT made (negative interaction test)
public function testSkipsDispatchWhenDisabled(): void
{
    $this->eventDispatcher
        ->expects($this->never())
        ->method('dispatch');

    $this->service->createWithoutEvents($data);
}
```
