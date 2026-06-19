---
id: INTEGRATION-001
title: Integration test uses Shopware integration base
group: integration
enforce: must-fix
test-types: integration
test-categories: all
scope: shopware
review-unit: method
---

## Integration test uses Shopware integration base

**Scope**: all | **Enforce**: Must fix

Integration tests must use `IntegrationTestBehaviour` (or extend a Shopware base class that pulls it in, e.g. `\Shopware\Core\Framework\Test\TestCaseBase\IntegrationTestBehaviour` trait alongside `TestCase`). Manual `KernelLifecycleManager` boot, ad-hoc container construction, or pure `TestCase` extension without the trait skips the established lifecycle, transaction rollback, and shared kernel reuse the rest of the suite depends on.

### Detection

1. Read class declaration and `use` statements.
2. Class must either:
   - `use IntegrationTestBehaviour;` (most common), or
   - Extend a Shopware base class that already pulls it in.
3. Flag if the class extends `TestCase` directly without any of the above, especially if `setUp()` calls `KernelLifecycleManager::bootKernel()`, instantiates `Kernel::getContainer()` manually, or constructs services via DI by hand.

```php
// INCORRECT - manual kernel boot
class OrderIndexerTest extends TestCase
{
    private ContainerInterface $container;

    protected function setUp(): void
    {
        $this->container = KernelLifecycleManager::bootKernel()->getContainer();
    }
}
```

### Fix

```php
// CORRECT - uses the established integration base
class OrderIndexerTest extends TestCase
{
    use IntegrationTestBehaviour;

    public function testIndexerRebuildsOrderState(): void
    {
        $repository = static::getContainer()->get('order.repository');
        // ...
    }
}
```
