Run ChunkHound operations sequentially across subagents — never in parallel.

When dispatching the `code-researcher` agent, invoke it sequentially. Never spawn multiple `code-researcher` agents in parallel.

When dispatching any other subagent (general-purpose or custom) and that subagent's task involves ChunkHound semantic search or code research (`mcp__plugin_chunkhound-integration_ChunkHound__search`, `mcp__plugin_chunkhound-integration_ChunkHound__code_research`), dispatch those subagents sequentially as well. Wait for each invocation to complete before starting the next.
