---
id: DESIGN-004
title: Test Redundancy
legacy: E009
group: design
enforce: must-fix
test-types: all
test-categories: A,B,C,D,E
scope: general
---

## Test Redundancy

**Scope**: A,B,C,D,E | **Enforce**: Must fix

Tests MUST NOT have redundant coverage. Every test case (in data providers) and every test method MUST cover a unique code path.

### Core Question

For each test case or method, ask: **"What unique code path does this cover?"**

### Valid Justifications

| Type | Description | Key Pattern |
|------|-------------|-------------|
| Code path | Exercises branch not covered by other cases | `'negative triggers error path'` |
| Boundary | Tests at exact threshold | `'exactly 100 hits limit'` |
| Regression | Prevents specific bug | `'unicode fix (bug #1234)'` |

### Invalid Justifications

| Pattern | Problem | Example |
|---------|---------|---------|
| Magnitude variations | Same code path, different scale | `'small value'`, `'large value'` |
| Synonym variations | Same behavior, different input format | `'with space'`, `'with tab'` (if treated identically) |
| "Another example" | No unique coverage value | `'valid email 1'`, `'valid email 2'` |

### Detection — Data Provider Redundancy

```php
// DESIGN-004 - keys describe WHAT, not WHY
public static function timeProvider(): iterable
{
    yield 'A much greater than B' => [now + 1000, now];
    yield 'A greater than B' => [now + 100, now];
    yield 'A slightly greater than B' => [now + 1, now];
}
```

All three cases exercise the same `A > B` code path. Only one is justified.

### Fix — Data Provider

```php
// CORRECT - each case has unique justification
public static function timeProvider(): iterable
{
    yield 'future time triggers refresh' => [now + 1, now];  // A > B path
    yield 'same time uses cache' => [now, now];              // A == B path
    yield 'past time returns stale' => [now - 1, now];       // A < B path
}
```

### Detection — Redundant Methods

```php
// INCORRECT - Both methods trigger root match path
public function testExtractsElementById(): void
{
    $result = $this->extractor->extract($root, 'root-id');
    static::assertSame('root-id', $result->getId());
}

public function testReturnedElementIsClone(): void
{
    $result = $this->extractor->extract($root, 'root-id');  // Same path!
    static::assertNotSame($root, $result);
}
```

### Fix — Merge Methods

```php
public function testExtractsElementByIdAndReturnsClone(): void
{
    $result = $this->extractor->extract($root, 'root-id');

    static::assertSame('root-id', $result->getId());
    static::assertNotSame($root, $result);
}
```

### Worked Example: SubTreeExtractor

Source class `SubTreeExtractor::extract()` has 3 code paths:
- PATH 1: `root.getId() === targetId` (root match)
- PATH 2: Recursive search finds child
- PATH 3: Returns null (not found)

**Before (violation -- 2 tests on PATH 1):**
```php
#[TestDox('extracts root element when target ID matches root')]
public function testExtractRootElement(): void
{
    $root = new ContentElement(id: 'root', component: 'root-component');
    $result = $this->extractor->extract($root, 'root');
    static::assertSame('root', $result->getId());
    static::assertSame('root-component', $result->getComponent());
}

#[TestDox('returns cloned instance not same reference when extracting root')]
public function testExtractRootReturnsClone(): void
{
    $root = new ContentElement(id: 'root', component: 'root-component');
    $result = $this->extractor->extract($root, 'root');  // Same PATH 1!
    static::assertNotSame($root, $result);
}
```

**After (merged):**
```php
#[TestDox('extracts root element and returns cloned instance')]
public function testExtractRootElementReturnsClone(): void
{
    $root = new ContentElement(id: 'root', component: 'root-component');

    $result = $this->extractor->extract($root, 'root');

    static::assertNotNull($result);
    static::assertSame('root', $result->getId());
    static::assertSame('root-component', $result->getComponent());
    static::assertNotSame($root, $result);  // Clone verification
}
```

### Relationship to PROVIDER-001

| Rule | Checks | Fails On |
|------|--------|----------|
| PROVIDER-001 | Key is descriptive | `'case1'`, `'test_1'` |
| DESIGN-004 | Key justifies existence | `'small positive'`, `'large positive'` |

A case can pass PROVIDER-001 (descriptive) but fail DESIGN-004 (unjustified):

```php
// Passes PROVIDER-001, FAILS DESIGN-004 - same code path
yield 'small positive number' => [1];
yield 'large positive number' => [1000];

// Passes BOTH - different code paths
yield 'positive triggers success' => [1];
yield 'negative triggers error' => [-1];
```

### When Multiple Similar Cases ARE Justified

```php
// JUSTIFIED - different sub-behaviors documented
yield 'ASCII username (fast path)' => ['john', true];
yield 'Unicode username (normalization path)' => ['jöhn', true];  // triggers NFD normalization

// JUSTIFIED - regression tests with citations
yield 'plus in local part (bug #1234)' => ['user+tag@example.com', true];
yield 'consecutive dots (bug #5678)' => ['user..name@example.com', false];
```

### Justification Checklist

For each test case, verify at least ONE:
- **Different code path**: Does this case execute different branches than other cases?
- **Boundary value**: Is this the exact threshold where behavior changes?
- **Regression**: Does this prevent a specific bug from recurring (cite issue)?

If none apply, the case is redundant (DESIGN-004).

### Detection Algorithm

1. **Read source class** and identify distinct code paths:
   - List branches/conditions in each public method
   - Note boundary conditions and error paths

2. **Build test-to-path mapping table** (REQUIRED OUTPUT):

   | Test Method | Calls | Inputs | Code Path Triggered |
   |-------------|-------|--------|---------------------|

3. **Group by code path** and flag groups with 2+ tests

4. **Check preservation indicators** before flagging:
   - Regression markers: `Regression`, `Bug`, `Issue`, `#\d+`, `SW-`, `JIRA-`
   - If present, report the preservation-value rule (DESIGN-008) instead

5. **Generate fix**:
   - Merge methods into single test with multiple assertions
   - Or consolidate to data provider if 3+ similar cases
   - **NEVER delete** a test method that is the sole coverage of any code path
   - **NEVER collapse** a data provider test into a single parameterless test
