#!/bin/bash
#
# discover-components.sh
#
# Library script for discovering plugins, commands, skills, and agents in the repository.
# This script is designed to be sourced by other scripts that need to enumerate components.
#
# Usage:
#   source discover-components.sh
#   plugins=$(discover_plugins)
#   commands=$(discover_commands)
#   skills=$(discover_skills)
#   agents=$(discover_agents)
#
# Requirements:
#   - jq (for parsing marketplace.json)
#   - REPO_ROOT environment variable must be set to repository root path
#   - MARKETPLACE_JSON environment variable must be set to marketplace.json path
#
# Each discovery function outputs one item per line to stdout, sorted alphabetically.
# Diagnostic messages are sent to stderr.
#

# Prevent direct execution - this is a library script
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "Error: This script is a library and should be sourced, not executed directly." >&2
  echo "Usage: source discover-components.sh" >&2
  exit 1
fi

# Validate required environment variables
if [ -z "$REPO_ROOT" ]; then
  echo "Error: REPO_ROOT environment variable is not set" >&2
  return 1
fi

if [ -z "$MARKETPLACE_JSON" ]; then
  echo "Error: MARKETPLACE_JSON environment variable is not set" >&2
  return 1
fi

# Discovery functions

# discover_plugins - Lists all published plugins from marketplace.json
#
# Output format: One plugin name per line (e.g., "comment-review")
# Sorted alphabetically
discover_plugins() {
  echo "[INFO] Discovering published plugins from marketplace.json..." >&2
  jq -r '.plugins[] | .name' "$MARKETPLACE_JSON" | sort
}

# discover_commands - Lists all commands with their parent plugins
#
# Output format: "plugin-name / /command-name" per line
# Example: "comment-review / /comment-check"
# Sorted alphabetically
discover_commands() {
  echo "[INFO] Discovering commands with plugins..." >&2
  local commands=()

  while IFS= read -r -d '' file; do
    # Extract plugin name from path: plugins/category/plugin-name/commands/...
    local plugin_path
    plugin_path=$(dirname "$(dirname "$file")")
    local plugin_name
    plugin_name=$(basename "$plugin_path")

    local cmd_name
    cmd_name=$(basename "$file" .md)

    # Format as "plugin / command"
    commands+=("$plugin_name / /$cmd_name")
  done < <(find "$REPO_ROOT/plugins" -type f -path "*/commands/*.md" -print0 2>/dev/null)

  printf '%s\n' "${commands[@]}" | sort -u
}

# discover_skills - Lists all skills with their parent plugins
#
# Output format: "plugin-name / skill-name" per line
# Example: "comment-review / comment-reviewing"
# Sorted alphabetically
discover_skills() {
  echo "[INFO] Discovering skills with plugins..." >&2
  local skills=()

  while IFS= read -r -d '' file; do
    # Extract plugin name from path: plugins/category/plugin-name/skills/...
    local plugin_path
    plugin_path=$(dirname "$(dirname "$(dirname "$file")")")
    local plugin_name
    plugin_name=$(basename "$plugin_path")

    local skill_name
    skill_name=$(basename "$(dirname "$file")")

    # Format as "plugin / skill"
    skills+=("$plugin_name / $skill_name")
  done < <(find "$REPO_ROOT/plugins" -type f -path "*/skills/*/SKILL.md" -print0 2>/dev/null)

  printf '%s\n' "${skills[@]}" | sort -u
}

# discover_agents - Lists all agents with their parent plugins
#
# Output format: "plugin-name / agent-name" per line
# Example: "codex-debugger / codex-escalation"
# Sorted alphabetically
discover_agents() {
  echo "[INFO] Discovering agents with plugins..." >&2
  local agents=()

  while IFS= read -r -d '' file; do
    # Extract plugin name from path: plugins/category/plugin-name/agents/...
    local plugin_path
    plugin_path=$(dirname "$(dirname "$file")")
    local plugin_name
    plugin_name=$(basename "$plugin_path")

    local agent_name
    agent_name=$(basename "$file" .md)

    # Format as "plugin / agent"
    agents+=("$plugin_name / $agent_name")
  done < <(find "$REPO_ROOT/plugins" -type f -path "*/agents/*.md" -print0 2>/dev/null)

  printf '%s\n' "${agents[@]}" | sort -u
}
