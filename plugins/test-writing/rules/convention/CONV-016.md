---
id: CONV-016
title: Test Prefix on Helper Class
legacy: W017
group: convention
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## Test Prefix on Helper Class

**Scope**: A,B,C,D,E | **Enforce**: Should fix

The `Test` prefix/suffix is reserved for classes extending `TestCase`. Helper classes in `_helper/` directories or defined inline should use a name reflecting their role.

### Detection

Flag when a class in a test helper directory (or defined inline in a test file) uses `Test` as a prefix and does NOT extend `TestCase`.

```php
// CONV-016 - TestContextStruct is not a test, it's a stub
// File: tests/unit/Core/Content/_helper/TestContextStruct.php
class TestContextStruct extends ContextStruct
{
    // ...
}
```

Do NOT flag:
- Classes extending `TestCase` (these ARE tests)
- Classes with `Test` in the middle of the name (e.g., `CartTestFixture` — `Test` is not the prefix)

### Fix

Name after the role: `Stub*`, `Fake*`, `Fixed*`, or a domain-specific descriptor.

```php
// CORRECT
class StubContextStruct extends ContextStruct { }
class FakePaymentHandler implements PaymentHandlerInterface { }
class FixedClockService implements ClockInterface { }
```
