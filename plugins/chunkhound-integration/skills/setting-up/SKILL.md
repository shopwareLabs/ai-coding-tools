---
name: setting-up
version: 1.1.0
description: >
  Interactive setup for the chunkhound-integration plugin (semantic code research via ChunkHound).
  Checks that the chunkhound CLI and an embedding provider (VoyageAI, OpenAI, or Ollama) are available,
  creates .chunkhound.json with provider configuration, runs the initial index, and validates the MCP
  server connection. Use when the user installs chunkhound-integration and needs configuration, asks how
  to set up semantic search, or when ChunkHound MCP tools fail with config or connection errors.
model: sonnet
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Plugin Setup

Interactive setup assistant. Read [Plugin Setup Guide](references/plugin-setup.md) for all plugin-specific details including prerequisites, configuration files, validation steps, and post-setup instructions.

## Workflow

### Phase 1: Detect Current State

Read the plugin setup guide reference file. It contains all plugin-specific information organized in standard sections.

For each prerequisite listed under `## Prerequisites`:
1. Run its check command (the **Check** field) via Bash
2. Record the result: installed (with version) or missing

For each config file listed under `## Configuration Files`:
1. Check if it exists at the specified location using Glob
2. Record the result: exists or missing

Report findings to the user:
- Installed prerequisites with versions
- Missing prerequisites (distinguish required vs optional)
- Existing config files
- Missing config files

If everything is already configured, skip to Phase 4 (Validate).

### Phase 2: Fix Prerequisites

For each missing prerequisite:

1. Tell the user what is missing, what requires it (the **Required by** field), and provide the install link
2. If the prerequisite is marked as optional, ask via AskUserQuestion whether they want to install it. Skip if they decline.
3. For required prerequisites, tell the user to install it and ask them to confirm when done
4. After confirmation, re-run the check command to verify

If a required prerequisite cannot be installed, stop and explain which config files and features depend on it. Do not proceed to Phase 3 for config files that depend on missing prerequisites.

### Phase 3: Create Config Files

For each config file from the guide that does not exist:

1. If the file is marked `Required: No`, ask via AskUserQuestion whether the user wants to configure it. Skip if they decline.
2. Read the **Setup Questions** section for this config file
3. Ask each question one at a time via AskUserQuestion, presenting the options and descriptions exactly as written in the guide
4. Skip conditional questions when their condition is not met (conditions are noted in parentheses, e.g., "only if environment = docker")
5. Build the config JSON object from the answers
6. Present the complete config to the user and ask for confirmation
7. Write the file to the specified location using Write

### Phase 4: Validate

Read the `## Validation` section of the guide. For each validation step:

1. Run the described check or MCP tool call
2. Report pass or fail
3. If a check fails, diagnose the likely cause and offer to fix it (e.g., wrong container name, container not running, missing PHP extension)

### Phase 5: Post-Setup

Read the `## Post-Setup` section of the guide. Report the remaining steps the user must take (e.g., restarting Claude Code to load MCP servers).

## Rules

- Ask one question at a time via AskUserQuestion. Never batch multiple questions.
- Skip phases and individual steps that are already satisfied (prerequisite installed, config file exists).
- Never proceed to config file creation if a required prerequisite it depends on is missing.
- Always show the user the complete config content before writing it.
- If validation fails, attempt to diagnose the cause before giving up.
- Use the exact options, descriptions, and defaults from the plugin setup guide. Do not improvise.
