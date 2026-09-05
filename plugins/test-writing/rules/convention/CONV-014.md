---
id: CONV-014
title: Unclear AAA Structure
group: convention
enforce: should-fix
test-types: all
test-categories: A,B,C,D
scope: general
review-unit: method
scoped-review: include
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

`process()` here only computes a result and does not touch `$order`'s items, so moving the count assertion past it observes the same value — this relocation is safe. (When the action under test DOES mutate or consume the state an assertion reads, see the carve-out below instead of relocating.)

```php
// AAA structure - assertions at end
public function testProcessesOrder(): void
{
    // Arrange
    $order = new Order();
    $order->addItem($this->product);

    // Act
    $result = $this->service->process($order);  // reads $order, does not mutate its items

    // Assert
    static::assertCount(1, $order->getItems());
    static::assertTrue($result->isSuccess());
}
```

### Position-Load-Bearing Carve-Out

An assertion sitting between two actions can be intentional rather than a structure defect: moving it past the next action changes the value it observes, because that next action mutates or destroys the state the assertion reads. Report such a placement at most as `consider`, never propose relocating it, and never remediate by adding assertions the test did not previously make just to compensate for the move — a remedy that must invent a new assertion to cover for a relocation is wrong by construction.

```php
// CORRECT (position load-bearing) - process() consumes the order's items,
// so asserting the pre-call count after process() would observe a different value
public function testProcessesOrderAndDrainsQueue(): void
{
    $order = new Order();
    $order->addItem($this->product);

    static::assertCount(1, $order->getItems());  // observes state process() is about to consume

    $result = $this->service->process($order);   // mutates $order — moving the assertion past this changes what it reads

    static::assertTrue($result->isSuccess());
}
```
