#!/usr/bin/env bash
# Docker Compose environment support for dev-tooling MCP servers
# Resolves container name and working directory from docker compose at call time.
# Requires: COMPOSE_SERVICE, COMPOSE_WORKDIR_OVERRIDE, COMPOSE_FILE_OVERRIDE, PROJECT_ROOT
# Must be sourced after mcpserver_core.sh (needs log function)

# Build the base docker compose command, optionally with -f flag.
# Uses: COMPOSE_FILE_OVERRIDE, PROJECT_ROOT
# Returns: command string on stdout
_compose_cmd() {
    local cmd="docker compose"
    if [[ -n "${COMPOSE_FILE_OVERRIDE}" ]]; then
        local file_path="${COMPOSE_FILE_OVERRIDE}"
        # Resolve relative paths against PROJECT_ROOT
        if [[ "${file_path}" != /* ]]; then
            file_path="${PROJECT_ROOT}/${file_path}"
        fi
        cmd="${cmd} -f ${file_path}"
    fi
    echo "${cmd}"
}

# Verify docker and docker compose are available.
# Returns: 0 on success, 1 with error message on stdout on failure
_compose_check_prerequisites() {
    if ! command -v docker &>/dev/null; then
        echo "docker CLI not found. Install Docker: https://docs.docker.com/get-docker/"
        return 1
    fi

    local version_output
    version_output=$(docker compose version 2>&1) || {
        if [[ "${version_output}" == *"is not a docker command"* ]]; then
            echo "docker compose not available. Install Docker Compose V2: https://docs.docker.com/compose/install/"
        else
            echo "Docker daemon is not running. Start Docker Desktop or the Docker service."
        fi
        return 1
    }

    return 0
}

# Resolve the running container name for the configured service.
# Uses: COMPOSE_SERVICE, COMPOSE_FILE_OVERRIDE, PROJECT_ROOT
# Returns: container name on stdout, or error message + return 1
_compose_resolve_container() {
    local base_cmd
    base_cmd=$(_compose_cmd)

    local ps_output
    ps_output=$(eval "${base_cmd} ps --format json --status running" 2>&1) || {
        echo "Failed to query running containers: ${ps_output}"
        return 1
    }

    # docker compose ps outputs one JSON object per line
    local container_name
    container_name=$(echo "${ps_output}" | jq -r --arg svc "${COMPOSE_SERVICE}" \
        'select(.Service == $svc) | .Name' 2>/dev/null | head -1)

    if [[ -n "${container_name}" ]]; then
        echo "${container_name}"
        return 0
    fi

    # Service not running — check if it exists in compose config
    local config_output
    config_output=$(eval "${base_cmd} config --format json" 2>&1) || {
        echo "Service '${COMPOSE_SERVICE}' is not running. Start it with: docker compose up -d ${COMPOSE_SERVICE}"
        return 1
    }

    local service_exists
    service_exists=$(echo "${config_output}" | jq -r --arg svc "${COMPOSE_SERVICE}" \
        '.services[$svc] // empty' 2>/dev/null)

    if [[ -z "${service_exists}" ]]; then
        local available
        available=$(echo "${config_output}" | jq -r '.services | keys | join(", ")' 2>/dev/null)
        echo "Service '${COMPOSE_SERVICE}' not found in compose config. Available services: ${available}"
        return 1
    fi

    echo "Service '${COMPOSE_SERVICE}' is not running. Start it with: docker compose up -d ${COMPOSE_SERVICE}"
    return 1
}

# Resolve the working directory inside the container for the configured service.
# If COMPOSE_WORKDIR_OVERRIDE is set, returns that directly.
# Otherwise, finds the bind mount whose source matches PROJECT_ROOT.
# Uses: COMPOSE_WORKDIR_OVERRIDE, COMPOSE_SERVICE, COMPOSE_FILE_OVERRIDE, PROJECT_ROOT
# Returns: workdir path on stdout, or error message + return 1
_compose_resolve_workdir() {
    if [[ -n "${COMPOSE_WORKDIR_OVERRIDE}" ]]; then
        echo "${COMPOSE_WORKDIR_OVERRIDE}"
        return 0
    fi

    local base_cmd
    base_cmd=$(_compose_cmd)

    local config_output
    config_output=$(eval "${base_cmd} config --format json" 2>&1) || {
        echo "Failed to read compose config: ${config_output}"
        return 1
    }

    local workdir
    workdir=$(echo "${config_output}" | jq -r --arg svc "${COMPOSE_SERVICE}" \
        --arg root "${PROJECT_ROOT}" \
        '.services[$svc].volumes // [] | .[] | select(.type == "bind" and .source == $root) | .target' \
        2>/dev/null | head -1)

    if [[ -n "${workdir}" ]]; then
        echo "${workdir}"
        return 0
    fi

    echo "No bind mount for ${PROJECT_ROOT} found on service '${COMPOSE_SERVICE}'. Set docker-compose.workdir in config."
    return 1
}

# Wrap a PHP/generic command for execution in the docker-compose environment.
# Resolves container and workdir at call time, returns docker exec string.
# Args: $1 = command to execute
# Returns: wrapped command string on stdout, or error message + return 1
_compose_wrap_command() {
    local cmd="$1"

    _compose_check_prerequisites || return $?

    local container
    container=$(_compose_resolve_container) || { echo "${container}"; return 1; }

    local workdir
    workdir=$(_compose_resolve_workdir) || { echo "${workdir}"; return 1; }

    echo "docker exec -i ${container} bash -c 'cd ${workdir} && ${cmd}'"
}

# Wrap an npm command for execution in the docker-compose environment.
# Same as _compose_wrap_command but appends JS context path to workdir.
# Args: $1 = command to execute
# Uses: JS_CONTEXT (admin|storefront)
# Returns: wrapped command string on stdout, or error message + return 1
_compose_wrap_npm_command() {
    local cmd="$1"

    _compose_check_prerequisites || return $?

    local container
    container=$(_compose_resolve_container) || { echo "${container}"; return 1; }

    local base_workdir
    base_workdir=$(_compose_resolve_workdir) || { echo "${base_workdir}"; return 1; }

    local workdir="${base_workdir}"
    case "${JS_CONTEXT:-}" in
        "admin")
            workdir="${base_workdir}/src/Administration/Resources/app/administration"
            ;;
        "storefront")
            workdir="${base_workdir}/src/Storefront/Resources/app/storefront"
            ;;
    esac

    echo "docker exec -i ${container} bash -c 'cd ${workdir} && ${cmd}'"
}
