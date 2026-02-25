---
id: CONV-010
title: Implementation-Specific Terminology
legacy: W001
group: convention
enforce: should-fix
test-types: all
test-categories: A,B,C,D
scope: general
---

## Implementation-Specific Terminology

**Scope**: A,B,C,D | **Enforce**: Should fix

Test names should describe behavior in business language, not implementation details.

### Detection

```php
// INCORRECT - mentions framework/implementation
public function testSymfonyValidatorIntegration(): void
public function testDoctrineQueryBuilderUsage(): void
public function testRedisConnectionHandling(): void
```

### Fix

```php
// CORRECT - describes behavior
public function testValidatesUserInput(): void
public function testFindsActiveProducts(): void
public function testHandlesCacheConnectionFailure(): void
```
