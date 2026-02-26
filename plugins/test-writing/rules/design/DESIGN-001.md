---
id: DESIGN-001
title: No Conditional Logic in Tests
group: design
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## No Conditional Logic in Tests

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Tests MUST NOT contain conditional logic. Each test requires a single execution path.

### Prohibited Patterns

- `if/else` statements
- `switch/match` expressions
- Ternary operators (`?:`) for control flow
- Conditional assertions

### Detection

```php
// INCORRECT - conditional in test
public function testValidation($value, $shouldPass): void
{
    $result = $this->validator->validate($value);
    if ($shouldPass) {
        static::assertTrue($result->isValid());
    } else {
        static::assertFalse($result->isValid());
    }
}
```

### Fix — Split Methods

```php
#[TestWithJson('["valid@email.com"]')]
#[TestWithJson('["user.name@domain.org"]')]
#[TestDox('accepts valid email: $value')]
public function testAcceptsValidEmail(string $value): void
{
    $result = $this->validator->validate($value);
    static::assertTrue($result->isValid());
}

#[TestWithJson('["invalid-email"]')]
#[TestWithJson('["@nodomain"]')]
#[TestDox('rejects invalid email: $value')]
public function testRejectsInvalidEmail(string $value): void
{
    $result = $this->validator->validate($value);
    static::assertFalse($result->isValid());
}
```
