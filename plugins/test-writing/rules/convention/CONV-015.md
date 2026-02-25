---
id: CONV-015
title: Package Attribute on Test Class
legacy: W014
group: convention
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: shopware
---

## Package Attribute on Test Class

**Scope**: A,B,C,D,E | **Enforce**: Should fix

Shopware's `#[Package(...)]` attribute identifies source-class ownership. It has no meaning on test classes.

### Detection

```php
// INCORRECT - #[Package] on test class
#[Package('core')]
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
```

### Fix

```php
// CORRECT - remove #[Package], keep #[CoversClass]
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
```

### Why

- `#[Package]` is a Shopware architecture annotation for source code organisation; test classes have no package ownership role
- Presence on test classes is copy-paste noise from the source class
- No functional impact, but misleads tooling and contributors
