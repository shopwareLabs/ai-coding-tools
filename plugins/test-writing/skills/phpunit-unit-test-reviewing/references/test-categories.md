# Test Categories

Categories are determined by the **test subject characteristics**, not test file location.

| Cat | Name | Characteristics | Key Patterns |
|-----|------|-----------------|--------------|
| A | Simple DTO | Tests value objects, entities, collections | No dependencies, direct instantiation |
| B | Service | Tests services with dependencies | Mocking/stubs required, DI setup |
| C | Flow/Event | Tests subscribers, flow actions | Event dispatcher setup, flow context |
| D | DAL | Tests using repository patterns | StaticEntityRepository, Criteria |
| E | Exception | Tests exception handling paths | expectException, error scenarios |

## Category Detection Workflow

1. **Check test subject**: What class is being tested?
2. **Check dependencies**: Does it require mocking/stubs?
3. **Check patterns**: Event dispatch? Repository? Simple object?

## Category A - Simple DTO

```php
class ProductEntityTest extends TestCase
{
    public function testConstructorRejectsInvalidData(): void
    {
        $this->expectException(InvalidArgumentException::class);
        new ProductEntity(name: '', price: -1);
    }

    public function testCalculatedPriceIncludesTax(): void
    {
        $product = new ProductEntity(name: 'Test', netPrice: 100.00, taxRate: 19);
        static::assertEquals(119.00, $product->getGrossPrice());
    }
}
```

Note: Do NOT test simple getters/setters or logic-free constructors (E005). Only test code with meaningful logic like validation or computed values.

## Category B - Service with Dependencies

```php
class ProductServiceTest extends TestCase
{
    public function testCreatesProduct(): void
    {
        $repo = new StaticEntityRepository([]);
        $service = new ProductService($repo);
        // ...
    }
}
```

## Category C - Flow/Event

```php
class ProductSubscriberTest extends TestCase
{
    public function testHandlesProductWrittenEvent(): void
    {
        $subscriber = new ProductSubscriber($this->service);
        $event = new ProductWrittenEvent(...);
        $subscriber->onProductWritten($event);
        // ...
    }
}
```

## Category D - DAL

```php
class ProductRepositoryTest extends TestCase
{
    public function testSearchFindsByName(): void
    {
        $repo = new StaticEntityRepository([
            new ProductCollection([...])
        ]);
        $criteria = new Criteria();
        // ...
    }
}
```

## Category E - Exception

```php
class ProductValidatorTest extends TestCase
{
    public function testThrowsOnInvalidData(): void
    {
        $this->expectException(InvalidProductException::class);
        $this->validator->validate(['invalid' => 'data']);
    }
}
```
