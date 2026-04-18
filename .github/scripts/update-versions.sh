#!/bin/bash
#
# update-versions.sh
#
# Synchronizes plugin versions from plugin.json (authoritative source)
# to all other locations: SKILL.md frontmatter and CHANGELOG.md.
# Authoritative source: Each plugin's .claude-plugin/plugin.json
#
# Usage:
#   ./update-versions.sh [--dry-run] [--plugin <name>]
#
# Options:
#   --dry-run         Show what would be updated without making changes
#   --plugin <name>   Only update a specific plugin
#
# Exit Codes:
#   0 - Versions synchronized successfully
#   2 - Fatal error (missing dependencies, files not found)
#
# Note: Creates backup files with .bak extension before modifying files.
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

# Script options
DRY_RUN=false
SINGLE_PLUGIN=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --plugin)
      SINGLE_PLUGIN="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}" >&2
      echo "Usage: $0 [--dry-run] [--plugin <name>]" >&2
      exit 1
      ;;
  esac
done

# Custom validation for version scripts
validate_version_files() {
  if [ ! -f "$MARKETPLACE_JSON" ]; then
    log_error "marketplace.json not found at $MARKETPLACE_JSON"
    exit 2
  fi
}

# Update all SKILL.md versions for a plugin
update_plugin_skills() {
  local plugin_name="$1"
  local target_version="$2"

  local skills
  skills=$(get_plugin_skills "$plugin_name")

  if [ -z "$skills" ]; then
    log_info "Plugin '$plugin_name' has no skills"
    return 0
  fi

  while IFS= read -r skill_file; do
    local current_version
    current_version=$(extract_skill_version "$skill_file")

    local relative_path="${skill_file#"$REPO_ROOT/"}"

    if [ -z "$current_version" ]; then
      log_warning "$relative_path: no version in frontmatter - skipping"
      continue
    fi

    if [ "$current_version" = "$target_version" ]; then
      log_info "$relative_path: already at $target_version"
      continue
    fi

    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY-RUN] Would update $relative_path: $current_version -> $target_version"
    else
      update_skill_version "$skill_file" "$target_version"
      log_success "$relative_path: $current_version -> $target_version"
    fi
  done <<< "$skills"
}

# Update CHANGELOG.md version for a plugin (add header if missing)
update_plugin_changelog() {
  local plugin_name="$1"
  local target_version="$2"

  local changelog
  changelog=$(get_plugin_changelog "$plugin_name")

  if [ -z "$changelog" ]; then
    log_info "Plugin '$plugin_name' has no CHANGELOG.md"
    return 0
  fi

  local current_version
  current_version=$(extract_changelog_version "$changelog")
  local relative_path="${changelog#"$REPO_ROOT/"}"

  if [ -z "$current_version" ]; then
    log_warning "$relative_path: no version header found"
    if [ "$DRY_RUN" = true ]; then
      log_info "[DRY-RUN] Would add version header $target_version to $relative_path"
    else
      update_changelog_header "$changelog" "$target_version"
      log_success "$relative_path: added version header $target_version"
    fi
    return 0
  fi

  if [ "$current_version" = "$target_version" ]; then
    log_info "$relative_path: already at $target_version"
    return 0
  fi

  # CHANGELOG versions typically shouldn't be auto-updated - they represent history
  # Only add new version headers, don't modify existing ones
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would add version header $target_version to $relative_path (current: $current_version)"
  else
    update_changelog_header "$changelog" "$target_version"
    log_success "$relative_path: added version header $target_version (previous: $current_version)"
  fi
}

# Update all versions for a single plugin
update_plugin_versions() {
  local plugin_name="$1"

  log_info "Processing plugin: $plugin_name"

  # Get authoritative version from plugin's .claude-plugin/plugin.json
  local plugin_version
  plugin_version=$(extract_plugin_version "$plugin_name")

  if [ -z "$plugin_version" ]; then
    log_error "Plugin '$plugin_name' not found or missing .claude-plugin/plugin.json"
    return 1
  fi

  log_info "Target version: $plugin_version"

  # Update each location
  update_plugin_skills "$plugin_name" "$plugin_version"
  update_plugin_changelog "$plugin_name" "$plugin_version"
}

# Main execution
main() {
  if [ "$DRY_RUN" = true ]; then
    log_info "Starting version synchronization (DRY-RUN mode)..."
  else
    log_info "Starting version synchronization..."
  fi

  # Validation
  check_dependencies
  validate_version_files

  # Determine which plugins to process
  local plugins
  if [ -n "$SINGLE_PLUGIN" ]; then
    # Verify plugin exists
    if ! jq -e --arg name "$SINGLE_PLUGIN" '.plugins[] | select(.name == $name)' "$MARKETPLACE_JSON" > /dev/null 2>&1; then
      log_error "Plugin '$SINGLE_PLUGIN' not found in marketplace.json"
      exit 2
    fi
    plugins="$SINGLE_PLUGIN"
  else
    plugins=$(jq -r '.plugins[].name' "$MARKETPLACE_JSON" | sort)
  fi

  if [ -z "$plugins" ]; then
    log_error "No plugins found in marketplace.json"
    exit 2
  fi

  # Process each plugin
  local total_plugins=0
  while IFS= read -r plugin_name; do
    ((++total_plugins))
    echo ""  # Visual separator
    update_plugin_versions "$plugin_name"
  done <<< "$plugins"

  echo ""
  log_info "═══════════════════════════════════════════════"

  if [ "$DRY_RUN" = true ]; then
    log_success "Dry-run complete! Reviewed $total_plugins plugin(s)"
    log_info "Run without --dry-run to apply changes"
  else
    log_success "Version synchronization complete!"
    log_info "Updated $total_plugins plugin(s)"
    log_info "Backup files created with .bak extension"
  fi
}

# Run main function
main
