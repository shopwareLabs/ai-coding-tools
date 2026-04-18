#!/bin/bash
#
# validate-template-sync.sh
#
# Validates that template→copy pairs stay synchronized. Pairs are supplied as
# CLI arguments so the authoritative list lives in the caller (the workflow
# and, for humans, .claude/rules/template-sync.md).
#
# Usage:
#   ./validate-template-sync.sh [--github-actions] <mode> <template> <copy> [<mode> <template> <copy> ...]
#
# Modes:
#   identical  Files must be byte-identical.
#   body       Files must share the same body below the YAML frontmatter.
#              The frontmatter (content between the first two `---` lines)
#              is stripped before comparison because it is intentionally
#              plugin-specific.
#
# Exit Codes:
#   0 - All pairs synchronized
#   1 - One or more drifts detected
#   2 - Fatal error (bad arguments, missing dependencies)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"

# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

positional=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --github-actions)
      GITHUB_ACTIONS_MODE=true
      shift
      ;;
    --)
      shift
      positional+=("$@")
      break
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

if [ "${#positional[@]}" -eq 0 ]; then
  log_error "No pairs supplied. Usage: $0 [--github-actions] <mode> <template> <copy> [<mode> <template> <copy> ...]"
  exit 2
fi

if (( ${#positional[@]} % 3 != 0 )); then
  log_error "Arguments must come in triples of <mode> <template> <copy>. Got ${#positional[@]} arguments."
  exit 2
fi

failed=0

report_drift() {
  local rel_path="$1"
  local message="$2"
  log_error "$rel_path: $message"
  if [ "$GITHUB_ACTIONS_MODE" = true ]; then
    echo "::error file=$rel_path,title=Template drift::$message"
  fi
  failed=$((failed + 1))
}

rel() {
  local p="$1"
  echo "${p#"$REPO_ROOT/"}"
}

resolve() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    echo "$p"
  else
    echo "$REPO_ROOT/$p"
  fi
}

check_identical() {
  local template copy
  template="$(resolve "$1")"
  copy="$(resolve "$2")"
  local rel_template rel_copy
  rel_template="$(rel "$template")"
  rel_copy="$(rel "$copy")"

  if [ ! -f "$template" ]; then
    report_drift "$rel_template" "template file missing"
    return
  fi
  if [ ! -f "$copy" ]; then
    report_drift "$rel_copy" "expected copy of $rel_template is missing"
    return
  fi

  if cmp -s "$template" "$copy"; then
    log_success "$rel_copy matches $rel_template"
  else
    report_drift "$rel_copy" "differs from $rel_template"
  fi
}

check_body() {
  local template copy
  template="$(resolve "$1")"
  copy="$(resolve "$2")"
  local rel_template rel_copy
  rel_template="$(rel "$template")"
  rel_copy="$(rel "$copy")"

  if [ ! -f "$template" ]; then
    report_drift "$rel_template" "template file missing"
    return
  fi
  if [ ! -f "$copy" ]; then
    report_drift "$rel_copy" "expected copy of $rel_template is missing"
    return
  fi

  local template_body copy_body
  template_body=$(mktemp)
  copy_body=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$template_body' '$copy_body'" RETURN

  awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$template" > "$template_body"
  awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$copy" > "$copy_body"

  if cmp -s "$template_body" "$copy_body"; then
    log_success "$rel_copy body matches $rel_template"
  else
    report_drift "$rel_copy" "body differs from $rel_template"
  fi
}

log_info "Validating template synchronization..."

i=0
while (( i < ${#positional[@]} )); do
  mode="${positional[i]}"
  template="${positional[i+1]}"
  copy="${positional[i+2]}"
  case "$mode" in
    identical) check_identical "$template" "$copy" ;;
    body)      check_body "$template" "$copy" ;;
    *)
      log_error "Unknown mode '$mode' at argument position $((i + 1)). Valid modes: identical, body."
      exit 2
      ;;
  esac
  i=$((i + 3))
done

echo ""
log_info "═══════════════════════════════════════════════"

if [ "$failed" -eq 0 ]; then
  log_success "All template copies are synchronized"
  if [ "$GITHUB_ACTIONS_MODE" = true ] && [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "template-sync-status=synchronized" >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi

log_error "$failed template drift(s) detected"
log_info "Fix: update the template first, then copy into every consumer listed in .claude/rules/template-sync.md"

if [ "$GITHUB_ACTIONS_MODE" = true ]; then
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "template-sync-status=drifted" >> "$GITHUB_OUTPUT"
    echo "template-sync-drifts=$failed" >> "$GITHUB_OUTPUT"
  fi
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "## ❌ Template Sync Validation Failed"
      echo ""
      echo "**$failed drift(s) detected** between \`templates/\` and their plugin copies."
      echo ""
      echo "See \`.claude/rules/template-sync.md\` for the mapping and workflow."
    } >> "$GITHUB_STEP_SUMMARY"
  fi
fi

exit 1
