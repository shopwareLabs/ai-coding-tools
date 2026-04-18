#!/usr/bin/env bash
# Environment configuration and command wrapping for dev tooling MCP servers
# Supports: native, docker, docker-compose, vagrant, ddev
# Supports both PHP (composer) and JS (npm/yarn/pnpm) command execution
# Requires config file with "environment" field
# LINT_CONFIG_FILE must be set by server.sh before sourcing this file

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

LINT_ENV=""
LINT_WORKDIR=""
DOCKER_CONTAINER=""

# Environment noise patterns to filter from tool output.
# Each entry is a sed BRE expression that matches a full line to remove.
# Only add patterns for noise that is NEVER useful in MCP context.
# NEVER add patterns that could match errors or failures.
ENV_NOISE_PATTERNS=(
    '/^Xdebug: \[Step Debug\] Could not connect to debugging client\./d'
)

# Filter known environment noise from command output.
# Reads from stdin, writes filtered output to stdout.
_filter_env_noise() {
    if [[ ${#ENV_NOISE_PATTERNS[@]} -eq 0 ]]; then
        cat
        return
    fi

    local sed_args=()
    for pattern in "${ENV_NOISE_PATTERNS[@]}"; do
        sed_args+=(-e "${pattern}")
    done
    sed "${sed_args[@]}"
}

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
        docker-compose)
            # Source compose module on first use
            if ! declare -f _compose_wrap_command &>/dev/null; then
                local shared_dir
                shared_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                source "${shared_dir}/docker-compose.sh"
            fi
            # Read config values — no CLI calls at startup
            COMPOSE_SERVICE=$(_get_config_value '."docker-compose".service' "web")
            COMPOSE_WORKDIR_OVERRIDE=$(_get_config_value '."docker-compose".workdir' "")
            COMPOSE_FILE_OVERRIDE=$(_get_config_value '."docker-compose".file' "")
            LINT_WORKDIR="(resolved at call time)"
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

# Wrap command for execution in detected environment.
# Honors SCOPE_CWD (relative to LINT_WORKDIR) when set; empty means unscoped.
# Usage: wrap_command "composer phpstan"
wrap_command() {
    local cmd="$1"
    local workdir="${LINT_WORKDIR}"
    local scoped="${SCOPE_CWD:-}"

    # Compute the effective workdir once.
    if [[ -n "${scoped}" ]]; then
        workdir="${LINT_WORKDIR}/${scoped}"
    fi

    case "${LINT_ENV}" in
        native)
            if [[ -n "${scoped}" ]]; then
                echo "cd \"${workdir}\" && ${cmd}"
            else
                echo "${cmd}"
            fi
            ;;
        docker)
            echo "docker exec -i ${DOCKER_CONTAINER} bash -c 'cd ${workdir} && ${cmd}'"
            ;;
        docker-compose)
            _compose_wrap_command "${cmd}"
            ;;
        vagrant)
            echo "vagrant ssh -c 'cd ${workdir} && ${cmd}'"
            ;;
        ddev)
            if [[ -n "${scoped}" ]]; then
                echo "ddev exec -d \"${workdir}\" ${cmd}"
            elif [[ "${cmd}" == composer* ]]; then
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

    wrapped_cmd=$(wrap_command "${cmd}") || {
        echo "${wrapped_cmd}"
        return 1
    }

    log "INFO" "Executing: ${wrapped_cmd}"

    local output
    local exit_code=0

    output=$(eval "${wrapped_cmd}" 2>&1) || exit_code=$?
    output=$(printf '%s' "${output}" | _filter_env_noise)

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

# =============================================================================
# JavaScript/Node.js Support Functions
# =============================================================================

# Parse paths JSON array into space-separated string with proper quoting
# Args: $1 = JSON array string (e.g., '["path1", "path with spaces"]')
#       $2 = default value if array is empty
# Returns: Quoted paths string safe for shell expansion
# Usage: paths=$(parse_paths_json "$paths_json" ".")
parse_paths_json() {
    local paths_json="$1"
    local default="${2:-}"

    if [[ "${paths_json}" == "[]" || -z "${paths_json}" ]]; then
        echo "${default}"
        return
    fi

    local -a path_array=()
    while IFS= read -r p; do
        [[ -n "${p}" ]] && path_array+=("'${p}'")
    done < <(echo "${paths_json}" | jq -r '.[]' 2>/dev/null)

    if [[ ${#path_array[@]} -eq 0 ]]; then
        echo "${default}"
    else
        echo "${path_array[*]}"
    fi
}

# Returns: full working directory path.
# Scoped call (SCOPE_CWD set): LINT_WORKDIR/SCOPE_CWD[/SCOPE_JS_SUBDIR]
#   JS_CONTEXT is ignored in this path by design — plugin layouts place
#   their JS configs directly in the plugin root, not under the top-level
#   src/Administration or src/Storefront subtree.
# Unscoped call: LINT_WORKDIR[/src/<context>/Resources/app/<context>]
get_js_workdir() {
    local base_workdir="${LINT_WORKDIR}"

    if [[ -n "${SCOPE_CWD:-}" ]]; then
        local path="${base_workdir}/${SCOPE_CWD}"
        [[ -n "${SCOPE_JS_SUBDIR:-}" ]] && path="${path}/${SCOPE_JS_SUBDIR}"
        echo "${path}"
        return
    fi

    local context_path=""
    case "${JS_CONTEXT:-}" in
        "admin")
            context_path="src/Administration/Resources/app/administration"
            ;;
        "storefront")
            context_path="src/Storefront/Resources/app/storefront"
            ;;
        *)
            echo "${base_workdir}"
            return
            ;;
    esac

    echo "${base_workdir}/${context_path}"
}

# Wrap npm command for execution in detected environment
# Args: $1 = command
wrap_npm_command() {
    local cmd="$1"
    local workdir
    workdir=$(get_js_workdir)

    case "${LINT_ENV}" in
        native)
            echo "cd ${workdir} && ${cmd}"
            ;;
        docker)
            echo "docker exec -i ${DOCKER_CONTAINER} bash -c 'cd ${workdir} && ${cmd}'"
            ;;
        docker-compose)
            _compose_wrap_npm_command "${cmd}"
            ;;
        vagrant)
            echo "vagrant ssh -c 'cd ${workdir} && ${cmd}'"
            ;;
        ddev)
            # DDEV has native npm/yarn commands that handle workdir automatically
            if [[ "${cmd}" == npm* ]]; then
                local npm_args="${cmd#npm }"
                echo "cd ${workdir} && ddev npm ${npm_args}"
            elif [[ "${cmd}" == yarn* ]]; then
                local yarn_args="${cmd#yarn }"
                echo "cd ${workdir} && ddev yarn ${yarn_args}"
            else
                echo "cd ${workdir} && ddev exec ${cmd}"
            fi
            ;;
        *)
            log "ERROR" "Unknown environment: ${LINT_ENV}"
            echo "cd ${workdir} && ${cmd}"
            ;;
    esac
}

# Execute npm command in detected environment
# Args: $1 = command
exec_npm_command() {
    local cmd="$1"
    local wrapped_cmd

    wrapped_cmd=$(wrap_npm_command "${cmd}") || {
        echo "${wrapped_cmd}"
        return 1
    }

    log "INFO" "Executing JS command: ${wrapped_cmd}"

    local output
    local exit_code=0

    output=$(eval "${wrapped_cmd}" 2>&1) || exit_code=$?
    output=$(printf '%s' "${output}" | _filter_env_noise)

    log "INFO" "Command exit code: ${exit_code}"

    echo "${output}"
    return "${exit_code}"
}
