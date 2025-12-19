#!/usr/bin/env bats
# bats file_tags=dev-tooling,js,admin

load 'test_helper/common_setup'

CONFIG_PREFIX="js-tooling"

# bats test_tags=context,blocking
@test "blocks generic commands (defaults to Admin context)" {
    run_hook "check-js-admin-tools.sh" "npm run lint"
    assert_failure 2
    assert_output --partial "eslint_check"
}

# bats test_tags=context,allow
@test "allows Storefront-specific commands" {
    run_hook "check-js-admin-tools.sh" "cd src/Storefront && npm run lint:js"
    assert_success
}

# bats test_tags=blocking
@test "blocks npm run lint:scss → suggests stylelint_check" {
    run_hook "check-js-admin-tools.sh" "npm run lint:scss"
    assert_failure 2
    assert_output --partial "stylelint_check"
}

# bats test_tags=blocking
@test "blocks npm run unit → suggests jest_run" {
    run_hook "check-js-admin-tools.sh" "npm run unit"
    assert_failure 2
    assert_output --partial "jest_run"
}

# bats test_tags=blocking
@test "blocks npm run build → suggests vite_build" {
    run_hook "check-js-admin-tools.sh" "npm run build"
    assert_failure 2
    assert_output --partial "vite_build"
}

# bats test_tags=allow
@test "allows unrelated commands" {
    run_hook "check-js-admin-tools.sh" "npm install"
    assert_success
}

# bats test_tags=config
@test "allows all when enforce_mcp_tools is false" {
    setup_config "js-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    run_hook "check-js-admin-tools.sh" "npm run lint"
    assert_success
}
