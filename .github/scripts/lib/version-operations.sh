#!/bin/bash
#
# version-operations.sh
#
# Version extraction and update functions for plugin version management.
# Provides operations to read and write versions across marketplace.json,
# README.md, SKILL.md frontmatter, and CHANGELOG.md files.
#
# Usage:
#   source lib/version-operations.sh
#   version=$(extract_marketplace_version "plugin-name")
#   update_skill_version "$skill_file" "1.2.0"
#
# Requirements:
#   - jq (for parsing marketplace.json)
#   - REPO_ROOT environment variable must be set
#   - MARKETPLACE_JSON environment variable must be set
#

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "Error: This is a library file and should be sourced, not executed directly." >&2
  exit 1
fi

# === VERSION EXTRACTION FUNCTIONS ===

# extract_marketplace_version - Get version from marketplace.json by plugin name
# Args: plugin_name
# Output: Version string (e.g., "1.2.0") or empty if not found
extract_marketplace_version() {
  local plugin_name="$1"
  jq -r --arg name "$plugin_name" '.plugins[] | select(.name == $name) | .version // empty' "$MARKETPLACE_JSON"
}

# extract_readme_version - Get version from README.md plugin header
# Args: plugin_name
# Output: Version string (e.g., "1.2.0") or empty if not found
# Parses headers like: ### plugin-name (v1.2.0)
extract_readme_version() {
  local plugin_name="$1"
  local readme="$REPO_ROOT/README.md"

  if [ ! -f "$readme" ]; then
    return
  fi

  # Match pattern: ### plugin-name (vX.Y.Z)
  grep -E "^### $plugin_name \(v[0-9]+\.[0-9]+\.[0-9]+\)" "$readme" 2>/dev/null | \
    sed -E 's/.*\(v([0-9]+\.[0-9]+\.[0-9]+)\).*/\1/' | head -1
}

# extract_skill_version - Get version from SKILL.md YAML frontmatter
# Args: skill_file_path
# Output: Version string (e.g., "1.2.0") or empty if not found
extract_skill_version() {
  local skill_file="$1"

  if [ ! -f "$skill_file" ]; then
    return
  fi

  # Extract version from YAML frontmatter (between --- delimiters)
  awk '
    BEGIN { in_frontmatter=0 }
    /^---$/ {
      if (in_frontmatter) exit
      in_frontmatter=1
      next
    }
    in_frontmatter && /^version:/ {
      # Handle both "version: 1.2.0" and "version: \"1.2.0\""
      gsub(/^version:[ \t]*/, "")
      gsub(/["\x27]/, "")
      gsub(/[ \t]+$/, "")
      print
      exit
    }
  ' "$skill_file"
}

# extract_changelog_version - Get latest version from CHANGELOG.md header
# Args: changelog_file_path
# Output: Version string (e.g., "1.2.0") or empty if not found
# Parses headers like: ## [1.2.0] - 2024-01-15
extract_changelog_version() {
  local changelog_file="$1"

  if [ ! -f "$changelog_file" ]; then
    return
  fi

  # Match first version header: ## [X.Y.Z]
  grep -m1 -E "^## \[[0-9]+\.[0-9]+\.[0-9]+\]" "$changelog_file" 2>/dev/null | \
    sed -E 's/## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/'
}

# === PLUGIN DISCOVERY FUNCTIONS ===

# get_plugin_source_dir - Get the source directory for a plugin
# Args: plugin_name
# Output: Absolute path to plugin directory or empty if not found
get_plugin_source_dir() {
  local plugin_name="$1"
  local source_path

  source_path=$(jq -r --arg name "$plugin_name" '.plugins[] | select(.name == $name) | .source // empty' "$MARKETPLACE_JSON")

  if [ -z "$source_path" ]; then
    return
  fi

  # Convert relative path (./plugins/...) to absolute
  echo "$REPO_ROOT/${source_path#./}"
}

# get_plugin_skills - Get all SKILL.md files for a plugin
# Args: plugin_name
# Output: One absolute path per line
get_plugin_skills() {
  local plugin_name="$1"
  local plugin_dir

  plugin_dir=$(get_plugin_source_dir "$plugin_name")

  if [ -z "$plugin_dir" ] || [ ! -d "$plugin_dir" ]; then
    return
  fi

  find "$plugin_dir" -type f -path "*/skills/*/SKILL.md" -print 2>/dev/null | sort
}

# get_plugin_changelog - Get CHANGELOG.md path for a plugin
# Args: plugin_name
# Output: Absolute path to CHANGELOG.md or empty if not found
get_plugin_changelog() {
  local plugin_name="$1"
  local plugin_dir

  plugin_dir=$(get_plugin_source_dir "$plugin_name")

  if [ -z "$plugin_dir" ] || [ ! -d "$plugin_dir" ]; then
    return
  fi

  local changelog="$plugin_dir/CHANGELOG.md"
  if [ -f "$changelog" ]; then
    echo "$changelog"
  fi
}

# === VERSION UPDATE FUNCTIONS ===

# update_readme_version - Update plugin version in README.md
# Args: plugin_name new_version
# Creates backup with .bak extension
update_readme_version() {
  local plugin_name="$1"
  local new_version="$2"
  local readme="$REPO_ROOT/README.md"

  if [ ! -f "$readme" ]; then
    return 1
  fi

  # Create backup
  cp "$readme" "${readme}.bak"

  # Replace version in plugin header: ### plugin-name (vX.Y.Z) -> ### plugin-name (vNEW)
  sed -i.tmp -E "s/^(### ${plugin_name} \(v)[0-9]+\.[0-9]+\.[0-9]+(\))/\1${new_version}\2/" "$readme"
  rm -f "${readme}.tmp"
}

# update_skill_version - Update version in SKILL.md YAML frontmatter
# Args: skill_file new_version
# Creates backup with .bak extension
update_skill_version() {
  local skill_file="$1"
  local new_version="$2"

  if [ ! -f "$skill_file" ]; then
    return 1
  fi

  # Create backup
  cp "$skill_file" "${skill_file}.bak"

  # Update version in YAML frontmatter using awk
  awk -v newver="$new_version" '
    BEGIN { in_frontmatter=0; done=0 }
    /^---$/ {
      if (in_frontmatter) {
        in_frontmatter=0
      } else {
        in_frontmatter=1
      }
      print
      next
    }
    in_frontmatter && /^version:/ && !done {
      print "version: " newver
      done=1
      next
    }
    { print }
  ' "${skill_file}.bak" > "$skill_file"
}

# update_changelog_header - Add new version header to CHANGELOG.md
# Args: changelog_file new_version
# Creates backup with .bak extension
# Note: Only adds header stub, does not populate content
update_changelog_header() {
  local changelog_file="$1"
  local new_version="$2"
  local today

  if [ ! -f "$changelog_file" ]; then
    return 1
  fi

  # Check if version already exists
  if grep -q "^## \[$new_version\]" "$changelog_file"; then
    return 0  # Already exists, nothing to do
  fi

  # Create backup
  cp "$changelog_file" "${changelog_file}.bak"

  today=$(date +%Y-%m-%d)

  # Insert new version header after the first # Changelog line
  awk -v ver="$new_version" -v date="$today" '
    BEGIN { inserted=0 }
    /^# / && !inserted {
      print
      print ""
      print "## [" ver "] - " date
      print ""
      print "### Added"
      print ""
      print "### Changed"
      print ""
      print "### Fixed"
      print ""
      inserted=1
      next
    }
    { print }
  ' "${changelog_file}.bak" > "$changelog_file"
}
