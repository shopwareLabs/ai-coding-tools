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
# `lint:js:fix` carries a colon where the context detector's trailing
# alternation expects whitespace or end-of-string, so a bare invocation used to
# miss the detector entirely and reach neither hook's block.
bats_test_function --description "blocks a bare npm run lint:js:fix → suggests eslint_fix" \
    -- js_storefront_hook_blocks "npm run lint:js:fix" "eslint_fix"
bats_test_function --description "blocks a bare npm run lint:js → suggests eslint_check" \
    -- js_storefront_hook_blocks "npm run lint:js" "eslint_check"
bats_test_function --description "blocks npm run development in Storefront context → suggests webpack_build" \
    -- js_storefront_hook_blocks "cd /app/storefront && npm run development" "webpack_build"
bats_test_function --description "blocks npx jest in Storefront context → suggests jest_run" \
    -- js_storefront_hook_blocks "cd src/Storefront && npx jest" "jest_run"
bats_test_function --description "blocks npm run unit:components → suggests vitest_run" \
    -- js_storefront_hook_blocks "npm run unit:components" "vitest_run"
bats_test_function --description "blocks npm run unit:components:coverage → suggests vitest_run" \
    -- js_storefront_hook_blocks "npm run unit:components:coverage" "vitest_run"
bats_test_function --description "blocks npx vitest in Storefront context → suggests vitest_run" \
    -- js_storefront_hook_blocks "cd src/Storefront && npx vitest" "vitest_run"
bats_test_function --description "blocks composer storefront:components:unit → suggests vitest_run" \
    -- js_storefront_hook_blocks "composer storefront:components:unit" "vitest_run"
bats_test_function --description "blocks composer ludtwig:storefront → suggests ludtwig_check" \
    -- js_storefront_hook_blocks "composer ludtwig:storefront" "ludtwig_check"
bats_test_function --description "blocks composer ludtwig:storefront:fix → suggests ludtwig_fix" \
    -- js_storefront_hook_blocks "composer ludtwig:storefront:fix" "ludtwig_fix"
bats_test_function --description "blocks a bare ludtwig invocation → suggests ludtwig_check" \
    -- js_storefront_hook_blocks "ludtwig ." "ludtwig_check"

# The target-less base scripts the MCP tools route path-scoped runs at.
# eslint:app, eslint:components and stylelint:app are Storefront-only names, so
# they are also Storefront context signals in their own right.
# bats test_tags=blocking,base-scripts
bats_test_function --description "blocks npm run eslint:app → suggests eslint_check" \
    -- js_storefront_hook_blocks "npm run eslint:app" "eslint_check"
bats_test_function --description "blocks npm run eslint:components → suggests eslint_check" \
    -- js_storefront_hook_blocks "npm run eslint:components" "eslint_check"
bats_test_function --description "blocks npm run stylelint:app → suggests stylelint_check" \
    -- js_storefront_hook_blocks "npm run stylelint:app" "stylelint_check"
bats_test_function --description "blocks npm run jest:base in Storefront context → suggests jest_run" \
    -- js_storefront_hook_blocks "cd src/Storefront && npm run jest:base" "jest_run"

# jest:base is declared by both packages. The Admin hook's unknown-context
# fallback owns the bare form, so this hook must decline it or the command
# would be blocked twice with two different tool names.
# bats test_tags=context,allow
@test "allows a bare npm run jest:base, which the Admin hook owns" {
    run_hook "check-js-storefront-tools.sh" "npm run jest:base"
    assert_success
}

# bats test_tags=blocking
@test "npm run lint:js:fix is routed to eslint_fix, not eslint_check" {
    run_hook "check-js-storefront-tools.sh" "npm run lint:js:fix"
    assert_failure 2
    refute_output --partial "eslint_check"
}

# bats test_tags=blocking
@test "npm run unit:components is routed to vitest_run, not jest_run" {
    run_hook "check-js-storefront-tools.sh" "npm run unit:components"
    assert_failure 2
    refute_output --partial "jest_run"
}

# bats test_tags=blocking
@test "composer ludtwig:storefront:fix is routed to ludtwig_fix, not ludtwig_check" {
    run_hook "check-js-storefront-tools.sh" "composer ludtwig:storefront:fix"
    assert_failure 2
    refute_output --partial "ludtwig_check"
}

# bats test_tags=blocking
@test "the jest block names the testPathPatterns parameter jest_run accepts" {
    run_hook "check-js-storefront-tools.sh" "cd src/Storefront && npm run unit"
    assert_failure 2
    assert_output --partial "testPathPatterns"
}

# bats test_tags=config
@test "allows all when enforce_mcp_tools is false" {
    setup_config "js-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    run_hook "check-js-storefront-tools.sh" "cd Storefront && npm run lint:js"
    assert_success
}
