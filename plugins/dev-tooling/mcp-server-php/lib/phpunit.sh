#!/usr/bin/env bash
# PHPUnit tool implementation for MCP server

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# tool_phpunit_run - MCP tool function
# Args: $1 = JSON arguments
# Returns: Raw PHPUnit output
tool_phpunit_run() {
    local args="$1"

    if echo "${args}" | jq -e 'any((.. | strings), (.. | objects | keys[]); contains("\n") or contains("\r"))' >/dev/null 2>&1; then
        printf '%s\n' "Refusing to run: arguments contain a line break, which cannot be embedded in a single command."
        return 1
    fi

    local scope_arg
    scope_arg=$(echo "${args}" | jq -r '.scope // empty' 2>/dev/null || echo "")
    if ! resolve_scope "${scope_arg}"; then
        echo "Scope resolution error"
        return 1
    fi
    local scoped_config
    scoped_config=$(scope_get_tool_field phpunit config)

    local default_testsuite default_config
    default_testsuite=$(_get_config_value ".phpunit.testsuite")
    default_config=$(_get_config_value ".phpunit.config")

    local parsed
    parsed=$(echo "${args}" | jq -c '{
        testsuite: (.testsuite // null),
        paths: (.paths // []),
        filter: (.filter // null),
        stop_on_failure: (.stop_on_failure // false),
        coverage: (.coverage // false),
        coverage_format: (.coverage_format // "text"),
        coverage_path: (.coverage_path // null),
        coverage_driver: (.coverage_driver // null),
        output_format: (.output_format // "default"),
        config: (.config // null)
    }' 2>/dev/null || echo '{"testsuite":null,"paths":[],"filter":null,"stop_on_failure":false,"coverage":false,"coverage_format":"text","coverage_path":null,"coverage_driver":null,"output_format":"default","config":null}')

    local testsuite paths_json filter stop_on_failure coverage coverage_format coverage_path coverage_driver output_format config
    testsuite=$(echo "${parsed}" | jq -r '.testsuite // empty')
    paths_json=$(echo "${parsed}" | jq -c '.paths')
    filter=$(echo "${parsed}" | jq -r '.filter // empty')
    stop_on_failure=$(echo "${parsed}" | jq -r '.stop_on_failure')
    coverage=$(echo "${parsed}" | jq -r '.coverage')
    coverage_format=$(echo "${parsed}" | jq -r '.coverage_format')
    coverage_path=$(echo "${parsed}" | jq -r '.coverage_path // empty')
    coverage_driver=$(echo "${parsed}" | jq -r '.coverage_driver // empty')
    output_format=$(echo "${parsed}" | jq -r '.output_format')
    config=$(echo "${parsed}" | jq -r '.config // empty')

    [[ -z "${testsuite}" ]] && testsuite="${default_testsuite}"
    [[ -z "${config}" ]] && config="${scoped_config}"
    [[ -z "${config}" ]] && config="${default_config}"
    [[ -z "${coverage_driver}" ]] && coverage_driver=$(_get_config_value ".phpunit.coverage_driver")

    # Paths are validated and quoted in one step: a malformed "paths" payload
    # must not fall through to the whole-suite run.
    local paths
    if ! paths=$(parse_paths_json "${paths_json}" ""); then
        printf '%s\n' "${paths}"
        return 1
    fi

    local guard
    if [[ -n "${testsuite}" ]] && ! guard=$(assert_no_shell_hostile_chars "testsuite" "${testsuite}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${config}" ]] && ! guard=$(assert_no_shell_hostile_chars "PHPUnit configuration" "${config}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${filter}" ]] && ! guard=$(assert_no_shell_hostile_chars "filter" "${filter}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if [[ -n "${coverage_path}" ]] && ! guard=$(assert_no_shell_hostile_chars "coverage path" "${coverage_path}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    log "INFO" "PHPUnit run: testsuite='${testsuite}' paths='${paths}' filter='${filter}' config='${config}' coverage_driver='${coverage_driver}'"

    local -a flags=()

    # Paths take precedence over testsuite
    if [[ -n "${paths}" ]]; then
        flags+=("${paths}")
    elif [[ -n "${testsuite}" ]]; then
        flags+=("--testsuite=$(shell_quote_arg "${testsuite}")")
    fi

    [[ -n "${config}" ]] && flags+=("--configuration=$(shell_quote_arg "${config}")")
    [[ -n "${filter}" ]] && flags+=("--filter=$(shell_quote_arg "${filter}")")
    [[ "${stop_on_failure}" == "true" ]] && flags+=("--stop-on-failure")
    [[ "${output_format}" == "testdox" ]] && flags+=("--testdox")

    # Coverage options (requires PCOV or Xdebug)
    if [[ "${coverage}" == "true" ]]; then
        case "${coverage_format}" in
            html)
                local html_path="${coverage_path:-coverage/}"
                flags+=("--coverage-html=$(shell_quote_arg "${html_path}")")
                flags+=("--coverage-text")
                ;;
            clover)
                local clover_path="${coverage_path:-coverage.xml}"
                flags+=("--coverage-clover=$(shell_quote_arg "${clover_path}")")
                flags+=("--coverage-text")
                ;;
            cobertura)
                local cobertura_path="${coverage_path:-coverage.xml}"
                flags+=("--coverage-cobertura=$(shell_quote_arg "${cobertura_path}")")
                flags+=("--coverage-text")
                ;;
            text|*)
                flags+=("--coverage-text")
                ;;
        esac
    fi

    # Prepend env var for drivers that require runtime activation (Xdebug 3)
    local env_prefix=""
    if [[ "${coverage}" == "true" && "${coverage_driver}" == "xdebug" ]]; then
        env_prefix="XDEBUG_MODE=coverage "
    fi

    local cmd="${env_prefix}vendor/bin/phpunit"
    [[ ${#flags[@]} -gt 0 ]] && cmd="${cmd} ${flags[*]}"

    exec_command "${cmd}"
}
