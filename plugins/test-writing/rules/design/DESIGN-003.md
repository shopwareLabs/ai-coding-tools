---
id: DESIGN-003
title: Missing Data Provider for 3+ Similar Tests
group: design
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
review-unit: class-bodies
scoped-review: include
---

## Missing Data Provider for 3+ Similar Tests

**Scope**: A,B,C,D,E | **Enforce**: Must fix

When 3+ tests verify similar variations, consolidate with a data provider.

### Static Constraint

Data provider methods are declared `public static function`. PHPUnit invokes them without a test-case instance, so `$this` is unavailable inside a provider body. A provider uses `self::`, `static::`, or constants.

A case that needs instance state is a separate test method, not a provider row.

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

### Similar Bodies Are Not Enough — Check the Assertions Too

Similarity for this rule is not established by matching arrange/act code alone. Two tests can read almost identically and still verify different things: consolidating them into one provider row is safe only when their assertions differ solely in the discriminating value, never in what they check. Before proposing a merge, read every candidate test's assertions and confirm none of them asserts a detail the others omit — a body match paired with a distinguishing assertion is not "3+ similar tests" under this rule, and stays as separate methods regardless of how alike the setup looks.

A finding that folds tests into an **existing** data provider names that provider and confirms the fold does not contradict its documented scope: a provider whose docblock or key naming claims a specific input tier (for example, "valid emails only") does not absorb a case outside that tier just because the test bodies look alike.

Shopware's guideline states the fold condition and its limit: "Fold two tests into one provider when they differ only in their input and their expectation; pass the discriminating value together with the expectation instead of copying the whole scenario. This does not override the rule above about keeping one focused test per distinct behavior: a case that carries its own meaning stays its own test."
