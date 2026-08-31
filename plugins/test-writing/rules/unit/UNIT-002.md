---
id: UNIT-002
title: Single Class Coverage
group: unit
enforce: must-fix
test-types: unit
test-categories: A,B,C,D,E
scope: phpunit
review-unit: class-structure
scoped-review: exclude
---

## Single Class Coverage

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Test class MUST cover exactly ONE production class via `#[CoversClass]`, EXCEPT where it covers conformance across implementations of one contract. Covering several classes that do not share one contract indicates an integration test disguised as a unit test.

### Detection

Flag a test class carrying more than one `#[CoversClass]` attribute, unless the covered classes are implementations of one contract and the test exercises that contract's conformance across them.

```php
// INCORRECT - covers three classes that share no contract
#[CoversClass(ProductService::class)]
#[CoversClass(ProductRepository::class)]
#[CoversClass(ProductValidator::class)]
class ProductServiceTest extends TestCase
```

```php
// CORRECT - conformance across implementations of one contract
#[CoversClass(JsonPayloadSerializer::class)]
#[CoversClass(XmlPayloadSerializer::class)]
class PayloadSerializerConformanceTest extends TestCase
```

### Fix

```php
// CORRECT - covers single class
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
```

### When Multiple Classes Seem Necessary

1. **Check test location**: Should this be in `tests/integration/`?
2. **Review dependencies**: Are you testing the service or its dependencies?
3. **Use stubs**: Mock/stub collaborators instead of testing them directly
4. **Split tests**: Create separate test classes for each covered class
5. **Drop surplus attributes**: Where one production class is exercised but several `#[CoversClass]` attributes are present, reducing to one attribute resolves the violation without a file operation
6. **Conformance suites are exempt**: A test class covering conformance across implementations of one contract is not the integration-test smell this rule targets

### Example Refactoring

**Before (violation):**
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

**After:**
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
