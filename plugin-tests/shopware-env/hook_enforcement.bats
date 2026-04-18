#!/usr/bin/env bats
# bats file_tags=shopware-env,hooks
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

lifecycle_hook_blocks() { assert_hook_blocks "check-lifecycle-tools.sh" "$1" "$2"; }

# composer
bats_test_function --description "blocks composer install → suggests install_dependencies" \
    -- lifecycle_hook_blocks "composer install" "install_dependencies"
bats_test_function --description "blocks composer update → suggests install_dependencies" \
    -- lifecycle_hook_blocks "composer update" "install_dependencies"

# npm in shopware context
bats_test_function --description "blocks npm install → suggests install_dependencies" \
    -- lifecycle_hook_blocks "npm install" "install_dependencies"
bats_test_function --description "blocks npm ci → suggests install_dependencies" \
    -- lifecycle_hook_blocks "npm ci" "install_dependencies"

# database
bats_test_function --description "blocks bin/console system:install → suggests database_install" \
    -- lifecycle_hook_blocks "bin/console system:install --drop-database" "database_install"
bats_test_function --description "blocks bin/console system:setup → suggests database_install" \
    -- lifecycle_hook_blocks "bin/console system:setup" "database_install"

# plugin commands
bats_test_function --description "blocks bin/console plugin:create → suggests plugin_create" \
    -- lifecycle_hook_blocks "bin/console plugin:create MyPlugin" "plugin_create"
bats_test_function --description "blocks bin/console plugin:install → suggests plugin_setup" \
    -- lifecycle_hook_blocks "bin/console plugin:install SwagCommercial --activate" "plugin_setup"
bats_test_function --description "blocks bin/console plugin:refresh → suggests plugin_setup" \
    -- lifecycle_hook_blocks "bin/console plugin:refresh" "plugin_setup"
bats_test_function --description "blocks bin/console plugin:activate → suggests plugin_setup" \
    -- lifecycle_hook_blocks "bin/console plugin:activate SwagCommercial" "plugin_setup"

# frontend build chain commands
bats_test_function --description "blocks bin/console bundle:dump → suggests frontend_build_*" \
    -- lifecycle_hook_blocks "bin/console bundle:dump" "frontend_build_admin or frontend_build_storefront"
bats_test_function --description "blocks bin/console theme:compile → suggests frontend_build_storefront" \
    -- lifecycle_hook_blocks "bin/console theme:compile" "frontend_build_storefront"
bats_test_function --description "blocks bin/console assets:install → suggests frontend_build_*" \
    -- lifecycle_hook_blocks "bin/console assets:install" "frontend_build_admin or frontend_build_storefront"

@test "allows unrelated commands without block message" {
    run_hook "check-lifecycle-tools.sh" "git status"
    assert_success
    refute_output --partial "install_dependencies"
    refute_output --partial "database_install"
    refute_output --partial "plugin_"
    refute_output --partial "frontend_build_"
}

@test "allows blocked command without block message when enforce_mcp_tools is false" {
    setup_config "php-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    run_hook "check-lifecycle-tools.sh" "composer install"
    assert_success
    refute_output --partial "install_dependencies"
}
