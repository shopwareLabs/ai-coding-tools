#!/usr/bin/env bash
# Environment resolution for lifecycle tools
# Config file values override model-passed arguments.

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Resolve the execution environment from config (when available) or from the
# tool arguments. Fails hard if neither provides an environment.
#
# When LIFECYCLE_HAS_CONFIG is true, config values win unconditionally
# (detect_environment has already populated LINT_ENV/LINT_WORKDIR via server.sh).
# When false, reads environment/docker_service/compose_file from JSON args.
# Globals:
#   LIFECYCLE_HAS_CONFIG, PROJECT_ROOT - read
#   LINT_ENV, LINT_WORKDIR - set when reading from args
#   DOCKER_CONTAINER, COMPOSE_SERVICE, COMPOSE_FILE - exported when the
#     resolved environment uses them
# Arguments:
#   $1 - tool arguments as JSON
# Outputs:
#   Nothing on success; on stdout the message naming why resolution was refused
# Returns:
#   0 when an environment was resolved, 1 when no environment was given or a
#   value cannot be embedded in a wrapped command
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

    local guard
    if ! guard=$(assert_no_shell_hostile_chars "docker_service" "${docker_service}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if ! guard=$(assert_no_shell_hostile_chars "compose_file" "${compose_file}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

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

    # shellcheck disable=SC2034  # read via dynamic scope by shared/environment.sh (wrap_command, get_js_workdir)
    LINT_WORKDIR="${PROJECT_ROOT}"
    log "INFO" "Environment from args: ${LINT_ENV}"
    return 0
}
