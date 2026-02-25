---
id: CONV-017
title: Single-Use Test Property
legacy: W016
group: convention
enforce: should-fix
test-types: all
test-categories: B,C,D
scope: general
---

## Single-Use Test Property

**Scope**: B,C,D | **Enforce**: Should fix

A test property is assigned in `setUp()` but only referenced in one test method. Inline the construction at the usage site to reduce indirection.

### Detection

Trigger when ALL of these are true:
1. A `private` property is declared on the test class
2. It is assigned in `setUp()`
3. It is referenced in exactly one test method (excluding `setUp()` itself)

```php
// CONV-017 - $cacheFinalizer only used in one test
private CacheFinalizer $cacheFinalizer;

protected function setUp(): void
{
    $this->cacheTagCollector = $this->createStub(CacheTagCollector::class);
    $this->cacheFinalizer = new CacheFinalizer($this->cacheTagCollector);
    $this->route = new ContentRoute($this->loader, $this->cacheFinalizer);
}
```

Do NOT flag when:
- Property is used in 2+ test methods (shared setup is justified)
- Property is a mock/stub that also appears in assertions or `expects()` calls
- Property is the system-under-test (`$this->service`, `$this->route`)

### Fix

```php
// CORRECT - inline at usage site
protected function setUp(): void
{
    $this->cacheTagCollector = $this->createStub(CacheTagCollector::class);
    $this->route = new ContentRoute($this->loader, new CacheFinalizer($this->cacheTagCollector));
}
```
