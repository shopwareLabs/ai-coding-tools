# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.4] - 2026-04-13

### Fixed
- `commit-message-writing` SKILL.md: bare-path references to `references/scope-inference.md` and `references/writing-rules.md` so progressive disclosure loads them correctly.
- `adr-writing` reference `validation-checklist.md`: removed redundant pointer to `writing-rules-anti-ai-slop.md` (already loaded directly by SKILL.md).

## [1.6.3] - 2026-04-11

### Fixed
- Removed "Source of truth" back-reference annotations from all skill reference copies that pointed outside the skill directory, breaking agentic loops by triggering forbidden or prompted file reads
- Removed self-describing meta paragraphs from plugin-level shared reference files (branch-and-pr-detection.md, writing-rules-anti-ai-slop.md) that were copied verbatim into skills

### Changed
- AGENTS.md now explicitly requires copies to be self-contained with no external path annotations

## [1.6.2] - 2026-04-10

### Fixed
- Removed non-functional `mdc:` link prefix from skill reference links in commit-message-writing

## [1.6.1] - 2026-04-10

### Fixed
- Added missing per-skill copies of `branch-and-pr-detection.md` reference — commit-message-writing, feature-branch-pr-writing, and pr-description-writing failed to resolve the reference at runtime after the extraction in 1.6.0

### Changed
- Replaced explicit MCP tool lists with server-level wildcards (`mcp__plugin_gh-tooling_gh-tooling`) in skill frontmatter `allowed-tools`

## [1.6.0] - 2026-04-09

### Added
- Shared `references/branch-and-pr-detection.md` reference for branch detection, PR lookup, target identification, and cross-skill routing
- Routing table centralizes the handoff logic between pr-description-writing, feature-branch-pr-writing, and commit-message-writing
- Copies in each skill's `references/` directory following the same sync pattern as anti-slop rules

### Changed
- `pr-description-writing` Phase 1: replaced inline detection steps with reference loading (6 steps to 3)
- `feature-branch-pr-writing` Phase 1: replaced inline detection steps with reference loading (7 steps to 4)
- `commit-message-writing` Phase 1 step 3: replaced inline squash-mode detection with reference loading

## [1.5.0] - 2026-04-08

### Added
- `commit-message-writing` skill: generates conventional commit messages for Shopware core
  - Squash mode: title-only for trunk merges, detects base branch from PR target
  - Branch mode: title + body for development commits, WHY-not-WHAT body principle
  - Scope inference: file path mapping, commit history validation, native project memory persistence
  - Anti-slop rules copied from shared source of truth

## [1.4.4] - 2026-04-02

### Added
- `adr-writing` skill now pins `model: opus` for architectural reasoning quality
- Domain contamination warning in feature-branch description examples (all examples are from one domain, calibrate structure not vocabulary)

### Fixed
- Phase 4 self-check reworded: "state in one sentence what contract it describes" replaces yes/no question that allowed rationalization (both PR skills)
- Phase 5 diff-restatement elevated to dedicated validation step alongside em dash check (both PR skills)
- Cross-reference guidance: explain what's different from predecessor, not just what's the same (both PR skills' writing-rules.md)

## [1.4.3] - 2026-04-02

### Fixed
- Phase 4 self-check replaced yes/no question with concrete action: "state in one sentence what contract it describes" (both PR skills)
- Phase 5 diff-restatement check elevated to first-class validation step alongside em dash check (both PR skills)
- Cross-reference guidance: when citing a predecessor, explain what's different, not just what's the same (both PR skills' writing-rules.md)

## [1.4.2] - 2026-04-02

### Fixed
- Phase 5 anti-slop validation now requires literal character search for em dashes instead of mental scan (all 4 skills)
- Phase 4 self-check gate: "would a reviewer learn this from the diff alone?" forces contract-level rewriting before moving on (both PR skills)
- Diff-restating rule now has concrete bad/good before/after example from a real compiler pass case (both PR skills' writing-rules.md)

## [1.4.1] - 2026-04-02

### Changed
- Expanded diff-restating rule in both PR skills: distinguishes obvious form (naming files) from subtle form (walking through implementation logic a reviewer will see in the diff)
- Added contracts-over-implementation guidance to Do's in both PR skills
- Fixed description examples that violated the expanded rule (#15860 DI detail, #15622 private helper name and parser internals)

## [1.4.0] - 2026-04-01

### Added
- `feature-branch-pr-writing` skill for PRs targeting non-trunk branches
- Narrative prose format with topical subsections (no numbered template)
- Chain detection: finds related PRs on the same feature branch
- Two-step diagram reasoning: (1) would the reviewer understand better by seeing it? (2) can it fit one diagram or should it split?
- Description examples from real Shopware PRs across three sizing tiers

### Changed
- `pr-description-writing` now hands off to `feature-branch-pr-writing` when PR target is not `trunk`
- `pr-description-writing` frontmatter clarifies it handles trunk-targeting PRs only

## [1.3.0] - 2026-03-31

### Added
- `adr-writing` skill merged from standalone `adr-writing` plugin
- Anti-slop validation pass in ADR creation workflow (Step 5: Validate and Write)
- Anti-slop checks in ADR validation workflow (loaded alongside validation checklist)
- Anti-slop section in validation report output

### Changed
- Skill renamed from `adr-creating` to `adr-writing` to match plugin naming convention
- ADR writing-style.md: removed numbered-bold-label anti-pattern section (now covered by anti-slop rules)

## [1.2.0] - 2026-03-31

### Added
- Optional "Additional Changes" section in PR descriptions for incidental improvements (test cleanup, refactors) that aren't part of the main feature story
- Phase 2 now offers secondary threads as an Additional Changes section when they have educational value or touch files a reviewer might question
- Template structure defines format, placement, and content guidance for the section

## [1.1.6] - 2026-03-31

### Added
- Anti-slop validation pass in both skills: re-reads writing-rules.md and checks the full draft against all anti-slop categories before presenting or writing output
- Front-loaded em dash hard ban callout at the top of all three writing-rules files (source of truth, PR description, release-info)

### Changed
- PR description Phase 5 renamed from "Present" to "Validate and Present"
- Release-info Phase 5 renamed from "Write" to "Validate and Write"

## [1.1.5] - 2026-03-27

### Fixed
- PR description output no longer uses commit-message-style hard line wraps at 72/80 characters

## [1.1.4] - 2026-03-27

### Added
- Em dash ban: do not use em dashes, replace with periods, commas, parentheses, or deletion
- Colon overuse rule: don't insert colons before every explanation
- Semicolon overuse rule: don't stitch simple sentences with semicolons
- Intensifiers added to banned vocabulary: truly, really, incredibly, very
- "This" + abstract noun added to banned sentence patterns
- Rule of three added to banned sentence patterns

### Changed
- Removed all em dashes from rule examples and guidance text across all writing-rules files
- Restructured anti-slop rules into punctuation patterns, vocabulary, sentence patterns, and format sections

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
