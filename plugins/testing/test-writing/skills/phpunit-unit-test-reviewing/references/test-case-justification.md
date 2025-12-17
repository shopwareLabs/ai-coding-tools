# Test Case Justification

## Core Principle

Every test case MUST have a justifiable reason for existence. Ask: **"What unique value does this case provide?"**

A test case is justified if it **covers an otherwise uncovered code path**.

## Valid Justifications

| Type | Description | Example Key |
|------|-------------|-------------|
| **Code path** | Exercises branch/condition not covered by other cases | `'negative value triggers error path'` |
| **Boundary** | Tests at exact threshold where behavior changes | `'exactly 100 triggers limit check'` |
| **Regression** | Prevents specific bug from recurring | `'unicode in name (bug #1234)'` |

## Invalid Justifications (E009)

| Pattern | Problem | Example |
|---------|---------|---------|
| Magnitude variations | Same code path, different scale | `'small value'`, `'large value'` |
| Synonym variations | Same behavior, different input format | `'with space'`, `'with tab'` (if treated identically) |
| "Another example" | No unique coverage value | `'valid email 1'`, `'valid email 2'` |

## Detection Patterns

### Missing Justification

Yield key describes WHAT the value is, not WHY it matters:

```php
// E009 - describes values, not purpose
yield 'small positive' => [1];
yield 'medium positive' => [50];
yield 'large positive' => [1000];
```

All three exercise the same `value > 0` branch. Only one is justified.

### Proper Justification

Yield key explains the unique value:

```php
// CORRECT - each case has distinct purpose
yield 'positive triggers success path' => [1];
yield 'zero triggers boundary handling' => [0];
yield 'negative triggers validation error' => [-1];
```

## Justification Checklist

For each test case, verify at least ONE:

- [ ] **Different code path**: Does this case execute different branches than other cases?
- [ ] **Boundary value**: Is this the exact threshold where behavior changes?
- [ ] **Regression**: Does this prevent a specific bug from recurring (cite issue)?

If none apply, the case is redundant (E009).

## Examples

### Time Comparison

```php
// E009 VIOLATION - all test same "A > B" path
yield 'A much greater than B' => [now + 1000, now];
yield 'A greater than B' => [now + 100, now];
yield 'A slightly greater than B' => [now + 1, now];
```

```php
// CORRECT - each case covers unique path
yield 'future time triggers refresh' => [now + 1, now];    // A > B path
yield 'same time uses cache' => [now, now];                // A == B path
yield 'past time returns stale' => [now - 1, now];         // A < B path
```

### String Validation

```php
// E009 VIOLATION - all test "valid email" path
yield 'simple email' => ['a@b.com'];
yield 'with subdomain' => ['a@mail.b.com'];
yield 'with plus' => ['a+tag@b.com'];
yield 'with dots' => ['a.b@c.com'];
```

```php
// CORRECT - one valid representative, distinct invalid paths
yield 'valid email format' => ['user@example.com', true];
yield 'missing @ triggers format error' => ['userexample.com', false];
yield 'empty local part triggers length error' => ['@example.com', false];
yield 'IDN domain (RFC 6531 compliance doc)' => ['user@xn--n3h.com', true];
```

### Numeric Boundaries

```php
// E009 VIOLATION - magnitude variations, same path
yield 'age 20' => [20, true];
yield 'age 30' => [30, true];
yield 'age 50' => [50, true];
```

```php
// CORRECT - boundary values
yield 'exactly 18 is minimum valid age' => [18, true];
yield 'below minimum triggers rejection' => [17, false];
yield 'max age boundary' => [120, true];
yield 'above max triggers validation' => [121, false];
```

## Relationship to W004

| Code | Checks | Example Failure |
|------|--------|-----------------|
| **W004** | Key is descriptive (not `case1`) | `yield 'case1' => [...]` |
| **E009** | Key justifies existence | `yield 'another valid email' => [...]` |

A test case can pass W004 (descriptive key) but fail E009 (no justification):

```php
// Passes W004, FAILS E009
yield 'small positive number' => [1];
yield 'large positive number' => [1000];

// Passes BOTH
yield 'positive triggers success' => [1];
yield 'negative triggers error' => [-1];
```

## When Multiple Similar Cases ARE Justified

Multiple cases from same code path are valid when:

1. **Different sub-behaviors**: Same branch but different internal handling
2. **Regression coverage**: Each case prevents a specific bug

```php
// JUSTIFIED - different sub-behaviors documented
yield 'ASCII username (fast path)' => ['john', true];
yield 'Unicode username (normalization path)' => ['jöhn', true];  // triggers NFD normalization

// JUSTIFIED - regression tests with citations
yield 'plus in local part (bug #1234)' => ['user+tag@example.com', true];
yield 'consecutive dots (bug #5678)' => ['user..name@example.com', false];
```

## Preservation Criteria (I007)

Some tests that appear redundant should be preserved due to historical or documentation value. Before flagging E009 (redundancy), check for these preservation indicators.

### Preservation Indicators

Tests with these characteristics may have preservation value:

| Indicator Type | Pattern | Example |
|----------------|---------|---------|
| **Regression marker in name** | `Regression`, `Bug`, `Issue`, `#\d+` | `testRegressionBug4521` |
| **Issue tracker reference** | `JIRA-`, `SW-`, `GH-` | `testJIRA1234UserCreation` |
| **Comment with bug reference** | `// regression`, `// bug fix`, `// prevents #` | `// Regression test for SW-12345` |
| **Data provider key with bug ref** | `bug`, `regression`, `issue #` | `'unicode fix (bug #1234)'` |

### When to Preserve vs Remove

| Scenario | Action | Code |
|----------|--------|------|
| Redundant test with no indicators | Flag E009 | Remove/consolidate |
| Redundant test with preservation indicator | Report I007 | Keep, suggest documentation |
| Redundant test with explicit comment explaining value | Keep as-is | No action |

### Example Analysis

```php
class UserServiceTest extends TestCase
{
    // PRIMARY TEST - covers main path
    public function testCreatesUser(): void
    {
        $user = $this->service->create(['name' => 'John']);
        static::assertNotNull($user->getId());
    }

    // E009: Redundant - same code path, no preservation indicator
    public function testCreatesUserWithValidData(): void
    {
        $user = $this->service->create(['name' => 'Jane']);
        static::assertNotNull($user->getId());
    }

    // I007: Preservation value - regression indicator in name
    public function testRegressionBug4521EmptyNameHandling(): void
    {
        $user = $this->service->create(['name' => '']);
        static::assertNotNull($user->getId());
    }

    // KEEP: Explicit documentation comment
    /**
     * Regression test for SW-12345: Unicode names were truncated
     * in version 6.4.0 due to UTF-8 encoding bug.
     */
    public function testCreatesUserWithUnicodeName(): void
    {
        $user = $this->service->create(['name' => '日本語']);
        static::assertEquals('日本語', $user->getName());
    }
}
```

### Adding Preservation Documentation

If a test has preservation value but lacks documentation:

```php
// BEFORE - unclear preservation value
public function testBug4521(): void { ... }

// AFTER - documented preservation value
/**
 * Regression test for bug #4521: Empty names caused null pointer exception.
 * @see https://github.com/shopware/shopware/issues/4521
 */
public function testRegressionBug4521EmptyNameHandling(): void { ... }
```

## Test Method Redundancy (E009)

The same justification rules that apply to data provider cases also apply to separate test methods. Both are covered by E009 (Test Redundancy).

### Detection Pattern

1. Identify the **tested method call** in each test
2. Determine which **code path** the inputs trigger
3. Group tests by code path
4. Flag groups with 2+ tests

### Example Analysis

```php
class SubTreeExtractorTest extends TestCase
{
    // Path A: Root match (root.id == targetId)
    public function testExtractsElementById(): void { ... }
    public function testReturnedElementIsClone(): void { ... }  // ← E009: Same as Path A

    // Path B: Recursive search (found in children)
    public function testExtractsNestedChildElementById(): void { ... }
    public function testExtractsDeeplyNestedElement(): void { ... }  // ← E009: Same as Path B

    // Path C: Not found (returns null)
    public function testReturnsNullForMissingElementId(): void { ... }  // ✓ Unique path
}
```

### Consolidation Options

When E009 is detected for method redundancy:

1. **Merge into single test** with multiple assertions (if assertions are complementary)
2. **Use data provider** to parameterize the different scenarios
