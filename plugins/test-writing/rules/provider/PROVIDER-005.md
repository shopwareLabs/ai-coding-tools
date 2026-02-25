---
id: PROVIDER-005
title: PHPUnit 11.5 Features
legacy: I003
group: provider
enforce: consider
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## PROVIDER-005 — PHPUnit 11.5 Features

**Scope**: A,B,C,D,E | **Enforce**: Consider

Test could use modern PHPUnit features.

### Available Features

- `#[TestWithJson]` for inline data providers
- `#[TestDox]` for documentation
- `#[CoversClass]` for coverage
- `expectUserDeprecationMessageMatches()` for deprecations

### TestWithJson Attribute

Inline data provider for simple cases:

```php
#[TestWithJson('["valid@email.com", true]')]
#[TestWithJson('["invalid", false]')]
#[TestDox('validates email $email expecting $valid')]
public function testEmailValidation(string $email, bool $valid): void
{
    static::assertEquals($valid, $this->validator->isValid($email));
}
```

### When to Suggest

- Simple test cases with scalar arguments
- 5 or fewer data sets
- No complex object construction needed
