# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-02-25

### Changed
- **Breaking**: Unified agent+skill pattern — generation skill now uses `context: fork` into thin `test-generator` agent (mirrors reviewer pattern)
- **Breaking**: Eliminated `phpunit-unit-test-reviewer-fixer` agent — fix loop moved inline to orchestrator skill (Phase 3)
- **Breaking**: Eliminated `phpunit-unit-test-generator` agent — replaced by generic `test-generator` agent
- Orchestrator workflow expanded from 4 to 5 phases: Generate → Review → Fix Loop → User Decision → Final Report
- Each skill consumed exactly one way (`context: fork`), no dual consumption (`Skill` + `skills:` preloading)
- Orchestrator now uses `Skill` tool (not `Task`) for generation and review invocations
- Orchestrator uses `Edit` + MCP tools directly for inline fix loop validation
- Fix loop oscillation detection runs in orchestrator context with full access to `AskUserQuestion`

### Removed
- `agents/phpunit-unit-test-generator.md` — replaced by `agents/test-generator.md`
- `agents/phpunit-unit-test-reviewer-fixer.md` — fix loop absorbed by orchestrator

## [1.2.8] - 2026-02-24

### Added
- **W016** — Single-use test property: flags properties assigned in `setUp()` but referenced in only one test method; fix is to inline the construction at the usage site
- **W017** — `Test` prefix on non-test helper class: the `Test` prefix is reserved for classes extending `TestCase`; helper classes should use `Stub*`, `Fake*`, or a role-based name
- **W018** — Description-only data provider parameter: flags parameters used only for `#[TestDox]` interpolation; fix is to use `$_dataName` (resolves to yield key automatically)

### Fixed
- **Generation**: Skip test generation for source files excluded from coverage by `phpunit.xml.dist` — checks `<directory suffix>` and `<file>` exclusion rules before analyzing the class, returns SKIPPED when matched
- **E018**: Decoration pattern test example now uses `expectExceptionObject()` instead of bare `expectException()` — aligns with E018 rule since `DecorationPatternException` has a parameterized constructor
- **Generation**: `phpunit-conventions.md` Pattern 3 example corrected to use `$_dataName` instead of a `$description` parameter — prevents generating the anti-pattern W018 now detects

## [1.2.7] - 2026-02-23

### Fixed
- **E008**: Strengthened `expectException*()` exception guidance to prevent false positives — Phase 3 instruction now explicitly states both directions (flag `static::expectException*()`, do NOT flag `$this->expectException*()`); Quick Reference table pattern narrowed from `$this->assertEquals()` to `$this->assert*()` with inline exclusion note

## [1.2.6] - 2026-02-21

### Added
- **W015** — Data provider uses `return []` instead of `yield`/`iterable`: flagged as a warning, fix is to convert to `yield` statements

### Changed
- **E019**: Replace `expects($this->any())` with `expects($this->atLeastOnce())` — `any()` permits 0 invocations so callbacks with assertions could silently never fire; added Scenario B to flag `->with(static::callback(...))` chains that lack `->expects()`
- **E008**: `expectException*()` setup methods must use `$this->`, not `static::`
- **W007**: Require verb-first provider names; adjective/noun starts are flagged

## [1.2.5] - 2026-02-20

Regression fixes from second real-world review (95-file ContentSystem suite). Corrects three rules that caused behavioral assertions to be silently lost during automated fixing.

### Fixed
- **W012**: Detection now correctly excludes `createMock()` when `->with(static::callback(...))` argument verification is present — argument callbacks justify `createMock()` as much as `expects()` does; the previous rule caused W012 to fire and the fixer to strip the callback assertions
- **E019**: Fix pattern now branches on whether `->with(static::callback(...))` is present — if so, replace `expects($this->once())` with `expects($this->any())` instead of removing `expects()` entirely; PHPUnit silently ignores `->with()` constraints without `expects()`, so full removal discarded argument assertions
- **E009**: Phase 11 fix step now explicitly prohibits: (1) deleting a test method that is the sole coverage of any code path, and (2) collapsing a data provider test into a single parameterless test with inline assertions (which creates W002)

### Added
- **W014** — `#[Package(...)]` attribute on test classes: Shopware's source-class ownership annotation has no meaning on test classes; flagged as a warning, fix is removal
- **I009** — Duplicated inline Arrange code: informational suggestion when two or more test methods repeat ≥ 5 identical lines of object construction that could be extracted to `setUp()` or a private helper

## [1.2.4] - 2026-02-19

### Fixed
- Corrected invocation matcher methods (`once()`, `never()`, `exactly()`) to use `$this->` instead of `static::` in all code examples and skill instructions — ECS enforces this distinction (invocation matchers are instance methods, not static assertion helpers)
- Clarified E008 scope: `static::` applies to assertion methods (`assert*`, `expect*`) only; invocation matchers inside `->expects()` require `$this->`

## [1.2.3] - 2026-02-19

Improvements derived from real-world test generation experience (content system, 66 test files, 17 improvement iterations). Encodes the most frequently recurring fix patterns directly into generation templates and the reviewing skill.

### Added
- **E018** — Weak exception assertion: flags `expectException(Foo::class)` without `expectExceptionMessage()`, `expectExceptionCode()`, or `expectExceptionObject()` for parameterized exceptions (was the single most pervasive issue in practice, affecting 13+ files)
- **E019** — Call-count over-coupling: flags `expects($this->once())->method()->willReturn()` when the test already asserts the returned value, making the call-count redundant (affected 9 files)
- **W012** — `createMock()` when `createStub()` would suffice: flags `createMock()` on variables where no `expects()` call is ever made (16 files converted in one sweep in practice)
- **W013** — Opaque test data identifiers: flags 32-char hex UUID strings used as test IDs when descriptive strings (`'product-id'`) would be clearer

### Changed
- **Category B template**: uses `createStub()` by default; `createMock()` only in explicitly labeled side-effect verification sub-section; exception error cases now always include `expectExceptionMessage()` at minimum
- **Category E template**: `expectExceptionObject()` is now the primary pattern; data provider pattern uses `\Throwable $exception` for full object matching; all factory-method examples assert error code + status code + message
- **`essential-rules.md`**: added `createStub` vs `createMock` distinction; added Test Data Identifiers section
- **`common-patterns.md`**: new "Stub vs Mock" section with intersection type reference; exception testing leads with `expectExceptionObject()`; `expects(once())` moved to labeled side-effect sub-section; added Decoration Pattern Testing section
- **`mocking-strategy.md`**: new top-level `createStub()` vs `createMock()` section with call-count over-coupling anti-patterns
- Reviewing skill overview updated to 19 error codes, 13 warnings
- E005 expanded to explicitly include call-count verification on non-side-effect methods as a detection pattern

## [1.2.2] - 2025-12-19

Issues discovered during test generation for `Shopware\Core\Content\ContentSystem\Output\SubTreeExtractor` class.

### Changed
- Final status now reports as COMPLIANT or NON-COMPLIANT instead of PASS/ISSUES_FOUND
- E-codes are mandatory compliance failures; W-codes are optional improvements

### Fixed
- Fixer agent now attempts ALL E-codes, not just tool validation errors
- No longer prompts for confirmation on NON-COMPLIANT status
- Re-invokes fixer when fixes failed due to dependencies and iterations remain

## [1.2.1] - 2025-12-18

### Changed
- Updated MCP tool references from `php-tooling` plugin to `dev-tooling` plugin
- Documentation now references `dev-tooling` as the required dependency

## [1.2.0] - 2025-12-18

### Changed
- **Breaking**: Split reviewer into `phpunit-unit-test-reviewer` (read-only) and `phpunit-unit-test-reviewer-fixer` (edit-capable with internal fix loop)
- Fixer agent handles iterations internally (up to 4) with oscillation detection
- Significant reduction in main context tool calls (Edit + MCP isolated to fixer agent)
- Extended output contract with `iterations_used`, `fixes_applied`, `oscillation_detected`
- Read-only reviewer cannot modify files (security improvement)

## [1.1.0] - 2025-12-17

### Changed
- Enhanced E009 (test redundancy) detection with explicit code path analysis algorithm
- Added source class reading requirement in Phase 1 for code path identification
- Added worked example showing test method merge pattern (`SubTreeExtractor`)

### Fixed
- E009 now correctly detects methods exercising same code path (discovered via real-world test generation)

## [1.0.0] - 2025-12-16

### Added
- Three-tier skill system: generation, review, and orchestration
- Generator and reviewer agents for input validation
- Test categories with category-specific templates (DTO, Service, Flow/Event, DAL, Exception)
- Error, warning, and informational codes for compliance validation
- Review loop with oscillation and stuck loop detection
- PHPStan/PHPUnit/ECS validation via php-tooling MCP integration
- Shopware testing references (stubs, feature flags, mocking strategy)
