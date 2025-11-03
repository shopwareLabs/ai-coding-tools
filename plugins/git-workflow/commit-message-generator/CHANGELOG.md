# Changelog

## [1.2.1] - 2025-11-03

### Added
- New `scope-detector` subagent for commit scope analysis

### Changed
- Extracted scope inference logic from `SKILL.md` Step 3 into dedicated `scope-detector` agent
- Simplified `SKILL.md` Step 3 by delegating to subagent
- Improved scope detection with confidence-based user interaction and project config validation

## [1.2.0] - 2025-11-03

### Added
- New `type-detector` subagent for commit type analysis

### Changed
- Extracted type detection logic from `SKILL.md` Step 2 into dedicated `type-detector` agent
- Simplified `SKILL.md` Step 2 by delegating to subagent
- Moved `type-detection.md` reference from skill-owned to plugin-owned location

## [1.1.0] - 2025-11-02

### Added
- Cross-platform clipboard integration for generated commit messages with automatic tool detection and graceful fallback

## [1.0.1] - 2025-11-02

### Changed
- Clarified output format rules in SKILL.md and output-formats.md to specify that validation checkmarks (✓/✗/⚠) are internal-only in generation mode and brief analysis should appear before the commit message

## [1.0.0] - 2025-11-02

### Added
- `/commit-gen [commit-ref]` command to generate conventional commit messages from staged changes or existing commits
- `/commit-check` command to validate commit message format and consistency
- `commit-message-generating` skill for automatic invocation
- Automatic type detection (feat, fix, refactor, perf, etc.)
- Scope inference from changed file paths
- Breaking change detection and formatting
- Consistency validation (type/scope/subject accuracy)
- Project-specific configuration via `.commitmsgrc.md`
- 5 progressive disclosure reference files (spec, type/scope detection, validation, custom rules)
- Git utility scripts for reliable operations
- Support for custom types, scopes, and ticket formats
- Detailed validation reports with recommendations
