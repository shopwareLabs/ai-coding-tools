#!/usr/bin/env bats
# bats file_tags=shopware-env,lifecycle
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

# ============================================================================
# install_dependencies
# ============================================================================

setup_deps_env() {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/dependencies.sh"
}

# Run tool_install_dependencies with JSON args and assert the emitted command
# contains the given substring (or is empty when expected == "").
# Args: $1=description (unused at runtime, documentation only), $2=json args,
#       $3=expected output substring
assert_install_deps_emits() {
    setup_deps_env
    run tool_install_dependencies "$2"
    assert_success
    if [[ -z "$3" ]]; then
        assert_output ""
    else
        assert_output --partial "$3"
    fi
}

bats_test_function --description "install_dependencies: composer-only runs 'composer install' by default" \
    -- assert_install_deps_emits \
        "composer-install default" \
        '{"composer": true, "administration": false, "storefront": false}' \
        "composer install"

bats_test_function --description "install_dependencies: composer-only with update=true runs 'composer update'" \
    -- assert_install_deps_emits \
        "composer-update flag" \
        '{"composer": true, "administration": false, "storefront": false, "update": true}' \
        "composer update"

bats_test_function --description "install_dependencies: admin+storefront uses 'composer init:js' by default" \
    -- assert_install_deps_emits \
        "admin+storefront default" \
        '{"composer": false, "administration": true, "storefront": true}' \
        "composer init:js"

bats_test_function --description "install_dependencies: admin-only uses 'npm:admin -- clean-install' by default" \
    -- assert_install_deps_emits \
        "admin-only default" \
        '{"composer": false, "administration": true, "storefront": false}' \
        "composer npm:admin -- clean-install"

bats_test_function --description "install_dependencies: admin-only with update=true uses 'npm:admin -- install'" \
    -- assert_install_deps_emits \
        "admin-only update" \
        '{"composer": false, "administration": true, "storefront": false, "update": true}' \
        "composer npm:admin -- install"

bats_test_function --description "install_dependencies: storefront-only uses 'npm:storefront -- clean-install' by default" \
    -- assert_install_deps_emits \
        "storefront-only default" \
        '{"composer": false, "administration": false, "storefront": true}' \
        "composer npm:storefront -- clean-install"

bats_test_function --description "install_dependencies: storefront-only with update=true uses 'npm:storefront -- install'" \
    -- assert_install_deps_emits \
        "storefront-only update" \
        '{"composer": false, "administration": false, "storefront": true, "update": true}' \
        "composer npm:storefront -- install"

bats_test_function --description "install_dependencies: all flags false produces no output" \
    -- assert_install_deps_emits \
        "all-false" \
        '{"composer": false, "administration": false, "storefront": false}' \
        ""

@test "install_dependencies: admin+storefront with update=true skips init:js and runs individual installs" {
    setup_deps_env
    run tool_install_dependencies '{"composer": false, "administration": true, "storefront": true, "update": true}'
    assert_success
    refute_output --partial "composer init:js"
    assert_output --partial "composer npm:admin -- install"
    assert_output --partial "composer npm:storefront -- install"
    assert_output --partial "bin/install-extension-npm"
}

# ============================================================================
# database_install / database_reset
# ============================================================================

setup_db_env() {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/database.sh"
}

@test "database_install: runs system:install with correct flags" {
    setup_db_env
    run tool_database_install '{}'
    assert_success
    assert_output --partial "bin/console system:install --drop-database --basic-setup --force --no-assign-theme"
}

@test "database_reset: runs same command as database_install" {
    setup_db_env
    run tool_database_reset '{}'
    assert_success
    assert_output --partial "bin/console system:install --drop-database --basic-setup --force --no-assign-theme"
}

# ============================================================================
# testdb_prepare
# ============================================================================

setup_testdb_env() {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/testdb.sh"
}

@test "testdb_prepare: runs phpunit with FORCE_INSTALL and correct flags" {
    setup_testdb_env
    run tool_testdb_prepare '{}'
    assert_success
    assert_output --partial "vendor/bin/phpunit --group=none --testsuite migration,unit,integration,devops"
}

# ============================================================================
# frontend_build_admin / frontend_build_storefront
# ============================================================================

setup_frontend_env() {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/frontend.sh"
}

@test "frontend_build_admin: runs full admin build chain" {
    setup_frontend_env
    run tool_frontend_build_admin '{}'
    assert_success
    assert_output --partial "bin/console bundle:dump"
    assert_output --partial "bin/console feature:dump"
    assert_output --partial "bin/console framework:schema:dump"
    assert_output --partial "composer build:js:admin"
    assert_output --partial "bin/console assets:install"
}

@test "frontend_build_storefront: runs full storefront build chain" {
    setup_frontend_env
    run tool_frontend_build_storefront '{}'
    assert_success
    assert_output --partial "bin/console bundle:dump"
    assert_output --partial "bin/console feature:dump"
    assert_output --partial "composer build:js:storefront"
    assert_output --partial "bin/console theme:compile"
    assert_output --partial "bin/console assets:install"
}

# ============================================================================
# plugin_create / plugin_setup
# ============================================================================

setup_plugin_env() {
    setup_lifecycle_mcp_env "${PLUGIN_DIR}/mcp-server-lifecycle/lib/plugin.sh"
}

@test "plugin_create: runs create + refresh + install --activate" {
    setup_plugin_env
    run tool_plugin_create '{"plugin_name": "SwagExample", "plugin_namespace": "SwagExample"}'
    assert_success
    assert_output --partial "bin/console plugin:create 'SwagExample' 'SwagExample'"
    assert_output --partial "bin/console plugin:refresh"
    assert_output --partial "bin/console plugin:install SwagExample --activate"
}

@test "plugin_create: fails without plugin_name" {
    setup_plugin_env
    run tool_plugin_create '{"plugin_namespace": "SwagExample"}'
    assert_failure
    assert_output "Error: 'plugin_name' parameter is required"
}

@test "plugin_setup: runs refresh + install --activate" {
    setup_plugin_env
    run tool_plugin_setup '{"plugin_name": "SwagCommercial"}'
    assert_success
    assert_output --partial "bin/console plugin:refresh"
    assert_output --partial "bin/console plugin:install SwagCommercial --activate"
}

@test "plugin_setup: fails without plugin_name" {
    setup_plugin_env
    run tool_plugin_setup '{}'
    assert_failure
    assert_output "Error: 'plugin_name' parameter is required"
}
