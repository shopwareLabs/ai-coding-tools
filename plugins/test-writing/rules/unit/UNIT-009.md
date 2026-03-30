---
id: UNIT-009
title: No Dedicated Tests for Abstract Classes
group: unit
enforce: must-fix
test-types: unit
test-categories: A,B,C,D,E
scope: general
---

## No Dedicated Tests for Abstract Classes

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Test classes MUST NOT directly test abstract classes. Abstract classes cannot be instantiated — tests that create anonymous subclasses or mocks solely to exercise the abstract class couple to internal structure rather than observable behavior. Test concrete implementations instead.

### Detection Algorithm

1. Read the class referenced by `#[CoversClass(...)]`
2. If the source class declaration contains `abstract class` → **violation**

Secondary signals (confirm violation, not standalone triggers):

- Anonymous subclass instantiation: `new class(...) extends AbstractFoo {}`
- Mock of the abstract class used as the primary SUT (not as a collaborator)
- Test method names referencing the abstract class directly (e.g., `testAbstractHandlerProcesses`)

### Detection

```php
// INCORRECT - dedicated test for abstract class using anonymous subclass
#[CoversClass(AbstractPaymentHandler::class)]
class AbstractPaymentHandlerTest extends TestCase
{
    public function testProcessesPayment(): void
    {
        $handler = new class($this->createStub(Logger::class)) extends AbstractPaymentHandler {
            protected function doHandle(Transaction $tx): bool
            {
                return true;
            }
        };

        $result = $handler->process($this->transaction);

        static::assertTrue($result);
    }
}
```

```php
// INCORRECT - mocking abstract class to test its concrete methods
#[CoversClass(AbstractImporter::class)]
class AbstractImporterTest extends TestCase
{
    public function testValidatesInput(): void
    {
        $importer = $this->getMockForAbstractClass(AbstractImporter::class);

        $this->expectException(InvalidArgumentException::class);
        $importer->import([]);
    }
}
```

### Fix

Delete the test file. The concrete methods of the abstract class are covered through tests of its concrete implementations.

```php
// CORRECT - test a concrete implementation instead
#[CoversClass(StripePaymentHandler::class)]
class StripePaymentHandlerTest extends TestCase
{
    public function testProcessesPayment(): void
    {
        $handler = new StripePaymentHandler(
            $this->createStub(Logger::class),
            $this->createStub(StripeClient::class),
        );

        $result = $handler->process($this->transaction);

        static::assertTrue($result);
    }
}
```

### Why Not Test Abstract Classes Directly

1. **Anonymous subclasses test a class that doesn't exist in production** — behavior depends on the real subclass implementation
2. **`getMockForAbstractClass()` hides real interactions** — mock stubs out the abstract methods, removing the very code paths that define the class's behavior
3. **Concrete implementation tests already cover the inherited methods** — if they don't, the concrete test is incomplete
4. **Refactoring the abstract class breaks the anonymous subclass** — creating coupling to internal structure rather than public API
