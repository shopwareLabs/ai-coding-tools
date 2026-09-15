#!/usr/bin/env bats
# bats file_tags=dev-tooling,worktree,hook
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

SCRIPTS_DIR="${REPO_ROOT}/plugins/dev-tooling/hooks/scripts"
HOOK_SCRIPT="${SCRIPTS_DIR}/worktree-directives.sh"

# Runs the hook with a raw JSON payload on stdin.
# Args: $1 = the JSON payload
_run_worktree_hook() {
    local payload="$1"
    run bash -c 'printf "%s" "$1" | bash "$2"' _ "${payload}" "${HOOK_SCRIPT}"
}

# Runs the hook and replaces $output with the decoded additionalContext string.
# The hook emits JSON, so a substring assertion against its raw stdout matches
# escape artifacts — the message's own quotes arrive as \" — and passes just as
# well when the envelope around the message is wrong. Every message assertion
# below runs against the decoded string instead.
# Args: $1 = the JSON payload
_run_hook_and_decode_context() {
    local payload="$1"
    run bash -c 'printf "%s" "$1" | bash "$2" | jq -r ".hookSpecificOutput.additionalContext"' \
        _ "${payload}" "${HOOK_SCRIPT}"
}

_enter_input() {
    local worktree_path="$1" cwd_path="$2"
    jq -cn --arg wp "${worktree_path}" --arg cwd "${cwd_path}" \
        '{tool_name: "EnterWorktree", tool_response: {worktreePath: $wp}, cwd: $cwd}'
}

# --- The JSON envelope ---

# Claude Code reads the directive out of this exact structure. A hook that keeps
# emitting the right sentence in the wrong envelope reaches no session at all.
# One test covers both branches: they share the single here-document that writes
# the envelope, so the Exit branch would add a second name for one shape. The
# jq filter runs under `run` and prints the paths it read, because a bare
# `jq -e` inside a test fails with an exit status and no diagnostic at all.
@test "the hook emits a PostToolUse hookSpecificOutput envelope holding the directive as a string" {
    run bash -c 'printf "%s" "$1" | bash "$2" | jq -r "[
            (.hookSpecificOutput.hookEventName // \"<absent>\"),
            (.hookSpecificOutput.additionalContext | type),
            (.hookSpecificOutput.additionalContext | startswith(\"Worktree entered: \") | tostring)
        ] | join(\"|\")"' \
        _ "$(_enter_input "/repo/.claude/worktrees/feature" "/repo/.claude/worktrees/feature")" \
        "${HOOK_SCRIPT}"
    assert_success
    assert_output "PostToolUse|string|true"
}

# --- The directive text ---

# Claude Code's hooks reference states that cwd "is the worktree root after
# Claude enters a worktree", so a real EnterWorktree payload carries the same
# directory in both fields. The precedence test below is the one that makes them
# disagree, and it does that to show which field is read rather than to model a
# payload that occurs.
@test "EnterWorktree with a worktree path names it and every server" {
    _run_hook_and_decode_context "$(_enter_input "/repo/.claude/worktrees/feature" "/repo/.claude/worktrees/feature")"
    assert_success
    assert_output --partial "Worktree entered: /repo/.claude/worktrees/feature"
    assert_output --partial 'set_project_root with project_root "/repo/.claude/worktrees/feature"'
    assert_output --partial "php-tooling"
    assert_output --partial "js-admin-tooling"
    assert_output --partial "js-storefront-tooling"
}

@test "EnterWorktree reads tool_response.worktreePath in preference to cwd" {
    _run_hook_and_decode_context "$(_enter_input "/repo/.claude/worktrees/feature" "/repo/somewhere-else")"
    assert_success
    assert_output --partial "Worktree entered: /repo/.claude/worktrees/feature"
    refute_output --partial "/repo/somewhere-else"
}

@test "EnterWorktree falls back to cwd when tool_response.worktreePath is absent" {
    local payload
    payload=$(jq -cn --arg cwd "/repo/.claude/worktrees/feature" \
        '{tool_name: "EnterWorktree", tool_response: {}, cwd: $cwd}')
    _run_hook_and_decode_context "${payload}"
    assert_success
    assert_output --partial "Worktree entered: /repo/.claude/worktrees/feature"
}

@test "EnterWorktree with neither worktreePath nor cwd emits the diagnostic" {
    local payload
    payload=$(jq -cn '{tool_name: "EnterWorktree", tool_response: {}, cwd: ""}')
    _run_hook_and_decode_context "${payload}"
    assert_success
    assert_output --partial 'neither "tool_response.worktreePath" nor "cwd" held one'
    assert_output --partial "call set_project_root on all three with the worktree path"
}

@test "EnterWorktree with tool_response as a non-object string falls back to cwd" {
    local payload
    payload=$(jq -cn --arg cwd "/repo/.claude/worktrees/feature" \
        '{tool_name: "EnterWorktree", tool_response: "not an object", cwd: $cwd}')
    _run_hook_and_decode_context "${payload}"
    assert_success
    assert_output --partial "Worktree entered: /repo/.claude/worktrees/feature"
}

@test "ExitWorktree names every server and the no-argument call" {
    local payload
    payload=$(jq -cn '{tool_name: "ExitWorktree", tool_response: {}, cwd: "/repo"}')
    _run_hook_and_decode_context "${payload}"
    assert_success
    assert_output --partial "Call set_project_root with no project_root argument"
    assert_output --partial "php-tooling"
    assert_output --partial "js-admin-tooling"
    assert_output --partial "js-storefront-tooling"
}

# --- Input the hook cannot use leaves the session untouched ---

@test "a tool name outside EnterWorktree/ExitWorktree produces no output" {
    local payload
    payload=$(jq -cn '{tool_name: "SomeOtherTool", tool_response: {}, cwd: "/repo"}')
    _run_worktree_hook "${payload}"
    assert_success
    assert_output ""
}

@test "malformed JSON input exits 0 with no output" {
    run bash -c 'printf "%s" "$1" | bash "$2"' _ '{not valid json' "${HOOK_SCRIPT}"
    assert_success
    assert_output ""
}

@test "empty input exits 0 with no output" {
    run bash -c 'printf "" | bash "$1"' _ "${HOOK_SCRIPT}"
    assert_success
    assert_output ""
}
