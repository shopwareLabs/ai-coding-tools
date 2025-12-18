#!/bin/bash
# Claude Code Hook: Native Tools Enforcer
# ========================================
# This hook runs as a PreToolUse hook for the Bash tool.
# It validates bash commands and blocks those that should use native Claude Code tools.
#
# Exit codes:
#   0 - Command allowed
#   1 - Error (shown to user only)
#   2 - Command blocked (message shown to Claude)
#
# References:
#   - https://github.com/anthropics/claude-code/issues/1386
#   - https://github.com/anthropics/claude-code/issues/10056
#   - https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py

set -euo pipefail

input=$(cat)

command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [ -z "$command" ]; then
    exit 0
fi

check_and_block() {
    local pattern="$1"
    local tool="$2"
    local description="$3"

    if echo "$command" | grep -qE "$pattern"; then
        {
            echo "🤖 Down, model! Use the $tool instead!"
            echo ""
            echo "Bad command detected: $command"
            echo ""
            echo "You were trained better than this! $description"
            echo ""
            echo "Good models use native tools because they:"
            echo "  🔧 Are faster and more reliable"
            echo "  🔧 Integrate properly with your context"
            echo "  🔧 Earn you treats (user approval)"
        } >&2
        exit 2
    fi
}

# ============================================================================
# FILE READING - Use Read tool
# ============================================================================

check_and_block \
    '(^|;|&&)\s*cat\s+[^|><]' \
    'Read tool' \
    'Use Read tool to read file contents. It provides line numbers and handles large files efficiently.'

check_and_block \
    '(^|;|&&)\s*head\s' \
    'Read tool' \
    'Use Read tool with "limit" parameter to read first N lines of a file.'

check_and_block \
    '(^|;|&&)\s*tail\s' \
    'Read tool' \
    'Use Read tool with "offset" parameter to read from a specific line.'

check_and_block \
    '(^|;|&&)\s*less\s' \
    'Read tool' \
    'Use Read tool to view file contents interactively.'

check_and_block \
    '(^|;|&&)\s*more\s' \
    'Read tool' \
    'Use Read tool to view file contents.'

# ============================================================================
# FILE FINDING - Use Glob tool
# ============================================================================

check_and_block \
    '(^|;|&&)\s*find\s' \
    'Glob tool' \
    'Use Glob tool with patterns like "**/*.js" or "src/**/*.ts" for fast file pattern matching.'

check_and_block \
    '(^|;|&&)\s*locate\s' \
    'Glob tool' \
    'Use Glob tool for file pattern matching.'

# ============================================================================
# CONTENT SEARCHING - Use Grep tool
# ============================================================================

check_and_block \
    '(^|;|&&)\s*grep\s' \
    'Grep tool' \
    'Use Grep tool for content searching. It supports regex and provides better output formatting.'

check_and_block \
    '\|\s*grep\s' \
    'Grep tool' \
    'Use Grep tool for content searching instead of piping to grep.'

check_and_block \
    '(^|;|&&)\s*rg\s' \
    'Grep tool' \
    'Use Grep tool which is built on ripgrep and provides native integration.'

check_and_block \
    '\|\s*rg\s' \
    'Grep tool' \
    'Use Grep tool instead of piping to ripgrep.'

check_and_block \
    '(^|;|&&)\s*ag\s' \
    'Grep tool' \
    'Use Grep tool instead of silver searcher (ag).'

check_and_block \
    '(^|;|&&)\s*ack\s' \
    'Grep tool' \
    'Use Grep tool instead of ack.'

# ============================================================================
# FILE WRITING - Use Write tool
# ============================================================================

check_and_block \
    'echo\s+.*>\s*[^&]' \
    'Write tool' \
    'Use Write tool to create or overwrite files. It handles content safely and tracks changes.'

check_and_block \
    'printf\s+.*>\s*[^&]' \
    'Write tool' \
    'Use Write tool to create or overwrite files.'

check_and_block \
    'cat\s*>\s*[^&]' \
    'Write tool' \
    'Use Write tool to create files.'

check_and_block \
    'cat\s*<<' \
    'Write tool' \
    'Use Write tool instead of heredoc for creating files with content.'

check_and_block \
    '\|\s*tee\s' \
    'Write tool' \
    'Use Write tool to write content to files.'

# ============================================================================
# FILE EDITING - Use Edit tool
# ============================================================================

check_and_block \
    '(^|;|&&)\s*sed\s' \
    'Edit tool' \
    'Use Edit tool for file modifications. It provides safe string replacement with context.'

check_and_block \
    '\|\s*sed\s' \
    'Edit tool' \
    'Use Edit tool for text transformations instead of piping to sed.'

check_and_block \
    'sed\s+-i' \
    'Edit tool' \
    'Use Edit tool for in-place file editing. It tracks changes and handles conflicts.'

check_and_block \
    '(^|;|&&)\s*awk\s' \
    'Edit tool' \
    'Use Edit tool for file transformations.'

check_and_block \
    '\|\s*awk\s' \
    'Edit tool' \
    'Use Edit tool for text transformations instead of piping to awk.'

check_and_block \
    'perl\s+-i' \
    'Edit tool' \
    'Use Edit tool for in-place file editing.'

exit 0
