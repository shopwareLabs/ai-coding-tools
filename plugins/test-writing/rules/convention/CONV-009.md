---
id: CONV-009
title: Weak Exception Assertion
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## Weak Exception Assertion

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Tests that verify exception type alone (`expectException(Foo::class)`) without verifying message, code, or the full exception object allow tests to pass even when the wrong exception message or parameters are produced.

### When to Flag

Trigger when ALL of these are true:
1. `expectException(SomeClass::class)` appears in the test
2. No companion `expectExceptionMessage()`, `expectExceptionCode()`, or `expectExceptionObject()` appears
3. The exception class has a parameterized constructor, message template, or factory methods

Do NOT flag when:
- Exception has no meaningful message/parameters (bare `\RuntimeException('error')` for internal guards)
- `expectExceptionObject()` is already used (the strongest form)
- `expectExceptionMessage()` or `expectExceptionCode()` is already present

### Detection

```php
// INCORRECT - type-only assertion
public function testThrowsWhenNotFound(): void
{
    $this->expectException(ContentSystemException::class);  // What message? What parameters?

    $this->service->load('missing-id');
}
```

### Fix 1 — Factory-based exceptions (preferred)

```php
// CORRECT - full object match via factory method
public function testThrowsWhenNotFound(): void
{
    $this->expectExceptionObject(ContentSystemException::elementNotFound('missing-id'));

    $this->service->load('missing-id');
}
```

### Fix 2 — Direct exception assertions

```php
// CORRECT - type + message assertion minimum
public function testThrowsWhenNotFound(): void
{
    $this->expectException(ContentSystemException::class);
    $this->expectExceptionMessage('Element with id "missing-id" was not found');

    $this->service->load('missing-id');
}
```

### Data Provider Exception Testing

```php
public static function exceptionProvider(): iterable
{
    yield 'missing element' => [
        'input' => 'missing-id',
        'exception' => ContentSystemException::elementNotFound('missing-id'),
    ];
    yield 'invalid type' => [
        'input' => 'wrong-type-id',
        'exception' => ContentSystemException::invalidElementType('wrong-type-id', 'cms_page'),
    ];
}

#[DataProvider('exceptionProvider')]
#[TestDox('throws correct exception for $input')]
public function testThrowsCorrectException(string $input, \Throwable $exception): void
{
    $this->expectExceptionObject($exception);

    $this->service->process($input);
}
```
