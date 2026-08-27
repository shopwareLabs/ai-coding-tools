#!/usr/bin/env bash
# Environment configuration and command wrapping for the MCP servers that consume this template
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
# Sets LINT_ENV to: native|docker|docker-compose|vagrant|ddev
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

# The base working directory the active environment runs commands in.
# LINT_WORKDIR carries that path directly for native, docker, vagrant and ddev.
# Under docker-compose it carries the literal sentinel "(resolved at call time)"
# because the container path is read from the compose config at call time, so a
# caller reading LINT_WORKDIR there builds a path out of the sentinel text.
# This function only dispatches: docker-compose.sh's _compose_resolve_workdir
# stays the single resolver, and that module is sourced only when the
# environment is docker-compose — which is why the accessor lives here, in the
# module every server sources, and not beside the resolver.
# SCOPE_CWD is NOT applied, matching what LINT_WORKDIR means elsewhere;
# wrap_command and get_js_workdir compose it onto this base themselves.
# Stdout: the working directory, or the resolver's message when it fails
# Returns: 0 on success, 1 when the docker-compose workdir cannot be resolved
get_workdir() {
    if [[ "${LINT_ENV}" != "docker-compose" ]]; then
        printf '%s\n' "${LINT_WORKDIR}"
        return 0
    fi

    if ! declare -f _compose_resolve_workdir &>/dev/null; then
        printf '%s\n' "get_workdir: docker-compose support is not loaded; detect_environment must run first."
        return 1
    fi

    local workdir
    workdir=$(_compose_resolve_workdir) || { printf '%s\n' "${workdir}"; return 1; }

    printf '%s\n' "${workdir}"
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
            printf '%s\n' "docker exec -i $(shell_quote_arg "${DOCKER_CONTAINER}") bash -c 'cd ${workdir} && ${cmd}'"
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
# or other shell constructs, so the wrapped string must survive exactly one
# local shell parse. Not every value in it is config-sourced — shopware-env's
# lifecycle tools take the container or service name from a tool argument — so
# the container and service names, which land at the local level, are quoted by
# shell_quote_arg at construction. How many parses a value inside the command
# then survives differs per wrap_command branch, and shell_quote_arg escapes for
# exactly one:
#   docker, docker-compose, vagrant: the workdir and command sit inside the
#     single-quoted remote string, so the local eval passes them through
#     literally and the remote shell is the parse the double quotes are written
#     for. Only a single quote would terminate that string locally, which is
#     what assert_no_shell_hostile_chars refuses for tool-supplied values.
#   native: no remote shell — the local eval is the only parse.
#   ddev: no quoting wrapper at all. `ddev [exec …] <cmd>` is emitted as bare
#     argv, so the local eval already consumes shell_quote_arg's escaping.
#     `ddev composer` re-execs that argv directly and is safe, but `ddev exec`
#     rejoins its argv and runs it through `bash -c` inside the container unless
#     `--raw` is passed explicitly, which wrap_command does not do — so a value
#     on that path is parsed twice while shell_quote_arg escapes for one.
#     Quoting cannot close it: ddev re-quotes only the arguments containing a
#     space, a double quote or "#", so the layer count varies per value and no
#     fixed escaping depth is right for all of them. assert_no_shell_hostile_chars
#     therefore refuses the metacharacters of the second parse whenever LINT_ENV
#     is ddev, which is what keeps this branch safe; wrap_npm_command's ddev
#     branch has the same shape and the same guard covers it.
# A workdir taken from the config file is trusted at the same level as the
# config itself.
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

    # The child must not inherit the server's stdin: it is the client's
    # JSON-RPC protocol pipe, and a stdin-reading tool child would block on
    # it forever instead of seeing EOF.
    output=$(eval "${wrapped_cmd}" </dev/null 2>&1) || exit_code=$?
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

# Quote one value so that a single shell parse yields the original literal.
# Single quotes are not usable here: the docker, docker-compose and vagrant
# wrappers embed the whole command inside a single-quoted string, so a single
# quote in generated output terminates that string. Double quotes survive every
# wrapper; backslash, double quote, dollar and backtick are escaped so the one
# parse cannot substitute or execute anything.
# Args: $1 = value
# Stdout: the quoted value
shell_quote_arg() {
    local value="${1:-}"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$/\\\$}"
    value="${value//\`/\\\`}"

    printf '%s\n' "\"${value}\""
}

# Reject values that cannot be embedded in a wrapped command at all.
# A single quote would terminate the single-quoted string the docker,
# docker-compose and vagrant wrappers embed the command in, and a line break
# would break the compound-command shape the path probes build. Both are
# legitimate to refuse in a file path or a pattern.
#
# Under ddev a third class has to go: every character the container's shell
# would act on. wrap_command's ddev branch emits bare argv, so the local eval
# consumes shell_quote_arg's escaping and `ddev exec` then runs the rejoined
# argv through `bash -c` in the container — two parses for an escaping written
# for one. No fixed escaping depth closes that, because ddev re-quotes only the
# arguments containing a space, a double quote or "#", so the number of layers
# an argument picks up depends on its own content: escaping twice delivers every
# value with literal quotes baked into it, and escaping three times is a syntax
# error. Refusing is the only shape that keeps the value intact.
# Globs stay allowed — the container shell expands them, which changes which
# files a tool sees but cannot execute anything the caller wrote.
# Globals: LINT_ENV, read to decide whether the ddev class applies.
# Args: $1 = label naming what the values are, $2.. = values
# Stdout: a message naming the offending value
# Returns: 0 when every value is embeddable, 1 otherwise
assert_no_shell_hostile_chars() {
    if [[ $# -lt 2 ]]; then
        printf '%s\n' "assert_no_shell_hostile_chars: a label and at least one value are required"
        return 1
    fi

    local label="$1"
    shift

    # Substitution, quoting, command separation and grouping. A space is absent
    # because ddev double-quotes any argument containing one, and with the four
    # characters that stay live inside double quotes refused above it, that
    # quoting holds. Glob characters are absent deliberately.
    local ddev_metachars='$`\";&|<>(){}'

    local value
    for value in "$@"; do
        case "${value}" in
            *"'"*)
                printf '%s\n' "Refusing to run: ${label} \"${value}\" contains a single quote, which cannot be quoted safely for the command wrappers."
                return 1
                ;;
            *$'\n'*|*$'\r'*)
                printf '%s\n' "Refusing to run: ${label} \"${value}\" contains a line break, which cannot be embedded in a single command."
                return 1
                ;;
        esac

        if [[ "${LINT_ENV:-}" == "ddev" && "${value}" == *["${ddev_metachars}"]* ]]; then
            printf '%s\n' "Refusing to run: ${label} \"${value}\" contains a shell metacharacter, which the ddev environment parses a second time inside the container. Remove it, or use the docker, docker-compose, vagrant or native environment."
            return 1
        fi
    done

    return 0
}

# Parse paths JSON array into a space-separated string of quoted paths.
# Distinguishes "paths" absent (or an empty array) from "paths" malformed: the
# schema does not enforce that "paths" is an array of non-empty strings, so a
# caller that sends a bare string, or an array holding an empty string or a
# non-string entry, would otherwise fall through to the empty-array default
# and run the tool's own baked target set instead of the narrow scope asked
# for — a wide run reported back as if it had honored the request.
# Args: $1 = JSON array string (e.g., '["path1", "path with spaces"]')
#       $2 = default value if array is empty
# Stdout: the quoted paths, the default when the array is empty/absent, or the
#         message naming why "paths" was refused
# Returns: 0 on success, 1 when "paths" is malformed or a path cannot be
#          embedded in a command
# Usage: paths=$(parse_paths_json "$paths_json" ".") || { printf '%s\n' "$paths"; return 1; }
parse_paths_json() {
    local paths_json="$1"
    local default="${2:-}"

    if [[ -z "${paths_json}" || "${paths_json}" == "[]" ]]; then
        printf '%s\n' "${default}"
        return 0
    fi

    if ! echo "${paths_json}" | jq -e 'type == "array"' >/dev/null 2>&1; then
        printf '%s\n' "Refusing to run: \"paths\" must be an array of strings, received: ${paths_json}"
        return 1
    fi

    if echo "${paths_json}" | jq -e 'any(.[]; type != "string" or . == "")' >/dev/null 2>&1; then
        printf '%s\n' "Refusing to run: \"paths\" must be an array of non-empty strings, received: ${paths_json}"
        return 1
    fi

    # A line break inside one element has to be refused here, before the decoded
    # array is read back line by line: after that split it is indistinguishable
    # from the separator between two elements, so one path arrives as two and
    # the per-value guard below inspects two line-break-free fragments and
    # passes both. A fabricated second element such as "." widens a narrow
    # request to the whole tree on the tools that write. assert_no_shell_hostile_chars
    # refuses a line break in a path anyway, so nothing embeddable is lost.
    if echo "${paths_json}" | jq -e 'any(.[]; (index("\n") != null) or (index("\r") != null))' >/dev/null 2>&1; then
        printf '%s\n' "Refusing to run: \"paths\" must not contain a line break, received: ${paths_json}"
        return 1
    fi

    local raw_output
    if ! raw_output=$(echo "${paths_json}" | jq -r '.[]' 2>&1); then
        printf '%s\n' "Refusing to run: could not read \"paths\": ${raw_output}"
        return 1
    fi

    local -a raw_paths=()
    local p
    while IFS= read -r p; do
        raw_paths+=("${p}")
    done <<< "${raw_output}"

    local guard
    if ! guard=$(assert_no_shell_hostile_chars "path" "${raw_paths[@]}"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    local -a path_array=()
    for p in "${raw_paths[@]}"; do
        path_array+=("$(shell_quote_arg "${p}")")
    done

    printf '%s\n' "${path_array[*]}"
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
            printf '%s\n' "docker exec -i $(shell_quote_arg "${DOCKER_CONTAINER}") bash -c 'cd ${workdir} && ${cmd}'"
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

    # The child must not inherit the server's stdin: it is the client's
    # JSON-RPC protocol pipe, and a stdin-reading tool child would block on
    # it forever instead of seeing EOF.
    output=$(eval "${wrapped_cmd}" </dev/null 2>&1) || exit_code=$?
    output=$(printf '%s' "${output}" | _filter_env_noise)

    log "INFO" "Command exit code: ${exit_code}"

    echo "${output}"
    return "${exit_code}"
}

# Read one npm script body from the active JS working directory.
# `npm pkg get` prints `{}` for an undefined key and still exits 0, so its exit
# code is not a usable signal — the output is.
# Args: $1 = npm script name
# Stdout: the script body, and nothing else
# Returns: 0 = body printed, 1 = script not defined, 2 = probe unusable — the
#          name is missing, the name cannot be embedded, or the probe failed
npm_script_body() {
    local script_name="${1:-}"

    if [[ -z "${script_name}" ]]; then
        log "ERROR" "npm_script_body: script name is required"
        return 2
    fi

    local guard
    if ! guard=$(assert_no_shell_hostile_chars "npm script name" "${script_name}"); then
        log "ERROR" "npm_script_body: ${guard}"
        return 2
    fi

    local raw
    local exit_code=0
    raw=$(exec_npm_command "npm pkg get $(shell_quote_arg "scripts.${script_name}")") || exit_code=$?

    if [[ "${exit_code}" -ne 0 ]]; then
        log "ERROR" "npm_script_body: probe for \"${script_name}\" failed: ${raw}"
        return 2
    fi

    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"

    if [[ "${raw}" == "{}" ]]; then
        return 1
    fi

    if [[ "${raw}" != '"'*'"' ]]; then
        log "ERROR" "npm_script_body: unexpected npm pkg get output for \"${script_name}\": ${raw}"
        return 2
    fi

    raw="${raw#\"}"
    raw="${raw%\"}"
    printf '%s\n' "${raw}"
}

# True when the command segment invokes a package-manager run-script.
# Args: $1 = trimmed command segment
_npm_script_is_run_invocation() {
    local segment="$1"

    case "${segment}" in
        "npm run "*|"yarn run "*|"pnpm run "*) return 0 ;;
        "yarn -"*) return 1 ;;
        "yarn "*) return 0 ;;
    esac

    return 1
}

# True when the command segment carries a standalone `--` token, which forwards
# appended arguments past the run-script's own CLI parser.
# Args: $1 = trimmed command segment
_npm_script_has_double_dash() {
    local padded=" $1 "
    [[ "${padded}" == *" -- "* ]]
}

# Decide whether `npm run <script> -- <args>` places the arguments correctly.
# npm appends them to the end of the whole script string, so a body that closes
# a subshell or group, or that chains further commands, receives them in the
# wrong place. An `&&` chain is safe only when its final command is the tool
# itself: a final segment that is another run-script invocation without a
# standalone `--` hands the appended arguments to npm's own CLI parser, which
# rejects the flag names and leaks their values through as bare positional
# arguments to the inner script — a silently wrong run.
#
# KNOWN GAP, deliberately not closed here: a final segment that is neither the
# tool nor a run-script is accepted. `eslint . && echo done` puts the appended
# flags and paths on `echo`, which ignores them and exits 0, while ESLint runs
# over its own unscoped targets. Nothing in a body's shape separates that from
# a legitimate `export VITE_MODE=production && ts-node -T build.ts`, which is
# the Administration's real `build` script, or from `npm run lint -- --fix`,
# its real `lint:fix`. Requiring the caller to name the expected binary was
# measured against those two and refuses both, so the gate would trade a silent
# wrong run for a loud refusal of scripts that work. Closing it needs a signal
# this function does not have.
# Args: $1 = script body
# Returns: 0 when appending is safe, 1 otherwise
npm_script_append_safe() {
    local body="${1:-}"

    body="${body%"${body##*[![:space:]]}"}"

    if [[ -z "${body}" ]]; then
        return 1
    fi

    local last="${body: -1}"
    if [[ "${last}" == ")" || "${last}" == "}" ]]; then
        return 1
    fi

    if [[ "${body}" == *";"* || "${body}" == *"|"* ]]; then
        return 1
    fi

    local final_segment="${body##*&&}"
    final_segment="${final_segment#"${final_segment%%[![:space:]]*}"}"
    final_segment="${final_segment%"${final_segment##*[![:space:]]}"}"

    if _npm_script_is_run_invocation "${final_segment}" && ! _npm_script_has_double_dash "${final_segment}"; then
        return 1
    fi

    return 0
}

# Resolve one npm script and decide whether arguments may be appended to it.
# Args: $1 = npm script name
# Stdout: the script body (rc 0), or a failure message (rc 1 and rc 2)
# Returns: 0 = safe to append, 1 = script not defined, 2 = defined but unsafe
npm_script_append_gate() {
    local script_name="${1:-}"

    local body
    local exit_code=0
    body=$(npm_script_body "${script_name}") || exit_code=$?

    if [[ "${exit_code}" -eq 1 ]]; then
        printf '%s\n' "npm script \"${script_name}\" is not defined in package.json."
        return 1
    fi

    if [[ "${exit_code}" -ne 0 ]]; then
        printf '%s\n' "Could not read npm script \"${script_name}\" from package.json; see the server log for the failed probe."
        return 2
    fi

    if ! npm_script_append_safe "${body}"; then
        printf '%s\n' "npm script \"${script_name}\" cannot take appended arguments: \"${body}\". npm appends \`--\` arguments to the end of the whole script body, so they would land outside the tool invocation. Path-scoped runs are unavailable until that script is split into a single appendable command."
        return 2
    fi

    printf '%s\n' "${body}"
    return 0
}

# Build the probe command both path assertions run.
# The probe is a plain compound command, so it is parsed exactly once wherever
# it lands: by the host shell on native, and by the container or guest shell
# under the wrappers that embed it in a single-quoted string. Nesting `sh -c`
# inside would make the number of parses differ per environment, and no fixed
# escaping depth is correct for all of them — a caller value would then reach a
# second parse and execute.
# ddev is the exception and is not covered by that sentence. Its branch emits
# bare argv with no quoting wrapper, so the local shell splits this compound at
# its first `&&`: only the leading `cd` reaches the container and the file tests
# run on the host. Values are still parsed once each, because
# assert_no_shell_hostile_chars refuses the second parse's metacharacters under
# ddev — but the answer describes the host tree. It usually agrees because ddev
# bind-mounts the project, which is why it goes unnoticed.
# Args: $1 = base directory
#       $2 = space-separated extensions without dots ("" = existence only)
#       $3.. = paths, relative to the base directory
# Stdout: the probe command
_paths_probe_command() {
    local base_dir="$1"
    local extensions="$2"
    shift 2

    local -a ext_list=()
    read -r -a ext_list <<< "${extensions}" || true

    local case_patterns=""
    local find_expr=""
    local ext
    for ext in "${ext_list[@]+"${ext_list[@]}"}"; do
        if [[ -n "${case_patterns}" ]]; then
            case_patterns="${case_patterns}|"
            find_expr="${find_expr} -o"
        fi
        case_patterns="${case_patterns}*.${ext}"
        find_expr="${find_expr} -type f -name $(shell_quote_arg "*.${ext}")"
    done

    local probe
    probe="cd $(shell_quote_arg "${base_dir}") && {"

    local p quoted
    for p in "$@"; do
        quoted=$(shell_quote_arg "${p}")
        if [[ ${#ext_list[@]} -eq 0 ]]; then
            probe="${probe} [ -e ${quoted} ] || printf \"MISSING:%s\\n\" ${quoted};"
            continue
        fi
        probe="${probe} if [ -f ${quoted} ]; then case ${quoted} in ${case_patterns}) ;; *) printf \"UNMATCHED:%s\\n\" ${quoted};; esac;"
        probe="${probe} elif [ -d ${quoted} ]; then [ -n \"\$(find -L ${quoted}${find_expr} 2>/dev/null | head -n 1)\" ] || printf \"UNMATCHED:%s\\n\" ${quoted};"
        probe="${probe} else printf \"MISSING:%s\\n\" ${quoted}; fi;"
    done

    probe="${probe} }"

    printf '%s\n' "${probe}"
}

# Run one path probe from <base_dir> inside the same environment the JS tools
# run in, and report every path it rejected.
# Args: $1 = base directory, $2 = extensions ("" = existence only), $3.. = paths
# Stdout: a message naming every rejected path
# Returns: 0 when every path passed, 1 otherwise
_assert_paths() {
    local base_dir="$1"
    local extensions="$2"
    shift 2

    if [[ -z "${base_dir}" ]]; then
        printf '%s\n' "assert_paths: base directory is required"
        return 1
    fi

    local guard
    if ! guard=$(assert_no_shell_hostile_chars "base directory" "${base_dir}"); then
        printf '%s\n' "${guard}"
        return 1
    fi
    if ! guard=$(assert_no_shell_hostile_chars "path" "$@"); then
        printf '%s\n' "${guard}"
        return 1
    fi

    local probe
    probe=$(_paths_probe_command "${base_dir}" "${extensions}" "$@")

    local output
    local exit_code=0
    output=$(exec_npm_command "${probe}") || exit_code=$?

    if [[ "${exit_code}" -ne 0 ]]; then
        printf '%s\n' "Could not verify paths under \"${base_dir}\": ${output}"
        return 1
    fi

    local -a missing=()
    local -a unmatched=()
    local line
    while IFS= read -r line; do
        case "${line}" in
            MISSING:*) missing+=("${line#MISSING:}") ;;
            UNMATCHED:*) unmatched+=("${line#UNMATCHED:}") ;;
        esac
    done <<< "${output}"

    local failed=0

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf '%s\n' "Refusing to run: these paths do not exist under \"${base_dir}\": ${missing[*]}"
        failed=1
    fi

    if [[ ${#unmatched[@]} -gt 0 ]]; then
        printf '%s\n' "Refusing to run: these paths hold no file the tool reads under \"${base_dir}\": ${unmatched[*]}. Accepted extensions: ${extensions}."
        failed=1
    fi

    return "${failed}"
}

# Assert that every given path exists, from <base_dir> inside the same
# environment the JS tools run in. Storefront lint scripts carry
# --no-error-on-unmatched-pattern, so an unresolvable path lints nothing and
# still exits 0; this turns that into a hard failure.
# Args: $1 = base directory (relative to the JS working directory, or absolute)
#       $2.. = paths to check, relative to the base directory
# Stdout: a message naming every missing path when any is missing
# Returns: 0 when all exist, 1 otherwise
assert_paths_exist() {
    if [[ $# -lt 2 ]]; then
        printf '%s\n' "assert_paths_exist: a base directory and at least one path are required"
        return 1
    fi

    local base_dir="$1"
    shift

    _assert_paths "${base_dir}" "" "$@"
}

# Assert that every given path exists AND can match a file the tool reads:
# a regular file must carry one of the accepted extensions, and a directory
# must hold at least one file with one of them at any depth. Existence alone
# does not prove that — a directory of .scss files handed to ESLint lints
# nothing and still exits 0, which reports success for a run that covered
# nothing.
# Known residual: a lone non-snippet .json file passes the ESLint extension set,
# because the Storefront ESLint config genuinely lints snippet JSON and
# rejecting .json outright would refuse a legitimate target.
# Args: $1 = base directory (relative to the JS working directory, or absolute)
#       $2 = space-separated extensions without dots, e.g. "js ts vue"
#       $3.. = paths to check, relative to the base directory
# Stdout: a message naming every rejected path
# Returns: 0 when every path can match, 1 otherwise
assert_paths_lintable() {
    if [[ $# -lt 3 ]]; then
        printf '%s\n' "assert_paths_lintable: a base directory, an extension list and at least one path are required"
        return 1
    fi

    local base_dir="$1"
    local extensions="$2"
    shift 2

    if [[ -z "${extensions}" ]]; then
        printf '%s\n' "assert_paths_lintable: the extension list is required"
        return 1
    fi

    _assert_paths "${base_dir}" "${extensions}" "$@"
}
