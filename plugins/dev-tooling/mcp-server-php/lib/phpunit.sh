#!/usr/bin/env bash
# PHPUnit tool implementation for MCP server

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# tool_phpunit_run - MCP tool function
# Args: $1 = JSON arguments
# Returns: Raw PHPUnit output
tool_phpunit_run() {
    local args="$1"

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
    [[ -z "${config}" ]] && config="${default_config}"
    [[ -z "${coverage_driver}" ]] && coverage_driver=$(_get_config_value ".phpunit.coverage_driver")

    # Build paths array properly to handle paths with spaces
    local -a path_array=()
    if [[ "${paths_json}" != "[]" ]]; then
        while IFS= read -r p; do
            [[ -n "${p}" ]] && path_array+=("${p}")
        done < <(echo "${paths_json}" | jq -r '.[]' 2>/dev/null)
    fi

    log "INFO" "PHPUnit run: testsuite='${testsuite}' paths='${path_array[*]:-}' filter='${filter}' config='${config}' coverage_driver='${coverage_driver}'"

    local -a flags=()

    # Paths take precedence over testsuite
    if [[ ${#path_array[@]} -gt 0 ]]; then
        for p in "${path_array[@]}"; do flags+=("'${p}'"); done
    elif [[ -n "${testsuite}" ]]; then
        flags+=("--testsuite=${testsuite}")
    fi

    [[ -n "${config}" ]] && flags+=("--configuration=${config}")
    [[ -n "${filter}" ]] && flags+=("--filter='${filter}'")
    [[ "${stop_on_failure}" == "true" ]] && flags+=("--stop-on-failure")
    [[ "${output_format}" == "testdox" ]] && flags+=("--testdox")

    # Coverage options (requires PCOV or Xdebug)
    if [[ "${coverage}" == "true" ]]; then
        case "${coverage_format}" in
            html)
                local html_path="${coverage_path:-coverage/}"
                flags+=("--coverage-html=${html_path}")
                flags+=("--coverage-text")
                ;;
            clover)
                local clover_path="${coverage_path:-coverage.xml}"
                flags+=("--coverage-clover=${clover_path}")
                flags+=("--coverage-text")
                ;;
            cobertura)
                local cobertura_path="${coverage_path:-coverage.xml}"
                flags+=("--coverage-cobertura=${cobertura_path}")
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
