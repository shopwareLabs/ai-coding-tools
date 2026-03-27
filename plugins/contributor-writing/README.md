# Contributor Writing

Writing skills for Shopware core contributors. Currently includes release info and upgrade entry drafting, with more skills planned.

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

## Prerequisites

- Working in the `shopware/shopware` repository
- `gh-tooling` plugin installed (for PR analysis via GitHub CLI)
- `gh` CLI authenticated
