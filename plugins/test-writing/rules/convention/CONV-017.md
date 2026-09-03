---
id: CONV-017
title: Single-Use Test Property
group: convention
enforce: should-fix
test-types: all
test-categories: B,C,D
scope: general
review-unit: class-bodies
scoped-review: exclude
---

## Single-Use Test Property

**Scope**: B,C,D | **Enforce**: Should fix

A test property is assigned in `setUp()` but only referenced in one test method. Inline the construction at the usage site to reduce indirection.

Counting a property's references requires every test body in the class, so evaluate this rule over the whole class, never over one method.

### Detection

Trigger when ALL of these are true:
1. A `private` property is declared on the test class
2. It is assigned in `setUp()`
3. It is referenced in exactly one test method (excluding `setUp()` itself)

```php
// CONV-017 - $cacheFinalizer's only reference outside its own assignment is inside one test method
private CacheFinalizer $cacheFinalizer;

protected function setUp(): void
{
    $this->cacheTagCollector = $this->createStub(CacheTagCollector::class);
    $this->cacheFinalizer = new CacheFinalizer($this->cacheTagCollector);
    $this->route = new ContentRoute($this->loader, $this->cacheTagCollector);
}

public function testFinalizeMarksResponsePublic(): void
{
    $response = new Response();

    $this->cacheFinalizer->finalize($response);   // the sole reference

    static::assertSame('public', $response->headers->get('Cache-Control'));
}
```

Do NOT flag when:
- Property is used in 2+ test methods (shared setup is justified)
- Property is a mock/stub that also appears in assertions or `expects()` calls
- Property is the system-under-test (`$this->service`, `$this->route`)

### Fix

Relocate the construction into the one test method that references it and drop the property declaration. `setUp()` keeps every collaborator the remaining properties still need.

```php
// CORRECT - constructed in its only consumer; $cacheTagCollector stays because $this->route needs it
protected function setUp(): void
{
    $this->cacheTagCollector = $this->createStub(CacheTagCollector::class);
    $this->route = new ContentRoute($this->loader, $this->cacheTagCollector);
}

public function testFinalizeMarksResponsePublic(): void
{
    $cacheFinalizer = new CacheFinalizer($this->cacheTagCollector);
    $response = new Response();

    $cacheFinalizer->finalize($response);

    static::assertSame('public', $response->headers->get('Cache-Control'));
}
```
