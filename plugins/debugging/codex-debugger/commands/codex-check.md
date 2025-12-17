---
description: Verify Codex availability and configuration for codex-debugger plugin
allowed-tools:
  - Bash
  - mcp__codex__codex
---

You are checking if OpenAI Codex is properly configured and available for the codex-debugger plugin.

Run these verification steps in sequence:

## Step 1: Check Codex CLI Installation

Use Bash to check if the Codex CLI is installed:
```bash
which codex
```

If not found, inform the user they need to install it:
```bash
npm install -g @openai/codex
# or
brew install codex
```

## Step 2: Check Codex CLI Version

If installed, check the version:
```bash
codex --version
```

Recommend updating if version is old (known issues with conversationId in older versions):
```bash
npm update -g @openai/codex
```

## Step 3: Verify MCP Server Registration

Check if the codex MCP server is registered with Claude Code by attempting to use the `mcp__codex__codex` tool with a minimal test prompt.

Call the tool with this exact configuration:
```json
{
  "prompt": "Test connection. Reply with 'OK' if you receive this.",
  "model": "gpt-5",
  "approval-policy": "never"
}
```

If the tool is not available or fails:
- The MCP server is not registered (user needs to restart Claude Code)
- The Codex CLI is not authenticated
- The user's OpenAI account lacks Codex access

## Step 4: Authentication Check

If the MCP call failed with authentication errors, the user needs to authenticate:
```bash
codex login
```

Codex authentication is required (typically included with ChatGPT Plus/Pro/Team subscriptions).

## Step 5: Report Status

Provide a clear summary in this format:

```
Codex Pre-Flight Check Results
==============================

✓ Codex CLI: Installed (version X.X.X)
✓ MCP Server: Registered and accessible
✓ Authentication: Valid
✓ API Access: Codex available

Status: Ready for use

The codex-debugger plugin is fully operational.
```

Or if issues found:

```
Codex Pre-Flight Check Results
==============================

✗ Codex CLI: Not found
  → Run: npm install -g @openai/codex

⚠ MCP Server: Not registered
  → Restart Claude Code to load the MCP server

✗ Authentication: Not configured
  → Run: codex login

Status: Setup required

Follow the troubleshooting steps above, then run /codex-check again.
```

Include specific troubleshooting guidance based on which checks failed.

## Common Issues

- **"command not found: codex"** - Install the Codex CLI
- **"MCP server not found"** - Restart Claude Code after plugin installation
- **"Authentication failed"** - Run `codex login`
- **"Insufficient permissions"** - Upgrade to ChatGPT Plus/Pro/Team
- **conversationId issues** - Update Codex CLI to latest version

For more details, see: plugins/debugging/codex-debugger/README.md
