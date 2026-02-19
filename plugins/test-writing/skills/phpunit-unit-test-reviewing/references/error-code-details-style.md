# Style Warning and Informational Details

Detailed explanations for style warnings (W001-W013) and informational codes (I001-I008).

## Table of Contents
- [W001 - Implementation-Specific Naming](#w001---implementation-specific-naming)
- [W002 - Assertion Scope](#w002---assertion-scope)
- [W003 - Missing TestDox](#w003---missing-testdox)
- [W004 - Data Provider Key Quality](#w004---data-provider-key-quality)
- [W005 - Assertion Method Choice](#w005---assertion-method-choice)
- [W006 - Legacy Generator Method](#w006---legacy-generator-method)
- [W007 - Data Provider Naming Convention](#w007---data-provider-naming-convention)
- [W008 - Class-Level TestDox](#w008---class-level-testdox)
- [W009 - Mystery Guest File Dependency](#w009---mystery-guest-file-dependency)
- [W010 - Unbalanced Coverage Distribution](#w010---unbalanced-coverage-distribution)
- [W011 - Unclear AAA Structure](#w011---unclear-aaa-structure)
- [W012 - createMock() When createStub() Would Suffice](#w012---createmock-when-createstub-would-suffice)
- [W013 - Opaque Test Data Identifiers](#w013---opaque-test-data-identifiers)
- [Informational Codes (I001-I008)](#informational-codes-i001-i008)

## W001 - Implementation-Specific Naming

Test names should describe behavior in business language, not implementation details.

### Detection
```php
// INCORRECT - mentions framework/implementation
public function testSymfonyValidatorIntegration(): void
public function testDoctrineQueryBuilderUsage(): void
public function testRedisConnectionHandling(): void
```

### Fix Pattern
```php
// CORRECT - describes behavior
public function testValidatesUserInput(): void
public function testFindsActiveProducts(): void
public function testHandlesCacheConnectionFailure(): void
```

## W002 - Assertion Scope

Tests should have one logical assertion per test. Multiple assertions are acceptable only when testing a single logical behavior.

### When Multiple Assertions Are OK
- Verifying multiple properties of a single created object
- Checking before/after state of one operation
- Asserting related aspects of one behavior

### Detection - Different Behaviors
```php
// INCORRECT - different behaviors
public function testProductCreation(): void
{
    $product = $this->service->create($data);
    static::assertEquals('Test', $product->getName());    // creation
    static::assertTrue($product->isActive());              // status
    static::assertCount(3, $this->repo->findAll());        // persistence
    static::assertNotEmpty($this->logger->getLogs());      // logging
}
```

### Detection - Unrelated Assertions
```php
// INCORRECT - unrelated assertions
public function testProcessOrder(): void
{
    $order = $this->service->process($data);

    static::assertEquals('pending', $order->getStatus());
    static::assertEquals(100.00, $order->getTotal());
    static::assertCount(5, $this->emailService->getSent()); // Different concern
}
```

### Fix Pattern
```php
// CORRECT - single behavior with related assertions
public function testCreatesProductWithProvidedProperties(): void
{
    $product = $this->service->create(['name' => 'Test', 'price' => 10.50]);

    static::assertEquals('Test', $product->getName());
    static::assertEquals(10.50, $product->getPrice());
    static::assertNotNull($product->getId());
}

// Separate test for separate concern
public function testProcessOrderSendsNotificationEmails(): void
{
    $this->service->process($data);
    static::assertCount(5, $this->emailService->getSent());
}
```

## W003 - Missing TestDox

Complex tests benefit from TestDox documentation.

### When to Require TestDox
- Data provider tests
- Tests with complex setup
- Tests with non-obvious assertions

### Detection
```php
// INCORRECT - data provider without TestDox
#[DataProvider('priceProvider')]
public function testCalculatesPrice(float $gross, float $net, float $tax): void
```

### Fix Pattern
```php
// CORRECT - with TestDox
#[DataProvider('priceProvider')]
#[TestDox('calculates price: gross=$gross, net=$net, tax=$tax')]
public function testCalculatesPrice(float $gross, float $net, float $tax): void
```

## W004 - Data Provider Key Quality

Data provider yield keys must be present AND descriptive. This warning triggers when:
- Keys are missing entirely (implicit numeric indices)
- Keys are present but non-descriptive (e.g., `'case1'`, `'test_1'`, `'a'`)

### Detection - Missing Keys
```php
// INCORRECT - no keys (implicit numeric indices 0, 1, 2...)
public static function dataProvider(): iterable
{
    yield ['valid@email.com', true];
    yield ['invalid', false];
}
```

### Detection - Non-Descriptive Keys
```php
// INCORRECT - keys exist but are not descriptive
public static function configProvider(): iterable
{
    yield 'case1' => [new StaticSystemConfigService([]), 'default'];
    yield 'case2' => [new StaticSystemConfigService(['key' => 'val']), 'val'];
}
```

### Fix Pattern
```php
// CORRECT - descriptive keys explain the test case
public static function configProvider(): iterable
{
    yield 'empty config uses default' => [
        new StaticSystemConfigService([]),
        'default',
    ];
    yield 'custom config overrides default' => [
        new StaticSystemConfigService(['key' => 'val']),
        'val',
    ];
}
```

## W005 - Assertion Method Choice

Use specific assertion methods instead of boolean comparisons.

### Detection
```php
// INCORRECT - assertTrue with comparison
static::assertTrue($result === 5);
static::assertTrue($array === []);
static::assertFalse($string === null);
```

### Fix Pattern
```php
// CORRECT - specific assertions
static::assertEquals(5, $result);
static::assertEmpty($array);
static::assertNotNull($string);
```

### Common Assertion Mappings
| Instead of | Use |
|------------|-----|
| `assertTrue($a === $b)` | `assertEquals($b, $a)` |
| `assertTrue($a !== $b)` | `assertNotEquals($b, $a)` |
| `assertTrue($a === null)` | `assertNull($a)` |
| `assertFalse($a === null)` | `assertNotNull($a)` |
| `assertTrue(count($a) === 0)` | `assertEmpty($a)` |
| `assertTrue($a instanceof X)` | `assertInstanceOf(X::class, $a)` |

## W006 - Legacy Generator Method

Use `Generator::generateSalesChannelContext()` instead of the legacy `createSalesChannelContext()`.

### Detection
```php
// INCORRECT - legacy method (W006)
use Shopware\Core\Test\Generator;

$context = Generator::createSalesChannelContext();
```

### Fix Pattern
```php
// CORRECT - new method with full component support
use Shopware\Core\Test\Generator;

$context = Generator::generateSalesChannelContext(
    baseContext: $context,
    salesChannel: $salesChannel,
    currency: $currency,
    areaRuleIds: [RuleAreas::PRODUCT_AREA => $ruleIds],
    languageInfo: Generator::createLanguageInfo(Defaults::LANGUAGE_SYSTEM, 'Test')
);

// Or minimal usage with defaults
$context = Generator::generateSalesChannelContext();
```

## W007 - Data Provider Naming Convention

Data provider methods SHOULD use `{action}Provider` suffix naming pattern.

### Detection
```php
// INCORRECT patterns
public static function provideValidEmails(): iterable     // prefix pattern
public static function dataProviderForValidation(): iterable  // verbose prefix
public static function getTestCases(): iterable           // non-standard
public static function cases(): iterable                  // too generic
```

### Fix Pattern
```php
// CORRECT - suffix pattern: {action}Provider
public static function validEmailProvider(): iterable
public static function validationProvider(): iterable
public static function testCaseProvider(): iterable
```

### Naming Convention
Format: `{action}Provider` where action describes what is provided

| Test Method | Provider Name |
|-------------|---------------|
| `testAcceptsValidEmail` | `validEmailProvider` |
| `testLoadsConfig` | `configProvider` |
| `testThrowsException` | `exceptionProvider` |
| `testCalculatesPrice` | `priceCalculationProvider` |
| `testValidatesInput` | `validationProvider` |

### Why
- Matches 78% of existing Shopware data providers
- Clearly indicates the method is a data provider via suffix
- Action-based naming mirrors test method naming convention
- Enables consistent pattern matching across codebase

## W008 - Class-Level TestDox

Class-level `#[TestDox]` attribute is discouraged. Use method-level TestDox only.

### Detection
```php
// INCORRECT - class-level TestDox
#[TestDox('A product service')]
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
```

### Fix Pattern
```php
// CORRECT - no class-level TestDox
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
{
    #[TestDox('creates product with valid data')]
    public function testCreatesProduct(): void {}
}
```

### Why
- Class-level creates incomplete sentences requiring method continuation
- Method-level sentences are self-contained and clearer
- Avoids dependency between class and method documentation

## W009 - Mystery Guest File Dependency

External file dependencies obscure test intent. Find `file_get_contents()`, `include`, `require`, `fopen()` calls.

### Skip (Acceptable Patterns)

- `__DIR__ . '/_fixtures/'`, `'/fixtures/'`, `'/Fixture/'`
- Sibling fixtures: `__DIR__ . '/../fixtures/'`
- Binary test files: `__DIR__ . '/shopware-logo.png'`
- Stub files: `__DIR__ . '/template.stub'`
- Bootstrap: `vendor/autoload.php`

### Flag

- Absolute paths: `/home/user/data.json`
- Source file access: `__DIR__ . '/../../../src/Config.php'`
- Cross-test fixtures: `__DIR__ . '/../OtherTest/_fixtures/`
- Dynamic glob without fixture context

### Detection

```php
// FLAG - accessing source files
$config = file_get_contents(__DIR__ . '/../../../src/Resources/config/default.json');

// SKIP - fixture directory
$config = file_get_contents(__DIR__ . '/_fixtures/config.json');
```

### Fix

```php
// Inline fixture (preferred)
$config = ['theme' => 'dark', 'language' => 'en'];
```

## W010 - Unbalanced Coverage Distribution

Flag when combined edge+error cases < 20% of total tests.

### Classification

| Category | Indicators |
|----------|------------|
| **Error case** | `expectException()`, or name contains: Throws, Fails, Invalid, Error, Exception, Rejects |
| **Edge case** | Name contains: Empty, Null, Zero, Boundary, Max, Min, Negative, Overflow |
| **Happy path** | Default (no indicators above) |

### Detection

```php
// W010: 10% edge + 10% error = 20% (at threshold)
class ProductServiceTest extends TestCase
{
    // Happy path (8 tests - 80%)
    public function testCreatesProduct(): void {}
    public function testUpdatesProduct(): void {}
    // ... 6 more happy path tests

    // Edge case (1 test - 10%)
    public function testHandlesEmptyName(): void {}

    // Error case (1 test - 10%)
    public function testThrowsForInvalidId(): void {}
}
```

### Fix

Add edge and error cases to reach > 20% combined coverage.

## W011 - Unclear AAA Structure

Assertions should be grouped at the end, not interspersed with setup/action code.

Skip: Tests with < 5 statements, data provider consumers, exception tests.

### Detection Algorithm

1. Skip if test has < 5 statements (too simple)
2. Find all assertion calls (`static::assert*`, `$this->assert*`, `$this->expect*`)
3. Find the final action (last non-assertion method call on SUT)
4. Flag if any assertions appear before the final action block

### Detection

```php
// W011 - assertions not at end
public function testProcessesOrder(): void
{
    $order = new Order();
    static::assertNotNull($order);        // Assertion in arrange phase
    $order->addItem($this->product);
    static::assertCount(1, $order->getItems());  // Assertion mid-action
    $result = $this->service->process($order);
    static::assertTrue($result->isSuccess());
}
```

### Fix

```php
// AAA structure - assertions at end
public function testProcessesOrder(): void
{
    // Arrange
    $order = new Order();
    $order->addItem($this->product);

    // Act
    $result = $this->service->process($order);

    // Assert
    static::assertCount(1, $order->getItems());
    static::assertTrue($result->isSuccess());
}
```

---

## Informational Codes (I001-I008)

### I001 - Data Provider Consolidation

Test could benefit from consolidating similar variations into data provider.

**When to mention**: 2 similar tests exist (3+ triggers E007 error).

### I002 - Execution Time Concern

Test may have performance issues due to:
- External service calls
- Large data sets
- Missing mocks for slow operations

**Suggestion**: Consider mocking external dependencies or using smaller test data.

### I003 - PHPUnit 11.5 Features

Test could use modern PHPUnit features.

**Available Features**:
- `#[TestWithJson]` for inline data providers
- `#[TestDox]` for documentation
- `#[CoversClass]` for coverage
- `expectUserDeprecationMessageMatches()` for deprecations

### I004 - expectExceptionObject Suggestion

When exceptions are created via factory methods, consider using `expectExceptionObject()` for complete instance matching.

**When to suggest**: Test uses `expectException()` + `expectExceptionMessage()` for an exception that has a factory method.

**Example**:
```php
// Could be improved
$this->expectException(OrderException::class);
$this->expectExceptionMessage('Customer is not logged in.');

// Better - uses factory method
$this->expectExceptionObject(OrderException::customerNotLoggedIn());
```

### I005 - DisabledFeatures for Legacy Tests

Consider using `#[DisabledFeatures]` for tests that verify deprecated/legacy behavior.

**When to suggest**: Test appears to verify behavior that only applies to older versions, or contains comments about deprecation.

**Context**: Unit tests run with all major feature flags **active by default**. Tests for legacy behavior must explicitly disable flags.

**Example**:
```php
use Shopware\Core\Test\Annotation\DisabledFeatures;

// Test for legacy behavior (flag disabled)
#[DisabledFeatures(['v6.8.0.0'])]
public function testLegacyBehavior(): void
{
    $result = $this->service->process($data);
    static::assertSame('old-format', $result);
}
```

### I006 - Callable StaticEntityRepository for Criteria Validation

Consider using callable-based StaticEntityRepository to validate criteria construction.

**When to suggest**: Test builds complex criteria that should be verified, or the test calls `search()` and the criteria correctness is important.

**Example**:
```php
// Advanced: Validate criteria inside the callback
$repo = new StaticEntityRepository([
    static function (Criteria $criteria, Context $context) {
        // Assert filter was built correctly
        static::assertCount(1, $criteria->getFilters());
        static::assertInstanceOf(EqualsFilter::class, $criteria->getFilters()[0]);

        return new ProductCollection([$product]);
    }
], new ProductDefinition());
```

### I007 - Preservation Value in Redundant Tests

When E009 (redundancy) detection finds a potentially redundant test, check for preservation value indicators before flagging.

**Purpose**: Some redundant tests have historical value that justifies their existence:
- Regression tests for specific bug fixes
- Documentation of edge cases discovered in production
- Compliance or audit requirements

**Preservation indicators** (suggest I007 instead of E009):
- Test name contains: `Regression`, `Bug`, `Issue`, `#\d+`, `JIRA-`, `SW-`
- Comments contain: `// regression`, `// bug fix`, `// prevents #`, `// see issue`
- Data provider key contains: `bug`, `regression`, `issue #`

**Example**:
```php
// E009 would flag as redundant (same code path as testCreatesUser)
// But I007 notes preservation value due to regression indicator
public function testRegressionBug4521UserCreation(): void
{
    // This test covers the same path as testCreatesUser
    // but documents a specific historical bug fix
    $user = $this->service->create(['name' => '']);
    static::assertNotNull($user->getId());
}
```

**When to suggest**:
- E009 would fire, but preservation indicator is present
- Inform user that test appears redundant but may have preservation value
- Suggest adding explicit documentation if preservation is intentional

**Recommendation format**:
```
I007: testRegressionBug4521UserCreation appears to cover the same code path
as testCreatesUser. If this test documents a specific bug fix, consider
adding a comment with the issue reference. Otherwise, consider consolidating.
```

### I008 - Real Fixture Files for File I/O Testing

Tests validating file I/O using inline content strings are candidates for real fixture files in a `_fixtures/` directory. Applies to importers, exporters, parsers, or file processors. Skip when test already uses `_fixtures/` or content is trivial.

**Detection**: Tests with inline file content creation rather than fixture files:
- Large heredoc/nowdoc (`<<<`) file content in test methods
- `file_put_contents()` with inline string content (not reading from fixture)
- `fwrite()` or `SplFileObject::fwrite()` with inline content
- Mock objects returning hardcoded file content strings for file-processing tests
- Multi-step content creation: building strings, then writing to temp files

**Bad Example**:
```php
public function testParsesTranslationFile(): void
{
    $content = '{"key": "value", "nested": {"inner": "data"}}';
    file_put_contents($this->tempDir . '/en.json', $content);

    $result = $this->parser->parse($this->tempDir . '/en.json');

    static::assertSame('value', $result['key']);
}
```

**Good Example** (Shopware pattern: copy fixtures in setUp, clean in tearDown):
```php
protected function setUp(): void
{
    $this->tempDir = sys_get_temp_dir() . '/test-' . uniqid();
    (new Filesystem())->mirror(__DIR__ . '/_fixtures/translations', $this->tempDir);
}

protected function tearDown(): void
{
    (new Filesystem())->remove($this->tempDir);
}

public function testParsesTranslationFile(): void
{
    $result = $this->parser->parse($this->tempDir . '/en.json');
    static::assertSame('value', $result['key']);
}
```

**Fix**: Create fixture files in a `_fixtures/` directory adjacent to the test class. Copy to temp location in `setUp()` and clean up in `tearDown()`.

**When NOT to flag**:
- Test reads fixture files directly without copying (acceptable if read-only)
- Test uses vfsStream for virtual file system simulation
- Content is trivial (single-line JSON, simple strings under 50 chars)
- String content isn't written to any file or stream

**Alternative**: vfsStream is acceptable for simple cases, but real fixtures are preferred when testing actual file parsing or complex I/O scenarios.

**Note**: Informational only. See `LintTranslationFilesCommandTest`, `ManifestTest`, `AppLoaderTest` for Shopware examples of this pattern.

## W012 - createMock() When createStub() Would Suffice

Using `createMock()` when `createStub()` is sufficient communicates false intent: it implies interaction verification is planned even when none exists.

### Why Warning

- **Wrong intent**: `createMock()` signals "I will verify how this is called"; `createStub()` signals "I only need it to return values"
- **PHPUnit best practice**: PHPUnit's own documentation recommends `createStub()` for pure state-based testing
- **16 files converted in one sweep in practice**: Indicates systematic misuse when `createMock()` is used as the default
- **Lighter object**: `Stub` does not track call invocations, making tests marginally faster and less noisy on assertion failure

### Detection

Trigger when ALL of these are true:
1. `createMock(Foo::class)` is called for a property or local variable
2. No `->expects(...)` call appears on that variable anywhere in the test class

```php
// INCORRECT - createMock() used but no expects() call (W012)
private CartService&MockObject $cartService;

protected function setUp(): void
{
    $this->cartService = $this->createMock(CartService::class);
    $this->cartService->method('getCart')->willReturn($this->cart);  // No expects()
}
```

### Fix Pattern

```php
use PHPUnit\Framework\MockObject\Stub;

// CORRECT - createStub() matches intent
private CartService&Stub $cartService;

protected function setUp(): void
{
    $this->cartService = $this->createStub(CartService::class);
    $this->cartService->method('getCart')->willReturn($this->cart);
}
```

### When createMock() IS Correct

```php
// CORRECT - createMock() justified by expects() call
private EventDispatcherInterface&MockObject $eventDispatcher;

public function testDispatchesEvent(): void
{
    $this->eventDispatcher
        ->expects($this->once())     // Interaction verification: createMock() is correct
        ->method('dispatch')
        ->with(static::isInstanceOf(ProductCreatedEvent::class));

    $this->service->create($data);
}
```

### Intersection Type Reference

| PHPUnit method | PHP 8.1+ type | Use when |
|----------------|---------------|----------|
| `createStub(Foo::class)` | `Foo&Stub` | Only return values needed |
| `createMock(Foo::class)` | `Foo&MockObject` | Call-count or argument verification needed |

## W013 - Opaque Test Data Identifiers

Using UUID hex strings or other opaque identifiers as test data makes test failure messages unreadable — you cannot tell from the assertion failure which entity was involved.

### Why Warning

- **Unreadable failures**: `Expected "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" but got null` gives no context; `Expected "product-id" but got null` immediately identifies the problem
- **Fixed in practice as a quality sweep**: Entire test files updated to replace opaque UUIDs with descriptive strings
- **No functional benefit**: Shopware's `StaticEntityRepository` and entity stubs work identically with string IDs — real UUID format is not required in unit tests

### Detection

Flag when a string literal matches:
- 32 consecutive hex characters: `[0-9a-f]{32}` (UUID without dashes)
- All-same-character hex strings: `'aaaa...aaaa'`, `'0000...0001'`
- Clearly placeholder UUIDs: `'00000000000000000000000000000001'`

Do NOT flag when:
- The identifier is generated by `Uuid::randomHex()` (code under test requires UUID format)
- The test exercises UUID format validation specifically
- The identifier appears in fixture data for integration-style tests

### Detection Example

```php
// INCORRECT - opaque identifiers (W013)
$product = new ProductEntity();
$product->setUniqueIdentifier('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');

$result = $this->service->loadProduct('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
static::assertSame('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', $result->getId());
```

### Fix Pattern

```php
// CORRECT - descriptive identifiers (self-documenting failures)
$product = new ProductEntity();
$product->setUniqueIdentifier('product-id');

$result = $this->service->loadProduct('product-id');
static::assertSame('product-id', $result->getId());
```

### Good Identifier Names

| Context | Good | Bad |
|---------|------|-----|
| Generic product | `'product-id'` | `'aaaa...aaaa'` |
| Root element | `'root-element'` | `'00000000000000000000000000000001'` |
| Missing/not found | `'missing-id'` | `'ffffffffffffffffffffffffffffffff'` |
| Multiple entities | `'first-product'`, `'second-product'` | `'aaa...aaa'`, `'bbb...bbb'` |
| Parent/child | `'parent-id'`, `'child-id'` | random hex |
