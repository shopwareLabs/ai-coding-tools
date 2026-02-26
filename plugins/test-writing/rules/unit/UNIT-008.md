---
id: UNIT-008
title: Callable StaticEntityRepository
group: unit
enforce: consider
test-types: unit
test-categories: B,C,D
scope: shopware
---

## Callable StaticEntityRepository

**Scope**: B,C,D | **Enforce**: Consider

Consider using callable-based StaticEntityRepository to validate criteria construction.

### When to Suggest

Test builds complex criteria that should be verified, or the test calls `search()` and the criteria correctness is important.

### Example

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

### Advanced Callable Pattern: Inline Assertions

```php
$repo = new StaticEntityRepository([
    static function (Criteria $criteria, Context $context) use ($salesChannelEntity) {
        // Validate filter count
        static::assertCount(1, $criteria->getFilters());

        // Validate specific filter type and value
        static::assertEquals([
            new NotEqualsFilter('typeId', Defaults::SALES_CHANNEL_TYPE_PRODUCT_COMPARISON),
        ], $criteria->getFilters());

        // Validate criteria IDs
        static::assertContains('red', $criteria->getIds());
        static::assertContains('green', $criteria->getIds());

        return new EntitySearchResult(
            SalesChannelDefinition::ENTITY_NAME,
            1,
            new SalesChannelCollection([$salesChannelEntity]),
            null,
            $criteria,
            $context
        );
    }
], new SalesChannelDefinition());
```
