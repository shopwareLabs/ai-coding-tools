#!/usr/bin/env bats
# bats file_tags=native-tools-enforcer,guardrails

load 'test_helper/common_setup'

SCRIPT="check-native-tools.sh"

# bats test_tags=blocking
@test "blocks cat → suggests Read tool" {
    run_hook "$SCRIPT" "cat README.md"
    assert_failure 2
    assert_output --partial "Read tool"
}

# bats test_tags=blocking
@test "blocks find → suggests Glob tool" {
    run_hook "$SCRIPT" "find . -name '*.js'"
    assert_failure 2
    assert_output --partial "Glob tool"
}

# bats test_tags=blocking
@test "blocks grep → suggests Grep tool" {
    run_hook "$SCRIPT" "grep pattern file.txt"
    assert_failure 2
    assert_output --partial "Grep tool"
}

# bats test_tags=blocking
@test "blocks piped grep → suggests Grep tool" {
    run_hook "$SCRIPT" "ls | grep foo"
    assert_failure 2
    assert_output --partial "Grep tool"
}

# bats test_tags=blocking
@test "blocks rg → suggests Grep tool" {
    run_hook "$SCRIPT" "rg pattern src/"
    assert_failure 2
    assert_output --partial "Grep tool"
}

# bats test_tags=blocking
@test "blocks echo redirect → suggests Write tool" {
    run_hook "$SCRIPT" "echo 'content' > file.txt"
    assert_failure 2
    assert_output --partial "Write tool"
}

# bats test_tags=blocking
@test "blocks heredoc → suggests Write tool" {
    run_hook "$SCRIPT" "cat <<EOF"
    assert_failure 2
    assert_output --partial "Write tool"
}

# bats test_tags=blocking
@test "blocks sed → suggests Edit tool" {
    run_hook "$SCRIPT" "sed 's/foo/bar/' file.txt"
    assert_failure 2
    assert_output --partial "Edit tool"
}

# bats test_tags=blocking
@test "blocks awk → suggests Edit tool" {
    run_hook "$SCRIPT" "awk '{print \$1}' file.txt"
    assert_failure 2
    assert_output --partial "Edit tool"
}

# bats test_tags=blocking
@test "blocks command after &&" {
    run_hook "$SCRIPT" "cd src && grep pattern *.js"
    assert_failure 2
}

# bats test_tags=allow
@test "allows safe commands" {
    run_hook "$SCRIPT" "git status"
    assert_success
}

# bats test_tags=input
@test "allows empty command" {
    run bash -c 'echo "{\"tool_input\": {\"command\": \"\"}}" | bash "$1"' _ "${SCRIPTS_DIR}/check-native-tools.sh"
    assert_success
}

# bats test_tags=input
@test "allows missing command field" {
    run bash -c 'echo "{\"tool_input\": {}}" | bash "$1"' _ "${SCRIPTS_DIR}/check-native-tools.sh"
    assert_success
}
