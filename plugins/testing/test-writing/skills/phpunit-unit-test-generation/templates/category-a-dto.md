# Category A: DTO/Entity/Value Object Test Template

## Contents
- [When to Use](#when-to-use)
- [Basic Template](#template)
- [Collection Test Template](#collection-test-template)
- [Struct Test Template](#struct-test-template)

---

## When to Use

Use for classes with:
- No constructor dependencies
- Value objects, entities, structs, collections
- Factory methods (`fromArray()`, `create()`) with transformation/validation
- Custom serialization (`toArray()`, `jsonSerialize()`)

**Skip tests for**:
- Trivial getters/setters (return/assign property only)
- Logic-free constructors (parameter → property assignment only)
- Constant returns (`getApiAlias()`, `getExpectedClass()`)
- Public readonly property access

## Template

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    // 1. HAPPY PATH
    #[TestDox('creates instance from array with type transformation')]
    public function testFromArrayCreatesWithTransformation(): void
    {
        $data = ['price' => '10.99', 'quantity' => '5'];

        $subject = {TargetClass}::fromArray($data);

        static::assertSame(1099, $subject->getPriceInCents());
        static::assertSame(5, $subject->getQuantity());
    }

    #[TestDox('serializes to JSON with correct structure')]
    public function testJsonSerializeReturnsCorrectStructure(): void
    {
        $subject = new {TargetClass}('value1', 123);

        $json = $subject->jsonSerialize();

        static::assertArrayHasKey('property1', $json);
        static::assertSame('value1', $json['property1']);
    }

    // 5. ERROR CASES
    #[TestDox('throws exception when required field missing')]
    public function testFromArrayWithMissingRequiredFieldThrows(): void
    {
        $this->expectException(\InvalidArgumentException::class);

        {TargetClass}::fromArray(['incomplete' => 'data']);
    }
}
```

## Collection Test Template

Only test custom filter/sort methods with logic. Skip `getApiAlias()`, `getExpectedClass()` (constant returns).

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
use Shopware\Core\{Module}\{Submodule}\{Entity}Entity;

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    #[TestDox('filters collection to only active entities')]
    public function testFilterByActiveReturnsOnlyActiveEntities(): void
    {
        $entity1 = (new {Entity}Entity())->assign(['id' => '1', 'active' => true]);
        $entity2 = (new {Entity}Entity())->assign(['id' => '2', 'active' => false]);

        $collection = new {TargetClass}([$entity1, $entity2]);

        $filtered = $collection->filterByActive(true);

        static::assertCount(1, $filtered);
        static::assertSame('1', $filtered->first()?->getId());
    }

    #[TestDox('sorts collection by price ascending')]
    public function testSortByPriceReturnsSortedCollection(): void
    {
        $entity1 = (new {Entity}Entity())->assign(['id' => '1', 'price' => 200]);
        $entity2 = (new {Entity}Entity())->assign(['id' => '2', 'price' => 100]);

        $collection = new {TargetClass}([$entity1, $entity2]);

        $sorted = $collection->sortByPrice();

        static::assertSame('2', $sorted->first()?->getId());
    }
}
```

## Struct Test Template

Only test factory methods and serialization with logic. Skip `getApiAlias()` (constant return).

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    #[TestDox('creates struct from array with amount conversion')]
    public function testFromArrayCreatesStructWithTransformation(): void
    {
        $data = [
            'amount' => '99.99',
            'currency' => 'EUR',
        ];

        $struct = {TargetClass}::fromArray($data);

        static::assertSame(9999, $struct->getAmountInCents());
        static::assertSame('EUR', $struct->getCurrency());
    }

    #[TestDox('serializes to JSON with formatted amount')]
    public function testJsonSerializeReturnsCorrectStructure(): void
    {
        $struct = new {TargetClass}(9999, 'EUR');

        $json = $struct->jsonSerialize();

        static::assertArrayHasKey('amount', $json);
        static::assertSame('99.99', $json['amount']);
    }
}
```
