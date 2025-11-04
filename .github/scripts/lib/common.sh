#!/bin/bash
#
# common.sh
#
# Shared utility functions for issue template scripts.
# This library provides logging, validation, and environment setup.
#
# Usage:
#   source lib/common.sh
#
# Required environment variables:
#   REPO_ROOT         - Repository root directory
#   MARKETPLACE_JSON  - Path to marketplace.json
#   TEMPLATES_DIR     - Path to issue templates directory
#

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "Error: This is a library file and should be sourced, not executed directly." >&2
  exit 1
fi

# GitHub Actions mode detection
GITHUB_ACTIONS_MODE=false
if [ "${GITHUB_ACTIONS:-false}" = "true" ] || [ -n "${GITHUB_WORKFLOW:-}" ]; then
  GITHUB_ACTIONS_MODE=true
fi

# Colors for output (disabled in GitHub Actions mode)
if [ "$GITHUB_ACTIONS_MODE" = true ]; then
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
fi

# Logging functions
log_info() {
  if [ "$GITHUB_ACTIONS_MODE" = true ]; then
    echo "::notice::$1"
  else
    echo -e "${BLUE}[INFO]${NC} $1"
  fi
}

log_success() {
  if [ "$GITHUB_ACTIONS_MODE" = true ]; then
    echo "::notice::✅ $1"
  else
    echo -e "${GREEN}[SUCCESS]${NC} $1"
  fi
}

log_warning() {
  if [ "$GITHUB_ACTIONS_MODE" = true ]; then
    echo "::warning::$1"
  else
    echo -e "${YELLOW}[WARNING]${NC} $1"
  fi
}

log_error() {
  if [ "$GITHUB_ACTIONS_MODE" = true ]; then
    echo "::error::$1"
  else
    echo -e "${RED}[ERROR]${NC} $1" >&2
  fi
}

# Dependency checking
check_dependencies() {
  local missing_deps=()

  if ! command -v jq &> /dev/null; then
    missing_deps+=("jq")
  fi

  if ! command -v sed &> /dev/null; then
    missing_deps+=("sed")
  fi

  if [ ${#missing_deps[@]} -ne 0 ]; then
    log_error "Missing required dependencies: ${missing_deps[*]}"
    log_error "Install with: brew install ${missing_deps[*]} (macOS) or apt-get install ${missing_deps[*]} (Linux)"
    exit 2
  fi
}

# File validation
validate_files() {
  if [ ! -f "$MARKETPLACE_JSON" ]; then
    log_error "marketplace.json not found at $MARKETPLACE_JSON"
    exit 2
  fi

  if [ ! -d "$TEMPLATES_DIR" ]; then
    log_error "Issue templates directory not found at $TEMPLATES_DIR"
    exit 2
  fi
}
