#!/bin/bash
#
# validate-issue-templates.sh
#
# Validates that GitHub issue template dropdowns are up-to-date.
# Read-only script that never modifies files.
#
# Usage:
#   ./validate-issue-templates.sh [--github-actions]
#
# Options:
#   --github-actions  Enable GitHub Actions output formatting (auto-detected from CI env)
#
# Exit Codes:
#   0 - All templates are up-to-date
#   1 - One or more templates are outdated
#   2 - Fatal error (missing dependencies, files not found)
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
    --github-actions)
      GITHUB_ACTIONS_MODE=true
      shift
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}" >&2
      echo "Usage: $0 [--github-actions]" >&2
      exit 1
      ;;
  esac
done

# Validation function with GitHub Actions support
validate_dropdown() {
  local file="$1"
  local dropdown_id="$2"
  shift 2
  local expected_options=("$@")

  # Get current options from file
  local current_options=()
  while IFS= read -r line; do
    current_options+=("$line")
  done < <(extract_dropdown_options "$file" "$dropdown_id")

  # Sort expected options
  local sorted_expected=()
  while IFS= read -r line; do
    sorted_expected+=("$line")
  done < <(printf '%s\n' "${expected_options[@]}" | sort)

  # Compare arrays
  local current_str="${current_options[*]}"
  local expected_str="${sorted_expected[*]}"

  if [ "$current_str" = "$expected_str" ]; then
    log_success "$(basename "$file"):$dropdown_id is up-to-date"
    return 0
  else
    local filename=$(basename "$file")
    log_error "$filename:$dropdown_id is outdated"

    if [ "$GITHUB_ACTIONS_MODE" = true ]; then
      # GitHub Actions: Show detailed diff as error annotation
      echo "::error file=$file,title=Outdated dropdown '$dropdown_id'::Found ${#current_options[@]} options, expected ${#sorted_expected[@]}. Run '.github/scripts/update-issue-templates.sh' to update."

      # Find missing and extra options
      local missing_options=()
      local extra_options=()

      # Check for missing options
      for opt in "${sorted_expected[@]}"; do
        local found=false
        for curr_opt in "${current_options[@]}"; do
          if [ "$opt" = "$curr_opt" ]; then
            found=true
            break
          fi
        done
        if [ "$found" = false ]; then
          missing_options+=("$opt")
        fi
      done

      # Check for extra options
      for opt in "${current_options[@]}"; do
        local found=false
        for exp_opt in "${sorted_expected[@]}"; do
          if [ "$opt" = "$exp_opt" ]; then
            found=true
            break
          fi
        done
        if [ "$found" = false ]; then
          extra_options+=("$opt")
        fi
      done

      # Report missing options
      if [ ${#missing_options[@]} -gt 0 ]; then
        echo "::warning file=$file::Missing ${#missing_options[@]} option(s) in dropdown '$dropdown_id': ${missing_options[*]}"
      fi

      # Report extra options
      if [ ${#extra_options[@]} -gt 0 ]; then
        echo "::warning file=$file::Extra ${#extra_options[@]} option(s) in dropdown '$dropdown_id': ${extra_options[*]}"
      fi
    else
      # Standard output: Show full lists
      log_info "Current options (${#current_options[@]}):"
      printf '  - %s\n' "${current_options[@]}" >&2
      log_info "Expected options (${#sorted_expected[@]}):"
      printf '  - %s\n' "${sorted_expected[@]}" >&2
    fi

    return 1
  fi
}

# Template validation functions
validate_command_issue_template() {
  local template="$TEMPLATES_DIR/command_issue.yml"
  log_info "Processing command_issue.yml..."

  local commands=()
  while IFS= read -r line; do
    commands+=("$line")
  done < <(discover_commands)

  validate_dropdown "$template" "command" "${commands[@]}"
  return $?
}

validate_skill_issue_template() {
  local template="$TEMPLATES_DIR/skill_issue.yml"
  log_info "Processing skill_issue.yml..."

  local skills=()
  while IFS= read -r line; do
    skills+=("$line")
  done < <(discover_skills)

  validate_dropdown "$template" "skill" "${skills[@]}"
  return $?
}

validate_agent_issue_template() {
  local template="$TEMPLATES_DIR/agent_issue.yml"
  log_info "Processing agent_issue.yml..."

  local agents=()
  while IFS= read -r line; do
    agents+=("$line")
  done < <(discover_agents)

  validate_dropdown "$template" "agent" "${agents[@]}"
  return $?
}

validate_other_component_template() {
  local template="$TEMPLATES_DIR/plugin_component_other.yml"
  log_info "Processing plugin_component_other.yml..."

  local plugins=()
  while IFS= read -r line; do
    plugins+=("$line")
  done < <(discover_plugins)

  validate_dropdown "$template" "plugin" "${plugins[@]}"
  return $?
}

# Main execution
main() {
  log_info "Validating issue template dropdowns..."

  # Validation
  check_dependencies
  validate_files

  # Track validation failures
  local failed=0

  # Validate all templates
  validate_command_issue_template || ((failed++))
  validate_skill_issue_template || ((failed++))
  validate_agent_issue_template || ((failed++))
  validate_other_component_template || ((failed++))

  if [ $failed -eq 0 ]; then
    log_success "All issue template dropdowns are up-to-date!"

    # GitHub Actions: Set output for downstream jobs
    if [ "$GITHUB_ACTIONS_MODE" = true ] && [ -n "${GITHUB_OUTPUT:-}" ]; then
      echo "templates-status=up-to-date" >> "$GITHUB_OUTPUT"
      echo "templates-outdated=0" >> "$GITHUB_OUTPUT"
    fi
    exit 0
  else
    log_error "$failed template(s) have outdated dropdowns"
    log_info "Run '.github/scripts/update-issue-templates.sh' to update templates"

    # GitHub Actions: Set output and create job summary
    if [ "$GITHUB_ACTIONS_MODE" = true ]; then
      # Set output variables if available
      if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "templates-status=outdated" >> "$GITHUB_OUTPUT"
        echo "templates-outdated=$failed" >> "$GITHUB_OUTPUT"
      fi

      # Create job summary if available
      if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        {
          echo "## ❌ Issue Template Validation Failed"
          echo ""
          echo "**$failed template(s) have outdated dropdowns**"
          echo ""
          echo "### Action Required"
          echo ""
          echo "Run the following command to update the templates:"
          echo '```bash'
          echo ".github/scripts/update-issue-templates.sh"
          echo '```'
          echo ""
          echo "Then commit the changes:"
          echo '```bash'
          echo "git add .github/ISSUE_TEMPLATE/"
          echo 'git commit -m "chore: update issue template dropdowns"'
          echo '```'
        } >> "$GITHUB_STEP_SUMMARY"
      fi
    fi
    exit 1
  fi
}

# Run main function
main
