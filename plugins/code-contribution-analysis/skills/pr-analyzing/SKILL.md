---
name: pr-analyzing
version: 1.0.0
description: Use this skill when the user asks to analyze a GitHub pull request, review a PR's architectural impact, assess what changed in a PR and why it matters, or research the code relationships affected by a PR. Example triggers - "Analyze PR #4521", "What's the impact of this PR?", "Review the architectural implications of pull request 4521". Fetches PR metadata, diff, reviews, and comments from GitHub, then researches architectural context via chunkhound-integration MCP. Accepts an optional triage reasoning context from callers.
---

# PR Analyzing

Analyze a GitHub pull request by combining authoritative PR data from GitHub with semantic code research from ChunkHound. Produces a structured analysis of scope, impact, and architectural context.

Do not activate for generic code questions that do not reference a specific PR.

## Prerequisites

Requires the **chunkhound-integration** companion plugin. The skill calls `mcp__plugin_chunkhound-integration_ChunkHound__code_research` at Step 3 and stops with an error if that tool is not callable — see [Errors](#errors).

PR data is fetched from GitHub using whatever access the session has available (a GitHub MCP server, the `gh` CLI, or direct API calls).

## Input

- **Required:** PR number
- **Optional:** Repository as `owner/name` — defaults to the current repository context
- **Optional:** Triage reasoning — context from the caller about why analysis was requested (e.g., "flagged because it touches 12 files across Checkout and Payment"). Treat as a hint for research focus, not required input.

## Workflow

### Step 1 — Fetch PR data

Fetch the following from GitHub, in order:

1. PR metadata — title, body, author, labels, state
2. Changed files — list with additions/deletions per file
3. Unified diff
4. Reviews — decisions and top-level review bodies
5. Inline code review comments

Use whatever GitHub access is available in the session. Collect everything before Step 2. On error (PR not found, access denied, no GitHub access), stop and report to the user.

### Step 2 — Assess scope

From the fetched data, determine:

- **File count** and **spread** — how many files changed and how many distinct directories or top-level areas they span
- **Volume** — total additions and deletions
- **Labels** — area labels, type labels (feature, bugfix, breaking change), and any flags
- **Review complexity** — number of reviews, inline comment volume, whether reviews are contentious or unanimous

This assessment drives how much research depth Step 3 warrants.

### Step 3 — Research architectural impact

Use `mcp__plugin_chunkhound-integration_ChunkHound__code_research` with an **incremental strategy** — each stage runs only if the prior stage's findings are insufficient.

**Stage 1 — Identify points of interest.** From the diff and file list, pick concrete components, patterns, or relationships worth understanding deeper. Run focused `code_research` queries targeting specific changed components.

Examples:

- "What does `AsyncPaymentHandler` do and how does it relate to existing payment handlers?"
- "What is the `PaymentService` class responsible for?"

**Stage 2 — Architectural context.** Based on Stage 1 findings, ask targeted questions about how the identified components connect to the broader codebase — callers, consumers, related patterns.

Examples:

- "How does `AsyncPaymentHandler` connect to the order state machine and what other components depend on this payment flow?"
- "What services call `PaymentService.processAsync` and how do they handle errors?"

**Stage 3 — Focused deep dive (optional).** If Stage 2 reveals unexpected connections or further complexity, follow up on the specific relationship or pattern discovered.

Example:

- "What is the contract between `PaymentHandler` and `OrderTransactionStateHandler` — what happens if the async callback fails?"

**Budget.** ChunkHound queries are expensive. Stage 1 alone often suffices for single-area, non-cross-cutting PRs. Reserve Stage 2 and Stage 3 for PRs that span multiple areas, introduce new components, modify widely-used interfaces or base classes, or where review discussion hints at architectural concerns. When in doubt, start with Stage 1 and let findings drive whether more stages are needed.

Track which stages ran so the output can report the research method honestly.

### Step 4 — Produce output

Return the analysis as structured text in the conversation, following [Output Structure](#output-structure) below. Do not write files, create summaries outside the conversation, or invoke other skills.

## Output Structure

Return these sections in order:

**Summary** — one-line description of what the PR changes.

**Areas affected** — which parts of the codebase the PR touches. Derive from file paths and labels (e.g., "Checkout, Payment, Admin"); match project conventions where known.

**Scope** — file count, lines changed (additions / deletions), and complexity indicators. Call out cross-cutting vs. localized changes.

**Architectural impact** — how the changed components connect to the rest of the system, based on ChunkHound research. Reference specific components, patterns, or relationships. Cite file paths where relevant.

**Key findings** — specific architectural observations worth calling out:

- New patterns or components introduced
- Contract changes affecting downstream consumers
- Cross-cutting effects not obvious from the diff alone
- Deprecations or replacements of existing code

**Review discussion** — substantive points from reviewer comments. Omit this section entirely if reviews are empty or uncontested.

**Research method** — brief note on which stages ran (e.g., "Stage 1 only — no further questions raised" or "Stage 1 + Stage 2"). Makes analysis depth transparent.

## Errors

**GitHub data unavailable.** If PR data cannot be fetched at Step 1 — no GitHub access is configured, the PR is not found, or access is denied — stop and report the error to the user. Do not attempt analysis without PR data.

**chunkhound-integration unavailable.** If `mcp__plugin_chunkhound-integration_ChunkHound__code_research` is not callable at Step 3, stop and report to the user that the skill requires chunkhound-integration for architectural research. Do not produce partial analysis from GitHub data alone — architectural research is a core part of this skill's output, and GitHub-metadata-only analysis would look like a complete result but silently omit the most valuable section.
