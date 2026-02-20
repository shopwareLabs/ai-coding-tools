# Category C: Flow/Event Test Template

## Contents
- [When to Use](#when-to-use)
- [Event Subscriber Template](#event-subscriber-template)
- [Flow Action Template](#flow-action-template)
- [Flow Storer Template](#flow-storer-template)
- [Event Dispatcher Verification](#event-dispatcher-verification)

---

## When to Use

Use for classes that:
- Implement `EventSubscriberInterface`
- Extend `FlowAction` or `FlowStorer`
- Handle events or flow actions
- Dispatch events

**Skip tests for**:
- `getSubscribedEvents()` that only returns constant mappings (unless mappings themselves are complex)

## Event Subscriber Template

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
use Shopware\Core\{Module}\{Event}\{Event}Event;

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    private {TargetClass} $subscriber;
    // Declare dependency properties

    protected function setUp(): void
    {
        // Initialize dependencies
        $this->subscriber = new {TargetClass}(
            // Pass dependencies
        );
    }

    // 1. HAPPY PATH
    #[TestDox('registers correct event listeners')]
    public function testGetSubscribedEventsReturnsCorrectMapping(): void
    {
        $events = {TargetClass}::getSubscribedEvents();

        static::assertArrayHasKey({Event}Event::class, $events);
        static::assertSame('onEventName', $events[{Event}Event::class]);
    }

    #[TestDox('processes event and updates result')]
    public function testOnEventNameProcessesEvent(): void
    {
        // Arrange
        $event = new {Event}Event(/* event data */);

        // Act
        $this->subscriber->onEventName($event);

        // Assert - verify side effects
        // static::assertSame($expected, $event->getResult());
    }

    // 2. VARIATIONS
    #[TestDox('modifies event data correctly')]
    public function testOnEventNameModifiesEventData(): void
    {
        // Arrange
        $event = new {Event}Event(/* data */);

        // Act
        $this->subscriber->onEventName($event);

        // Assert
        static::assertSame('modified', $event->getModifiedProperty());
    }

    // 4. EDGE CASES
    #[TestDox('skips processing when event data is empty')]
    public function testOnEventNameWithEmptyDataSkipsProcessing(): void
    {
        // Arrange
        $event = new {Event}Event(/* empty data */);

        // Act
        $this->subscriber->onEventName($event);

        // Assert - verify no side effects
        // static::assertNull($event->getResult());
    }
}
```

## Flow Action Template

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\Content\Flow\Dispatching\StorableFlow;
use Shopware\Core\Content\Flow\Dispatching\Struct\ActionSequence;
use Shopware\Core\Framework\Context;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
// Import dependencies

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    private {TargetClass} $action;
    // Declare dependency properties

    protected function setUp(): void
    {
        // Initialize dependencies
        $this->action = new {TargetClass}(
            // Pass dependencies
        );
    }

    // 1. HAPPY PATH
    #[TestDox('returns correct action name')]
    public function testGetNameReturnsCorrectActionName(): void
    {
        static::assertSame('action.{name}', $this->action::getName());
    }

    #[TestDox('declares required flow event interfaces')]
    public function testRequirementsReturnsExpectedFlowEvents(): void
    {
        $requirements = $this->action->requirements();

        static::assertContains(ExpectedAware::class, $requirements);
    }

    #[TestDox('executes action when flow contains required data')]
    public function testHandleFlowExecutesAction(): void
    {
        // Arrange
        $flow = $this->createStorableFlow([
            'orderId' => 'test-order-id',
        ]);
        $sequence = new ActionSequence();
        $sequence->action = $this->action::getName();
        $sequence->config = ['key' => 'value'];

        // Act
        $this->action->handleFlow($flow);

        // Assert - verify action was executed
    }

    // 4. EDGE CASES
    #[TestDox('skips execution when flow data is missing')]
    public function testHandleFlowWithMissingDataSkipsExecution(): void
    {
        // Arrange
        $flow = $this->createStorableFlow([]);

        // Act
        $this->action->handleFlow($flow);

        // Assert - verify action was skipped
    }

    private function createStorableFlow(array $data): StorableFlow
    {
        $flow = new StorableFlow('test.event', Context::createDefaultContext(), $data);

        return $flow;
    }
}
```

## Flow Storer Template

```php
<?php declare(strict_types=1);

namespace Shopware\Tests\Unit\Core\{Module}\{Submodule};

use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\TestDox;
use PHPUnit\Framework\TestCase;
use Shopware\Core\Content\Flow\Dispatching\StorableFlow;
use Shopware\Core\Content\Flow\Events\BeforeLoadStorableFlowDataEvent;
use Shopware\Core\Framework\Context;
use Shopware\Core\{Module}\{Submodule}\{TargetClass};
// Import dependencies

#[CoversClass({TargetClass}::class)]
class {TargetClass}Test extends TestCase
{
    private {TargetClass} $storer;

    protected function setUp(): void
    {
        $this->storer = new {TargetClass}(
            // Pass dependencies
        );
    }

    // 1. HAPPY PATH
    #[TestDox('stores event data to flow storage array')]
    public function testStoreAddsDataToStoredArray(): void
    {
        // Arrange
        $event = new TestFlowEvent(/* data */);
        $stored = [];

        // Act
        $stored = $this->storer->store($event, $stored);

        // Assert
        static::assertArrayHasKey('{key}', $stored);
        static::assertSame($expectedValue, $stored['{key}']);
    }

    #[TestDox('restores data from stored array to flow')]
    public function testRestoreLoadsDataFromStored(): void
    {
        // Arrange
        $stored = ['{key}' => 'stored-value'];
        $flow = new StorableFlow('test', Context::createDefaultContext(), $stored);

        // Act
        $this->storer->restore($flow);

        // Assert
        static::assertTrue($flow->hasData('{key}'));
        static::assertSame('stored-value', $flow->getData('{key}'));
    }

    // 4. EDGE CASES
    #[TestDox('skips restore when key not in stored data')]
    public function testRestoreWithMissingKeySkipsRestore(): void
    {
        // Arrange
        $stored = [];
        $flow = new StorableFlow('test', Context::createDefaultContext(), $stored);

        // Act
        $this->storer->restore($flow);

        // Assert
        static::assertFalse($flow->hasData('{key}'));
    }
}
```

## Event Dispatcher Verification

EventDispatcher is acceptable to mock for verifying event dispatch behavior.

```php
#[TestDox('dispatches event on successful operation')]
public function testDispatchesEventOnSuccess(): void
{
    // Arrange
    $eventDispatcher = $this->createMock(EventDispatcherInterface::class);
    $eventDispatcher
        ->expects($this->once())
        ->method('dispatch')
        ->with(static::callback(function ($event) {
            return $event instanceof ExpectedEvent
                && $event->getProperty() === 'expected';
        }));

    $subject = new {TargetClass}($eventDispatcher);

    // Act
    $subject->doSomething();
}
```
