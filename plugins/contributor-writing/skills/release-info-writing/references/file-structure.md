# File Structure and Placement Rules

## RELEASE_INFO Heading Hierarchy

```
# 6.7.9.0 (upcoming)        ← h1: version (look for "upcoming" marker)

## Features                   ← h2: category
### Entry title               ← h3: individual entry
[entry body]

## API
### Entry title
[entry body]

## Core
### Entry title
[entry body]

## Administration
### Entry title
[entry body]

## Storefront
### Entry title
[entry body]

## App System
### Entry title
[entry body]

## Hosting & Configuration
### Entry title
[entry body]

## Critical Fixes
### Entry title
[entry body]

# 6.7.8.0                   ← h1: previous released version
...
```

**Entry format:** `### Descriptive Title` followed by a blank line, then the entry body.

## UPGRADE Heading Hierarchy

```
# 6.8.0.0                    ← h1: version

# Changed Functionality       ← h1: category (note: h1 not h2)
## Entry title                 ← h2: individual entry
[entry body]

# API
## Entry title
[entry body]

# Core
## Entry title
[entry body]

# Administration
## Entry title
[entry body]

# Storefront
## Entry title
[entry body]
```

**Entry format:** `## Descriptive Title` followed by a blank line, then the entry body.

**Note:** UPGRADE uses h1 for categories and h2 for entries (one level higher than RELEASE_INFO). Some sections use `<details>` collapse tags for long content.

## Standard Categories

These are the standard categories. Scan the entire target file (all versions, not just upcoming) to discover any additional categories in use.

| Category | RELEASE_INFO heading | UPGRADE heading |
|---|---|---|
| Features | `## Features` | (not used in UPGRADE) |
| API | `## API` | `# API` |
| Core | `## Core` | `# Core` |
| Administration | `## Administration` | `# Administration` |
| Storefront | `## Storefront` | `# Storefront` |
| App System | `## App System` | (if present) |
| Hosting & Configuration | `## Hosting & Configuration` | (if present) |
| Critical Fixes | `## Critical Fixes` | (not used in UPGRADE) |
| Changed Functionality | (not used in RELEASE_INFO) | `# Changed Functionality` |

## File Path to Category Mapping

Use these heuristics to propose a category. The user confirms or overrides.

| File path pattern | Suggested category |
|---|---|
| `src/Core/` | Core |
| `src/Storefront/` | Storefront |
| `src/Administration/` | Administration |
| `src/Elasticsearch/` | Core |
| Routes, controllers with `/api/` | API |
| `src/Core/Framework/App/` | App System |
| Config files, hosting, `.env`, `shopware.yaml` | Hosting & Configuration |
| Mixed paths across multiple areas | Ask the user — pick the primary area |

When changes span multiple areas, choose the category that best represents the **user-facing impact**, not where most files changed.

## Placement Logic

### RELEASE_INFO

1. Find the upcoming version section: scan for an h1 containing `(upcoming)` — e.g., `# 6.7.9.0 (upcoming)`
2. Within that section, find the target h2 category
3. If the category heading exists: append the new entry as the **last `###` entry** in that category (before the next `##` or `#`)
4. If the category heading does not exist: create the `##` heading in the standard order (Features → API → Core → Administration → Storefront → App System → Hosting & Configuration → Critical Fixes), then add the entry

### UPGRADE

1. Find the target version section: scan for the h1 with the target version — e.g., `# 6.8.0.0`
2. Within that section, find the target h1 category
3. If the category heading exists: append the new entry as the **last `##` entry** in that category (before the next `#` at the same level)
4. If the category heading does not exist: create the `#` heading, then add the entry

### Edge Cases

- If no "upcoming" section exists in RELEASE_INFO, ask the user — do not create a new version heading
- If the UPGRADE file has no section for the target version, ask the user
- Always insert a blank line before and after the new entry for clean formatting
