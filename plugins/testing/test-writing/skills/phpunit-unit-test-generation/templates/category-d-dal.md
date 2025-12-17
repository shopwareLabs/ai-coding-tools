# Category D: DAL/Repository Test Template

## Contents
- [When to Use](#when-to-use)
- [Service with Repository Template](#service-with-repository-template)
- [Multi-Response Queue Pattern](#multi-response-queue-pattern)
- [Criteria Validation Patterns](#criteria-validation-patterns)
- [SalesChannelRepository Template](#saleschannelrepository-template)

---

## When to Use

Use for classes that:
- Use `EntityRepository` for data access
- Build `Criteria` for searches
- Perform DAL operations (search, create, update, delete)
- Work with entity collections

**IMPORTANT**: Always use `StaticEntityRepository` instead of `$this->createMock(EntityRepository::class)`.

## Service with Repository Template

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\Framework\Context;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Criteria;
use Shopware\Core\Test\Stub\DataAbstractionLayer\StaticEntityRepository;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
use Shopware\Core\{Module}\{Entity}\{Entity}Collection;
use Shopware\Core\{Module}\{Entity}\{Entity}Entity;
use Shopware\Core\{Module}\{Entity}\{Entity}Definition;

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    // 1. HAPPY PATH
    #[TestDox('finds entity by ID and returns populated entity')]
    public function testSearchReturnsMatchingEntities(): void
    {
        // Arrange - queue response
        $entity = (new {Entity}Entity())->assign([
            'id' => 'test-id',
            'name' => 'Test Entity',
        ]);

        /** @var StaticEntityRepository<{Entity}Collection> $repo */
        $repo = new StaticEntityRepository([
            new {Entity}Collection([$entity]),
        ], new {Entity}Definition());

        $subject = new {TargetClass}($repo);

        // Act
        $result = $subject->find('test-id', Context::createDefaultContext());

        // Assert
        static::assertNotNull($result);
        static::assertSame('test-id', $result->getId());
        static::assertSame('Test Entity', $result->getName());
    }

    #[TestDox('persists new entity via repository create')]
    public function testCreatePersistsEntity(): void
    {
        // Arrange
        /** @var StaticEntityRepository<{Entity}Collection> $repo */
        $repo = new StaticEntityRepository([]);

        $subject = new {TargetClass}($repo);

        // Act
        $subject->create(['name' => 'New Entity'], Context::createDefaultContext());

        // Assert - verify write operations
        static::assertCount(1, $repo->creates);
        static::assertSame('New Entity', $repo->creates[0]['name']);
    }

    // 2. VARIATIONS
    #[TestDox('updates existing entity via repository update')]
    public function testUpdateModifiesEntity(): void
    {
        // Arrange
        /** @var StaticEntityRepository<{Entity}Collection> $repo */
        $repo = new StaticEntityRepository([]);

        $subject = new {TargetClass}($repo);

        // Act
        $subject->update('entity-id', ['name' => 'Updated'], Context::createDefaultContext());

        // Assert
        static::assertCount(1, $repo->updates);
        static::assertSame('entity-id', $repo->updates[0]['id']);
        static::assertSame('Updated', $repo->updates[0]['name']);
    }

    #[TestDox('removes entity via repository delete')]
    public function testDeleteRemovesEntity(): void
    {
        // Arrange
        /** @var StaticEntityRepository<{Entity}Collection> $repo */
        $repo = new StaticEntityRepository([]);

        $subject = new {TargetClass}($repo);

        // Act
        $subject->delete('entity-id', Context::createDefaultContext());

        // Assert
        static::assertCount(1, $repo->deletes);
        static::assertSame('entity-id', $repo->deletes[0]['id']);
    }

    // 3. CRITERIA VALIDATION
    #[TestDox('builds search criteria with correct filters')]
    public function testSearchWithCallableValidatesCriteria(): void
    {
        // Arrange - callable for criteria validation
        /** @var StaticEntityRepository<{Entity}Collection> $repo */
        $repo = new StaticEntityRepository([
            static function (Criteria $criteria, Context $context): {Entity}Collection {
                // Validate criteria was built correctly
                static::assertCount(1, $criteria->getFilters());
                static::assertSame(['name', 'description'], $criteria->getFields());

                return new {Entity}Collection([]);
            },
        ], new {Entity}Definition());

        $subject = new {TargetClass}($repo);

        // Act
        $subject->searchByName('test', Context::createDefaultContext());
    }

    // 4. EDGE CASES
    #[TestDox('returns null when entity not found')]
    public function testSearchReturnsNullWhenNotFound(): void
    {
        // Arrange - empty collection
        /** @var StaticEntityRepository<{Entity}Collection> $repo */
        $repo = new StaticEntityRepository([
            new {Entity}Collection([]),
        ]);

        $subject = new {TargetClass}($repo);

        // Act
        $result = $subject->find('non-existent', Context::createDefaultContext());

        // Assert
        static::assertNull($result);
    }
}
```

## Multi-Response Queue Pattern

Use when service makes multiple repository calls:

```php
#[TestDox('processes multiple repository calls with queued responses')]
public function testMultipleSearchCallsUseQueuedResponses(): void
{
    // Arrange - queue multiple responses (consumed in order)
    $entity1 = (new {Entity}Entity())->assign(['id' => '1']);
    $entity2 = (new {Entity}Entity())->assign(['id' => '2']);

    /** @var StaticEntityRepository<{Entity}Collection> $repo */
    $repo = new StaticEntityRepository([
        new {Entity}Collection([$entity1]),  // First search() returns this
        new {Entity}Collection([$entity2]),  // Second search() returns this
        new {Entity}Collection([]),          // Third search() returns empty
    ]);

    $subject = new {TargetClass}($repo);
    $context = Context::createDefaultContext();

    // Act - each call consumes next queued response
    $result1 = $subject->find('1', $context);
    $result2 = $subject->find('2', $context);
    $result3 = $subject->find('3', $context);

    // Assert
    static::assertSame('1', $result1?->getId());
    static::assertSame('2', $result2?->getId());
    static::assertNull($result3);
}
```

## Criteria Validation Patterns

Use callable-based StaticEntityRepository to validate criteria construction:

```php
#[TestDox('builds criteria with correct filter types')]
public function testBuildsCriteriaWithCorrectFilters(): void
{
    /** @var StaticEntityRepository<{Entity}Collection> $repo */
    $repo = new StaticEntityRepository([
        static function (Criteria $criteria, Context $context): {Entity}Collection {
            // Validate filter types
            $filters = $criteria->getFilters();
            static::assertCount(2, $filters);

            static::assertInstanceOf(EqualsFilter::class, $filters[0]);
            static::assertSame('active', $filters[0]->getField());
            static::assertTrue($filters[0]->getValue());

            static::assertInstanceOf(ContainsFilter::class, $filters[1]);
            static::assertSame('name', $filters[1]->getField());

            return new {Entity}Collection([]);
        },
    ]);

    $subject = new {TargetClass}($repo);
    $subject->searchActive('test', Context::createDefaultContext());
}

#[TestDox('builds criteria with required associations')]
public function testBuildsCriteriaWithAssociations(): void
{
    /** @var StaticEntityRepository<{Entity}Collection> $repo */
    $repo = new StaticEntityRepository([
        static function (Criteria $criteria, Context $context): {Entity}Collection {
            static::assertTrue($criteria->hasAssociation('translations'));
            static::assertTrue($criteria->hasAssociation('media'));

            return new {Entity}Collection([]);
        },
    ]);

    $subject = new {TargetClass}($repo);
    $subject->findWithAssociations('id', Context::createDefaultContext());
}

#[TestDox('builds criteria with sorting and pagination')]
public function testBuildsCriteriaWithSortingAndLimit(): void
{
    /** @var StaticEntityRepository<{Entity}Collection> $repo */
    $repo = new StaticEntityRepository([
        static function (Criteria $criteria, Context $context): {Entity}Collection {
            static::assertSame(10, $criteria->getLimit());
            static::assertSame(0, $criteria->getOffset());

            $sorting = $criteria->getSorting();
            static::assertCount(1, $sorting);
            static::assertSame('createdAt', $sorting[0]->getField());
            static::assertSame('DESC', $sorting[0]->getDirection());

            return new {Entity}Collection([]);
        },
    ]);

    $subject = new {TargetClass}($repo);
    $subject->findRecent(10, Context::createDefaultContext());
}
```

## SalesChannelRepository Template

Use for Store API / sales channel scoped services. Use `Generator::generateSalesChannelContext()`.

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Criteria;
use Shopware\Core\System\SalesChannel\SalesChannelContext;
use Shopware\Core\Test\Generator;
use Shopware\Core\Test\Stub\DataAbstractionLayer\StaticSalesChannelRepository;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
use Shopware\Core\{Module}\{Entity}\{Entity}Collection;
use Shopware\Core\{Module}\{Entity}\{Entity}Entity;

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    #[TestDox('finds entity within sales channel context')]
    public function testSearchInSalesChannelContext(): void
    {
        // Arrange
        $entity = (new {Entity}Entity())->assign(['id' => 'test-id']);

        /** @var StaticSalesChannelRepository<{Entity}Collection> $repo */
        $repo = new StaticSalesChannelRepository([
            new {Entity}Collection([$entity]),
        ]);

        $salesChannelContext = Generator::generateSalesChannelContext();
        $subject = new {TargetClass}($repo);

        // Act
        $result = $subject->find('test-id', $salesChannelContext);

        // Assert
        static::assertNotNull($result);
        static::assertSame('test-id', $result->getId());
    }
}
```
