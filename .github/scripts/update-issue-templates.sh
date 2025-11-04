#!/bin/bash
#
# update-issue-templates.sh
#
# Updates GitHub issue template dropdowns by scanning the repository
# for plugins, commands, skills, and agents.
#
# Usage:
#   ./update-issue-templates.sh
#
# Exit Codes:
#   0 - Templates updated successfully
#   2 - Fatal error (missing dependencies, files not found)
#
# Note: Creates backup files with .bak extension before modifying templates.
#

set -euo pipefail

# Set up environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
export TEMPLATES_DIR="$REPO_ROOT/.github/ISSUE_TEMPLATE"

# Source libraries
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=./discover-components.sh
source "$SCRIPT_DIR/discover-components.sh"
# shellcheck source=./lib/yaml-operations.sh
source "$SCRIPT_DIR/lib/yaml-operations.sh"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    *)
      echo -e "${RED}Error: Unknown option $1${NC}" >&2
      echo "Usage: $0" >&2
      exit 1
      ;;
  esac
done

# Template update functions
update_command_issue_template() {
  local template="$TEMPLATES_DIR/command_issue.yml"
  log_info "Processing command_issue.yml..."

  # Get all commands with plugins
  local commands=()
  while IFS= read -r line; do
    commands+=("$line")
  done < <(discover_commands)

  # Update dropdown
  log_info "Updating 'command' dropdown..."
  update_dropdown "$template" "command" "${commands[@]}"
  log_success "Updated command dropdown"
}

update_skill_issue_template() {
  local template="$TEMPLATES_DIR/skill_issue.yml"
  log_info "Processing skill_issue.yml..."

  # Get all skills with plugins
  local skills=()
  while IFS= read -r line; do
    skills+=("$line")
  done < <(discover_skills)

  # Update dropdown
  log_info "Updating 'skill' dropdown..."
  update_dropdown "$template" "skill" "${skills[@]}"
  log_success "Updated skill dropdown"
}

update_agent_issue_template() {
  local template="$TEMPLATES_DIR/agent_issue.yml"
  log_info "Processing agent_issue.yml..."

  # Get all agents with plugins
  local agents=()
  while IFS= read -r line; do
    agents+=("$line")
  done < <(discover_agents)

  # Update dropdown
  log_info "Updating 'agent' dropdown..."
  update_dropdown "$template" "agent" "${agents[@]}"
  log_success "Updated agent dropdown"
}

update_other_component_template() {
  local template="$TEMPLATES_DIR/plugin_component_other.yml"
  log_info "Processing plugin_component_other.yml..."

  # Get all plugins
  local plugins=()
  while IFS= read -r line; do
    plugins+=("$line")
  done < <(discover_plugins)

  # Update dropdown
  log_info "Updating 'plugin' dropdown..."
  update_dropdown "$template" "plugin" "${plugins[@]}"
  log_success "Updated plugin dropdown"
}

# Main execution
main() {
  log_info "Starting issue template update process..."

  # Validation
  check_dependencies
  validate_files

  # Update all templates
  update_command_issue_template
  update_skill_issue_template
  update_agent_issue_template
  update_other_component_template

  log_success "All issue templates updated successfully!"
  log_info "Backup files created with .bak extension"
}

# Run main function
main
