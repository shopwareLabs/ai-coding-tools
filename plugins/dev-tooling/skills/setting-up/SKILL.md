---
name: setting-up
version: 3.12.3
description: >
  Interactive setup for this plugin. Walks through the prerequisites, creates
  the required configuration files, and validates that MCP tools and/or LSP are
  correctly wired. Use when the plugin is first installed or when tools fail
  with missing-config errors.
model: sonnet
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Plugin Setup

Interactive setup assistant. Read references/plugin-setup.md for all plugin-specific details including prerequisites, configuration files, validation steps, and post-setup instructions.

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

If everything is already configured, skip to Phase 4 (Configure Permissions) — permissions are always offered.

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

### Phase 4: Configure Permissions

Pre-approve the plugin's tools in `.claude/settings.local.json` so the user is not prompted on first use. Read the `## Permission Groups` section of the guide. Each group bundles related tools behind a single question — never ask per individual tool.

1. Check whether `.claude/settings.local.json` exists at the project root. If present, read it with Read. Otherwise treat the starting state as `{"permissions": {"allow": [], "ask": [], "deny": []}}`.

2. For each group listed in the guide:
   - Skip the group if its **Optional** condition is not met (e.g., the related config file was not created, or a dependent feature like `enable_write_server` is disabled).
   - Skip the group silently if every pattern in it is already present in any of the `allow`, `ask`, or `deny` lists.
   - Otherwise ask via AskUserQuestion, using the group's name and description. Offer three options — `allow`, `ask`, `deny` — with the group's **Recommended** value as the default.

3. Merge the answers into the settings:
   - Append each selected pattern to the chosen list.
   - Deduplicate: never add a pattern that already exists anywhere in `allow`, `ask`, or `deny`.
   - Never remove, reorder, or move existing entries between lists.
   - Preserve every other key in the file verbatim.

4. Show the user the new entries that will be added (grouped by target list) and ask for confirmation. On confirmation, Write the updated file.

### Phase 5: Validate

Read the `## Validation` section of the guide. For each validation step:

1. Run the described check or MCP tool call
2. Report pass or fail
3. If a check fails, diagnose the likely cause and offer to fix it (e.g., wrong container name, container not running, missing PHP extension)

### Phase 6: Post-Setup

Read the `## Post-Setup` section of the guide. Report the remaining steps the user must take (e.g., restarting Claude Code to load MCP servers).

## Rules

- Ask one question at a time via AskUserQuestion. Never batch multiple questions.
- Skip phases and individual steps that are already satisfied (prerequisite installed, config file exists, permission pattern already in settings).
- Never proceed to config file creation if a required prerequisite it depends on is missing.
- Always show the user the complete config content before writing it.
- When updating `.claude/settings.local.json`, only append new entries. Never remove, reorder, or move existing permission entries between lists.
- If validation fails, attempt to diagnose the cause before giving up.
- Use the exact options, descriptions, defaults, and permission groups from the plugin setup guide. Do not improvise.
