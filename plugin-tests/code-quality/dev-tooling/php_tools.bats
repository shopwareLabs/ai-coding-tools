#!/usr/bin/env bats
# bats file_tags=dev-tooling,php

load 'test_helper/common_setup'

CONFIG_PREFIX="php-tooling"

# bats test_tags=blocking
@test "blocks vendor/bin/phpstan → suggests phpstan_analyze" {
    run_hook "check-php-tools.sh" "vendor/bin/phpstan analyze src/"
    assert_failure 2
    assert_output --partial "phpstan_analyze"
}

# bats test_tags=blocking
@test "blocks vendor/bin/ecs → suggests ecs_check/ecs_fix" {
    run_hook "check-php-tools.sh" "vendor/bin/ecs check src/"
    assert_failure 2
    assert_output --partial "ecs_check or ecs_fix"
}

# bats test_tags=blocking
@test "blocks vendor/bin/phpunit → suggests phpunit_run" {
    run_hook "check-php-tools.sh" "vendor/bin/phpunit tests/"
    assert_failure 2
    assert_output --partial "phpunit_run"
}

# bats test_tags=blocking
@test "blocks bin/console → suggests console_run/console_list" {
    run_hook "check-php-tools.sh" "bin/console cache:clear"
    assert_failure 2
    assert_output --partial "console_run or console_list"
}

# bats test_tags=blocking
@test "blocks command after &&" {
    run_hook "check-php-tools.sh" "git pull && vendor/bin/phpstan analyze"
    assert_failure 2
}

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
