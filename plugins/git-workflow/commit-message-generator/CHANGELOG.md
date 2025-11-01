# Changelog

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
