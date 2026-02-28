# PHP Tool Failure Anatomy

## PHPUnit

### Invocation

`php -d memory_limit=-1 vendor/bin/phpunit --testsuite X --log-junit junit.xml`

### Output Anatomy

Progress characters: `.` pass, `F` failure, `E` error, `W` warning, `D` deprecation, `S` skip, `N` notice, `I` incomplete, `R` risky.

Failures section starts with: `There was 1 failure:` or `There were N errors:`

Each failure numbered `1)`, `2)` etc., showing `Class::method` then message then `file:line`.

Summary line: `Tests: N, Assertions: N, Failures: N` (or `Errors: N`, `Warnings: N`, etc.)

Final verdict: `FAILURES!` or `OK` or `OK, but there were issues!`

### Where the Error Is

Always in the last ~200 lines. Search backward from `Tests: N, Assertions:` to find all failure blocks.

### False Positives

- `Detected N tests where the duration exceeded` — slow test warning, NOT a failure
- `D` in progress output — deprecation, NOT a failure
- `W` in progress output — PHP warning, usually not root cause
- `S` in progress output — skipped test, NOT a failure
- `5 tests triggered 6 PHP warnings:` — warning summary, only a failure if exit code is non-zero AND no `F`/`E` markers exist

### Real Example

```
There were 7 errors:

1) Shopware\Tests\Unit\Core\...\SomeTest::testMethod
Error: Call to undefined method ...

/home/runner/work/shopware/shopware/src/Core/.../SomeFile.php:123

Tests: 12280, Assertions: 38203, Errors: 7, Warnings: 2
```

---

## PHPStan

### Invocation

`composer run phpstan -- --error-format=table --no-progress`

### Output Anatomy

Errors appear in TWO forms (both present):

1. `##[error]` annotation lines — one per error, full message on single line
2. Table format — grouped by file, with line numbers, multi-line descriptions, and rule identifiers (with emoji prefix)

Summary: `[ERROR] Found N errors`

Elapsed time and memory usage appear before summary.

### Where the Error Is

After `Note: Using configuration file ...` and before `[ERROR] Found N errors`. The `##[error]` lines appear first, then the table.

### False Positives

- `##[error]Process completed with exit code 1.` — step exit, not a PHPStan error
- Cache-related messages — noise

### Real Example

```
 ------ --------------------------------------------------------------------
  Line   src/Core/Content/Flow/Dispatching/Action/SendMailAction.php
 ------ --------------------------------------------------------------------
  55     Type MailTemplateCollection in generic type ... is not subtype of ...
         🪪  generics.notSubtype
  57     Parameter $mailTemplateRepository ... has invalid type ...
         🪪  class.notFound
 ------ --------------------------------------------------------------------

 [ERROR] Found 15 errors
```

---

## ECS (Easy Coding Standard / PHP-CS-Fixer)

### Invocation

`composer run ecs` (wraps `php-cs-fixer fix --dry-run --diff`)

### Output Anatomy

Progress bars: `2042/8739 [▓▓▓▓▓▓░░░...]` — pure noise, thousands of lines.

Violations listed by file number: `1) /path/to/file.php`

Each violation shows a diff block: `---------- begin diff ----------` / `----------- end diff -----------`

Summary: `Found N of M files that can be fixed in X seconds, Y MB memory used`

Exit: `Script php-cs-fixer fix --dry-run --diff handling the ecs event returned with error code 8`

### Where the Error Is

In the last ~50 lines before the summary. The diff blocks contain the exact changes needed.

### False Positives

- Progress bar lines — ignore completely
- Memory/timing stats — informational only

### Real Example

```
1) /home/runner/.../BusinessEventRegistry.php
      ---------- begin diff ----------
--- Original
+++ New
@@ @@
-    use SomeOldTrait;
+    use SomeNewTrait;
      ----------- end diff -----------

Found 2 of 8739 files that can be fixed
```
