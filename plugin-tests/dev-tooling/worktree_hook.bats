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

_enter_input() {
    local worktree_path="$1" cwd_path="$2"
    jq -cn --arg wp "${worktree_path}" --arg cwd "${cwd_path}" \
        '{tool_name: "EnterWorktree", tool_response: {worktreePath: $wp}, cwd: $cwd}'
}

@test "EnterWorktree with a worktree path names it and every server" {
    _run_worktree_hook "$(_enter_input "/repo/.claude/worktrees/feature" "/repo")"
    assert_success
    assert_output --partial "Worktree entered: /repo/.claude/worktrees/feature"
    assert_output --partial 'set_project_root with project_root \"/repo/.claude/worktrees/feature\"'
    assert_output --partial "php-tooling, js-admin-tooling and js-storefront-tooling"
}

@test "EnterWorktree falls back to cwd when tool_response.worktreePath is absent" {
    local payload
    payload=$(jq -cn --arg cwd "/repo/.claude/worktrees/feature" \
        '{tool_name: "EnterWorktree", tool_response: {}, cwd: $cwd}')
    _run_worktree_hook "${payload}"
    assert_success
    assert_output --partial "Worktree entered: /repo/.claude/worktrees/feature"
}

@test "EnterWorktree with neither worktreePath nor cwd emits the diagnostic" {
    local payload
    payload=$(jq -cn '{tool_name: "EnterWorktree", tool_response: {}, cwd: ""}')
    _run_worktree_hook "${payload}"
    assert_success
    assert_output --partial 'neither \"tool_response.worktreePath\" nor \"cwd\" held one'
    assert_output --partial "call set_project_root on all three with the worktree path"
}

@test "EnterWorktree with tool_response as a non-object string falls back to cwd" {
    local payload
    payload=$(jq -cn --arg cwd "/repo/.claude/worktrees/feature" \
        '{tool_name: "EnterWorktree", tool_response: "not an object", cwd: $cwd}')
    _run_worktree_hook "${payload}"
    assert_success
    assert_output --partial "Worktree entered: /repo/.claude/worktrees/feature"
}

@test "ExitWorktree names every server and the no-argument call" {
    local payload
    payload=$(jq -cn '{tool_name: "ExitWorktree", tool_response: {}, cwd: "/repo"}')
    _run_worktree_hook "${payload}"
    assert_success
    assert_output --partial "Call set_project_root with no project_root argument"
    assert_output --partial "php-tooling, js-admin-tooling and js-storefront-tooling"
}

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
