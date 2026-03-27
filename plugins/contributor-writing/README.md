# Contributor Writing

Writing skills for Shopware core contributors. Includes release info and upgrade entry drafting, and PR description generation.

## Installation

```bash
/plugin install contributor-writing@shopware-ai-coding-tools
```

Requires the `gh-tooling` plugin for PR analysis:

```bash
/plugin install gh-tooling@shopware-ai-coding-tools
```

## Skills

### release-info-writing

Draft `RELEASE_INFO` and `UPGRADE` entries for the Shopware core repository. Analyzes branch diffs against `trunk`, classifies changes, and writes entries calibrated to the magnitude of change. Includes anti-slop rules to prevent LLM-typical writing patterns.

The skill activates automatically when you complete features or mention writing release documentation. You can also invoke it directly:

```
Write a release info entry for my changes
Add an upgrade entry for the breaking change I just made
Document this feature for the release notes
```

**What it does:**

1. **Detects target files** — parses `.danger.php` for the canonical `RELEASE_INFO-6.x.md` and `UPGRADE-6.x.md` file names
2. **Analyzes your branch** — reads the full diff against `trunk` to understand the story of your changes
3. **Classifies** — determines if entries are needed in RELEASE_INFO, UPGRADE, both, or neither
4. **Gathers context** — asks you targeted questions about why external developers should care
5. **Drafts entries** — generates entries sized to the magnitude of change, calibrated against existing entries, with anti-slop rules enforced (banned AI vocabulary, varied sentence rhythm, concrete over abstract)
6. **Writes** — inserts entries into the correct file section on your approval

**What it doesn't do:**

- Auto-commit or create PRs
- Generate full changelogs (those are auto-generated from PR titles)
- Work in extension repositories (core only)
- Polish entries for publication (DevRel handles that)

### pr-description-writing

Draft PR titles and descriptions for the Shopware core repository. Analyzes branch diffs against `trunk`, identifies the primary story, and generates a conventional commit title plus the full 5-section PR template.

The skill activates automatically when you ask to write a PR description or are about to create a PR:

```
Write a PR description for my changes
Draft a description for this branch
Improve the PR description
```

**What it does:**

1. **Assesses branch state** — detects current branch, checks for existing PR, reads the full diff
2. **Analyzes changes** — synthesizes the narrative across all commits, identifies primary story
3. **Gathers context** — asks targeted questions for motivation, reproduction steps, issue links
4. **Drafts** — generates conventional commit title + full template sections, calibrated to explanation complexity
5. **Presents** — outputs formatted title + description ready for use

**What it doesn't do:**

- Create or update PRs on GitHub
- Write to any files
- Auto-commit

## Shared References

Both skills enforce the same anti-AI-slop writing rules (banned vocabulary, sentence patterns, formatting discipline, tone). The source of truth is `references/writing-rules-anti-ai-slop.md` — each skill's `references/writing-rules.md` contains a copy of these rules alongside skill-specific guidance.

## Prerequisites

- Working in the `shopware/shopware` repository
- `gh-tooling` plugin installed (for PR analysis via GitHub CLI)
- `gh` CLI authenticated
