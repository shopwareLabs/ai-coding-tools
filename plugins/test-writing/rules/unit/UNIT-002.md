---
id: UNIT-002
title: Single Class Coverage
legacy: E015
group: unit
enforce: must-fix
test-types: unit
test-categories: A,B,C,D,E
scope: phpunit
---

## Single Class Coverage

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Test class MUST cover exactly ONE production class via `#[CoversClass]`. Covering multiple classes indicates an integration test disguised as a unit test.

### Detection

```php
// INCORRECT - covers multiple classes
#[CoversClass(ProductService::class)]
#[CoversClass(ProductRepository::class)]
#[CoversClass(ProductValidator::class)]
class ProductServiceTest extends TestCase
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
