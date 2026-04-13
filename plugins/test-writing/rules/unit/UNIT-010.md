---
id: UNIT-010
title: No Error Suppression on Deprecated Code
group: unit
enforce: must-fix
test-types: unit
test-categories: A,B,C,D,E
scope: shopware
---

## No Error Suppression on Deprecated Code

**Scope**: A,B,C,D,E | **Enforce**: Must fix

The `@` error suppression operator MUST NOT be used to silence deprecation warnings in tests. It is ineffective in Shopware's test infrastructure:

- **Flag active** (default in CI via `FeatureFlagExtension`): `Feature::triggerDeprecationOrThrow()` throws `FeatureException`. The `@` operator cannot suppress exceptions.
- **Flag inactive** (via `#[DisabledFeatures]`): `triggerDeprecationOrThrow()` checks the `TESTS_RUNNING` env var and silently returns. No deprecation is emitted. `@` suppresses nothing.

The `@` operator only has effect in the narrow case where `TESTS_RUNNING` is falsy, the flag is inactive, and `$emitDeprecations` is true — a combination that does not occur in normal unit test runs.

### Detection

Scan test file for `@` operator immediately before:
- Method calls: `@$object->method(`, `@$this->service->method(`
- Static calls: `@Class::method(`
- Instantiation: `@new Class(`

Where the called code is deprecated (has `@deprecated` tag or calls `Feature::triggerDeprecationOrThrow()`).

```php
// INCORRECT - @ cannot suppress the FeatureException thrown when flags are active
public function testUploadFromLocalPathFileNotFound(): void
{
    $this->expectException(MediaException::class);

    @$this->mediaUploadService->uploadFromLocalPath($filePath, $this->context, $params);
}
```

### Fix

Remove the `@` operator and add `#[DisabledFeatures]` on the method (see UNIT-007 for full guidance — `Feature::skipTestIfActive()` is not a valid substitute in unit tests, it silently skips the test body):

```php
// CORRECT - proper guard instead of suppression
#[DisabledFeatures(['v6.8.0.0'])]
public function testUploadFromLocalPathFileNotFound(): void
{
    $this->expectException(MediaException::class);

    $this->mediaUploadService->uploadFromLocalPath($filePath, $this->context, $params);
}
```
