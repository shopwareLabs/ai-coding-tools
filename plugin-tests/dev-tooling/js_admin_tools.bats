#!/usr/bin/env bats
# bats file_tags=dev-tooling,js,admin
bats_require_minimum_version 1.11.0

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

js_admin_hook_blocks() { assert_hook_blocks "check-js-admin-tools.sh" "$1" "$2"; }

# bats test_tags=blocking
bats_test_function --description "blocks npm run lint:scss → suggests stylelint_check" \
    -- js_admin_hook_blocks "npm run lint:scss" "stylelint_check"
bats_test_function --description "blocks npm run unit → suggests jest_run" \
    -- js_admin_hook_blocks "npm run unit" "jest_run"
bats_test_function --description "blocks npm run build → suggests vite_build" \
    -- js_admin_hook_blocks "npm run build" "vite_build"
bats_test_function --description "blocks npm run format → suggests prettier_check" \
    -- js_admin_hook_blocks "npm run format" "prettier_check"
bats_test_function --description "blocks npm run lint:types → suggests tsc_check" \
    -- js_admin_hook_blocks "npm run lint:types" "tsc_check"
bats_test_function --description "blocks npm run lint:all → suggests lint_all" \
    -- js_admin_hook_blocks "npm run lint:all" "lint_all"
bats_test_function --description "blocks npx eslint → suggests eslint_check" \
    -- js_admin_hook_blocks "npx eslint src/" "eslint_check"
bats_test_function --description "blocks npx jest → suggests jest_run" \
    -- js_admin_hook_blocks "npx jest --watch" "jest_run"

# The target-less base scripts the MCP tools route path-scoped runs at. None of
# them matched a pattern before: `:` is not in the `(\s|--|$)` tail the shorter
# names use, so `npm run lint` never covered `npm run lint:debugging`.
# bats test_tags=blocking,base-scripts
bats_test_function --description "blocks npm run lint:debugging → suggests eslint_check" \
    -- js_admin_hook_blocks "npm run lint:debugging" "eslint_check"
bats_test_function --description "blocks npm run stylelint:base → suggests stylelint_check" \
    -- js_admin_hook_blocks "npm run stylelint:base" "stylelint_check"
bats_test_function --description "blocks npm run prettier:base → suggests prettier_check" \
    -- js_admin_hook_blocks "npm run prettier:base" "prettier_check"
bats_test_function --description "blocks npm run jest:base → suggests jest_run" \
    -- js_admin_hook_blocks "npm run jest:base" "jest_run"

# bats test_tags=context,allow
@test "allows npm run stylelint:app, which only the Storefront package declares" {
    run_hook "check-js-admin-tools.sh" "npm run stylelint:app"
    assert_success
}

# bats test_tags=context,allow
@test "allows npm run eslint:app, which only the Storefront package declares" {
    run_hook "check-js-admin-tools.sh" "npm run eslint:app"
    assert_success
}

# bats test_tags=context,allow
@test "allows npm run jest:base when the command names the Storefront tree" {
    run_hook "check-js-admin-tools.sh" "cd src/Storefront/Resources/app/storefront && npm run jest:base"
    assert_success
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
