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
#   DOCKER_CONTAINER, COMPOSE_SERVICE - exported when the resolved
#     environment uses them
#   COMPOSE_FILE_OVERRIDE, COMPOSE_WORKDIR_OVERRIDE - set for docker-compose
# Arguments:
#   $1 - tool arguments as JSON
# Outputs:
#   Nothing on success; on stdout the message naming why resolution was refused,
#   except a missing docker-compose module, whose message goes to stderr
# Returns:
#   0 when an environment was resolved, 1 when no environment was given, the
#   docker or docker-compose environment was given no docker_service, or a
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
            if [[ -z "${docker_service}" ]]; then
                echo "Error: the docker environment requires a 'docker_service' argument naming the container to run in, and none was passed."
                return 1
            fi
            export DOCKER_CONTAINER="${docker_service}"
            ;;
        docker-compose)
            if [[ -z "${docker_service}" ]]; then
                echo "Error: the docker-compose environment requires a 'docker_service' argument naming the compose service to run in, and none was passed."
                return 1
            fi
            export COMPOSE_SERVICE="${docker_service}"
            # docker-compose.sh expands both overrides under set -u; _compose_cmd
            # turns COMPOSE_FILE_OVERRIDE into -f. The empty workdir selects the
            # call-time container resolution.
            # shellcheck disable=SC2034  # read via dynamic scope by shared/docker-compose.sh (_compose_cmd)
            COMPOSE_FILE_OVERRIDE="${compose_file}"
            # shellcheck disable=SC2034  # read via dynamic scope by shared/docker-compose.sh (_compose_wrap_command)
            COMPOSE_WORKDIR_OVERRIDE=""
            # Not captured: a command substitution would source the module
            # into a subshell and discard it.
            _ensure_compose_module >&2 || return 1
            ;;
    esac

    # The workdir dev-tooling binds when its configuration names none: the host
    # path only where the command runs on the host. With no configuration loaded,
    # _env_configured_workdir answers with each container environment's default.
    # shellcheck disable=SC2034  # read via dynamic scope by shared/environment.sh (wrap_command, get_js_workdir)
    case "${env_arg}" in
        docker|vagrant|ddev)
            LINT_WORKDIR=$(_env_configured_workdir "${env_arg}") || return 1
            ;;
        docker-compose)
            LINT_WORKDIR="(resolved at call time)"
            ;;
        *)
            LINT_WORKDIR="${PROJECT_ROOT}"
            ;;
    esac
    log "INFO" "Environment from args: ${LINT_ENV}"
    return 0
}
