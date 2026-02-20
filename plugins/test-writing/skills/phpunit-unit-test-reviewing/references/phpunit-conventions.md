# PHPUnit Conventions

## PHPUnit 10+ Attribute Requirements

### CoversClass Attribute (MANDATORY)

Every test class MUST have `#[CoversClass]` attribute. PHPStan enforces this.

```php
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;
use Shopware\Core\Content\Product\ProductService;

#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
```

### Import Order Convention

Conceptual grouping (ECS may reorder alphabetically):

```php
namespace Shopware\Tests\Unit\Core\Content\Product;

use PHPUnit\Framework\Attributes\CoversClass;     // PHPUnit attributes
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;                   // Base class
use Shopware\Core\Content\Product\ProductService; // Target class under test
```

**Note**: Shopware ECS applies PSR-12 alphabetical import ordering. The grouping above is conceptual - actual order will be alphabetized by ECS.

### Single-Class Coverage Pattern

Each test class covers exactly ONE production class:

```php
// CORRECT - one class coverage
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase

// INCORRECT - multiple classes (integration test smell)
#[CoversClass(ProductService::class)]
#[CoversClass(ProductRepository::class)]
class ProductServiceTest extends TestCase
```

### Namespace Mirroring

| Source | Test |
|--------|------|
| `Shopware\Core\Content\Product\ProductService` | `Shopware\Tests\Unit\Core\Content\Product\ProductServiceTest` |

## Static Assertion Pattern

Use `static::` for all assertions (E008 if `$this->`):

```php
// CORRECT - static assertions
static::assertEquals($expected, $actual);
static::assertSame($expected, $actual);
static::assertTrue($condition);
static::assertInstanceOf(ProductEntity::class, $result);

// INCORRECT - instance assertions
$this->assertEquals($expected, $actual);  // E008
$this->assertTrue($condition);            // E008
```

`expectException()`, `expectExceptionMessage()`, `expectExceptionCode()`, `expectExceptionObject()` are **setup methods** — MUST use `$this->`. Using `static::` on these is **E008**. Only `assert*()` methods use `static::`.

## Attribute Order Rules

### STRICT Order (E003 if violated)

```
1. PHPDoc (/** */)           <- FIRST if present
2. DataProvider attributes   <- SECOND
3. TestDox                   <- ALWAYS LAST
4. Method declaration        <- with test prefix
```

### Valid Examples

```php
// Minimal - just test prefix
public function testCreatesProduct(): void

// With TestDox
#[TestDox('creates product with valid data')]
public function testCreatesProduct(): void

// With DataProvider and TestDox
#[DataProvider('productDataProvider')]
#[TestDox('creates product with $name')]
public function testCreatesProduct(string $name): void

// Full with PHPDoc
/**
 * @param array<string, mixed> $data
 */
#[DataProvider('productDataProvider')]
#[TestDox('creates product with $name')]
public function testCreatesProduct(string $name, array $data): void

// With TestWithJson
#[TestWithJson('["Product A", 10.50]')]
#[TestWithJson('["Product B", 20.00]')]
#[TestDox('creates product $name with price $price')]
public function testCreatesProduct(string $name, float $price): void
```

### Invalid Examples (E003)

```php
// WRONG - TestDox before DataProvider
#[TestDox('creates product')]
#[DataProvider('provider')]
public function testCreates(): void

// WRONG - Test attribute with test prefix (E004)
#[Test]
public function testCreates(): void
```

## Test Method Ordering

### Standard Pattern (E010 if violated)

```php
class ProductServiceTest extends TestCase
{
    // 1. HAPPY PATH - Core functionality
    public function testCreatesProduct(): void {}
    public function testUpdatesProduct(): void {}

    // 2. STANDARD VARIATIONS - Common alternatives
    public function testCreatesProductWithCustomSku(): void {}
    public function testUpdatesProductPartially(): void {}

    // 3. CONFIGURATION OPTIONS - Feature flags, settings
    public function testCreatesProductWithDebugMode(): void {}
    public function testSkipsValidationWhenDisabled(): void {}

    // 4. EDGE CASES - Boundaries, special values
    public function testCreatesProductWithEmptyDescription(): void {}
    public function testHandlesMaximumPriceValue(): void {}

    // 5. ERROR CASES - Failures, exceptions
    public function testThrowsOnInvalidName(): void {}
    public function testThrowsOnNegativePrice(): void {}
}
```

## Test Class Structure

### Required Order (E013 if violated)

```php
class ProductServiceTest extends TestCase
{
    use SomeTrait;                              // 1. Traits

    public const TEST_ID = '0190...';           // 2. Constants

    private ProductService $service;            // 3. Properties
    private StaticEntityRepository $repo;

    protected function setUp(): void            // 4. setUp/tearDown
    {
        $this->repo = new StaticEntityRepository([]);
        $this->service = new ProductService($this->repo);
    }

    protected function tearDown(): void
    {
        // cleanup if needed
    }

    public function testCreatesProduct(): void  // 5. Test methods
    {
    }

    private function createTestProduct(): ProductEntity  // 6. Helpers
    {
        return (new ProductEntity())->assign(['id' => self::TEST_ID]);
    }
}
```

## Data Provider Conventions

### Static Method Requirement

```php
// CORRECT - static method
public static function validEmailProvider(): iterable
{
    yield 'standard email' => ['user@example.com'];
}

// INCORRECT - instance method
public function validEmailProvider(): iterable
{
    yield 'standard email' => ['user@example.com'];
}
```

### Return Type (W015 if violated)

```php
// CORRECT - iterable return type with yield
public static function validEmailProvider(): iterable
{
    yield 'standard email' => ['user@example.com'];
    yield 'with subdomain' => ['user@mail.example.com'];
}

// INCORRECT - array return type with return [] (W015)
public static function validEmailProvider(): array
{
    return [
        'standard email' => ['user@example.com'],
        'with subdomain' => ['user@mail.example.com'],
    ];
}
```

### Descriptive Yield Keys (W004 if missing/non-descriptive)

```php
// CORRECT - descriptive keys
public static function configProvider(): iterable
{
    yield 'sales channel specific default' => [
        new StaticSystemConfigService(['category.cms_page' => 'pageId']),
        'pageId',
    ];
    yield 'global fallback when no channel config' => [
        new StaticSystemConfigService([]),
        'globalDefault',
    ];
}

// INCORRECT - numeric/missing keys (W004)
public static function configProvider(): iterable
{
    yield [new StaticSystemConfigService([]), 'default'];
    yield [new StaticSystemConfigService(['key' => 'val']), 'val'];
}
```

## PHPUnit 11.5 Features

### TestWithJson Attribute

Inline data provider for simple cases:

```php
#[TestWithJson('["valid@email.com", true]')]
#[TestWithJson('["invalid", false]')]
#[TestDox('validates email $email expecting $valid')]
public function testEmailValidation(string $email, bool $valid): void
{
    static::assertEquals($valid, $this->validator->isValid($email));
}
```

### TestDox Attribute

Documentation in test output:

```php
#[TestDox('creates user with email $email')]
public function testCreatesUser(string $email): void
```

## TestDox Phrasing Guidelines

### Grammar Rules (E011 if violated)

| Aspect | Rule | Good | Bad |
|--------|------|------|-----|
| Voice | Active | "creates product" | "product is created" |
| Tense | Present simple | "returns null" | "will return null" |
| Person | Third person (implicit) | "validates email" | "I validate email" |
| Start | Action verb | "creates order" | "tests that order is created" |

### Required Sentence Structure

TestDox MUST be a **predicate phrase** starting with an action verb:

```php
// CORRECT - action verb start
#[TestDox('creates product with valid data')]
#[TestDox('returns null when product not found')]
#[TestDox('throws exception for invalid input')]

// INCORRECT - non-action start (E011)
#[TestDox('Product is created')]           // passive voice
#[TestDox('It creates product')]           // BDD "it" prefix
#[TestDox('Should create product')]        // BDD "should"
#[TestDox('Tests product creation')]       // "tests" prefix
#[TestDox('The product gets created')]     // article start
```

### With Data Provider Parameters

Use `$paramName` placeholders for dynamic values:

```php
#[DataProvider('emailProvider')]
#[TestDox('validates email $email as $validity')]
public function testEmailValidation(string $email, string $validity): void
```

### Common Verb Patterns

| Category | Verbs | Example |
|----------|-------|---------|
| **Creation** | creates, generates, builds | "creates order from cart" |
| **Retrieval** | returns, finds, loads, gets | "returns null when not found" |
| **Validation** | validates, accepts, rejects | "rejects invalid email format" |
| **State** | is, has, contains | "has correct default values" |
| **Exception** | throws, fails | "throws on negative price" |
| **Transformation** | converts, transforms, maps | "converts price to cents" |

### TestDox Phrasing Anti-Patterns (E011)

| Pattern | Problem | Fix |
|---------|---------|-----|
| `It creates...` | BDD-style "it" prefix | `creates...` |
| `Should create...` | BDD-style "should" | `creates...` |
| `Product is created` | Passive voice | `creates product` |
| `Tests that...` | Redundant "tests" | Remove prefix |
| `testMethodName` | Just method name | Describe behavior |
| `Will return...` | Future tense | `returns...` |

### Class-Level TestDox (W008)

Class-level `#[TestDox]` is **discouraged**. Use method-level only:

```php
// INCORRECT - class-level TestDox (W008)
#[TestDox('A product service')]
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase

// CORRECT - method-level only
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
{
    #[TestDox('creates product with valid data')]
    public function testCreatesProduct(): void
}
```

**Why**: Class-level TestDox creates sentence fragments that depend on method-level
continuation. Method-level standalone sentences are clearer and self-contained.

### Deprecation Testing

```php
public function testDeprecatedMethod(): void
{
    $this->expectUserDeprecationMessageMatches('/Method .* is deprecated/');
    $this->service->deprecatedMethod();
}
```

## Exception Testing Patterns

### Pattern 1: expectException + expectExceptionMessage (E014 if after)

Set expectations BEFORE the throwing call:

```php
// CORRECT - expectations before throwing call
public function testThrowsOnInvalidData(): void
{
    $this->expectException(InvalidProductException::class);
    $this->expectExceptionMessage('Product name cannot be empty');

    $this->service->validate(['name' => '']);  // Throwing call LAST
}
```

### Pattern 2: expectExceptionObject for Factory Exceptions

```php
public function testNotLoggedIn(): void
{
    $this->expectExceptionObject(OrderException::customerNotLoggedIn());

    $route->cancel(new Request(['orderId' => Uuid::randomHex()]), $context);
}
```

### Pattern 3: Separate Tests for Exception Cases

Instead of conditional exception handling (which violates E001), use separate test methods:

```php
#[DataProvider('provideInvalidData')]
#[TestDox('throws exception for invalid input: $description')]
public function testThrowsOnInvalidData(mixed $input, string $description): void
{
    $this->expectException(ValidationException::class);
    $this->validator->validate($input);
}

#[DataProvider('provideValidData')]
#[TestDox('accepts valid input: $description')]
public function testAcceptsValidData(mixed $input, string $description): void
{
    $this->validator->validate($input);
    $this->expectNotToPerformAssertions();
}
```

## Type Narrowing in Tests

PHPUnit assertions provide type narrowing for static analysis:

```php
// CORRECT - PHPUnit assertions narrow types AND fail test on mismatch
public function testReturnsProduct(): void
{
    $result = $this->service->findProduct($id);

    static::assertNotNull($result);           // $result is now non-null
    static::assertInstanceOf(ProductEntity::class, $result);  // $result is now ProductEntity
    static::assertIsString($result->getName());  // getName() is now string

    // Safe to use $result as ProductEntity
    static::assertSame('Expected', $result->getName());
}
```

| Assertion | Input Type | Narrowed Type |
|-----------|------------|---------------|
| `assertNotNull($v)` | `T\|null` | `T` |
| `assertIsString($v)` | `mixed` | `string` |
| `assertIsArray($v)` | `mixed` | `array` |
| `assertInstanceOf(C::class, $v)` | `object` | `C` |
