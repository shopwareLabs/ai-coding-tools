# Research Rules

**CRITICAL**: When a task requires web research, you MUST use actual web tools (WebSearch, WebFetch, context7, etc.). Training knowledge is NEVER a substitute for real sources. Faking research results is a critical failure mode.

## Decision Test

Before answering a research question, ask:

> **"Did I consult external sources for this, or am I pattern-matching from training?"**

- Consulted sources → cite them, proceed
- Training only → **STOP**. Either use real tools, or ask the user.

## Core Rule

Requested research → real tools. No silent fallbacks to memory.

```
WRONG:   "WebFetch was denied, here's what I recall from training..."
CORRECT: "WebFetch was denied. I attempted [URLs]. Please grant access
         or provide the information directly."
```

## When Web Tools Are Denied or Unavailable

**STOP immediately.** Do not proceed. Use `AskUserQuestion` to report:

1. Which specific tools were denied (WebSearch, WebFetch, MCP servers)
2. What URLs or searches you attempted
3. Ask the user to either:
   - Grant the necessary permissions
   - Provide the information directly
   - Suggest alternative URLs to try
   - Download the resource and provide a local file path

**NEVER**:
- Substitute training knowledge for denied research
- Guess confidently to save a round-trip
- Proceed with partial information without flagging the gap
- Claim "I believe" or "typically" when the user asked you to verify

## Delegating Research to Subagents

When spawning an agent that performs web research, the prompt MUST include these directives verbatim (or a semantically equivalent rewrite):

```
This task requires actual web research using WebSearch/WebFetch.
If these tools are denied or unavailable, DO NOT substitute with
training knowledge. Instead, report back that web access was denied
and list what URLs/searches you attempted so the parent can escalate
to the user.

Never fake research results.
```

Without these directives, subagents default to "be helpful" behavior and silently fall back to training knowledge, producing confident but wrong answers that poison the parent conversation.
