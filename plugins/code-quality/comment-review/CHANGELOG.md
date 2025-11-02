# Changelog

## [1.1.2] - 2025-11-02

### Changed
- Updated bash script invocation examples in SKILL.md to use {baseDir} placeholder instead of hardcoded /path/to/skill path for better maintainability and clarity

## [1.1.1] - 2025-11-01

### Fixed
- Fixed "BASH_SOURCE[0]: parameter not set" error in git-helpers.sh when sourcing script with set -u in complex command chains by using safe parameter expansion (${BASH_SOURCE[0]:-})

## [1.1.0] - 2025-10-30

### Added
- Uncertainty evaluation mechanism with HIGH/MEDIUM/LOW classification using content signal detection (examples, constraints, rationale, trade-offs) and progressive disclosure
- "Changes Requiring Verification" section in report output with actionable verification prompts
- uncertainty-patterns.md reference file with pattern definitions, content signal library, and verification templates

### Changed
- Integrated uncertainty evaluation into skill description, pre-edit review workflow, and change tracking
- Enhanced output format to include verification section with adaptive verbosity

### Performance
- Two-stage evaluation (lightweight heuristics, then full patterns only when HIGH/MEDIUM detected) reduces token overhead for simple reviews

## [1.0.1] - 2025-10-30

### Fixed
- Corrected broken internal documentation links that referenced non-existent files (configuration-guide.md → config-overview.md, api-documentation-guidelines.md → api-docs-core-principles.md)
- Fixed git command execution in wrong directory by using git -C with WORK_DIR variable in git-helpers.sh

## [1.0.0] - 2025-10-22

Initial release.

### Skill - Comment Reviewing
- Comment review following "why not what" principle with five-category action system (Remove, Improve, Keep, Flag, Condense)
- Intelligent comment type detection (implementation vs API documentation) with multi-language support
- Git integration with consistency checking and pre-edit validation
- Project-specific configuration via `.reviewrc.md` with adaptive output formats
- Special cases handling (legacy code, algorithms, generated code)

### Commands
- `/comment-review` - Review and improve comments with smart scope detection
- `/comment-check` - Analyze comment quality (read-only)
- Support for files, directories, --git flag, commits, ranges, and commit lists
