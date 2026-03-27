# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.3] - 2026-03-27

### Changed
- Section 3 guidance: "Not applicable" is sufficient for technical improvements, refactors, and features without a reproduction scenario

## [1.1.2] - 2026-03-27

### Changed
- Breaking change callout: only use distinct callout when break is incidental, not the PR's primary story
- Code example gate: exclude trivial snippets (added parameter, renamed method) that restate the prose

## [1.1.1] - 2026-03-27

### Added
- Shared anti-AI-slop reference at `references/writing-rules-anti-ai-slop.md` as source of truth
- "Don't assume intent" rule: don't attribute motivation to original code authors
- "Banned description formats" rule applied to both skills (was PR-only)
- Expanded "counts as noise" examples for PR description context

### Changed
- Anti-slop sections in both skills' writing-rules.md now mirror the shared reference

## [1.1.0] - 2026-03-27

### Added
- `pr-description-writing` skill for drafting PR titles and descriptions
- 5-phase workflow: assess branch state, analyze changes, gather context, draft, present
- Conventional commit title generation with type/scope detection from file paths
- Density calibration (small/medium/large) based on explanation complexity, not diff size
- Anti-slop rules adapted for PR descriptions (banned AI vocabulary, copilot-style patterns, sentence rhythm)
- PR description examples by density tier from real Shopware PRs
- Template structure reference with section-by-section guidance

## [1.0.1] - 2026-03-27

### Changed
- Writing rules: headings should omit counts when the number is deducible from the entry body
- Writing rules: concreteness section now distinguishes meaningful numbers from noise numbers

## [1.0.0] - 2026-03-27

### Added
- Initial release of contributor-writing plugin
- `release-info-writing` skill for drafting RELEASE_INFO and UPGRADE entries from branch analysis
- 5-phase workflow: detect target files, analyze branch scope, gather context, draft entries, write
- Classification decision tree for determining which files need entries
- Reference files for writing rules, entry examples, and file structure
- Anti-slop rules to prevent LLM-typical writing patterns (banned vocabulary, sentence rhythm, concreteness)
- GitHub tooling integration for PR analysis
