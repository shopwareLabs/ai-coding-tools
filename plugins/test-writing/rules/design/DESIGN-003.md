---
id: DESIGN-003
title: Missing Data Provider for 3+ Similar Tests
legacy: E007
group: design
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## Missing Data Provider for 3+ Similar Tests

**Scope**: A,B,C,D,E | **Enforce**: Must fix

When 3+ tests verify similar variations, consolidate with a data provider.

### Detection

```php
// INCORRECT - redundant similar tests
public function testAcceptsStandardEmail(): void
{
    static::assertTrue($this->validator->validate('user@example.com'));
}

public function testAcceptsEmailWithSubdomain(): void
{
    static::assertTrue($this->validator->validate('user@mail.example.com'));
}

public function testAcceptsEmailWithPlus(): void
{
    static::assertTrue($this->validator->validate('user+tag@example.com'));
}
```

### Fix — Data Provider

```php
public static function validEmailProvider(): iterable
{
    yield 'standard email' => ['user@example.com'];
    yield 'with subdomain' => ['user@mail.example.com'];
    yield 'with plus tag' => ['user+tag@example.com'];
}

#[DataProvider('validEmailProvider')]
#[TestDox('accepts valid email format: $email')]
public function testAcceptsValidEmail(string $email): void
{
    static::assertTrue($this->validator->validate($email));
}
```

### Fix — TestWithJson (PHPUnit 11.5+)

For small inline datasets (5 or fewer cases):

```php
#[TestWithJson('["user@example.com"]')]
#[TestWithJson('["user@mail.example.com"]')]
#[TestWithJson('["user+tag@example.com"]')]
#[TestDox('accepts valid email format: $email')]
public function testAcceptsValidEmail(string $email): void
{
    static::assertTrue($this->validator->validate($email));
}
```

### When to Use Each Approach

| Approach | Best For |
|----------|----------|
| `#[TestWithJson]` | 5 or fewer simple inline cases |
| `#[DataProvider]` | Large datasets, complex objects |
| `#[DataProvider]` | Shared data across tests |
| `#[DataProvider]` | Dynamic data generation |
