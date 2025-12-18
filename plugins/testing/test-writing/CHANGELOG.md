# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
