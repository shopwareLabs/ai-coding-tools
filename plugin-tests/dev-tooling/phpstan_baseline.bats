#!/usr/bin/env bats
# bats file_tags=dev-tooling,phpstan,baseline
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

BASELINE_SCRIPT="${REPO_ROOT}/plugins/dev-tooling/hooks/scripts/check-phpstan-baseline.sh"

# Helper: create PostToolUse JSON input with given paths array
make_post_input() {
    local paths_json="$1"
    printf '{"tool_input": {"paths": %s}, "cwd": "%s"}' "$paths_json" "$BATS_TEST_TMPDIR"
}

# Helper: run the hook with given JSON input
run_baseline_hook() {
    local input="$1"
    export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR"
    run bash -c 'printf "%s" "$1" | bash "$2"' _ "$input" "$BASELINE_SCRIPT"
}

# Helper: create a .php baseline with entries for given paths
create_php_baseline() {
    local file="${BATS_TEST_TMPDIR}/phpstan-baseline.php"
    {
        printf '<?php declare(strict_types=1);\n\n'
        printf '$ignoreErrors = [];\n'
        for path in "$@"; do
            printf "\$ignoreErrors[] = [\n"
            printf "    'rawMessage' => 'Some error',\n"
            printf "    'identifier' => 'some.error',\n"
            printf "    'count' => 1,\n"
            printf "    'path' => __DIR__ . '/%s',\n" "$path"
            printf "];\n"
        done
    } > "$file"
}

# Helper: create a .neon baseline with entries for given paths
create_neon_baseline() {
    local file="${BATS_TEST_TMPDIR}/phpstan-baseline.neon"
    {
        printf 'parameters:\n'
        printf '    ignoreErrors:\n'
        for path in "$@"; do
            printf '        -\n'
            printf '            message: "#Some error#"\n'
            printf '            count: 1\n'
            printf '            path: %s\n' "$path"
        done
    } > "$file"
}

# ============================================================================
# No output when not applicable
# ============================================================================

# bats test_tags=skip
@test "silent when no paths in tool_input" {
    create_php_baseline "src/Foo.php"
    run_baseline_hook '{"tool_input": {}}'
    assert_success
    assert_output ""
}

@test "silent when paths array is empty" {
    create_php_baseline "src/Foo.php"
    run_baseline_hook "$(make_post_input '[]')"
    assert_success
    assert_output ""
}

@test "silent when no baseline file exists" {
    run_baseline_hook "$(make_post_input '["src/Foo.php"]')"
    assert_success
    assert_output ""
}

@test "silent when analyzed files have no baseline entries" {
    create_php_baseline "src/Other.php"
    run_baseline_hook "$(make_post_input '["src/Foo.php"]')"
    assert_success
    assert_output ""
}

# ============================================================================
# PHP baseline detection
# ============================================================================

# bats test_tags=php-baseline
@test "warns when analyzed file matches PHP baseline entry" {
    create_php_baseline "src/Foo.php"
    run_baseline_hook "$(make_post_input '["src/Foo.php"]')"
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("src/Foo.php")'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("phpstan-baseline.php")'
}

@test "warns for multiple matching files in PHP baseline" {
    create_php_baseline "src/Foo.php" "src/Bar.php" "src/Baz.php"
    run_baseline_hook "$(make_post_input '["src/Foo.php", "src/Bar.php"]')"
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("src/Foo.php")'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("src/Bar.php")'
}

@test "only reports matching files, not unmatched ones" {
    create_php_baseline "src/Foo.php"
    run_baseline_hook "$(make_post_input '["src/Foo.php", "src/Other.php"]')"
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("src/Foo.php")'
    local ctx
    ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
    [[ "$ctx" != *"src/Other.php"* ]]
}

# ============================================================================
# NEON baseline detection
# ============================================================================

# bats test_tags=neon-baseline
@test "warns when analyzed file matches NEON baseline entry" {
    create_neon_baseline "src/Foo.php"
    run_baseline_hook "$(make_post_input '["src/Foo.php"]')"
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("src/Foo.php")'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("phpstan-baseline.neon")'
}

# ============================================================================
# Baseline priority (neon before php)
# ============================================================================

# bats test_tags=priority
@test "prefers neon baseline over php when both exist" {
    create_neon_baseline "src/Foo.php"
    create_php_baseline "src/Foo.php"
    run_baseline_hook "$(make_post_input '["src/Foo.php"]')"
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("phpstan-baseline.neon")'
}

# ============================================================================
# Path normalization
# ============================================================================

# bats test_tags=paths
@test "strips leading ./ from paths before matching" {
    create_php_baseline "src/Foo.php"
    run_baseline_hook "$(make_post_input '["./src/Foo.php"]')"
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("src/Foo.php")'
}

# ============================================================================
# JSON output structure
# ============================================================================

# bats test_tags=output
@test "outputs valid JSON with correct structure" {
    create_php_baseline "src/Foo.php"
    run_baseline_hook "$(make_post_input '["src/Foo.php"]')"
    assert_success
    echo "$output" | jq -e . >/dev/null
    echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | type == "string"'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length > 0'
}

# ============================================================================
# CLAUDE_PROJECT_DIR fallback to cwd
# ============================================================================

# bats test_tags=cwd
@test "falls back to cwd from input when CLAUDE_PROJECT_DIR unset" {
    create_php_baseline "src/Foo.php"
    unset CLAUDE_PROJECT_DIR
    local input
    input=$(printf '{"tool_input": {"paths": ["src/Foo.php"]}, "cwd": "%s"}' "$BATS_TEST_TMPDIR")
    run bash -c 'printf "%s" "$1" | bash "$2"' _ "$input" "$BASELINE_SCRIPT"
    assert_success
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("src/Foo.php")'
}
