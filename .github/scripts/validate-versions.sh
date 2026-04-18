#!/bin/bash
#
# validate-versions.sh
#
# Validates that plugin versions are synchronized across all locations:
# - plugin.json (authoritative source: .claude-plugin/plugin.json per plugin)
# - SKILL.md YAML frontmatter
# - CHANGELOG.md latest version headers
#
# Usage:
#   ./validate-versions.sh [--github-actions]
#
# Options:
#   --github-actions  Enable GitHub Actions output formatting (auto-detected from CI env)
#
# Exit Codes:
#   0 - All versions are synchronized
#   1 - One or more version mismatches detected
#   2 - Fatal error (missing dependencies, files not found)
#

set -euo pipefail

# Set up environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export REPO_ROOT
export MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"

# Source libraries
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=./lib/version-operations.sh
source "$SCRIPT_DIR/lib/version-operations.sh"

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

# Custom validation for version scripts (no TEMPLATES_DIR needed)
validate_version_files() {
  if [ ! -f "$MARKETPLACE_JSON" ]; then
    log_error "marketplace.json not found at $MARKETPLACE_JSON"
    exit 2
  fi
}

# Validate all SKILL.md versions for a plugin
# Returns 0 if all matching, 1 if any mismatched
validate_skill_versions() {
  local plugin_name="$1"
  local expected_version="$2"
  local failed=0

  local skills
  skills=$(get_plugin_skills "$plugin_name")

  if [ -z "$skills" ]; then
    log_warning "Plugin '$plugin_name' has no skills"
    return 0  # Not an error - some plugins don't have skills
  fi

  while IFS= read -r skill_file; do
    local skill_version
    skill_version=$(extract_skill_version "$skill_file")

    local relative_path="${skill_file#"$REPO_ROOT/"}"

    if [ -z "$skill_version" ]; then
      log_error "$relative_path: version not found in frontmatter"
      if [ "$GITHUB_ACTIONS_MODE" = true ]; then
        echo "::error file=$relative_path,title=Missing version::SKILL.md frontmatter missing 'version' field"
      fi
      ((failed++))
      continue
    fi

    if [ "$skill_version" = "$expected_version" ]; then
      log_success "$relative_path: version $skill_version"
    else
      log_error "$relative_path: version mismatch (expected $expected_version, found $skill_version)"
      if [ "$GITHUB_ACTIONS_MODE" = true ]; then
        echo "::error file=$relative_path,title=Version mismatch::Expected $expected_version, found $skill_version"
      fi
      ((failed++))
    fi
  done <<< "$skills"

  [ $failed -eq 0 ]
}

# Validate CHANGELOG.md version for a plugin
# Returns 0 if matching, 1 if mismatched
validate_changelog_version() {
  local plugin_name="$1"
  local expected_version="$2"

  local changelog
  changelog=$(get_plugin_changelog "$plugin_name")

  if [ -z "$changelog" ]; then
    log_warning "Plugin '$plugin_name' has no CHANGELOG.md"
    if [ "$GITHUB_ACTIONS_MODE" = true ]; then
      echo "::warning::Plugin '$plugin_name' has no CHANGELOG.md file"
    fi
    return 1
  fi

  local changelog_version
  changelog_version=$(extract_changelog_version "$changelog")
  local relative_path="${changelog#"$REPO_ROOT/"}"

  if [ -z "$changelog_version" ]; then
    log_error "$relative_path: no version header found"
    if [ "$GITHUB_ACTIONS_MODE" = true ]; then
      echo "::error file=$relative_path,title=Missing version::CHANGELOG.md has no version header"
    fi
    return 1
  fi

  if [ "$changelog_version" = "$expected_version" ]; then
    log_success "$relative_path: version $changelog_version"
    return 0
  else
    log_error "$relative_path: version mismatch (expected $expected_version, found $changelog_version)"
    if [ "$GITHUB_ACTIONS_MODE" = true ]; then
      echo "::error file=$relative_path,title=Version mismatch::Expected $expected_version, found $changelog_version"
    fi
    return 1
  fi
}

# Validate all versions for a single plugin
# Returns 0 if all synchronized, 1 if any mismatches
validate_plugin_versions() {
  local plugin_name="$1"
  local failed=0

  log_info "Validating plugin: $plugin_name"

  # Get authoritative version from plugin's .claude-plugin/plugin.json
  local plugin_version
  plugin_version=$(extract_plugin_version "$plugin_name")

  if [ -z "$plugin_version" ]; then
    log_error "Plugin '$plugin_name' not found or missing .claude-plugin/plugin.json"
    return 1
  fi

  log_info "Authoritative version: $plugin_version"

  # Validate each location
  validate_skill_versions "$plugin_name" "$plugin_version" || ((failed++))
  validate_changelog_version "$plugin_name" "$plugin_version" || ((failed++))

  [ $failed -eq 0 ]
}

# Main execution
main() {
  log_info "Validating plugin version consistency..."

  # Validation
  check_dependencies
  validate_version_files

  # Get all plugins from marketplace.json
  local plugins
  plugins=$(jq -r '.plugins[].name' "$MARKETPLACE_JSON" | sort)

  if [ -z "$plugins" ]; then
    log_error "No plugins found in marketplace.json"
    exit 2
  fi

  # Track validation results
  local total_plugins=0
  local failed_plugins=0
  local failed_plugin_names=()

  # Validate each plugin
  while IFS= read -r plugin_name; do
    ((++total_plugins))
    echo ""  # Visual separator
    if ! validate_plugin_versions "$plugin_name"; then
      ((++failed_plugins))
      failed_plugin_names+=("$plugin_name")
    fi
  done <<< "$plugins"

  echo ""
  log_info "═══════════════════════════════════════════════"

  if [ $failed_plugins -eq 0 ]; then
    log_success "All $total_plugins plugin(s) have synchronized versions!"

    # GitHub Actions: Set output for downstream jobs
    if [ "$GITHUB_ACTIONS_MODE" = true ] && [ -n "${GITHUB_OUTPUT:-}" ]; then
      echo "versions-status=synchronized" >> "$GITHUB_OUTPUT"
      echo "versions-mismatched=0" >> "$GITHUB_OUTPUT"
    fi
    exit 0
  else
    log_error "$failed_plugins of $total_plugins plugin(s) have version mismatches"
    log_info "Plugins with issues: ${failed_plugin_names[*]}"
    log_info "Run '.github/scripts/update-versions.sh' to synchronize versions"

    # GitHub Actions: Set output and create job summary
    if [ "$GITHUB_ACTIONS_MODE" = true ]; then
      # Set output variables if available
      if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "versions-status=mismatched" >> "$GITHUB_OUTPUT"
        echo "versions-mismatched=$failed_plugins" >> "$GITHUB_OUTPUT"
      fi

      # Create job summary if available
      if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        {
          echo "## ❌ Plugin Version Validation Failed"
          echo ""
          echo "**$failed_plugins of $total_plugins plugin(s) have version mismatches**"
          echo ""
          echo "### Affected Plugins"
          echo ""
          for name in "${failed_plugin_names[@]}"; do
            echo "- \`$name\`"
          done
          echo ""
          echo "### Action Required"
          echo ""
          echo "Run the following command to synchronize versions:"
          echo '```bash'
          echo ".github/scripts/update-versions.sh"
          echo '```'
          echo ""
          echo "Then commit the changes:"
          echo '```bash'
          echo 'git add README.md plugins/'
          echo 'git commit -m "chore: synchronize plugin versions"'
          echo '```'
          echo ""
          echo "### Version Sources"
          echo ""
          echo "| Location | Description |"
          echo "|----------|-------------|"
          echo "| \`plugins/**/.claude-plugin/plugin.json\` | **Authoritative source** |"
          echo "| \`plugins/**/skills/*/SKILL.md\` | YAML frontmatter: \`version: X.Y.Z\` |"
          echo "| \`plugins/**/CHANGELOG.md\` | Latest header: \`## [X.Y.Z]\` |"
        } >> "$GITHUB_STEP_SUMMARY"
      fi
    fi
    exit 1
  fi
}

# Run main function
main
