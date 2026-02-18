#!/usr/bin/env bats
# bats file_tags=dev-tooling,js,storefront
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

CONFIG_PREFIX="js-tooling"

# bats test_tags=context,allow
@test "allows generic commands (not Storefront context)" {
    run_hook "check-js-storefront-tools.sh" "npm run lint"
    assert_success
}

# bats test_tags=context,blocking
@test "blocks commands with Storefront path → suggests eslint_check" {
    run_hook "check-js-storefront-tools.sh" "cd src/Storefront && npm run lint:js"
    assert_failure 2
    assert_output --partial "eslint_check"
}

js_storefront_hook_blocks() { assert_hook_blocks "check-js-storefront-tools.sh" "$1" "$2"; }

# bats test_tags=blocking
bats_test_function --description "blocks npm run lint:scss → suggests stylelint_check" \
    -- js_storefront_hook_blocks "cd Storefront && npm run lint:scss" "stylelint_check"
bats_test_function --description "blocks npm run unit → suggests jest_run" \
    -- js_storefront_hook_blocks "cd Storefront && npm run unit" "jest_run"
bats_test_function --description "blocks npm run production → suggests webpack_build" \
    -- js_storefront_hook_blocks "cd /app/storefront && npm run production" "webpack_build"
bats_test_function --description "blocks npm run lint:js in Storefront context → suggests eslint_check" \
    -- js_storefront_hook_blocks "cd src/Storefront && npm run lint:js" "eslint_check"
bats_test_function --description "blocks npm run development in Storefront context → suggests webpack_build" \
    -- js_storefront_hook_blocks "cd /app/storefront && npm run development" "webpack_build"
bats_test_function --description "blocks npx jest in Storefront context → suggests jest_run" \
    -- js_storefront_hook_blocks "cd src/Storefront && npx jest" "jest_run"

# bats test_tags=config
@test "allows all when enforce_mcp_tools is false" {
    setup_config "js-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    run_hook "check-js-storefront-tools.sh" "cd Storefront && npm run lint:js"
    assert_success
}
