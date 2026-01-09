---
name: code-research-routing
version: 1.0.3
description: This skill should be used when the user asks "how does X work?", "what's the architecture?", "help me understand the codebase", "find all components that use Y", "trace the data flow", mentions design patterns, component relationships, or is onboarding to an unfamiliar codebase. Routes architectural queries to ChunkHound for semantic code research; uses native Grep/Glob only for simple string or file pattern searches.
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

Use Grep, Glob, or Read for direct, targeted queries:

| Query Pattern | Example | Why Native |
|---------------|---------|------------|
| Known file lookup | "Show me package.json" | Direct path → Read |
| File pattern search | "Find all *.test.ts files" | Pattern match → Glob |
| Simple string search | "Search for 'TODO' comments" | Literal string → Grep |
| Known symbol lookup | "Find function calculateTotal" | Exact identifier → Grep |

## Decision Framework

Before choosing a tool, ask:

1. **Does this require understanding relationships between files?** → ChunkHound
2. **Is this asking HOW something works?** → ChunkHound
3. **Is this a simple string/pattern search?** → Native Grep
4. **Does this require discovering code I don't know about?** → ChunkHound
5. **Do I already know exactly which file to look at?** → Native Read

## ChunkHound Tool Reference

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mcp__plugin_chunkhound-integration_ChunkHound__code_research` | Deep code research with LLM synthesis | Architecture, implementations, relationships |
| `mcp__plugin_chunkhound-integration_ChunkHound__search_semantic` | Find code by meaning/concept | "authentication logic", similar functionality |
| `mcp__plugin_chunkhound-integration_ChunkHound__search_regex` | Find exact code patterns | Function names, imports, specific syntax |
| `mcp__plugin_chunkhound-integration_ChunkHound__health_check` | Check server health status | Verify MCP connection |
| `mcp__plugin_chunkhound-integration_ChunkHound__get_stats` | Get database statistics | Check index health (file/chunk counts) |

## Prerequisites Check

If ChunkHound tools are unavailable:
1. Verify plugin is installed: `/plugin list`
2. Check MCP status: `/mcp`
3. Run diagnostics: `/chunkhound-status`
4. Restart Claude Code if MCP server not loading
