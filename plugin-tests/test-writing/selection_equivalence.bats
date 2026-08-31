#!/usr/bin/env bats
# bats file_tags=test-writing,build-rule-package,selection-equivalence
# §7.2 load-bearing quality guarantee: the Supplied-Rules Mode selection
# predicate (documented in phpunit-unit-test-reviewing/SKILL.md, applied against
# the package's per-rule header lines) must return the SAME rule-ID set as the
# corresponding get_rules / _filter_rules call, for every (group × category ×
# scoped × review_unit) combination a reviewer can pass. The awk below is an
# independent reference implementation of that prose predicate; equivalence with
# _filter_rules proves the prose and the server filter agree.
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

setup() {
    MCP_LOG_FILE="${BATS_TEST_TMPDIR}/mcp.log"
    export MCP_LOG_FILE
    log() { printf '[%s] %s\n' "$1" "$2" >> "${MCP_LOG_FILE}"; }
    source "${TEST_RULES_LIB_DIR}/common.sh"
    source "${TEST_RULES_LIB_DIR}/get.sh"
    source "${TEST_RULES_LIB_DIR}/build.sh"
    export CLAUDE_PLUGIN_DATA="${BATS_TEST_TMPDIR}/plugindata"
}

_pkg_path() {
    local p="${output#*path: }"
    printf '%s' "${p%%$'\n'*}"
}

# Reference implementation of the Supplied-Rules Mode predicate: select rule IDs
# from a package file by matching the per-rule header lines.
# Args: $1=pkg file, $2=group, $3=category (empty=no filter),
#       $4=scoped ("true" or empty), $5=review_unit (empty=no filter)
_select_from_package() {
    awk -v G="$2" -v CAT="$3" -v SCOPED="$4" -v RU="$5" '
        function csv_has(csv, val,   n, a, i) {
            n = split(csv, a, ",")
            for (i = 1; i <= n; i++) if (a[i] == val) return 1
            return 0
        }
        /^# [A-Z]+-[0-9]+ / { id = $2; g = ""; cats = ""; ru = ""; sr = ""; state = 1; next }
        state == 1 && /^Group: / {
            line = $0; sub(/^Group: /, "", line); sub(/ \|.*/, "", line); g = line; state = 2; next
        }
        state == 2 && /^Test types: / {
            n = split($0, parts, / \| /)
            for (i = 1; i <= n; i++) {
                kv = parts[i]; key = kv; sub(/: .*/, "", key); val = kv; sub(/^[^:]*: /, "", val)
                if (key == "Categories") cats = val
                else if (key == "Review unit") ru = val
                else if (key == "Scoped review") sr = val
            }
            ok = 1
            if (G != "" && g != G) ok = 0
            if (CAT != "" && !csv_has(cats, CAT)) ok = 0
            if (RU != "" && ru != RU) ok = 0
            if (SCOPED == "true" && sr == "exclude") ok = 0
            if (ok) print id
            state = 0; next
        }
    ' "$1"
}

# Reference implementation of the composed per-type selection: the type's own
# group plus the four shared groups, each filtered by that test type. Built from
# _filter_rules directly, so it does not borrow the composition helper the tools
# call.
# Args: $1=test_type, $2=scoped ("true" or empty), $3=review_unit (empty=no filter)
_composed_truth() {
    local tt="$1" scoped="$2" ru="$3"
    local g
    for g in convention design "${tt}" isolation provider; do
        _filter_rules "${g}" "${tt}" "" "" "" "${scoped}" "${ru}"
    done
}

@test "_select_from_package reference parser finds a known rule" {
    # Guards the test harness itself: a broken parser would make every
    # equivalence check vacuously pass.
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success
    local pkg
    pkg="$(_pkg_path)"
    run _select_from_package "${pkg}" convention A "" ""
    assert_success
    assert_line "CONV-001"
}

@test "Supplied-Rules selection predicate equals the get_rules filter for every combo" {
    _build_rule_index "${RULES_DIR}"
    run tool_build_rule_package
    assert_success
    local pkg
    pkg="$(_pkg_path)"

    local mismatches="" group cat scoped ru truth pred
    for group in convention design unit isolation provider; do
        for cat in "" A B C D E; do
            for scoped in "" true; do
                for ru in "" method class-structure class-bodies; do
                    # Truth: the server-side filter the reviewer would call.
                    # test_type=unit is a no-op for unit-review groups, mirroring Phase 2.
                    truth="$(_filter_rules "${group}" "unit" "${cat}" "" "" "${scoped}" "${ru}" | LC_ALL=C sort)"
                    pred="$(_select_from_package "${pkg}" "${group}" "${cat}" "${scoped}" "${ru}" | LC_ALL=C sort)"
                    if [[ "${truth}" != "${pred}" ]]; then
                        mismatches+="[group=${group} cat=${cat:-*} scoped=${scoped:-false} ru=${ru:-*}]"$'\n'
                        mismatches+="  truth: ${truth//$'\n'/ }"$'\n'
                        mismatches+="  pred : ${pred//$'\n'/ }"$'\n'
                    fi
                done
            done
        done
    done

    assert_equal "${mismatches}" ""
}

# The unified team review composes one package per non-unit test type via
# build_rule_package(group=X, test_type=T) and the workflow selects each agent's
# scoped ## RULES block from it by review_unit + scoped_review (never category —
# non-unit rules carry "Categories: all"). The same equivalence must hold for
# those single-group catalogs: package selection == _filter_rules.
@test "Supplied-Rules selection predicate equals the get_rules filter for non-unit group catalogs" {
    _build_rule_index "${RULES_DIR}"

    local mismatches="" group tt scoped ru truth pred pkg
    for group in integration migration placement; do
        case "${group}" in
            integration|placement) tt=integration ;;
            migration) tt=migration ;;
        esac
        run tool_build_rule_package "{\"group\":\"${group}\",\"test_type\":\"${tt}\"}"
        assert_success
        pkg="$(_pkg_path)"

        for scoped in "" true; do
            for ru in "" method class-structure class-bodies; do
                # Non-unit reviewers pass no category; mirror that with cat="".
                truth="$(_filter_rules "${group}" "${tt}" "" "" "" "${scoped}" "${ru}" | LC_ALL=C sort)"
                pred="$(_select_from_package "${pkg}" "${group}" "" "${scoped}" "${ru}" | LC_ALL=C sort)"
                if [[ "${truth}" != "${pred}" ]]; then
                    mismatches+="[group=${group} tt=${tt} scoped=${scoped:-false} ru=${ru:-*}]"$'\n'
                    mismatches+="  truth: ${truth//$'\n'/ }"$'\n'
                    mismatches+="  pred : ${pred//$'\n'/ }"$'\n'
                fi
            done
        done
    done

    assert_equal "${mismatches}" ""
}

# The unified team review composes ONE catalog per test type — the type's own
# group plus every convention/design/isolation/provider rule declaring that type
# — and the reviewing skills select from it by review_unit + scoped_review with
# NO group clause, because a composed catalog spans five groups. The same
# equivalence must hold for that multi-group selection: package selection ==
# the server's composed filter.
@test "Supplied-Rules selection predicate equals the get_rules filter for composed per-type catalogs" {
    _build_rule_index "${RULES_DIR}"

    local mismatches="" tt scoped ru truth pred pkg
    for tt in unit integration migration; do
        run tool_build_rule_package "{\"test_type\":\"${tt}\"}"
        assert_success
        pkg="$(_pkg_path)"

        for scoped in "" true; do
            for ru in "" method class-structure class-bodies; do
                # No group and no category: the composed catalog spans groups,
                # and non-unit rules carry "Categories: all".
                truth="$(_composed_truth "${tt}" "${scoped}" "${ru}" | LC_ALL=C sort)"
                pred="$(_select_from_package "${pkg}" "" "" "${scoped}" "${ru}" | LC_ALL=C sort)"
                if [[ "${truth}" != "${pred}" ]]; then
                    mismatches+="[tt=${tt} scoped=${scoped:-false} ru=${ru:-*}]"$'\n'
                    mismatches+="  truth: ${truth//$'\n'/ }"$'\n'
                    mismatches+="  pred : ${pred//$'\n'/ }"$'\n'
                fi
            done
        done
    done

    assert_equal "${mismatches}" ""
}
