---
id: ISOLATION-001
title: Shared Mutable State
legacy: E016
group: isolation
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## Shared Mutable State

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Class properties written in one test method and read in another violate the FIRST Independent principle. Each test must be self-contained.

### Detection

```php
// INCORRECT - shared mutable state
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
