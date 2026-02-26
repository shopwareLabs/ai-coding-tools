---
id: CONV-014
title: Unclear AAA Structure
group: convention
enforce: should-fix
test-types: all
test-categories: A,B,C,D
scope: general
---

## Unclear AAA Structure

**Scope**: A,B,C,D | **Enforce**: Should fix

Assertions should be grouped at the end, not interspersed with setup/action code.

Skip: Tests with < 5 statements, data provider consumers, exception tests.

### Detection Algorithm

1. Skip if test has < 5 statements (too simple)
2. Find all assertion calls (`static::assert*`, `$this->assert*`, `$this->expect*`)
3. Find the final action (last non-assertion method call on SUT)
4. Flag if any assertions appear before the final action block

### Detection

```php
// CONV-014 - assertions not at end
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
