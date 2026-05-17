---
name: code-research-routing
version: 2.0.0
description: Use this skill when the user asks an architectural or semantic question about a codebase — phrases like "how does X work?", "what's the architecture?", "help me understand this codebase", "find all components that use Y", "trace the data flow from A to B", "where is feature Z handled", "I'm new to this code, where do I start" — or whenever they mention design patterns, component relationships, multi-file dependency tracing, or onboarding to unfamiliar code. Activate even when the user does not explicitly mention "semantic search" or "ChunkHound". Routes architectural queries to ChunkHound's multi-hop semantic search; native `ugrep`/`bfs` via Bash still handle literal string and file-pattern lookups.
---

# Code Research Routing

Route code investigation queries to the appropriate tool based on query characteristics.

## When to Use ChunkHound

Use `mcp__plugin_chunkhound-integration_ChunkHound__code_research` for questions requiring semantic understanding:

| Query Pattern | Example | Why ChunkHound |
|---------------|---------|----------------|
| Architecture questions | "How does the payment system work?" | Multi-file relationships |
| Dependency discovery | "Find all components that use UserService" | Semantic traversal |
| Pattern recognition | "What design patterns are used here?" | Cross-file analysis |
| Data flow mapping | "How does data flow from API to database?" | Architectural synthesis |
| Onboarding queries | "I'm new, where should I start?" | Broad exploration |
| Implementation search | "How is authentication implemented?" | Concept-based discovery |

## When to Use Native Tools

Use `ugrep`/`bfs` via Bash or the Read tool for direct, targeted queries:

| Query Pattern | Example | Why Native |
|---------------|---------|------------|
| Known file lookup | "Show me package.json" | Direct path → Read |
| File pattern search | "Find all *.test.ts files" | Pattern match → `bfs` via Bash |
| Simple string search | "Search for 'TODO' comments" | Literal string → `ugrep` via Bash |
| Known symbol lookup | "Find function calculateTotal" | Exact identifier → `ugrep` via Bash |

## Decision Framework

Before choosing a tool, ask:

1. **Does this require understanding relationships between files?** → ChunkHound
2. **Is this asking HOW something works?** → ChunkHound
3. **Is this a simple string/pattern search?** → `ugrep` via Bash
4. **Does this require discovering code I don't know about?** → ChunkHound
5. **Do I already know exactly which file to look at?** → Native Read

## ChunkHound Tool Reference

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mcp__plugin_chunkhound-integration_ChunkHound__code_research` | Deep code research with LLM synthesis | Architecture, implementations, relationships |
| `mcp__plugin_chunkhound-integration_ChunkHound__search` | Pinpoint exact locations via regex or semantic search (`type` parameter) | Known symbol, concept, or pattern lookup after `code_research` |
| `mcp__plugin_chunkhound-integration_ChunkHound__daemon_status` | Daemon health, scan progress, realtime readiness | Verify MCP connection and that the initial scan completed |

## Synthesis Output Format

When the routing decision lands on ChunkHound and you have findings to report, structure them as:

### Overview
[2-3 sentence summary directly answering the core question]

### Key Components
- `path/to/file.ext:42` — Brief description of what this component does
- `path/to/other.ext:108` — Description of related functionality
- [Continue with relevant files…]

### Architecture Insights
[Describe how components relate to each other. Include data flows, design patterns observed, dependency relationships, integration points.]

### Recommendations
[Suggest next steps: areas to explore further, files to read in detail, questions to clarify with the user.]

For lightweight, in-thread answers (one-shot architectural questions where the user just wants a direct response) this format is optional — match it to the weight of the question. For wrapped invocations via the `code-researcher` subagent, always use the full structure: the subagent's only job is to return synthesized findings to the main thread.

## Prerequisites Check

If ChunkHound tools are unavailable:
1. Verify plugin is installed: `/plugin list`
2. Check MCP status: `/mcp`
3. Run diagnostics: `/chunkhound-status`
4. Restart Claude Code if MCP server not loading
