---
id: DESIGN-009
title: Duplicated Inline Arrange Code
legacy: I009
group: design
enforce: consider
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## Duplicated Inline Arrange Code

**Scope**: A,B,C,D,E | **Enforce**: Consider

Two or more test methods repeat the same object construction boilerplate when the object is already available from `setUp()` or could be extracted to a private helper.

**When to mention**: Two or more test methods contain 5+ nearly identical consecutive lines of construction (same class instantiation, same arguments).

**Skip when**: Inline construction has intentionally different arguments -- variation is the point.

### Detection

```php
// DESIGN-009 - identical construction in multiple test methods; could be a private helper
public function testEncodeThrowsOnInvalidValueType(): void
{
    $validator = new PassthroughConstraintValidator();
    $serializer = new CriteriaFilterFieldSerializer($validator);  // Duplicates setUp()
    ...
}

public function testEncodeThrowsOnInvalidItemType(): void
{
    $validator = new PassthroughConstraintValidator();
    $serializer = new CriteriaFilterFieldSerializer($validator);  // Same duplication
    ...
}
```

### Fix

Use the `$this->serializer` already initialised in `setUp()`, or extract a `private createSerializer(...): SerializerClass` helper placed after all test methods.
