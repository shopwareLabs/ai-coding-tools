# Essential Rules

Detailed naming, attribute, and structure conventions for PHPUnit tests.

## File Location and Structure

- **File location**: `tests/unit/` mirroring `src/` path
  - `src/Core/Content/Product/ProductService.php`
  - `tests/unit/Core/Content/Product/ProductServiceTest.php`
- **Class attribute**: `#[CoversClass(TargetClass::class)]` (REQUIRED)
- **Assertions**: Use `static::` not `$this->`
- **Base class**: Extend `PHPUnit\Framework\TestCase`

## Attribute Order (STRICT)

```php
/**
 * @param array<string, mixed> $data  // 1. PHPDoc FIRST (if needed)
 */
#[DataProvider('providerMethod')]     // 2. DataProvider/TestWithJson
#[TestDox('description with $var')]   // 3. TestDox ALWAYS LAST
public function testMethodName(): void // 4. Method declaration
```

## Test Method Naming

Format: `test` + `Action` + `Condition` + `ExpectedResult`

**FORBIDDEN**: `testIt...` BDD-style naming

**Good examples:**
- `testCalculatePriceReturnsCorrectAmount`
- `testCalculatePriceWithDiscountReturnsReducedAmount`
- `testCalculatePriceWithInvalidInputThrowsException`

**Wrong examples:**
- `testItCalculatesPrice` (BDD-style)
- `testItThrowsException` (BDD-style)

## TestDox Phrasing

TestDox MUST be a **predicate phrase** starting with an action verb:

| Aspect | Rule | Good | Bad |
|--------|------|------|-----|
| Voice | Active | "creates product" | "product is created" |
| Tense | Present | "returns null" | "will return null" |
| Start | Action verb | "validates email" | "it validates email" |

**Common verb patterns:**
- Creation: `creates`, `generates`, `builds`
- Retrieval: `returns`, `finds`, `loads`
- Validation: `validates`, `accepts`, `rejects`
- Exception: `throws`, `fails`

**FORBIDDEN prefixes:** `It...`, `Should...`, `Tests that...`, `The...`

**NO class-level TestDox** - Use method-level only.

**Example:**
```php
#[DataProvider('emailProvider')]
#[TestDox('validates email $email correctly')]
public function testValidatesEmail(string $email): void
```

## Data Provider Naming

Format: `{action}Provider`

**Examples:**
- `validEmailProvider` (for `testAcceptsValidEmail`)
- `configProvider` (for `testLoadsConfig`)
- `exceptionProvider` (for `testThrowsException`)

## One Behavior Per Test

- NO conditionals (if/else/switch/match/ternary) in tests
- NO multiple behaviors in one method
- Separate test methods for each scenario

## Test Method Ordering

```php
class ServiceTest extends TestCase
{
    // 1. HAPPY PATH - Core functionality
    public function testCreatesProduct(): void {}

    // 2. VARIATIONS - Common alternatives
    public function testCreatesProductWithCustomSku(): void {}

    // 3. CONFIGURATION - Feature flags, settings
    public function testSkipsValidationWhenDisabled(): void {}

    // 4. EDGE CASES - Boundaries, empty values
    public function testHandlesEmptyCollection(): void {}

    // 5. ERROR CASES - Exceptions
    public function testThrowsOnInvalidInput(): void {}
}
```

## Class Structure Order

Traits -> Constants -> Properties -> setUp/tearDown -> Test methods -> Helpers

## Avoid Redundant Tests

Each test method and data provider case must cover a unique code path.

## Mocking Priority

1. **Real implementation** - Use actual objects when simple (entities, value objects)
2. **Shopware stubs** - Prefer over mocks:
   - `StaticEntityRepository` for DAL repositories
   - `StaticSystemConfigService` for system config
   - `Generator::generateSalesChannelContext()` for contexts
3. **PHPUnit stubs** (`createStub()`) - For dependencies where you only configure return values
4. **PHPUnit mocks** (`createMock()`) - ONLY when you need `expects()` for interaction verification (side-effect methods)

**createStub() vs createMock():**
- Use `createStub(Foo::class)` → `Foo&Stub` when you only call `->method()->willReturn()`
- Use `createMock(Foo::class)` → `Foo&MockObject` ONLY when you call `->expects($this->once())` or similar
- Using `createMock()` without `expects()` is W012 (wrong intent, unnecessary overhead)

## Test Data Identifiers

Use **descriptive string identifiers** in test fixtures — not UUID hex strings. Real UUID format is not required in unit tests.

**Good:**
```php
$product->setUniqueIdentifier('product-id');
$repo = new StaticEntityRepository([new ProductCollection([$product])]);
$result = $this->service->loadProduct('product-id');
static::assertSame('product-id', $result->getId());
```

**Bad (W013):**
```php
$product->setUniqueIdentifier('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
$result = $this->service->loadProduct('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
```

**Good identifier patterns:** `'product-id'`, `'root-element'`, `'missing-id'`, `'parent-id'`, `'child-id'`, `'first-item'`, `'second-item'`

**Exception:** When the production code generates or validates real UUID format, use `Uuid::randomHex()` or a real UUID.
