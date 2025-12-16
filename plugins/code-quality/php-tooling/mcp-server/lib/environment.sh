#!/usr/bin/env bash
# Environment configuration and command wrapping for PHP linting tools
# Supports: native, docker, vagrant, ddev
# Requires .mcp-php-tooling.json with "environment" field
# LINT_CONFIG_FILE must be set by server.sh before sourcing this file

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

LINT_ENV=""
LINT_WORKDIR=""
DOCKER_CONTAINER=""

# Find first existing file from a list
# Args: $1 = directory, $2+ = filenames to check
# Returns: first found filename or empty string
_find_first_file() {
    local dir="$1"; shift
    for f in "$@"; do
        [[ -f "${dir}/${f}" ]] && echo "${f}" && return
    done
    echo ""
}

# Get config value from .mcp-php-tooling.json
# Args: $1 = json path (e.g., ".docker.container"), $2 = default value (optional)
# Returns: value from config or default (empty string if no default)
# shellcheck disable=SC2154  # LINT_CONFIG_FILE is exported from server.sh
_get_config_value() {
    local path="$1"
    local default="${2:-}"

    [[ -f "${LINT_CONFIG_FILE}" ]] || { echo "${default}"; return 0; }

    local value
    value=$(jq -r "${path} // empty" "${LINT_CONFIG_FILE}" 2>/dev/null || echo "")
    [[ -n "${value}" ]] && echo "${value}" || echo "${default}"
}

# Load environment from config (required)
# Sets LINT_ENV to: native|docker|vagrant|ddev
# Exits with error if config missing or invalid
# shellcheck disable=SC2154  # LINT_CONFIG_FILE is exported from server.sh
detect_environment() {
    local project_root="$1"

    if [[ ! -f "${LINT_CONFIG_FILE}" ]]; then
        log "ERROR" "Missing config file: ${LINT_CONFIG_FILE}"
        log "ERROR" "Create .mcp-php-tooling.json with 'environment' field"
        exit 1
    fi

    local env_value
    env_value=$(jq -r '.environment // empty' "${LINT_CONFIG_FILE}" 2>/dev/null || echo "")
    if [[ -z "${env_value}" ]]; then
        log "ERROR" "Missing 'environment' field in ${LINT_CONFIG_FILE}"
        exit 1
    fi

    LINT_ENV="${env_value}"
    _set_workdir_from_config "${project_root}" "${LINT_CONFIG_FILE}"
    log "INFO" "Environment from config: ${LINT_ENV}"
    return 0
}

# Get docker container name from config (required for docker environment)
# Exits with error if not configured
_get_docker_container() {
    local config_file="$1"

    local container
    container=$(jq -r '.docker.container // empty' "${config_file}" 2>/dev/null || echo "")

    if [[ -z "${container}" ]]; then
        log "ERROR" "Docker environment requires 'docker.container' in config"
        exit 1
    fi

    echo "${container}"
}

_set_workdir_from_config() {
    local project_root="$1"
    local config_file="$2"

    case "${LINT_ENV}" in
        docker)
            LINT_WORKDIR=$(_get_config_value ".docker.workdir" "/var/www/html")
            DOCKER_CONTAINER=$(_get_docker_container "${config_file}")
            ;;
        vagrant)
            LINT_WORKDIR=$(_get_config_value ".vagrant.workdir" "/vagrant")
            ;;
        ddev)
            LINT_WORKDIR=$(_get_config_value ".ddev.workdir" "/var/www/html")
            ;;
        native|*)
            LINT_WORKDIR="${project_root}"
            ;;
    esac
}

get_composer_command() {
    case "${LINT_ENV}" in
        ddev)
            echo "ddev composer"
            ;;
        *)
            echo "composer"
            ;;
    esac
}

# Wrap command for execution in detected environment
# Usage: wrap_command "composer phpstan"
wrap_command() {
    local cmd="$1"

    case "${LINT_ENV}" in
        native)
            echo "${cmd}"
            ;;
        docker)
            # Use -i for interactive but not -t (no tty in MCP context)
            echo "docker exec -i ${DOCKER_CONTAINER} bash -c 'cd ${LINT_WORKDIR} && ${cmd}'"
            ;;
        vagrant)
            echo "vagrant ssh -c 'cd ${LINT_WORKDIR} && ${cmd}'"
            ;;
        ddev)
            if [[ "${cmd}" == composer* ]]; then
                echo "ddev ${cmd}"
            else
                echo "ddev exec ${cmd}"
            fi
            ;;
        *)
            log "ERROR" "Unknown environment: ${LINT_ENV}"
            echo "${cmd}"
            ;;
    esac
}

# Execute command in detected environment
# Usage: exec_command "composer phpstan"
# Returns: command output on stdout, exit code
# Note: eval is used here because wrapped commands may contain pipes, redirects,
# or other shell constructs. The command is constructed internally from trusted
# config values, not from direct user input.
exec_command() {
    local cmd="$1"
    local wrapped_cmd

    wrapped_cmd=$(wrap_command "${cmd}")

    log "INFO" "Executing: ${wrapped_cmd}"

    local output
    local exit_code=0

    output=$(eval "${wrapped_cmd}" 2>&1) || exit_code=$?

    log "INFO" "Command exit code: ${exit_code}"

    echo "${output}"
    return "${exit_code}"
}

get_environment_info() {
    local project_root="$1"
    local has_config="false"
    local phpstan_config=""
    local ecs_config=""

    [[ -f "${LINT_CONFIG_FILE}" ]] && has_config="true"

    phpstan_config=$(_find_first_file "${project_root}" phpstan.neon phpstan.neon.dist phpstan.dist.neon)
    ecs_config=$(_find_first_file "${project_root}" .php-cs-fixer.php .php-cs-fixer.dist.php ecs.php ecs.dist.php)

    local example_cmd
    example_cmd=$(wrap_command "composer phpstan")

    cat <<EOF
## Linting Environment Information

**Environment:** ${LINT_ENV}
**Working Directory:** ${LINT_WORKDIR}
**Project Root:** ${project_root}
**Config File:** ${LINT_CONFIG_FILE}
EOF

    if [[ "${LINT_ENV}" == "docker" ]]; then
        echo "**Docker Container:** ${DOCKER_CONTAINER}"
    fi

    cat <<EOF

### Configuration Files
- **Config:** ${has_config} (${LINT_CONFIG_FILE})
- **PHPStan Config:** ${phpstan_config:-"Not found"}
- **ECS Config:** ${ecs_config:-"Not found"}

### Command Execution
Commands are executed using the **${LINT_ENV}** environment.

Example: \`composer phpstan\` becomes:
\`\`\`
${example_cmd}
\`\`\`
EOF
}
