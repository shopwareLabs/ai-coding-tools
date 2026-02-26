---
id: CONV-007
title: Class Structure Order
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## Class Structure Order

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Test class members MUST follow consistent ordering. Inconsistent structure makes navigation difficult and hinders code reviews.

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

    protected function tearDown(): void
    {
        // cleanup if needed
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
// INCORRECT - wrong order
class ProductServiceTest extends TestCase
{
    private function createProduct(): Product {}  // Helper before tests — WRONG

    public function testCreates(): void {}

    private ProductService $service;              // Property after tests — WRONG

    protected function setUp(): void {}           // setUp after tests — WRONG

    use SomeTrait;                                // Trait after everything — WRONG
}
```

### Fix

Reorder class members:
1. Traits (`use Trait;`)
2. Constants (`public const`)
3. Properties (`private $repo;`)
4. setUp/tearDown methods
5. Test methods (following CONV-005 ordering)
6. Helper methods (private functions)
