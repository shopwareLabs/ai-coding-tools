#!/usr/bin/env bash
# Docker Compose environment support for the MCP servers that consume this template
# Resolves container name and working directory from docker compose at call time.
# Requires: COMPOSE_SERVICE, COMPOSE_WORKDIR_OVERRIDE, COMPOSE_FILE_OVERRIDE, PROJECT_ROOT
# Must be sourced after mcpserver_core.sh (needs log) and environment.sh (needs
# shell_quote_arg). detect_environment sources this module, by which point both
# are already in scope.

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
        # Quoted at construction: every caller runs this string through eval, so
        # a compose file path — or a PROJECT_ROOT — containing a space would
        # otherwise split into two arguments and -f would receive only the first.
        cmd="${cmd} -f $(shell_quote_arg "${file_path}")"
    fi
    echo "${cmd}"
}

# Run one docker compose invocation from the launch root, and only from there.
#
# `docker compose` discovers its project from the working directory: the compose
# file it reads, the project name it derives and the sources its relative bind
# mounts resolve against all come from there. Every caller below builds a
# command string and eval's it, so which directory that runs in was until now
# whatever the caller happened to be in — and a worktree-targeted call runs its
# dispatch subshell inside the worktree. A worktree of a checkout whose compose
# file is tracked carries that file, with a relative `.:/var/www/html` bind and
# no `name:`, so the invocation would resolve the WORKTREE as the compose
# project: the service would read as absent and the call refused as
# not-running, or with a stable project name the container would be entered at
# the LAUNCH checkout's path while the banner names the worktree.
#
# Anchoring here rather than at each call site makes the project name, the file
# discovery and the bind sources launch-root facts whatever directory the call
# is running in, and leaves no site to forget. The cd is confined to a subshell
# so the caller's own working directory — the worktree it resolved — survives.
# Uses: PROJECT_ROOT
# Args: $1 = the docker compose invocation to run
# Stdout: the invocation's own output
# Returns: the invocation's own status, 1 when the launch root is not a directory
_compose_run() {
    local invocation="$1"

    if [[ -z "${PROJECT_ROOT:-}" || ! -d "${PROJECT_ROOT}" ]]; then
        printf '%s\n' "Refusing to run: the launch project root \"${PROJECT_ROOT:-}\" is not a directory, so \"docker compose\" cannot be run from it. Compose resolves its project from the working directory, so running it anywhere else would resolve a different one."
        return 1
    fi

    ( cd "${PROJECT_ROOT}" && eval "${invocation}" )
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
    ps_output=$(_compose_run "${base_cmd} ps --format json --status running" 2>&1) || {
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
    #
    # The captured output is appended rather than discarded: this branch used to
    # have one cause — `compose config` failing — so naming that cause was
    # accurate. The anchored run below added a second one, a launch root that is
    # no longer there, and a call refused by it would otherwise be told the
    # service is not running while the real reason never reaches the caller.
    local config_output
    config_output=$(_compose_run "${base_cmd} config --format json" 2>&1) || {
        echo "Service '${COMPOSE_SERVICE}' is not running. Start it with: docker compose up -d ${COMPOSE_SERVICE}${config_output:+ The compose config read said: ${config_output}}"
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

# The container path a host path is reached by: the destination of the longest
# bind-mount source that is the host path or an ancestor of it, followed by the
# remainder of the host path past that source. The longest match wins so a
# mount nested inside another decides its own subtree, and a path outside every
# mount is refused rather than answered with a shorter match's destination.
#
# Both sides are canonicalized before the prefix compare, because the compare
# is what decides the match and a spelling must not decide it. A compose file
# spells its bind-mount sources the way the shell that wrote it spelled them —
# on macOS often "/var/..." where the filesystem reaches "/private/var/..." —
# and the host path handed in carries whatever spelling its own caller used.
# Compared raw, one spelling of one directory reads as outside the other and a
# reachable root is refused. Canonicalizing both is idempotent for a value that
# was already resolved, which is what a worktree-targeted call passes.
#
# A source that cannot be canonicalized is skipped as a non-match rather than
# refused: another mount may still cover the host path, and refusing the whole
# call over one unusable entry would refuse a root that is reachable.
# Pure apart from that resolution: the mount list is an argument, so the match
# is covered directly.
# Args: $1 = host path, $2 = one "source<TAB>target" pair per line,
#       $3 = service name, for the refusal only
# Stdout: the container path, or the sentence naming the unmatched value
# Returns: 0 on a match, 1 when no bind mount covers the host path
_compose_match_mount() {
    local host_path="$1"
    local mounts="$2"
    local service="$3"

    local host_root
    host_root=$(_env_canonical_path "${host_path}") || {
        printf '%s\n' "Cannot map ${host_path} on service '${service}': its location could not be resolved, so whether a bind mount covers it cannot be established."
        return 1
    }

    while [[ "${host_root}" != "/" && "${host_root}" == */ ]]; do
        host_root="${host_root%/}"
    done

    local best_source=""
    local best_target=""
    local source target canonical_source
    while IFS=$'\t' read -r source target; do
        [[ -n "${source}" && -n "${target}" ]] || continue

        canonical_source=$(_env_canonical_path "${source}") || continue
        source="${canonical_source}"

        while [[ "${source}" != "/" && "${source}" == */ ]]; do
            source="${source%/}"
        done

        # The separator is appended once here rather than written into the
        # pattern: for a source of "/" the two would concatenate into "//*",
        # which matches nothing and would refuse every path a root mount covers.
        local prefix="${source}"
        if [[ "${prefix}" != "/" ]]; then
            prefix="${prefix}/"
        fi

        if [[ "${host_root}" != "${source}" && "${host_root}" != "${prefix}"* ]]; then
            continue
        fi

        if [[ -z "${best_source}" || "${#source}" -gt "${#best_source}" ]]; then
            best_source="${source}"
            best_target="${target}"
        fi
    done <<< "${mounts}"

    if [[ -z "${best_source}" ]]; then
        printf '%s\n' "No bind mount for ${host_path} found on service '${service}'. Set docker-compose.workdir in config."
        return 1
    fi

    local remainder="${host_root#"${best_source}"}"
    remainder="${remainder#/}"

    if [[ -z "${remainder}" ]]; then
        printf '%s\n' "${best_target}"
        return 0
    fi

    _env_join_workdir "${best_target}" "${remainder}"
}

# Resolve the working directory inside the container for one host path.
# COMPOSE_WORKDIR_OVERRIDE names PROJECT_ROOT's container path, so it takes the
# place of the match there and the host path's suffix below PROJECT_ROOT is
# appended to it. Without an override the longest matching bind mount decides.
# Uses: COMPOSE_WORKDIR_OVERRIDE, COMPOSE_SERVICE, COMPOSE_FILE_OVERRIDE
# Args: $1 = host path, $2 = the launch-side base (default PROJECT_ROOT)
# Returns: workdir path on stdout, or error message + return 1
_compose_resolve_workdir_for() {
    local host_root="$1"
    local launch_base="${2:-${PROJECT_ROOT:-}}"

    local suffix
    if ! suffix=$(_env_relative_suffix "${host_root}" "${launch_base}"); then
        printf '%s\n' "${suffix}"
        return 1
    fi

    if [[ -n "${COMPOSE_WORKDIR_OVERRIDE}" ]]; then
        _env_join_workdir "${COMPOSE_WORKDIR_OVERRIDE}" "${suffix}"
        return 0
    fi

    local base_cmd
    base_cmd=$(_compose_cmd)

    local config_output
    config_output=$(_compose_run "${base_cmd} config --format json" 2>&1) || {
        echo "Failed to read compose config: ${config_output}"
        return 1
    }

    local mounts
    mounts=$(echo "${config_output}" | jq -r --arg svc "${COMPOSE_SERVICE}" \
        '.services[$svc].volumes // [] | .[] | select(.type == "bind") | "\(.source)\t\(.target)"' \
        2>/dev/null) || mounts=""

    _compose_match_mount "${host_root}" "${mounts}" "${COMPOSE_SERVICE}"
}

# Resolve the working directory inside the container for the root this call
# targets.
#
# That is WORKTREE_EFFECTIVE_ROOT when something set it — the worktree module
# does, to the root the call resolved — and PROJECT_ROOT otherwise. Without
# this the resolver always answers for the launch tree, so a call targeting a
# worktree would cd into the launch tree's container path and run there while
# the result is attributed to the worktree. A launch-root call reads the same
# value it did before, because the two are equal there.
#
# The worktree module also sets the canonical pair it resolved, and those are
# preferred when present: its validation measured containment between exactly
# those two paths, so the mapping has to answer for the same pair rather than
# for the raw spelling one of them carries. Both fall back to the values a
# server that has no worktree module leaves in place.
# Uses: COMPOSE_WORKDIR_OVERRIDE, COMPOSE_SERVICE, COMPOSE_FILE_OVERRIDE,
#       PROJECT_ROOT, WORKTREE_EFFECTIVE_ROOT, WORKTREE_CANONICAL_ROOT,
#       WORKTREE_CANONICAL_LAUNCH
# Returns: workdir path on stdout, or error message + return 1
_compose_resolve_workdir() {
    _compose_resolve_workdir_for \
        "${WORKTREE_CANONICAL_ROOT:-${WORKTREE_EFFECTIVE_ROOT:-${PROJECT_ROOT}}}" \
        "${WORKTREE_CANONICAL_LAUNCH:-${PROJECT_ROOT:-}}"
}

# Wrap a PHP/generic command for execution in the docker-compose environment.
# Resolves container and workdir at call time, returns docker exec string.
# Honors SCOPE_CWD (relative to the resolved base workdir) when set.
# Args: $1 = command to execute
# Returns: wrapped command string on stdout, or error message + return 1
_compose_wrap_command() {
    local cmd="$1"

    _compose_check_prerequisites || return $?

    local container
    container=$(_compose_resolve_container) || { echo "${container}"; return 1; }

    local workdir
    workdir=$(_compose_resolve_workdir) || { echo "${workdir}"; return 1; }

    if [[ -n "${SCOPE_CWD:-}" ]]; then
        workdir="${workdir}/${SCOPE_CWD}"
    fi

    printf '%s\n' "docker exec -i $(shell_quote_arg "${container}") bash -c 'cd ${workdir} && ${cmd}'"
}

# Wrap an npm command for execution in the docker-compose environment.
# The JS working directory is composed by get_js_workdir, the one place the
# scope and context suffixes are built, so this wrapper and wrap_npm_command's
# docker branch cannot drift apart.
# Args: $1 = command to execute
# Uses: SCOPE_CWD, SCOPE_JS_SUBDIR, JS_CONTEXT (admin|storefront), LINT_WORKDIR
# Returns: wrapped command string on stdout, or error message + return 1
_compose_wrap_npm_command() {
    local cmd="$1"

    _compose_check_prerequisites || return $?

    local container
    container=$(_compose_resolve_container) || { echo "${container}"; return 1; }

    local base_workdir
    base_workdir=$(_compose_resolve_workdir) || { echo "${base_workdir}"; return 1; }

    # LINT_WORKDIR holds the call-time sentinel under docker-compose, so the
    # base resolved here is bound for the composition and given back: this
    # function runs in the caller's shell, and the next command built from
    # LINT_WORKDIR has to read the value that was in force before it.
    local workdir inherited_workdir="${LINT_WORKDIR:-}"
    LINT_WORKDIR="${base_workdir}"
    workdir=$(get_js_workdir)
    LINT_WORKDIR="${inherited_workdir}"

    printf '%s\n' "docker exec -i $(shell_quote_arg "${container}") bash -c 'cd ${workdir} && ${cmd}'"
}
