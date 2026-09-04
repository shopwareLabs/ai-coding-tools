#!/usr/bin/env bats
# bats file_tags=code-migration,verify-dumps
# Pins required-set completeness, dump normalization, dump-pair equivalence and
# post-migration safety checks, including hard failures when a filesystem scan
# cannot cover the complete source tree.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

VERIFY_SH="${SCRIPTS_DIR}/verify-dumps.sh"

# The kernel environment a correctly taken dump records for a given dump-file
# env label. "default" labels a console run with no --env option, so the kernel
# reports the installation's own environment — never the literal "default",
# which is exactly what verify-dumps.sh refuses.
kernel_env_for() {
    local env="$1"
    if [ "$env" = default ]; then
        printf 'dev\n'
    else
        printf '%s\n' "$env"
    fi
}

# Write one params dump recording <kernel-env>, in the flat top-level shape the
# console's json parameters descriptor emits: parameter names are the document's
# own keys, with no "parameters" wrapper. The two keys go in opposite order for
# the before and after phase, so normalization stays exercised on the params
# artifact the kernel-environment gate reads.
write_params_dump() {
    local path="$1" phase="$2" kernel_env="$3"
    if [ "$phase" = before ]; then
        printf '{"kernel.environment":"%s","artifact":"params"}' "$kernel_env" > "$path"
    else
        printf '{"artifact":"params","kernel.environment":"%s"}' "$kernel_env" > "$path"
    fi
}

# The same dump in the nested variant: the parameter map under a "parameters"
# key, which read_kernel_env accepts as an explicitly supported second shape.
write_nested_params_dump() {
    local path="$1" phase="$2" kernel_env="$3"
    if [ "$phase" = before ]; then
        printf '{"parameters":{"kernel.environment":"%s","artifact":"params"}}' "$kernel_env" > "$path"
    else
        printf '{"parameters":{"artifact":"params","kernel.environment":"%s"}}' "$kernel_env" > "$path"
    fi
}

# Write the four before/after dump pairs one env needs. The "services" pair
# carries the caller's content; hidden and routes are identical placeholders so
# the required-set check is satisfied, and params carries the kernel.environment
# the env label implies. Content is written raw, unsorted — normalization is the
# script's job now.
make_dump_set() {
    local dir="$1" env="$2" before_content="$3" after_content="$4"
    mkdir -p "$dir"
    printf '%s' "$before_content" > "${dir}/before-services-${env}.json"
    printf '%s' "$after_content" > "${dir}/after-services-${env}.json"

    local artifact
    for artifact in hidden routes; do
        printf '{"artifact":"%s","env":"%s"}' "$artifact" "$env" > "${dir}/before-${artifact}-${env}.json"
        printf '{"env":"%s","artifact":"%s"}' "$env" "$artifact" > "${dir}/after-${artifact}-${env}.json"
    done

    local kernel_env
    kernel_env=$(kernel_env_for "$env")
    write_params_dump "${dir}/before-params-${env}.json" before "$kernel_env"
    write_params_dump "${dir}/after-params-${env}.json" after "$kernel_env"
}

# Write the complete default-env dump set, the shape almost every test needs.
make_default_dump_set() {
    make_dump_set "$1" default "$2" "$3"
}

_assert_usage_error() {
    run --separate-stderr "${VERIFY_SH}" "$@"
    assert_failure 2
    assert_stderr --partial "usage:"
}

setup() {
    CLEAN_SRC="${BATS_TEST_TMPDIR}/clean-src"
    mkdir -p "${CLEAN_SRC}/src/Resources/config"
}

teardown() {
    if [ -n "${UNREADABLE_DIR:-}" ]; then
        chmod 700 "$UNREADABLE_DIR"
    fi
}

@test "an identical pair is reported as identical and exits 0" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_success
    assert_line '| services | identical |'
}

@test "a pair differing only in object key order is identical after normalization" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" \
        '{"zeta":"1","alpha":"2"}' \
        '{"alpha":"2","zeta":"1"}'

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_success
    assert_line '| services | identical |'
}

@test "a diff limited to anonymous inline hidden service ids is reported inert" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" \
        '{".0_App\\Foo~aaaa111": "x"}' \
        '{".0_App\\Foo~bbbb222": "x"}'

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_success
    assert_line '| services | inert (2 changed lines) |'
    assert_line 'Inert diffs: services/default (2 changed lines)'
}

@test "a run with no inert pair reports the inert-diff line as none" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_success
    assert_line 'Inert diffs: none'
}

@test "a real value change is reported as DIFFERS and exits 1" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"baz"}'

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 1
    assert_line '| services | DIFFERS |'
}

@test "an anonymous inline id change with a same-line value change is reported as DIFFERS" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" \
        '{".0_App\\Foo~aaaa111":"before"}' \
        '{".0_App\\Foo~bbbb222":"after"}'

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 1
    assert_line '| services | DIFFERS |'
}

@test "one inert hunk plus one real hunk in the same pair is reported DIFFERS" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" \
        '{".0_App\\Foo~aaaa111": "x", "public.flag": true}' \
        '{".0_App\\Foo~bbbb222": "x", "public.flag": false}'

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 1
    assert_line '| services | DIFFERS |'
}

@test "a dump missing from the required set fails with exit 2, naming the path" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    rm -f -- "${dump}/after-routes-default.json"

    run --separate-stderr "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 2
    assert_stderr --partial "missing required dump: ${dump}/after-routes-default.json"
}

@test "an env listed in the csv with no dumps at all fails with exit 2" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    run --separate-stderr "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default,test
    assert_failure 2
    assert_stderr --partial "missing required dump: ${dump}/before-services-test.json"
}

@test "a named env whose params dumps record another kernel environment fails with exit 2" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_dump_set "$dump" test '{"foo":"bar"}' '{"foo":"bar"}'
    write_params_dump "${dump}/before-params-test.json" before dev
    write_params_dump "${dump}/after-params-test.json" after dev

    run --separate-stderr "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" test
    assert_failure 2
    assert_stderr --partial "${dump}/before-params-test.json records kernel.environment \"dev\" but the filename claims env \"test\""
}

@test "a default pair recording the literal default kernel environment fails with exit 2" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    write_params_dump "${dump}/before-params-default.json" before default
    write_params_dump "${dump}/after-params-default.json" after default

    run --separate-stderr "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 2
    assert_stderr --partial 'record kernel.environment "default"'
    assert_stderr --partial 'taken with the literal environment name "default"'
}

@test "before and after params dumps recording different kernel environments fail with exit 2" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    write_params_dump "${dump}/after-params-default.json" after prod

    run --separate-stderr "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 2
    assert_stderr --partial "${dump}/before-params-default.json records kernel.environment \"dev\" but ${dump}/after-params-default.json records \"prod\""
}

@test "a params dump recording no kernel.environment fails with exit 2, naming the file" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    printf '{"artifact":"params"}' > "${dump}/before-params-default.json"

    run --separate-stderr "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 2
    assert_stderr --partial "${dump}/before-params-default.json records no kernel.environment parameter"
}

@test "a params dump nesting the parameter map under a parameters key is accepted" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    write_nested_params_dump "${dump}/before-params-default.json" before dev
    write_nested_params_dump "${dump}/after-params-default.json" after dev

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_success
    assert_line '| params | identical |'
}

@test "a multi-env csv with complete sets gets a table column per env and exits 0" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_dump_set "$dump" default '{"foo":"bar"}' '{"foo":"bar"}'
    make_dump_set "$dump" test '{"foo":"bar"}' '{"foo":"bar"}'

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default,test
    assert_success
    assert_line '| Artifact | default | test |'
    assert_line '| services | identical | identical |'
}

@test "a stray pair outside the csv is still discovered and diffed" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    printf '{"foo":"bar"}' > "${dump}/before-services-staging.json"
    printf '{"foo":"baz"}' > "${dump}/after-services-staging.json"

    run "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 1
    assert_line '| services | identical | DIFFERS |'
}

@test "a stray before dump outside the csv with no after counterpart fails with exit 2, naming it" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    printf '{"foo":"bar"}' > "${dump}/before-services-staging.json"

    run --separate-stderr "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 2
    assert_stderr --partial "missing counterpart dump: ${dump}/after-services-staging.json"
}

@test "a dump that is not valid JSON fails with exit 2, naming the file" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    printf 'Xdebug: connection failed\n' > "${dump}/before-services-default.json"

    run --separate-stderr "${VERIFY_SH}" "$dump" "${CLEAN_SRC}" default
    assert_failure 2
    assert_stderr --partial "${dump}/before-services-default.json is not valid JSON"
}

@test "a services.xml/services.php coexistence pair fails with exit 1" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    local src="${BATS_TEST_TMPDIR}/coexist-src"
    mkdir -p "${src}/src/Resources/config"
    printf '<container></container>\n' > "${src}/src/Resources/config/services.xml"
    printf '<?php\n' > "${src}/src/Resources/config/services.php"

    run "${VERIFY_SH}" "$dump" "$src" default
    assert_failure 1
    assert_output --partial "Coexistence check: FINDINGS"
    assert_output --partial "${src}/src/Resources/config/services.php"
}

@test "a packages XML/YAML coexistence pair fails with exit 1" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    local src="${BATS_TEST_TMPDIR}/packages-coexist-src"
    mkdir -p "${src}/src/Resources/config/packages"
    printf '<container></container>\n' > "${src}/src/Resources/config/packages/monolog.xml"
    printf 'monolog: {}\n' > "${src}/src/Resources/config/packages/monolog.yaml"

    run "${VERIFY_SH}" "$dump" "$src" default
    assert_failure 1
    assert_output --partial "Coexistence check: FINDINGS"
    assert_output --partial "${src}/src/Resources/config/packages/monolog.yaml"
}

@test "a packages/config.xml and packages/config.yaml coexistence pair fails with exit 1" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    local src="${BATS_TEST_TMPDIR}/packages-config-coexist-src"
    mkdir -p "${src}/src/Resources/config/packages"
    printf '<container></container>\n' > "${src}/src/Resources/config/packages/config.xml"
    printf 'framework: {}\n' > "${src}/src/Resources/config/packages/config.yaml"

    run "${VERIFY_SH}" "$dump" "$src" default
    assert_failure 1
    assert_output --partial "Coexistence check: FINDINGS"
    assert_output --partial "${src}/src/Resources/config/packages/config.yaml"
}

@test "a lone packages XML file does not produce a coexistence finding" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    local src="${BATS_TEST_TMPDIR}/packages-alone-src"
    mkdir -p "${src}/src/Resources/config/packages"
    printf '<container></container>\n' > "${src}/src/Resources/config/packages/monolog.xml"

    run "${VERIFY_SH}" "$dump" "$src" default
    assert_success
    assert_output --partial "Coexistence check: clean"
}

@test "a native-format XML directly in Resources/config alongside a same-basename sibling stays exempt" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    local src="${BATS_TEST_TMPDIR}/native-exempt-src"
    mkdir -p "${src}/src/Resources/config"
    printf '<config></config>\n' > "${src}/src/Resources/config/config.xml"
    printf '<?php\n' > "${src}/src/Resources/config/config.php"

    run "${VERIFY_SH}" "$dump" "$src" default
    assert_success
    assert_output --partial "Coexistence check: clean"
}

@test "a leftover .xml reference in migrated PHP fails with exit 1" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    local src="${BATS_TEST_TMPDIR}/leftover-src"
    mkdir -p "${src}/src/Resources/config"
    printf '<?php\n// migrated from old_routes.xml\n' > "${src}/src/Resources/config/routes.php"

    run "${VERIFY_SH}" "$dump" "$src" default
    assert_failure 1
    assert_output --partial "Leftover XML references: FINDINGS"
    assert_output --partial "old_routes.xml"
}

@test "a filename that merely ends like a native format is still flagged, not excluded as native" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    local src="${BATS_TEST_TMPDIR}/lookalike-src"
    mkdir -p "${src}/src/Resources/config"
    printf '<?php\n// migrated from workflow.xml\n' > "${src}/src/Resources/config/workflow.php"

    run "${VERIFY_SH}" "$dump" "$src" default
    assert_failure 1
    assert_output --partial "Leftover XML references: FINDINGS"
    assert_output --partial "workflow.xml"
}

@test "a leftover reference to a Shopware-native XML format is not a finding" {
    local dump="${BATS_TEST_TMPDIR}/dump"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'

    local src="${BATS_TEST_TMPDIR}/native-src"
    mkdir -p "${src}/src/Resources/config"
    printf '<?php\n// plugin settings live in config.xml\n' > "${src}/src/Resources/config/Plugin.php"

    run "${VERIFY_SH}" "$dump" "$src" default
    assert_success
    assert_output --partial "Leftover XML references: clean"
}

@test "relative dump and source roots beginning with a dash are treated as paths" {
    local parent="${BATS_TEST_TMPDIR}/leading-dash"
    local dump="${parent}/-dump"
    local src="${parent}/-src"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    mkdir -p "${src}/src/Resources/config"

    run bash -c 'cd "$1" && "$2" -dump -src default' -- "$parent" "$VERIFY_SH"
    assert_success
    assert_line 'Coexistence check: clean'
}

@test "an unreadable source subtree hard-fails instead of reporting a clean verification" {
    if [ "$(id -u)" -eq 0 ]; then
        skip "root can traverse unreadable directories"
    fi

    local dump="${BATS_TEST_TMPDIR}/unreadable-dump"
    local src="${BATS_TEST_TMPDIR}/unreadable-src"
    make_default_dump_set "$dump" '{"foo":"bar"}' '{"foo":"bar"}'
    mkdir -p "${src}/src/Resources/config" "${src}/blocked"
    UNREADABLE_DIR="${src}/blocked"
    chmod 000 "$UNREADABLE_DIR"

    run --separate-stderr "${VERIFY_SH}" "$dump" "$src" default
    assert_failure 2
    assert_output ''
    assert_stderr --partial "verify-dumps: find failed for ${src}"
}

@test "a single positional argument is a usage error" {
    _assert_usage_error "${BATS_TEST_TMPDIR}/dump"
}

@test "two positional arguments are a usage error" {
    _assert_usage_error "${BATS_TEST_TMPDIR}/dump" "${CLEAN_SRC}"
}

@test "an empty envs csv is a usage error" {
    _assert_usage_error "${BATS_TEST_TMPDIR}/dump" "${CLEAN_SRC}" ""
}

@test "an empty segment in the envs csv is a usage error" {
    _assert_usage_error "${BATS_TEST_TMPDIR}/dump" "${CLEAN_SRC}" "default,"
}
