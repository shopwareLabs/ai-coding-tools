# Changelog

## [3.0.0] - 2026-01-22

### Changed
- Inlined `type-detector`, `scope-detector`, and `body-validator` agents into SKILL.md with progressive disclosure references
- Type/scope/body logic now uses reference files instead of Task agent calls

### Removed
- `agents/type-detector.md` - Logic moved to `references/type-detection.md`
- `agents/scope-detector.md` - Logic moved to `references/scope-detection.md`
- `agents/body-validator.md` - Logic moved to `references/body-validation.md`
- `Task` from allowed-tools in SKILL.md

### Added
- `references/type-detection.md` - Decision tree, confidence levels, breaking change detection
- `references/scope-detection.md` - Scope inference rules, config validation
- `references/body-validation.md` - Presence checks, content quality, migration instructions

## [2.3.1] - 2026-01-08

### Fixed
- Commands now show explicit `Skill(...)` invocation syntax to prevent model confusion

## [2.3.0] - 2026-01-08

### Added
- `add_attribution_footer` configuration option - Optionally add attribution footer with "🤖 Generated with Claude Code" and "Co-authored-by: Claude \<model\>" lines (default: false)

## [2.2.0] - 2026-01-08

### Changed
- **Require explicit commit reference** - Both `/commit-gen` and `/commit-check` now require an explicit git reference (HEAD, SHA, branch name, etc.)
- Simplified Step 1 in SKILL.md - Single code path for resolving commit references
- Updated argument hints from `[commit-ref]` (optional) to `<commit-ref>` (required)

### Removed
- Staged changes support from `/commit-gen` - No longer supports generating from `git diff --cached`
- Default HEAD behavior from `/commit-check` - No longer defaults to HEAD when no argument provided
- Staged git commands from SKILL.md Git Commands section
- "No staged changes" error handling path

### Design Philosophy
Continues v2.0.0/2.1.0 simplification approach:
- Single deterministic code path (no branching for staged vs commit)
- ~10% additional code reduction across skill and commands
- Users commit first (even with temp message), then generate ideal message with `/commit-gen HEAD`

## [2.1.0] - 2026-01-08

### Changed
- Inlined `report-generator` agent into SKILL.md Step 5 - Pure formatting logic doesn't benefit from separate agent invocation

### Removed
- `agents/report-generator.md` - Report formatting now handled directly in SKILL.md validation workflow

## [2.0.0] - 2026-01-09

### Changed
- **Major architecture simplification** - Reduced codebase from ~8,560 to ~1,584 lines (81% reduction)
- SKILL.md: 553 → 183 lines (67% reduction) - Trusts Claude's native Conventional Commits knowledge
- type-detector agent: 1,023 → 156 lines (85% reduction) - Simplified to decision tree with confidence levels
- scope-detector agent: 970 → 151 lines (84% reduction) - Streamlined path-to-scope mapping
- body-validator agent: 327 → 124 lines (62% reduction) - Focused validation rules
- report-generator agent: 135 lines (79% reduction) - Concise report formatting
- commitmsgrc-template.md: 280 → 143 lines (50% reduction) - Reduced to 6 essential config options
- Moved clipboard handling from skill to `/commit-gen` command (uses native clipboard commands)

### Removed
- `scripts/clipboard-helper.sh` - Claude knows native clipboard commands
- `scripts/git-commit-helpers.sh` - Unused; SKILL.md uses direct git commands
- `references/conventional-commits-spec.md` - Claude knows the spec natively
- `references/type-detection.md` - Inlined into type-detector agent
- `references/scope-detection.md` - Inlined into scope-detector agent
- `references/output-formats.md` - Redundant with SKILL.md
- `references/error-handling.md` - Inlined into SKILL.md
- `references/validation-checklist.md` - Duplicated SKILL.md validation workflow
- 3-iteration self-validation loop - Single-pass validation is sufficient
- 9 of 15 config options - Kept 6 essential options

## [1.3.0] - 2025-11-04

### Added
- Body validation for commit messages with presence, content quality, structure, and migration instruction checks
- Configuration options for body requirements in `.commitmsgrc.md`

### Changed
- Validation workflow now includes body quality assessment
- Enhanced conventional commits specification with body quality examples

## [1.2.4] - 2025-11-04

### Changed
- Compressed skill instruction files for improved token efficiency and performance

## [1.2.3] - 2025-11-04

### Added
- New `report-generator` subagent for validation report formatting with three verbosity levels (concise, standard, verbose)

### Changed
- Refactored validation workflow to delegate report formatting to dedicated agent instead of inline generation
- Updated plugin architecture documentation to include report-generator agent and navigation paths

## [1.2.2] - 2025-11-04

### Changed
- Optimized agent architecture with inline patterns, removed external dependencies, and compressed instruction files for improved performance and token efficiency

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
