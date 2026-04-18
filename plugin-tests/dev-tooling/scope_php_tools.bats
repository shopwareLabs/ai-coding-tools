#!/usr/bin/env bats
# bats file_tags=dev-tooling,scope,php
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

setup() {
    LINT_ENV="native"
    LINT_WORKDIR="${BATS_TEST_TMPDIR}"
    LINT_CONFIG_FILE="${BATS_TEST_TMPDIR}/.mcp-php-tooling.json"
    cat > "${LINT_CONFIG_FILE}" <<'JSON'
{
  "environment":"native",
  "scopes":{
    "plugin-x":{
      "cwd":"custom/plugins/X",
      "phpstan":{"config":"phpstan.neon","bootstrap":["php tests/phpstan/bootstrap.php"]},
      "rector":{"config":"rector.php","bootstrap":["php tests/phpstan/bootstrap.php"]},
      "phpunit":{"config":"phpunit.xml.dist"},
      "style":{"tool":"php-cs-fixer","config":".php-cs-fixer.dist.php"}
    }
  }
}
JSON
    log() { :; }
    CALLS_FILE="${BATS_TEST_TMPDIR}/calls.log"
    source "${PLUGIN_DIR}/shared/environment.sh"
    source "${PLUGIN_DIR}/shared/scope.sh"
    # Capture each exec_command invocation for inspection.
    # Defined after environment.sh to override its real implementation.
    exec_command() { echo "[scope=${SCOPE_CWD:-<unscoped>}] $1" >> "${CALLS_FILE}"; echo "$1"; }
    source "${PLUGIN_DIR}/mcp-server-php/lib/phpstan.sh"
    source "${PLUGIN_DIR}/mcp-server-php/lib/rector.sh"
    source "${PLUGIN_DIR}/mcp-server-php/lib/ecs.sh"
    source "${PLUGIN_DIR}/mcp-server-php/lib/phpunit.sh"
    source "${PLUGIN_DIR}/mcp-server-php/lib/console.sh"
}

teardown() {
    unset LINT_ENV LINT_WORKDIR LINT_CONFIG_FILE SCOPE_NAME SCOPE_CWD CALLS_FILE
}

@test "phpstan scoped: runs bootstrap before phpstan" {
    run tool_phpstan_analyze '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 "[scope=custom/plugins/X] php tests/phpstan/bootstrap.php"
    assert_line --index 1 --partial "[scope=custom/plugins/X] composer phpstan"
}

@test "phpstan scoped: applies scope config when no explicit config" {
    run tool_phpstan_analyze '{"scope":"plugin-x"}'
    assert_success
    assert_output --partial "--configuration=phpstan.neon"
}

@test "phpstan scoped: explicit config arg overrides scope config" {
    run tool_phpstan_analyze '{"scope":"plugin-x","config":"phpstan.custom.neon"}'
    assert_success
    assert_output --partial "--configuration=phpstan.custom.neon"
}

@test "phpstan scoped: hard error on undeclared scope" {
    run tool_phpstan_analyze '{"scope":"ghost"}'
    assert_failure
    assert_output --partial 'Scope "ghost" is not declared'
}

@test "phpstan unscoped: backward compat, no bootstrap runs" {
    run tool_phpstan_analyze '{}'
    assert_success
    run cat "${CALLS_FILE}"
    refute_line --partial "php tests/phpstan/bootstrap.php"
    assert_line --index 0 --partial "[scope=<unscoped>] composer phpstan"
}

@test "phpstan bootstrap failure: fails whole call" {
    exec_command() {
        if [[ "$1" == "php tests/phpstan/bootstrap.php" ]]; then
            echo "bootstrap fatal error" >&2
            return 3
        fi
        echo "$1"
    }
    run tool_phpstan_analyze '{"scope":"plugin-x"}'
    assert_failure
    assert_output --partial "bootstrap failed"
}

@test "rector scoped: runs bootstrap before rector" {
    run tool_rector_check '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --index 0 "[scope=custom/plugins/X] php tests/phpstan/bootstrap.php"
}

@test "rector scoped: applies scope config" {
    run tool_rector_check '{"scope":"plugin-x"}'
    assert_success
    assert_output --partial "--config=rector.php"
}

@test "rector unscoped: no bootstrap runs" {
    run tool_rector_check '{}'
    assert_success
    run cat "${CALLS_FILE}"
    refute_line --partial "php tests/phpstan/bootstrap.php"
}

@test "ecs_check scoped: routes to php-cs-fixer with scope style config" {
    run tool_ecs_check '{"scope":"plugin-x"}'
    assert_success
    assert_output --partial "vendor/bin/php-cs-fixer"
    assert_output --partial "--config=.php-cs-fixer.dist.php"
    refute_output --partial "composer ecs"
}

@test "ecs_fix scoped: style.tool=php-cs-fixer runs fix subcommand" {
    run tool_ecs_fix '{"scope":"plugin-x"}'
    assert_success
    assert_output --partial "vendor/bin/php-cs-fixer fix"
    refute_output --partial "composer ecs-fix"
}

@test "ecs_check unscoped: composer ecs unchanged" {
    run tool_ecs_check '{}'
    assert_success
    assert_output --partial "composer ecs"
    refute_output --partial "php-cs-fixer"
}

@test "phpunit scoped: uses scope config" {
    run tool_phpunit_run '{"scope":"plugin-x"}'
    assert_success
    assert_output --partial "--configuration=phpunit.xml.dist"
}

@test "phpunit scoped: explicit arg overrides scope" {
    run tool_phpunit_run '{"scope":"plugin-x","config":"phpunit.custom.xml"}'
    assert_success
    assert_output --partial "--configuration=phpunit.custom.xml"
}

@test "phpunit scoped: runs under scope cwd" {
    run tool_phpunit_run '{"scope":"plugin-x"}'
    assert_success
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=custom/plugins/X] vendor/bin/phpunit"
}

@test "console scoped: runs under scope cwd" {
    run tool_console_run '{"scope":"plugin-x","command":"debug:container"}'
    assert_success
    assert_output --partial "debug:container"
    run cat "${CALLS_FILE}"
    assert_line --partial "[scope=custom/plugins/X]"
}
