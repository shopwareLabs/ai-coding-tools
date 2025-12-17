@README.md

## Quick Reference

| Component | Purpose | File |
|-----------|---------|------|
| Agent | Escalation protocol | `agents/codex-escalation.md` |
| Command | Setup verification | `commands/codex-check.md` |
| MCP Server | Codex integration | `.mcp.json` |

**Agent Configuration:**
- **Model**: `inherit` (uses parent model)
- **Color**: `yellow`
- **Tools**: `mcp__codex__codex`, `mcp__codex__codex-reply`, Read, Edit, Bash, Grep, Glob, TodoWrite

## Directory & File Structure

```
plugins/debugging/codex-debugger/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── .mcp.json                               # MCP server configuration
├── agents/
│   └── codex-escalation.md                 # Main escalation protocol agent
└── commands/
    └── codex-check.md                      # Pre-flight verification command
```

## Components

- **Agent**: `agents/codex-escalation.md`
- **Command**: `commands/codex-check.md`
- **MCP Server**: `.mcp.json`

## Key Navigation Points

### Finding Specific Functionality

| Task | Primary File | Section |
|------|--------------|---------|
| Modify escalation trigger conditions | `agents/codex-escalation.md` | Description `<example>` blocks, "Recognition Patterns" |
| Add/modify validation steps | `agents/codex-escalation.md` | Step 0 (pre-flight), Step 1 (context validation) |
| Adjust Codex consultation format | `agents/codex-escalation.md` | Step 2 "Format Your Prompt" |
| Change implementation strategy | `agents/codex-escalation.md` | Step 3 "Implement and Validate Solution" |
| Modify second-level escalation | `agents/codex-escalation.md` | Step 5 "Second-Level Escalation" |
| Change output format | `agents/codex-escalation.md` | "Output Format" section |
| Update pre-flight check logic | `commands/codex-check.md` | Steps 1-5 verification sequence |
| Configure Codex model/parameters | `.mcp.json` | `args` array (model, reasoning effort) |
| Add new agent tools | `agents/codex-escalation.md` | Frontmatter `tools:` field |


## When to Modify What

| Task | Edit Location |
|------|---------------|
| Changing when escalation triggers | `agents/codex-escalation.md` description `<example>` blocks and "Recognition Patterns" section |
| Adding context gathering steps | `agents/codex-escalation.md` Step 1 "Required Information" |
| Modifying Codex prompt template | `agents/codex-escalation.md` Step 2 "Format Your Prompt" |
| Adjusting Codex model or reasoning effort | `.mcp.json` args array |
| Adding pre-flight validation checks | `commands/codex-check.md` Steps 1-5 |
| Changing escalation to user behavior | `agents/codex-escalation.md` Step 5 "Second-Level Escalation" |
| Modifying output format | `agents/codex-escalation.md` "Output Format" section |
| Updating Known Issues documentation | `agents/codex-escalation.md` "Known Issues & Workarounds" section |
| Restricting command tools | `commands/codex-check.md` frontmatter `allowed-tools` field |


## Integration Points

### MCP Server Configuration

- **Server name**: `codex`
- **Tools provided**: `mcp__codex__codex`, `mcp__codex__codex-reply`
- **Default model**: GPT-5 with high reasoning effort (configured in `.mcp.json`)
- **Command**: `codex mcp-server`
- **Configuration**: `.mcp.json` in plugin root
- **Installation requirement**: Must restart Claude Code after installing plugin

### External Dependencies

**Codex CLI** (required):
- Install: `npm install -g @openai/codex` or `brew install codex`
- Authentication: `codex login`
- Verification: `/codex-check` command

**OpenAI Account** (required):
- ChatGPT Plus/Pro/Team subscription typically required for Codex access
- Provides GPT-5 model access

### Invocation Pattern

- **Automatic**: Agent is model-invoked when main Claude detects "running in circles" pattern
- **Manual verification**: `/codex-check` command for setup diagnostics
- **Architecture**: Agent runs in separate context window for fresh perspective

## Related Documentation

- **User guide**: [README.md](./README.md)
- **Installation**: [README.md](./README.md#quick-start)
- **Agent implementation**: [agents/codex-escalation.md](./agents/codex-escalation.md)
- **Pre-flight verification**: [commands/codex-check.md](./commands/codex-check.md)
- **MCP configuration**: [.mcp.json](./.mcp.json)
- **Changelog**: [CHANGELOG.md](./CHANGELOG.md)
- **Codex CLI docs**: https://developers.openai.com/codex/
