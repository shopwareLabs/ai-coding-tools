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
bats_test_function --description "blocks composer rector-fix → suggests rector_fix only" \
    -- php_hook_routes "composer rector-fix -- src/" "rector_fix" "rector_check"
bats_test_function --description "blocks php bin/console → suggests console_run/console_list" \
    -- php_hook_blocks "php bin/console cache:clear" "\`console_run\` or \`console_list\`"

# An environment assignment ahead of the command, and Composer's `run` /
# `run-script` subcommand ahead of a script name, still run the tool.
# bats test_tags=blocking
bats_test_function --description "blocks vendor/bin/phpunit behind an env assignment → suggests phpunit_run" \
    -- php_hook_blocks "APP_ENV=test vendor/bin/phpunit tests/" "phpunit_run"
bats_test_function --description "blocks bin/console behind an env assignment → suggests console_run/console_list" \
    -- php_hook_blocks "APP_ENV=test bin/console cache:clear" "\`console_run\` or \`console_list\`"
bats_test_function --description "blocks composer run phpstan → suggests phpstan_analyze" \
    -- php_hook_blocks "composer run phpstan" "phpstan_analyze"
bats_test_function --description "blocks composer run-script ecs-fix → suggests ecs_check/ecs_fix" \
    -- php_hook_blocks "composer run-script ecs-fix" "\`ecs_check\` or \`ecs_fix\`"
bats_test_function --description "blocks composer run rector → suggests rector_fix/rector_check" \
    -- php_hook_blocks "composer run rector" "\`rector_fix\` or \`rector_check\`"

# A `;` or `|` glued to the tool or script name still runs it.
# bats test_tags=blocking
bats_test_function --description "blocks vendor/bin/phpunit glued to ; → suggests phpunit_run" \
    -- php_hook_blocks "vendor/bin/phpunit;echo" "phpunit_run"
bats_test_function --description "blocks composer run rector glued to | → suggests rector_fix/rector_check" \
    -- php_hook_blocks "composer run rector|tee out.txt" "\`rector_fix\` or \`rector_check\`"

# Shopware core's current Composer scripts: `cs` / `cs-fix` replace the
# deprecated `ecs` alias, and `rector-fix` applies Rector. Each routes to the one
# tool that does the same thing.
# bats test_tags=blocking
php_hook_routes() {
    php_hook_blocks "$1" "\`$2\` on the"
    refute_output --partial "\`$3\`"
}
bats_test_function --description "blocks composer cs → suggests ecs_check only" \
    -- php_hook_routes "composer cs" "ecs_check" "ecs_fix"
bats_test_function --description "blocks composer run cs-fix glued to ; → suggests ecs_fix only" \
    -- php_hook_routes "composer run cs-fix;true" "ecs_fix" "ecs_check"
bats_test_function --description "blocks composer rector-fix behind an env assignment → suggests rector_fix only" \
    -- php_hook_routes "XDEBUG_MODE=off composer rector-fix" "rector_fix" "rector_check"

# A longer script name and text inside a quoted commit message are not a run.
# bats test_tags=allow
php_hook_allows() {
    run_hook "check-php-tools.sh" "$1"
    assert_success
    assert_output ""
}
bats_test_function --description "allows composer phpstan-baseline, a longer script name" \
    -- php_hook_allows "composer phpstan-baseline"
bats_test_function --description "allows composer run phpstan-baseline, a longer script name" \
    -- php_hook_allows "composer run phpstan-baseline"
bats_test_function --description "allows composer csv-import, a longer script name" \
    -- php_hook_allows "composer csv-import"
bats_test_function --description "allows composer cs-fixer-something, a longer script name" \
    -- php_hook_allows "composer cs-fixer-something"
bats_test_function --description "allows composer rector-fixture, a longer script name" \
    -- php_hook_allows "composer rector-fixture"
bats_test_function --description "allows composer run phpstan named inside a quoted commit message" \
    -- php_hook_allows 'git commit -m "document composer run phpstan"'
bats_test_function --description "allows an env-prefixed phpunit run named inside a quoted commit message" \
    -- php_hook_allows 'git commit -m "use APP_ENV=test vendor/bin/phpunit"'

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

# The servers merge every config file they find, later locations winning, so
# a `.claude/` file without the key leaves the root file's opt-out in force.
# bats test_tags=config
@test "allows all when the root config opts out and a .claude config omits the key" {
    setup_config "php-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    mkdir -p "${BATS_TEST_TMPDIR}/.claude"
    echo '{"environment": "native"}' > "${BATS_TEST_TMPDIR}/.claude/.mcp-php-tooling.json"
    run_hook "check-php-tools.sh" "vendor/bin/phpstan analyze"
    assert_success
}

# bats test_tags=config
@test "allows all when the MCP_PHP_TOOLING_CONFIG file opts out over an enforcing project config" {
    local override="${BATS_TEST_TMPDIR}/override.json"
    echo '{"environment": "native", "enforce_mcp_tools": false}' > "$override"
    MCP_PHP_TOOLING_CONFIG="$override" run_hook "check-php-tools.sh" "vendor/bin/phpstan analyze"
    assert_success
}

# A heredoc body is data for the command that opens it, not a command line.
# bats test_tags=allow
@test "allows a python heredoc whose body holds a phpstan line" {
    run_hook "check-php-tools.sh" $'python3 - <<\'PY\'\nimport subprocess\ncmd = """\nvendor/bin/phpstan analyse --error-format=json src\n"""\nprint(cmd)\nPY'
    assert_success
}

# bats test_tags=allow
@test "allows writing a script through a heredoc whose body runs phpunit" {
    run_hook "check-php-tools.sh" $'cat > tclass.sh <<EOF\n#!/bin/bash\nvendor/bin/phpunit --filter ProductTest\nEOF'
    assert_success
}

# bats test_tags=blocking
@test "blocks phpunit run after a heredoc's terminator line" {
    run_hook "check-php-tools.sh" $'cat > notes.txt <<EOF\nsome notes\nEOF\nvendor/bin/phpunit tests/'
    assert_failure 2
    assert_output --partial "phpunit_run"
}

# `<<-` lets the terminator line carry leading tabs.
# bats test_tags=blocking
@test "blocks phpunit run after a tab-indented <<- terminator line" {
    run_hook "check-php-tools.sh" $'cat > notes.txt <<-EOF\n\tsome notes\n\tEOF\nvendor/bin/phpunit tests/'
    assert_failure 2
    assert_output --partial "phpunit_run"
}

# A `<<<` here-string has no body, so the next line is a command.
# bats test_tags=blocking
@test "blocks phpunit run on the line after a here-string" {
    run_hook "check-php-tools.sh" $'grep -c x <<<"xyz"\nvendor/bin/phpunit tests/'
    assert_failure 2
    assert_output --partial "phpunit_run"
}
