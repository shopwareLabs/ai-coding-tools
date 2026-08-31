---
id: CONV-015
title: Package Attribute on Test Class
group: convention
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: shopware
review-unit: class-structure
scoped-review: exclude
---

## Package Attribute on Test Class

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Shopware's `#[Package(...)]` attribute identifies domain ownership. Every test class carries the `#[Package(...)]` value its covered domain carries, so a failing CI job routes to the owning team.

Report one finding per class, never one per method.

Evaluable on both decomposition tracks: the structural digest carries the class declaration and its attribute lines, so a digest-track reviewer sees whether `#[Package]` is present without reading the file.

### Detection

```php
// INCORRECT - no #[Package] on the test class
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
```

### Fix

```php
// CORRECT - #[Package] carries the covered domain's value
use Shopware\Core\Framework\Log\Package;

#[Package('core')]
#[CoversClass(ProductService::class)]
class ProductServiceTest extends TestCase
```

### Package Derivation

The `#[Package]` value of a test class is:

1. The `#[Package]` value of its `#[CoversClass]` target, when the class declares one and that target carries a `#[Package]`.
2. Otherwise the dominant `#[Package]` value among the `.php` files directly inside the `src/` directory the test path mirrors — `tests/{unit,integration,migration}/X/Y/` maps to `src/X/Y/`, walking up until the directory exists. Dominant means most frequent; ties resolve to the first in directory order.
3. Where neither yields a value, the test class carries no `#[Package]` and the condition is reported rather than guessed.

Unit and migration tests reach a value through rule 1. Integration tests carry no `#[CoversClass]` and reach a value through rule 2.

### Why

- Shopware's Danger rule `MissingPackageAttributeInTests` fails a pull request that adds a `tests/**/*Test.php` file without the attribute
- The attribute routes a failing CI job — nightlies especially — to the owning domain team without guessing
