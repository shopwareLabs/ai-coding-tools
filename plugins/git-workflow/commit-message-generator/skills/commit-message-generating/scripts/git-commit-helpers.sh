#!/usr/bin/env bash

# Git Commit Helper Functions
# Utility functions for commit message generation and validation

set -euo pipefail

# Change to working directory if WORK_DIR is set
# This ensures git commands run in the user's project, not the plugin directory
if [ -n "${WORK_DIR:-}" ]; then
    cd "$WORK_DIR"
fi

#######################################
# Get staged changes diff
# Outputs: Diff of staged changes
# Returns: 0 if successful, 1 if no staged changes or not a git repo
#######################################
get_staged_diff() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not a git repository" >&2
        return 1
    fi

    if ! git diff --cached --quiet 2>/dev/null; then
        git diff --cached
        return 0
    else
        echo "Error: No staged changes found" >&2
        return 1
    fi
}

#######################################
# Get staged files with status
# Outputs: File paths with status (A/M/D)
# Returns: 0 if successful, 1 if no staged changes
#######################################
get_staged_files() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not a git repository" >&2
        return 1
    fi

    git diff --cached --name-status
}

#######################################
# Get commit message for a reference
# Arguments:
#   $1 - Commit reference (default: HEAD)
# Outputs: Commit message
# Returns: 0 if successful, 1 if commit not found
#######################################
get_commit_message() {
    local commit_ref="${1:-HEAD}"

    if ! git rev-parse --verify "$commit_ref" > /dev/null 2>&1; then
        echo "Error: Commit '$commit_ref' not found" >&2
        return 1
    fi

    git log -1 --pretty=%B "$commit_ref"
}

#######################################
# Get commit diff for a reference
# Arguments:
#   $1 - Commit reference (default: HEAD)
# Outputs: Diff of commit
# Returns: 0 if successful, 1 if commit not found
#######################################
get_commit_diff() {
    local commit_ref="${1:-HEAD}"

    if ! git rev-parse --verify "$commit_ref" > /dev/null 2>&1; then
        echo "Error: Commit '$commit_ref' not found" >&2
        return 1
    fi

    git show --pretty="" "$commit_ref"
}

#######################################
# Get changed files for a commit
# Arguments:
#   $1 - Commit reference (default: HEAD)
# Outputs: File paths with status (A/M/D)
# Returns: 0 if successful, 1 if commit not found
#######################################
get_commit_files() {
    local commit_ref="${1:-HEAD}"

    if ! git rev-parse --verify "$commit_ref" > /dev/null 2>&1; then
        echo "Error: Commit '$commit_ref' not found" >&2
        return 1
    fi

    git show --name-status --pretty="" "$commit_ref"
}

#######################################
# Parse commit type from message
# Arguments:
#   $1 - Commit message
# Outputs: Commit type (feat, fix, etc.) or empty if invalid
# Returns: 0 if valid format, 1 if invalid
#######################################
parse_commit_type() {
    local message="$1"

    # Extract type from conventional commit format
    # Matches: type(scope): subject OR type: subject
    # Type is alphanumeric before first ( or :
    if [[ "$message" =~ ^([a-z]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    else
        return 1
    fi
}

#######################################
# Parse commit scope from message
# Arguments:
#   $1 - Commit message
# Outputs: Commit scope or empty if none
# Returns: 0 always
#######################################
parse_commit_scope() {
    local message="$1"

    # Extract scope from conventional commit format: type(scope): subject
    # Use grep to safely extract the scope from parentheses
    local scope
    scope=$(echo "$message" | grep -oP '(?<=\()[^)]+(?=\))' 2>/dev/null || true)

    if [[ -n "$scope" ]]; then
        echo "$scope"
        return 0
    else
        echo ""
        return 0
    fi
}

#######################################
# Parse commit subject from message
# Arguments:
#   $1 - Commit message
# Outputs: Commit subject (first line after type/scope)
# Returns: 0 if valid format, 1 if invalid
#######################################
parse_commit_subject() {
    local message="$1"

    # Extract subject from conventional commit format
    # Matches: type(scope): subject OR type: subject
    # Subject comes after the colon and space
    local subject
    subject=$(echo "$message" | sed -n 's/^[a-z][a-z-]*(\?[^)]*\)?!?: //p' | head -n1)

    if [[ -n "$subject" ]]; then
        echo "$subject"
        return 0
    else
        return 1
    fi
}

#######################################
# Check if commit has breaking change marker
# Arguments:
#   $1 - Commit message
# Outputs: "true" or "false"
# Returns: 0 always
#######################################
has_breaking_change_marker() {
    local message="$1"

    # Check for ! marker after type or scope
    if [[ "$message" == *"!"* ]]; then
        # Simple check: look for ! before the colon
        local first_line
        first_line=$(echo "$message" | head -n1)
        if [[ "$first_line" =~ \!: ]]; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

#######################################
# Validate commit message format (basic regex check)
# Arguments:
#   $1 - Commit message
# Outputs: Validation errors (if any)
# Returns: 0 if valid, 1 if invalid
#######################################
validate_commit_format() {
    local message="$1"
    local errors=()
    local first_line
    first_line=$(echo "$message" | head -n1)

    # Check basic conventional commit format
    # Must contain: type, colon, space, and subject
    if ! echo "$first_line" | grep -qE '^[a-z][a-z-]*(\([^)]*\))?!?: '; then
        errors+=("Invalid conventional commit format. Expected: type(scope): subject")
    fi

    # Check subject doesn't end with period
    if [[ "$first_line" == *. ]]; then
        errors+=("Subject should not end with a period")
    fi

    # Check subject length (first line after type/scope)
    local subject
    subject=$(echo "$first_line" | sed -n 's/^[a-z][a-z-]*[^:]*: //p')
    if [[ -n "$subject" ]]; then
        local subject_len=${#subject}
        if [ "$subject_len" -gt 72 ]; then
            errors+=("Subject too long: $subject_len characters (max 72)")
        fi
        if [ "$subject_len" -lt 10 ]; then
            errors+=("Subject too short: $subject_len characters (min 10)")
        fi
    fi

    # Output errors if any
    if [ ${#errors[@]} -gt 0 ]; then
        for error in "${errors[@]}"; do
            echo "$error"
        done
        return 1
    fi

    return 0
}

#######################################
# Get commit hash from reference
# Arguments:
#   $1 - Commit reference (default: HEAD)
# Outputs: Full commit SHA
# Returns: 0 if successful, 1 if not found
#######################################
get_commit_hash() {
    local commit_ref="${1:-HEAD}"

    if ! git rev-parse --verify "$commit_ref" > /dev/null 2>&1; then
        echo "Error: Commit '$commit_ref' not found" >&2
        return 1
    fi

    git rev-parse "$commit_ref"
}

#######################################
# Get short commit hash from reference
# Arguments:
#   $1 - Commit reference (default: HEAD)
# Outputs: Short commit SHA (7 chars)
# Returns: 0 if successful, 1 if not found
#######################################
get_commit_hash_short() {
    local commit_ref="${1:-HEAD}"

    if ! git rev-parse --verify "$commit_ref" > /dev/null 2>&1; then
        echo "Error: Commit '$commit_ref' not found" >&2
        return 1
    fi

    git rev-parse --short "$commit_ref"
}

#######################################
# Check if working directory is clean
# Outputs: Nothing
# Returns: 0 if clean, 1 if dirty
#######################################
is_working_directory_clean() {
    git diff-index --quiet HEAD --
}

#######################################
# Get list of modified file paths from diff
# Arguments:
#   $1 - Diff output
# Outputs: File paths (one per line)
# Returns: 0 always
#######################################
extract_file_paths() {
    local diff="$1"

    echo "$diff" | grep -E '^\+\+\+ b/' | sed 's/^+++ b\///' | grep -v '/dev/null' || true
}

# Export functions for use in other scripts
export -f get_staged_diff
export -f get_staged_files
export -f get_commit_message
export -f get_commit_diff
export -f get_commit_files
export -f parse_commit_type
export -f parse_commit_scope
export -f parse_commit_subject
export -f has_breaking_change_marker
export -f validate_commit_format
export -f get_commit_hash
export -f get_commit_hash_short
export -f is_working_directory_clean
export -f extract_file_paths
