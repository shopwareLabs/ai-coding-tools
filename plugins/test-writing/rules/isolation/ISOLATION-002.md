---
id: ISOLATION-002
title: Non-Deterministic Inputs
group: isolation
enforce: must-fix
test-types: all
test-categories: A,B,C,D
scope: general
---

## Non-Deterministic Inputs

**Scope**: A,B,C,D | **Enforce**: Must fix

Functions producing different results each run make tests non-repeatable.

### Functions to Detect

| Flag | Skip |
|------|------|
| `new \DateTime()` (no argument) | `new \DateTime('2024-01-01')` |
| `time()`, `microtime()` | `$this->createMock(\DateTimeInterface::class)` |
| `random_int()`, `mt_rand()`, `rand()` | Data provider context |
| `uniqid()`, `uuid_create()` | |

### Detection

```php
// INCORRECT - non-deterministic
public function testGeneratesReport(): void
{
    $result = $this->service->generate(new \DateTime());  // Non-deterministic
}
```

### Fix

```php
// CORRECT - fixed date
public function testGeneratesReport(): void
{
    $date = new \DateTime('2024-01-15 10:00:00');
    $result = $this->service->generate($date);
}
```
