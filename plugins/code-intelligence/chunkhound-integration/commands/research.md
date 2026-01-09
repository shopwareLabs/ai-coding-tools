---
name: research
description: Deep code research using ChunkHound semantic analysis
arguments:
  - name: query
    description: Research question about the codebase (e.g., "how does authentication work?")
    required: true
---

Use the `mcp__plugin_chunkhound-integration_ChunkHound__code_research` tool to investigate: $ARGUMENTS

Present findings in a structured format with:

1. **Overview**: High-level answer to the question (2-3 sentences)
2. **Key Components**: Relevant files with `file:line` citations
3. **Relationships**: How components connect and interact
4. **Recommendations**: Suggested next steps or areas to explore

If the MCP tool is unavailable, inform the user to check `/chunkhound-status` for diagnostics.
