---
id: ISOLATION-003
title: Mystery Guest File Dependency
group: isolation
enforce: should-fix
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## Mystery Guest File Dependency

**Scope**: A,B,C,D,E | **Enforce**: Should fix

External file dependencies obscure test intent. Find `file_get_contents()`, `include`, `require`, `fopen()` calls.

### Skip (Acceptable Patterns)

- `__DIR__ . '/_fixtures/'`, `'/fixtures/'`, `'/Fixture/'`
- Sibling fixtures: `__DIR__ . '/../fixtures/'`
- Binary test files: `__DIR__ . '/shopware-logo.png'`
- Stub files: `__DIR__ . '/template.stub'`
- Bootstrap: `vendor/autoload.php`

### Flag

- Absolute paths: `/home/user/data.json`
- Source file access: `__DIR__ . '/../../../src/Config.php'`
- Cross-test fixtures: `__DIR__ . '/../OtherTest/_fixtures/`
- Dynamic glob without fixture context

### Detection

```php
// FLAG - accessing source files
$config = file_get_contents(__DIR__ . '/../../../src/Resources/config/default.json');

// SKIP - fixture directory
$config = file_get_contents(__DIR__ . '/_fixtures/config.json');
```

### Fix

```php
// Inline fixture (preferred)
$config = ['theme' => 'dark', 'language' => 'en'];
```
