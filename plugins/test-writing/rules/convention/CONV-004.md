---
id: CONV-004
title: Static Assertions
legacy: E008
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## Static Assertions

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Use `static::` for all PHPUnit assertions, not `$this->`.

### Detection

```php
// INCORRECT - instance method calls
$this->assertNotNull($product->getId());        // CONV-004
$this->assertEquals('Test', $product->getName()); // CONV-004
$this->assertTrue($product->isActive());         // CONV-004
```

### Fix

```php
// CORRECT - static method calls
static::assertNotNull($product->getId());
static::assertEquals('Test', $product->getName());
static::assertTrue($product->isActive());
```

### Common Method Calls: Wrong vs Correct

| Wrong | Correct |
|-------|---------|
| `$this->assertEquals()` | `static::assertEquals()` |
| `$this->assertSame()` | `static::assertSame()` |
| `$this->assertTrue()` | `static::assertTrue()` |
| `$this->assertFalse()` | `static::assertFalse()` |
| `$this->assertNull()` | `static::assertNull()` |
| `$this->assertNotNull()` | `static::assertNotNull()` |
| `$this->assertInstanceOf()` | `static::assertInstanceOf()` |
| `$this->assertCount()` | `static::assertCount()` |
| `$this->assertEmpty()` | `static::assertEmpty()` |

### Exception: Setup Methods Use `$this->`

`expectException*()` methods are setup methods — they configure PHPUnit state before the throwing call. They MUST use `$this->`. Using `static::` on them is CONV-004.

| Wrong | Correct |
|-------|---------|
| `static::expectException(Foo::class)` | `$this->expectException(Foo::class)` |
| `static::expectExceptionMessage('msg')` | `$this->expectExceptionMessage('msg')` |
| `static::expectExceptionObject($e)` | `$this->expectExceptionObject($e)` |

### Closures/Callbacks

```php
// static:: for assertions inside the callback; $this->once() for the invocation matcher
$eventDispatcher = $this->createMock(EventDispatcherInterface::class);
$eventDispatcher
    ->expects($this->once())
    ->method('dispatch')
    ->willReturnCallback(function (object $event): object {
        static::assertInstanceOf(OrderCriteriaEvent::class, $event);
        return $event;
    });
```
