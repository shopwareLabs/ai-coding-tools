#!/usr/bin/env bats
# bats file_tags=code-migration,inventory
# Pins complete XML inventory classification and makes failed scans impossible
# to mistake for an empty migration inventory.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

INVENTORY_SH="${SCRIPTS_DIR}/inventory.sh"

# Fixture tree exercising every classification rule: services/routes/packages
# by basename and by directory, an env filename suffix, a routes/<env>/ and
# packages/<env>/ directory env, the routes_overwrite exception, a
# <when env=> block, a nested bundle Resources/config, and every excluded
# Shopware-native format.
setup() {
    EXT="${BATS_TEST_TMPDIR}/ext"
    mkdir -p "${EXT}/src/Resources/config/routes/dev" \
        "${EXT}/src/Resources/config/packages/test" \
        "${EXT}/src/Bundle/MyBundle/Resources/config"

    printf '<container></container>\n' > "${EXT}/src/Resources/config/services.xml"
    printf '<container></container>\n' > "${EXT}/src/Resources/config/services_test.xml"
    printf '<routes></routes>\n' > "${EXT}/src/Resources/config/routes.xml"
    printf '<routes></routes>\n' > "${EXT}/src/Resources/config/routes_dev.xml"
    printf '<routes></routes>\n' > "${EXT}/src/Resources/config/routes_overwrite.xml"
    printf '<routes></routes>\n' > "${EXT}/src/Resources/config/routes/admin.xml"
    printf '%s\n' '<routes>' '  <when env="staging">' '  </when>' '</routes>' \
        > "${EXT}/src/Resources/config/routes/staging.xml"
    printf '<container></container>\n' > "${EXT}/src/Resources/config/packages/monolog.xml"
    printf '<routes></routes>\n' > "${EXT}/src/Resources/config/routes/dev/api.xml"
    printf '<container></container>\n' > "${EXT}/src/Resources/config/packages/test/monolog.xml"
    printf '<container></container>\n' > "${EXT}/src/Bundle/MyBundle/Resources/config/services.xml"
    printf '<routes></routes>\n' > "${EXT}/src/Resources/config/routes/dev/routes_prod.xml"
    printf '<routes></routes>\n' > "${EXT}/src/Resources/config/routes/routes_dev.xml"

    printf '<config></config>\n' > "${EXT}/src/Resources/config/config.xml"
    printf '<custom-fields></custom-fields>\n' > "${EXT}/src/Resources/config/custom-fields.xml"
    printf '<flow></flow>\n' > "${EXT}/src/Resources/config/flow.xml"
    printf '<rule-conditions></rule-conditions>\n' > "${EXT}/src/Resources/config/rule-conditions.xml"
    printf '<manifest></manifest>\n' > "${EXT}/src/Resources/config/manifest.xml"
}

teardown() {
    if [ -n "${UNREADABLE_DIR:-}" ]; then
        chmod 700 "$UNREADABLE_DIR"
    fi
}

@test "classifies services.xml as services with the default env" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/services.xml"$'\t'"services"$'\t'"default"
}

@test "maps a services_<env>.xml filename suffix to that env" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/services_test.xml"$'\t'"services"$'\t'"test"
}

@test "classifies routes.xml as routes with the default env" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/routes.xml"$'\t'"routes"$'\t'"default"
}

@test "maps a routes_<env>.xml filename suffix to that env" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/routes_dev.xml"$'\t'"routes"$'\t'"dev"
}

@test "routes_overwrite.xml is not treated as an env suffix" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/routes_overwrite.xml"$'\t'"routes"$'\t'"default"
}

@test "a file under a routes/ directory is classified as routes by directory" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/routes/admin.xml"$'\t'"routes"$'\t'"default"
}

@test "a <when env=> block appends its env to the filename-derived env" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/routes/staging.xml"$'\t'"routes"$'\t'"default,staging"
}

@test "a file under a packages/ directory is classified as packages" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/packages/monolog.xml"$'\t'"packages"$'\t'"default"
}

@test "a file under routes/<env>/ takes the subdirectory name as its env" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/routes/dev/api.xml"$'\t'"routes"$'\t'"dev"
}

@test "a file under packages/<env>/ takes the subdirectory name as its env" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/packages/test/monolog.xml"$'\t'"packages"$'\t'"test"
}

@test "a routes_<env>.xml filename suffix under routes/<seg>/ is ignored in favor of the directory env" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/routes/dev/routes_prod.xml"$'\t'"routes"$'\t'"dev"
}

@test "a routes_<env>.xml filename suffix directly under routes/ contributes nothing, env is default" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Resources/config/routes/routes_dev.xml"$'\t'"routes"$'\t'"default"
}

@test "a nested bundle Resources/config is swept alongside the top-level one" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    assert_line "${EXT}/src/Bundle/MyBundle/Resources/config/services.xml"$'\t'"services"$'\t'"default"
}

@test "excludes every Shopware-native XML format from the inventory" {
    run "${INVENTORY_SH}" "${EXT}"
    assert_success
    refute_output --partial "/config.xml"$'\t'
    refute_output --partial "/custom-fields.xml"$'\t'
    refute_output --partial "/flow.xml"$'\t'
    refute_output --partial "/rule-conditions.xml"$'\t'
    refute_output --partial "/manifest.xml"$'\t'
}

@test "a native basename in a subdirectory of Resources/config stays in scope as packages" {
    local ext="${BATS_TEST_TMPDIR}/subdir-native"
    mkdir -p "${ext}/src/Resources/config/packages"
    printf '<container></container>\n' > "${ext}/src/Resources/config/packages/config.xml"

    run "${INVENTORY_SH}" "${ext}"
    assert_success
    assert_line "${ext}/src/Resources/config/packages/config.xml"$'\t'"packages"$'\t'"default"
}

@test "config.xml directly in Resources/config is still excluded" {
    local ext="${BATS_TEST_TMPDIR}/direct-native"
    mkdir -p "${ext}/src/Resources/config"
    printf '<config></config>\n' > "${ext}/src/Resources/config/config.xml"

    run "${INVENTORY_SH}" "${ext}"
    assert_success
    assert_output ''
}

@test "an unknown basename carrying the Symfony DI namespace is classified as services" {
    local ext="${BATS_TEST_TMPDIR}/di-namespace"
    mkdir -p "${ext}/src/Resources/config"
    printf '%s\n' '<container xmlns="http://symfony.com/schema/dic/services">' '</container>' \
        > "${ext}/src/Resources/config/elastic.xml"

    run "${INVENTORY_SH}" "${ext}"
    assert_success
    assert_line "${ext}/src/Resources/config/elastic.xml"$'\t'"services"$'\t'"default"
}

@test "a <when env=> block in a content-classified services file appends its env" {
    local ext="${BATS_TEST_TMPDIR}/di-when-env"
    mkdir -p "${ext}/src/Resources/config"
    printf '%s\n' '<container xmlns="http://symfony.com/schema/dic/services">' \
        '  <when env="test">' '  </when>' '</container>' \
        > "${ext}/src/Resources/config/elastic.xml"

    run "${INVENTORY_SH}" "${ext}"
    assert_success
    assert_line "${ext}/src/Resources/config/elastic.xml"$'\t'"services"$'\t'"default,test"
}

@test "an unknown basename carrying the Symfony routing namespace is classified as routes" {
    local ext="${BATS_TEST_TMPDIR}/routing-namespace"
    mkdir -p "${ext}/src/Resources/config"
    printf '%s\n' '<routes xmlns="http://symfony.com/schema/routing">' '</routes>' \
        > "${ext}/src/Resources/config/storefront-api.xml"

    run "${INVENTORY_SH}" "${ext}"
    assert_success
    assert_line "${ext}/src/Resources/config/storefront-api.xml"$'\t'"routes"$'\t'"default"
}

@test "an XML carrying neither Symfony namespace is skipped without discarding classified rows" {
    local ext="${BATS_TEST_TMPDIR}/foreign-schema"
    mkdir -p "${ext}/src/Core/System/Resources/config" "${ext}/src/Resources/config"
    printf '%s\n' '<config>' '  <card>' '  </card>' '</config>' \
        > "${ext}/src/Core/System/Resources/config/cart.xml"
    printf '<container xmlns="http://symfony.com/schema/dic/services"></container>\n' \
        > "${ext}/src/Resources/config/services.xml"

    run --separate-stderr "${INVENTORY_SH}" "${ext}"
    assert_success
    refute_output --partial "/cart.xml"$'\t'
    assert_line "${ext}/src/Resources/config/services.xml"$'\t'"services"$'\t'"default"
    assert_stderr --partial "inventory: skipped (not Symfony DI or routing XML): ${ext}/src/Core/System/Resources/config/cart.xml"
}

@test "an empty tree produces no output and exits 0" {
    mkdir -p "${BATS_TEST_TMPDIR}/empty"
    run "${INVENTORY_SH}" "${BATS_TEST_TMPDIR}/empty"
    assert_success
    assert_output ''
}

@test "a relative root beginning with a dash is treated as a path" {
    local parent="${BATS_TEST_TMPDIR}/leading-dash"
    mkdir -p "${parent}/-extension/src/Resources/config"
    printf '<container></container>\n' > "${parent}/-extension/src/Resources/config/services.xml"

    run bash -c 'cd "$1" && "$2" -extension' -- "$parent" "$INVENTORY_SH"
    assert_success
    assert_line './-extension/src/Resources/config/services.xml'$'\t''services'$'\t''default'
}

@test "an unreadable subtree hard-fails instead of returning a partial inventory" {
    if [ "$(id -u)" -eq 0 ]; then
        skip "root can traverse unreadable directories"
    fi

    UNREADABLE_DIR="${EXT}/blocked"
    mkdir -p "$UNREADABLE_DIR"
    chmod 000 "$UNREADABLE_DIR"

    run --separate-stderr "${INVENTORY_SH}" "$EXT"
    assert_failure 2
    assert_output ''
    assert_stderr --partial "inventory: find failed for ${EXT}"
}

@test "a nonexistent root fails with exit 2" {
    run --separate-stderr "${INVENTORY_SH}" "${BATS_TEST_TMPDIR}/does-not-exist"
    assert_failure 2
    assert_stderr --partial "not a directory"
}

@test "a failing sed inside the when-env scan exits 2 instead of silently dropping when-envs" {
    # inventory.sh's when_envs has exactly one sed call site; overriding sed
    # on PATH forces a deterministic failure there without racing file
    # permissions. Before the fix, when_envs's trailing "rm -f" ran after the
    # failing sed and became the function's return status, so the caller
    # (invoked under `if !`) never saw the failure and printed a silently
    # incomplete inventory with exit 0.
    run --separate-stderr env PATH="${FIXTURES_DIR}/stub-bin:${PATH}" "${INVENTORY_SH}" "${EXT}"
    assert_failure 2
    assert_output ''
    assert_stderr --partial "inventory: sed failed for"
}
