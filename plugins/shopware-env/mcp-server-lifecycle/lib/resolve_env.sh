#!/usr/bin/env bash
# Environment resolution for lifecycle tools
# Config file values override model-passed arguments.

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# resolve_lifecycle_env <json_args>
# Resolves execution environment from config (if available) or tool arguments.
# Fails hard if neither provides an environment.
#
# When LIFECYCLE_HAS_CONFIG is true, config values win unconditionally
# (detect_environment has already populated LINT_ENV/LINT_WORKDIR via server.sh).
# When false, reads environment/docker_service/compose_file from JSON args.
#
# Globals set (when reading from args): LINT_ENV, LINT_WORKDIR,
# and DOCKER_CONTAINER/COMPOSE_SERVICE/COMPOSE_FILE as applicable.
resolve_lifecycle_env() {
    local args="$1"

    if [[ "${LIFECYCLE_HAS_CONFIG}" == "true" ]]; then
        log "INFO" "Environment from config: ${LINT_ENV}"
        return 0
    fi

    local env_arg docker_service compose_file
    env_arg=$(echo "${args}" | jq -r '.environment // empty' 2>/dev/null || echo "")
    docker_service=$(echo "${args}" | jq -r '.docker_service // empty' 2>/dev/null || echo "")
    compose_file=$(echo "${args}" | jq -r '.compose_file // empty' 2>/dev/null || echo "")

    if [[ -z "${env_arg}" ]]; then
        echo "Error: no .mcp-php-tooling.json config found and no 'environment' argument passed. Provide an environment argument (native, docker, docker-compose, vagrant, ddev) or install the dev-tooling plugin and run its setting-up skill."
        return 1
    fi

    # shellcheck disable=SC2034  # consumed by environment.sh
    LINT_ENV="${env_arg}"

    case "${env_arg}" in
        docker)
            if [[ -n "${docker_service}" ]]; then
                export DOCKER_CONTAINER="${docker_service}"
            fi
            ;;
        docker-compose)
            if [[ -n "${docker_service}" ]]; then
                export COMPOSE_SERVICE="${docker_service}"
            fi
            if [[ -n "${compose_file}" ]]; then
                export COMPOSE_FILE="${compose_file}"
            fi
            ;;
    esac

    # shellcheck disable=SC2034  # consumed by environment.sh
    LINT_WORKDIR="${PROJECT_ROOT}"
    log "INFO" "Environment from args: ${LINT_ENV}"
    return 0
}
