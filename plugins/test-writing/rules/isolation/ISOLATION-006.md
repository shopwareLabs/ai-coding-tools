---
id: ISOLATION-006
title: Real Fixture Files
group: isolation
enforce: consider
test-types: all
test-categories: B,C
scope: general
---

## Real Fixture Files

**Scope**: B,C | **Enforce**: Consider

Tests validating file I/O using inline content strings are candidates for real fixture files in a `_fixtures/` directory. Applies to importers, exporters, parsers, or file processors.

### Detection

Tests with inline file content creation rather than fixture files:
- Large heredoc/nowdoc (`<<<`) file content in test methods
- `file_put_contents()` with inline string content (not reading from fixture)
- `fwrite()` or `SplFileObject::fwrite()` with inline content
- Mock objects returning hardcoded file content strings for file-processing tests
- Multi-step content creation: building strings, then writing to temp files

### Bad Example

```php
public function testParsesTranslationFile(): void
{
    $content = '{"key": "value", "nested": {"inner": "data"}}';
    file_put_contents($this->tempDir . '/en.json', $content);

    $result = $this->parser->parse($this->tempDir . '/en.json');

    static::assertSame('value', $result['key']);
}
```

### Good Example (Shopware pattern: copy fixtures in setUp, clean in tearDown)

```php
protected function setUp(): void
{
    $this->tempDir = sys_get_temp_dir() . '/test-' . uniqid();
    (new Filesystem())->mirror(__DIR__ . '/_fixtures/translations', $this->tempDir);
}

protected function tearDown(): void
{
    (new Filesystem())->remove($this->tempDir);
}

public function testParsesTranslationFile(): void
{
    $result = $this->parser->parse($this->tempDir . '/en.json');
    static::assertSame('value', $result['key']);
}
```

### When NOT to Flag

- Test reads fixture files directly without copying (acceptable if read-only)
- Test uses vfsStream for virtual file system simulation
- Content is trivial (single-line JSON, simple strings under 50 chars)
- String content isn't written to any file or stream

**Alternative**: vfsStream is acceptable for simple cases, but real fixtures are preferred when testing actual file parsing or complex I/O scenarios.

**Note**: See `LintTranslationFilesCommandTest`, `ManifestTest`, `AppLoaderTest` for Shopware examples of this pattern.
