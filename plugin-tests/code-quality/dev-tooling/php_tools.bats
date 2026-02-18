#!/usr/bin/env bats
# bats file_tags=dev-tooling,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

CONFIG_PREFIX="php-tooling"

php_hook_blocks() { assert_hook_blocks "check-php-tools.sh" "$1" "$2"; }

# bats test_tags=blocking
bats_test_function --description "blocks vendor/bin/phpstan → suggests phpstan_analyze" \
    -- php_hook_blocks "vendor/bin/phpstan analyze src/" "phpstan_analyze"
bats_test_function --description "blocks vendor/bin/ecs → suggests ecs_check/ecs_fix" \
    -- php_hook_blocks "vendor/bin/ecs check src/" "ecs_check or ecs_fix"
bats_test_function --description "blocks vendor/bin/phpunit → suggests phpunit_run" \
    -- php_hook_blocks "vendor/bin/phpunit tests/" "phpunit_run"
bats_test_function --description "blocks bin/console → suggests console_run/console_list" \
    -- php_hook_blocks "bin/console cache:clear" "console_run or console_list"
bats_test_function --description "blocks && compound command → suggests phpstan_analyze" \
    -- php_hook_blocks "git pull && vendor/bin/phpstan analyze" "phpstan_analyze"
bats_test_function --description "blocks composer phpstan → suggests phpstan_analyze" \
    -- php_hook_blocks "composer phpstan -- src/" "phpstan_analyze"
bats_test_function --description "blocks composer ecs → suggests ecs_check/ecs_fix" \
    -- php_hook_blocks "composer ecs -- src/" "ecs_check or ecs_fix"
bats_test_function --description "blocks php bin/console → suggests console_run/console_list" \
    -- php_hook_blocks "php bin/console cache:clear" "console_run or console_list"

# bats test_tags=allow
@test "allows unrelated commands" {
    run_hook "check-php-tools.sh" "composer install"
    assert_success
}

# bats test_tags=config
@test "allows all when enforce_mcp_tools is false" {
    setup_config "php-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    run_hook "check-php-tools.sh" "vendor/bin/phpstan analyze"
    assert_success
}
