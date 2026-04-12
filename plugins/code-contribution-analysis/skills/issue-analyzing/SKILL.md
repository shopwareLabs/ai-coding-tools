---
name: issue-analyzing
version: 1.0.0
description: Use this skill when the user asks to analyze a GitHub issue, understand what area of code an issue affects, assess an issue's scope, or research the code context around an issue. Example triggers - "Analyze issue #8910", "What's the scope of this issue?", "Research the code affected by issue 8910". Fetches issue metadata and comments from GitHub, then researches the affected code area via chunkhound-integration MCP. Accepts an optional triage reasoning context from callers.
---

# Issue Analyzing

Analyze a GitHub issue by combining authoritative issue data from GitHub with semantic code research from ChunkHound. Produces a structured analysis of problem scope, affected code area, and resolution status.

Do not activate for generic code questions that do not reference a specific issue.

## Prerequisites

Requires the **chunkhound-integration** companion plugin. The skill calls `mcp__plugin_chunkhound-integration_ChunkHound__code_research` at Step 3 and stops with an error if that tool is not callable — see [Errors](#errors).

Issue data is fetched from GitHub using whatever access the session has available (a GitHub MCP server, the `gh` CLI, or direct API calls).

## Input

- **Required:** Issue number
- **Optional:** Repository as `owner/name` — defaults to the current repository context
- **Optional:** Triage reasoning — context from the caller about why analysis was requested. Treat as a hint for research focus.

## Workflow

### Step 1 — Fetch issue data

Fetch the following from GitHub: issue metadata (title, body, author, labels, state) and all comments.

Use whatever GitHub access is available in the session. If a single call returns everything together, that's fine; if comments are returned separately, fetch them as part of this step. On error (issue not found, access denied, no GitHub access), stop and report to the user.

### Step 2 — Identify the affected code area

From the issue description and comments, extract signals about what part of the codebase is affected:

- **File paths or component names** mentioned directly in the description
- **Class or function names** referenced in the text (often in backticks or stack traces)
- **Error messages** that can be traced back to specific components
- **Area labels** (e.g., `area/checkout`, `area/admin`) that indicate scope
- **Linked PRs** referenced as fixes — comments often contain "Fixed in #X" or "See PR #Y"

If the issue is a feature request, the "affected area" is the area that would need to change to implement it. If the body is too vague to identify a specific area, note this in the output and research at the area label's level instead.

### Step 3 — Research the affected area

Use `mcp__plugin_chunkhound-integration_ChunkHound__code_research` with an **incremental strategy** — the same pattern as `pr-analyzing`, adapted for issues.

**Stage 1 — Locate components.** Run focused `code_research` queries to locate the components or areas referenced in the issue. Goal: find the concrete code that maps to the issue's problem space.

Examples:

- "What does the cart calculation logic do and where is it implemented?"
- "How is `LineItemCollection` structured and used?"

**Stage 2 — Understand the area.** Based on Stage 1 findings, ask targeted questions about how the affected components work and what depends on them.

Examples:

- "What components depend on cart calculation? What invariants does it assume?"
- "How does the checkout flow handle empty line items currently?"

**Stage 3 — Deep dive (optional).** If Stage 2 reveals cross-component effects or unexpected complexity, run a follow-up query.

Example:

- "What happens throughout the order lifecycle when a cart contains zero-quantity line items?"

**Budget.** Issues differ from PRs: there is no diff to anchor on. Stage 1 (locating the affected code) is more important for issues than for PRs — if the description is vague, the skill must work harder to identify what to research. When an issue description is extremely thin (one sentence, no specifics), prefer to stop after Stage 1 and state what could not be determined rather than running expensive research that produces low-value output.

Track which stages ran.

### Step 4 — Produce output

Return the analysis as structured text in the conversation, following [Output Structure](#output-structure) below.

## Output Structure

Return these sections in order:

**Summary** — one-line description of what the issue is about.

**Affected code area** — which parts of the codebase the issue touches. Derive from direct references in the description, area labels, and Stage 1 research findings.

**Code context** — how the affected area works, based on ChunkHound research. Describe the component's role, its invariants, and its dependencies. This grounds the issue in architectural reality.

**Scope assessment** — is the problem localized or cross-cutting? Does fixing it require changes in multiple components?

**Resolution status** — resolved, in progress, or open? If linked PRs were referenced in comments, name them. If a fix is merged, summarize it in one line.

**Key findings** — specific observations from research worth calling out (e.g., unexpected consumers of the affected code, invariants the issue might violate, related components at risk).

**Research method** — brief note on which stages ran.

## Errors

**GitHub data unavailable.** If issue data cannot be fetched at Step 1 — no GitHub access is configured, the issue is not found, or access is denied — stop and report the error to the user. Do not attempt analysis without issue data.

**chunkhound-integration unavailable.** If `mcp__plugin_chunkhound-integration_ChunkHound__code_research` is not callable at Step 3, stop and report to the user that the skill requires chunkhound-integration for code research. Do not produce partial analysis from GitHub data alone — code context is the substance of issue analysis, and keyword-only output would look like a complete result but silently omit the most valuable section.
