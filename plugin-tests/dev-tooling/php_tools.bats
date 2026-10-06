#!/usr/bin/env bats
# bats file_tags=dev-tooling,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

CONFIG_PREFIX="php-tooling"

# The block message names the tool and its server; neither host's mcp__ form.
php_hook_blocks() {
    assert_hook_blocks "check-php-tools.sh" "$1" "$2"
    assert_output --partial "on the \`php-tooling\` MCP server"
    refute_output --partial "mcp__"
}

# bats test_tags=blocking
bats_test_function --description "blocks vendor/bin/phpstan → suggests phpstan_analyze" \
    -- php_hook_blocks "vendor/bin/phpstan analyze src/" "phpstan_analyze"
bats_test_function --description "blocks vendor/bin/ecs → suggests ecs_check/ecs_fix" \
    -- php_hook_blocks "vendor/bin/ecs check src/" "\`ecs_check\` or \`ecs_fix\`"
bats_test_function --description "blocks vendor/bin/phpunit → suggests phpunit_run" \
    -- php_hook_blocks "vendor/bin/phpunit tests/" "phpunit_run"
bats_test_function --description "blocks bin/console → suggests console_run/console_list" \
    -- php_hook_blocks "bin/console cache:clear" "\`console_run\` or \`console_list\`"
bats_test_function --description "blocks && compound command → suggests phpstan_analyze" \
    -- php_hook_blocks "git pull && vendor/bin/phpstan analyze" "phpstan_analyze"
bats_test_function --description "blocks composer phpstan → suggests phpstan_analyze" \
    -- php_hook_blocks "composer phpstan -- src/" "phpstan_analyze"
bats_test_function --description "blocks composer ecs → suggests ecs_check/ecs_fix" \
    -- php_hook_blocks "composer ecs -- src/" "\`ecs_check\` or \`ecs_fix\`"
bats_test_function --description "blocks vendor/bin/rector → suggests rector_fix/rector_check" \
    -- php_hook_blocks "vendor/bin/rector process src/" "\`rector_fix\` or \`rector_check\`"
bats_test_function --description "blocks composer rector → suggests rector_fix/rector_check" \
    -- php_hook_blocks "composer rector -- --dry-run" "\`rector_fix\` or \`rector_check\`"
bats_test_function --description "blocks php bin/console → suggests console_run/console_list" \
    -- php_hook_blocks "php bin/console cache:clear" "\`console_run\` or \`console_list\`"

# bats test_tags=cwd
@test "reads the config from the hook input cwd when CLAUDE_PROJECT_DIR is unset" {
    unset CLAUDE_PROJECT_DIR
    local project
    project=$(make_cwd_project "php-tooling" "ddev")
    run_hook_with_cwd "check-php-tools.sh" "vendor/bin/phpstan analyze" "$project"
    assert_failure 2
    assert_output --partial "'ddev' environment"
}

# bats test_tags=cwd
@test "an empty CLAUDE_PROJECT_DIR falls through to the hook input cwd" {
    export CLAUDE_PROJECT_DIR=""
    local project
    project=$(make_cwd_project "php-tooling" "ddev")
    run_hook_with_cwd "check-php-tools.sh" "vendor/bin/phpstan analyze" "$project"
    assert_failure 2
    assert_output --partial "'ddev' environment"
}

# bats test_tags=cwd
@test "CLAUDE_PROJECT_DIR wins over the hook input cwd when both are set" {
    local project
    project=$(make_cwd_project "php-tooling" "ddev")
    run_hook_with_cwd "check-php-tools.sh" "vendor/bin/phpstan analyze" "$project"
    assert_failure 2
    assert_output --partial "'native' environment"
    refute_output --partial "'ddev' environment"
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
