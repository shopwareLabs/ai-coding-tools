# Validation Error Mapping

Common validation errors and their fixes for PHPStan, PHPUnit, and ECS.

## PHPStan Errors

| Error Pattern | Fix |
|---------------|-----|
| Missing import | Add `use` statement |
| Parameter type mismatch | Add `@param` PHPDoc |
| Return type mismatch | Add `@return` PHPDoc or use type-narrowing assertion |
| Undefined variable | Initialize in setUp() or declare as property |
| Call to undefined method | Check mock configuration |
| Access to undefined property | Ensure property is declared |
| Cannot call method on null | Add null check or fix mock setup |
| Property has no type | Add typed property declaration |
| Method has no return type | Add return type declaration |
| Class not found | Add `use` statement or check namespace |

## PHPUnit Errors

| Error Pattern | Fix |
|---------------|-----|
| Assertion failure | Verify expected value matches actual behavior |
| Missing mock return | Add `->willReturn()` to mock setup |
| Exception not thrown | Check exception condition is met |
| setUp() error | Verify all dependencies initialized |
| Data provider error | Check provider method signature and yield format |
| Test depends on another | Remove dependency or use `@depends` |
| Risky test (no assertions) | Add assertions or mark intentionally |
| Incomplete test | Implement test body or remove `$this->markTestIncomplete()` |
| Skipped test | Fix condition or remove `$this->markTestSkipped()` |

## ECS/Code Style Errors

| Error Pattern | Fix |
|---------------|-----|
| Missing blank line | Add blank line between sections |
| Extra blank lines | Remove duplicate blank lines |
| Wrong indentation | Fix spacing (4 spaces per level) |
| Missing type declaration | Add parameter/return types |
| Unused import | Remove unused `use` statements |
| Wrong namespace | Fix namespace to match directory |
| Missing final keyword | Add `final` to class declaration |
| Wrong array syntax | Use short array syntax `[]` |

## MCP Response Validation

Before processing MCP tool responses, verify:

1. **Response structure**: Has expected output fields
2. **No error field**: Response does not contain `error` key
3. **Valid JSON**: Response parses correctly

If MCP error present:
- Log error in validation results
- Proceed to next validation step
- Report partial validation in final status

## MCP Tools Unavailable

If MCP tools cannot be reached:
- **Status**: Set to `PARTIAL`
- **Message**: "MCP tools unavailable - manual validation required"
