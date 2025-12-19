#!/usr/bin/env bats
# bats file_tags=dev-tooling,js,storefront

load 'test_helper/common_setup'

CONFIG_PREFIX="js-tooling"

# bats test_tags=context,allow
@test "allows generic commands (not Storefront context)" {
    run_hook "check-js-storefront-tools.sh" "npm run lint"
    assert_success
}

# bats test_tags=context,blocking
@test "blocks commands with Storefront path" {
    run_hook "check-js-storefront-tools.sh" "cd src/Storefront && npm run lint:js"
    assert_failure 2
    assert_output --partial "eslint_check"
}

# bats test_tags=blocking
@test "blocks npm run lint:scss → suggests stylelint_check" {
    run_hook "check-js-storefront-tools.sh" "cd Storefront && npm run lint:scss"
    assert_failure 2
    assert_output --partial "stylelint_check"
}

# bats test_tags=blocking
@test "blocks npm run unit → suggests jest_run" {
    run_hook "check-js-storefront-tools.sh" "cd Storefront && npm run unit"
    assert_failure 2
    assert_output --partial "jest_run"
}

# bats test_tags=blocking
@test "blocks npm run production → suggests webpack_build" {
    run_hook "check-js-storefront-tools.sh" "cd /app/storefront && npm run production"
    assert_failure 2
    assert_output --partial "webpack_build"
}

# bats test_tags=config
@test "allows all when enforce_mcp_tools is false" {
    setup_config "js-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    run_hook "check-js-storefront-tools.sh" "cd Storefront && npm run lint:js"
    assert_success
}
