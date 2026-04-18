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

@test "install_dependencies: composer only runs composer install when lockfile exists" {
    setup_deps_env
    touch "${BATS_TEST_TMPDIR}/composer.lock"
    run tool_install_dependencies '{"composer": true, "administration": false, "storefront": false}'
    assert_success
    assert_output --partial "composer install"
}

@test "install_dependencies: composer only runs composer update when no lockfile" {
    setup_deps_env
    run tool_install_dependencies '{"composer": true, "administration": false, "storefront": false}'
    assert_success
    assert_output --partial "composer update"
}

@test "install_dependencies: admin+storefront uses composer init:js" {
    setup_deps_env
    run tool_install_dependencies '{"composer": false, "administration": true, "storefront": true}'
    assert_success
    assert_output --partial "composer init:js"
}

@test "install_dependencies: admin only uses composer npm:admin" {
    setup_deps_env
    run tool_install_dependencies '{"composer": false, "administration": true, "storefront": false}'
    assert_success
    assert_output --partial "composer npm:admin"
}

@test "install_dependencies: storefront only uses composer npm:storefront" {
    setup_deps_env
    run tool_install_dependencies '{"composer": false, "administration": false, "storefront": true}'
    assert_success
    assert_output --partial "composer npm:storefront"
}

@test "install_dependencies: all false produces no output" {
    setup_deps_env
    run tool_install_dependencies '{"composer": false, "administration": false, "storefront": false}'
    assert_success
    assert_output ""
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
    assert_output --partial "plugin_name"
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
    assert_output --partial "plugin_name"
}
