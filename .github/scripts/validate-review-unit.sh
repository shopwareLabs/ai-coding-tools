#!/bin/bash
#
# validate-review-unit.sh
#
# Validates that every test-writing detection rule declares a valid `review-unit`
# frontmatter field. A rule file is any markdown file under the test-writing
# rules directory that declares an `id` in its frontmatter (mirrors the MCP
# server's indexing rule). Read-only script that never modifies files.
#
# Usage:
#   ./validate-review-unit.sh [--github-actions]
#
# Options:
#   --github-actions  Enable GitHub Actions output formatting (auto-detected from CI env)
#
# Exit Codes:
#   0 - Every rule declares a valid review-unit
#   1 - One or more rules have a missing or invalid review-unit
#   2 - Fatal error (rules directory or files not found)
#

set -euo pipefail

# Set up environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export REPO_ROOT
# RULES_DIR defaults to the bundled rules; overridable (e.g. by tests) via the env.
RULES_DIR="${RULES_DIR:-$REPO_ROOT/plugins/test-writing/rules}"

# Source libraries (logging + GitHub Actions detection)
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

VALID_VALUES=("method" "class-structure" "class-bodies")

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --github-actions)
      GITHUB_ACTIONS_MODE=true
      shift
      ;;
    *)
      log_error "Unknown option $1"
      echo "Usage: $0 [--github-actions]" >&2
      exit 2
      ;;
  esac
done

# Read a single frontmatter field's value from a rule file.
# Reads only the leading `--- ... ---` block; ignores matching lines in the body.
# Args: $1 = file path, $2 = field name
# Outputs: the trimmed field value (empty if absent)
read_frontmatter_field() {
  local file="$1" field="$2"
  local in_frontmatter=0 delim_count=0 line val
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "---" ]]; then
      delim_count=$((delim_count + 1))
      if [[ $delim_count -eq 1 ]]; then
        in_frontmatter=1
        continue
      fi
      break
    fi
    if [[ $in_frontmatter -eq 1 && "$line" == "${field}:"* ]]; then
      val="${line#"${field}":}"
      # Trim leading and trailing whitespace
      val="${val#"${val%%[![:space:]]*}"}"
      val="${val%"${val##*[![:space:]]}"}"
      printf '%s\n' "$val"
      return 0
    fi
  done < "$file"
  return 0
}

is_valid_value() {
  local candidate="$1" allowed
  for allowed in "${VALID_VALUES[@]}"; do
    [[ "$candidate" == "$allowed" ]] && return 0
  done
  return 1
}

main() {
  log_info "Validating review-unit frontmatter in test-writing rules..."

  if [[ ! -d "$RULES_DIR" ]]; then
    log_error "Rules directory not found at $RULES_DIR"
    exit 2
  fi

  local failed=0 checked=0 file id value
  while IFS= read -r file; do
    id="$(read_frontmatter_field "$file" "id")"
    # Not a rule file (no id in frontmatter) — skip, mirroring the MCP server.
    [[ -z "$id" ]] && continue
    checked=$((checked + 1))

    value="$(read_frontmatter_field "$file" "review-unit")"
    if [[ -z "$value" ]]; then
      log_error "$id ($file): missing required 'review-unit' field"
      if [[ "$GITHUB_ACTIONS_MODE" = true ]]; then
        echo "::error file=$file,title=Missing review-unit::Rule $id must declare review-unit: method|class-structure|class-bodies"
      fi
      failed=$((failed + 1))
    elif ! is_valid_value "$value"; then
      log_error "$id ($file): invalid review-unit '$value' (expected method|class-structure|class-bodies)"
      if [[ "$GITHUB_ACTIONS_MODE" = true ]]; then
        echo "::error file=$file,title=Invalid review-unit::Rule $id has review-unit '$value'; expected method|class-structure|class-bodies"
      fi
      failed=$((failed + 1))
    fi
  done < <(find "$RULES_DIR" -type f -name '*.md' | sort)

  if [[ $checked -eq 0 ]]; then
    log_error "No rule files found under $RULES_DIR"
    exit 2
  fi

  if [[ $failed -eq 0 ]]; then
    log_success "All $checked test-writing rules declare a valid review-unit"
    if [[ "$GITHUB_ACTIONS_MODE" = true ]] && [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      echo "review-unit-status=valid" >> "$GITHUB_OUTPUT"
    fi
    exit 0
  fi

  log_error "$failed of $checked test-writing rules have a missing or invalid review-unit"
  if [[ "$GITHUB_ACTIONS_MODE" = true ]] && [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## ❌ review-unit Validation Failed"
      echo ""
      echo "**$failed of $checked rules** have a missing or invalid \`review-unit\`."
      echo ""
      echo "Every rule under \`plugins/test-writing/rules/\` must declare:"
      echo ""
      echo '```yaml'
      echo "review-unit: method | class-structure | class-bodies"
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 1
}

main
