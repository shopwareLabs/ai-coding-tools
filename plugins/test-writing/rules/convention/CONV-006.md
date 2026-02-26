---
id: CONV-006
title: TestDox Phrasing
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: phpunit
---

## TestDox Phrasing

**Scope**: A,B,C,D,E | **Enforce**: Must fix

TestDox content MUST follow phrasing guidelines for consistent, readable documentation.

### Required Format

TestDox must be a **predicate phrase** with:
- **Active voice** (not passive)
- **Present tense** (not future)
- **Action verb start** (not "it", "should", "tests")
- **Third person** (implicit subject)

### Detection Patterns

| Pattern | Issue |
|---------|-------|
| `#[TestDox('It creates...')]` | BDD "it" prefix |
| `#[TestDox('Should create...')]` | BDD "should" prefix |
| `#[TestDox('Product is created')]` | Passive voice |
| `#[TestDox('Tests that...')]` | Redundant "tests" |
| `#[TestDox('Will return...')]` | Future tense |
| `#[TestDox('The product...')]` | Article start |

### Detection — Passive Voice

```php
// INCORRECT
#[TestDox('product is created with valid data')]
#[TestDox('exception is thrown for invalid input')]
```

### Fix — Active Voice

```php
// CORRECT
#[TestDox('creates product with valid data')]
#[TestDox('throws exception for invalid input')]
```

### Detection — BDD Style

```php
// INCORRECT
#[TestDox('It creates a product')]
#[TestDox('Should create a product')]
```

### Fix — Action Verb Start

```php
// CORRECT
#[TestDox('creates product')]
#[TestDox('validates email')]
```

### Valid Examples

```php
#[TestDox('creates product with valid data')]
#[TestDox('returns null when product not found')]
#[TestDox('throws exception for negative price')]
#[TestDox('validates email format $email')]
#[TestDox('accepts unicode characters in name')]
```

### With Data Provider Parameters

```php
#[DataProvider('emailProvider')]
#[TestDox('validates email $email as $validity')]
public function testEmailValidation(string $email, string $validity): void
```

### Common Verb Patterns

| Category | Verbs | Example |
|----------|-------|---------|
| Creation | creates, generates, builds | "creates order from cart" |
| Retrieval | returns, finds, loads, gets | "returns null when not found" |
| Validation | validates, accepts, rejects | "rejects invalid email format" |
| State | is, has, contains | "has correct default values" |
| Exception | throws, fails | "throws on negative price" |
| Transformation | converts, transforms, maps | "converts price to cents" |

### Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| `It creates...` | BDD-style "it" prefix | `creates...` |
| `Should create...` | BDD-style "should" | `creates...` |
| `Product is created` | Passive voice | `creates product` |
| `Tests that...` | Redundant "tests" | Remove prefix |
| `testMethodName` | Just method name | Describe behavior |
| `Will return...` | Future tense | `returns...` |

### Relationship to CONV-003

| Rule | Validates | Example |
|------|-----------|---------|
| CONV-003 | Method name | `testCreatesProductWithValidData` |
| CONV-006 | TestDox content | `#[TestDox('creates product with valid data')]` |
