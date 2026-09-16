#!/usr/bin/env bash
# Per-call project root resolution for the dev-tooling MCP servers.
# A tool call may target a linked git worktree of the root the server was
# launched in. This module decides which root a call runs against, validates it,
# and rebinds the working directory for that call only.
#
# Owned by dev-tooling. Not templated — do not add it to the mapping in
# .claude/rules/template-sync.md.
#
# Comment rule for this file: a fact about a shared function's contract lives
# once, in that function's header, never at a call site. Keep a comment only if
# deleting it would let an obvious "simplification" break measured behavior. A
# comment explaining why the code is fast, or what it used to be, is cut.
#
# Requires: PROJECT_ROOT, LINT_CONFIG_FILE, DEV_TOOLING_STATE_FILE exported by
#           server.sh; log(), load_config(), _discover_configs(),
#           _get_config_value(), get_workdir(), get_js_workdir() and
#           scope_validate() from the shared modules; JS_CONTEXT set by the JS servers only.
#
# Public:
#   worktree_state_init           - create the state file; once, from server.sh
#   worktree_state_cleanup        - remove it; from server.sh's EXIT trap
#   worktree_enter <args>         - resolve the effective root and banner it
#   worktree_resolve_root <args>  - the resolution half of worktree_enter
#   worktree_root_banner          - the banner half of worktree_enter
#   worktree_assert_dependencies [php|js]
#                                 - check the dependencies a tool needs are
#                                   installed; the kind defaults to the server's
#                                   own
#   worktree_assert_paths_within_root <paths JSON>
#                                 - refuse an absolute "paths" entry outside it
#   worktree_release_owned_temp   - remove the merged-config temp file this call created
#   tool_set_project_root <args>  - MCP tool: set or clear the sticky root
#   tool_cwd <args>               - MCP tool: report the resolution state

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true  # Bash 4.4+

# The launch root is the effective root until a call resolves otherwise.
WORKTREE_EFFECTIVE_ROOT="${PROJECT_ROOT:-}"
WORKTREE_ROOT_SOURCE="launch"

# Path to the merged-config temp file this call created, or empty; see
# worktree_release_owned_temp for why only a path recorded here may be removed.
WORKTREE_OWNED_TEMP_FILE=""

# The effective root and the launch root as the filesystem reaches them, set
# together by _worktree_validate_root's containment test and read by the path
# mapping through resolve_env_workdir. Containment compares canonical paths, so
# the mapping has to measure the same pair; empty means no canonical pair has
# been established for the current call, and every reader then falls back to the
# raw spelling. Both are empty for a native call, where containment is not
# measured and the mapping is the identity.
WORKTREE_CANONICAL_ROOT=""
WORKTREE_CANONICAL_LAUNCH=""

# The environment _worktree_validate_root established for the current call,
# read by the mapping instead of re-running the configuration read, and the
# failure message _worktree_map_call_environment leaves for its caller to
# route — printed by the binding, folded into the report by tool_cwd.
WORKTREE_VALIDATED_ENVIRONMENT=""
WORKTREE_MAP_MESSAGE=""

# The derivation's own temp file, and the refusal it holds. Both belong to the
# call that ran the derivation; see _worktree_run_derivation.
WORKTREE_DERIVATION_LOG=""
WORKTREE_DERIVATION_MESSAGE=""

WORKTREE_SELECTED_CONFIG_FILE="${LINT_CONFIG_FILE:-}"

# The configuration the server started with. It stays in force for a call that
# targets the launch root, and for a worktree carrying no configuration of its
# own; a selected file differing from this one is what makes a call re-derive
# the environment from the file that applies to it.
WORKTREE_LAUNCH_CONFIG_FILE="${LINT_CONFIG_FILE:-}"

# The environment-side path WORKTREE_EFFECTIVE_ROOT is reached by, empty when
# the two coincide — which is every native call. Diagnostic only: nothing
# branches on it, and it exists so a message naming a root can also name the
# path the command actually runs against when the two differ.
WORKTREE_ENV_WORKDIR=""

# The launch root's common git directory; empty means it isn't a git repository, which every worktree-targeted call then refuses.
WORKTREE_LAUNCH_COMMON=""

# Why the last _worktree_validate_root call refused. A global rather than
# stdout: reading it via command substitution would subshell away the selected config and owned temp path that call also sets.
WORKTREE_VALIDATION_MESSAGE=""

# =============================================================================
# State file
# =============================================================================

# worktree_state_init
# Creates the server's state file and exports its path. A tool runs in a
# dispatch subshell, so a value it assigns to a shell variable never reaches a
# later call; this file is how a tool reaches state that outlives its own.
# Globals: sets and exports DEV_TOOLING_STATE_FILE
# Outputs: a message on stderr when the file cannot be created
# Returns: 0 on success, 1 otherwise
worktree_state_init() {
    local path rc=0
    path=$(mktemp "${TMPDIR:-/tmp}/dev-tooling-state.XXXXXX") || rc=$?
    if [[ "${rc}" -ne 0 || -z "${path}" ]]; then
        printf '%s\n' "Could not create the dev-tooling state file under ${TMPDIR:-/tmp}." >&2
        return 1
    fi

    # mktemp leaves the file empty; every reader below expects a JSON object.
    if ! printf '%s\n' '{}' > "${path}"; then
        rm -f -- "${path}"
        printf '%s\n' "Could not initialize the dev-tooling state file ${path}." >&2
        return 1
    fi

    DEV_TOOLING_STATE_FILE="${path}"
    export DEV_TOOLING_STATE_FILE

    # A launch root that is not a git repository leaves this empty rather than
    # failing the server: only a worktree-targeted call needs the value.
    WORKTREE_LAUNCH_COMMON=""
    local launch_pair
    if launch_pair=$(_worktree_git_dir_pair "${PROJECT_ROOT}"); then
        { IFS= read -r _; IFS= read -r WORKTREE_LAUNCH_COMMON; } <<< "${launch_pair}"
    fi

    return 0
}

# worktree_state_cleanup
# Removes the state file. Called from server.sh's EXIT trap.
# Globals: reads DEV_TOOLING_STATE_FILE
# Returns: 0 always, so it cannot displace the trap's other work
worktree_state_cleanup() {
    if [[ -n "${DEV_TOOLING_STATE_FILE:-}" ]]; then
        rm -f -- "${DEV_TOOLING_STATE_FILE}"
    fi
    return 0
}

# _worktree_state_read_sticky
# Globals: reads DEV_TOOLING_STATE_FILE
# Stdout: the sticky project root, empty when none is set, or the message
#         naming why it could not be read
# Returns: 0 on success, 1 when the state file is absent or unusable
_worktree_state_read_sticky() {
    if [[ -z "${DEV_TOOLING_STATE_FILE:-}" ]]; then
        printf '%s\n' "DEV_TOOLING_STATE_FILE is not set, so the sticky project root cannot be read."
        return 1
    fi

    if [[ ! -f "${DEV_TOOLING_STATE_FILE}" ]]; then
        printf '%s\n' "The state file ${DEV_TOOLING_STATE_FILE} does not exist, so the sticky project root cannot be read."
        return 1
    fi

    local value rc=0
    value=$(jq -r '.sticky_root // empty' "${DEV_TOOLING_STATE_FILE}" 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "The state file ${DEV_TOOLING_STATE_FILE} does not hold a JSON object, so the sticky project root cannot be read."
        return 1
    fi

    printf '%s\n' "${value}"
    return 0
}

# _worktree_state_update <jq filter> [--arg name value ...]
# Applies a filter to the state file's current object and renames the result
# onto the path atomically, so a call killed mid-write cannot leave a partial
# file.
#
# The current content is the filter's input, which is what keeps a key this
# writer does not own: the file has more than one writer — the sticky root and
# the probe cache — and a write that rebuilt the object from nothing would drop
# the other's key silently.
#
# A file that is absent, or that holds something other than a JSON object, is
# read as an empty object rather than refused. There is nothing to preserve in
# either: a file that is not an object has no keys a filter could carry
# forward. Refusing would instead let a damaged state file lock out the reset
# path — clearing sticky_root is the recovery a session reaches for, and it
# must not be the one write that cannot run. An empty file is in this class
# too: jq emits nothing for it at exit 0, which would otherwise rename an empty
# file over the state.
# Globals: reads DEV_TOOLING_STATE_FILE
# Stdout: nothing on success, the message naming the failure otherwise
# Returns: 0 on success, 1 otherwise
_worktree_state_update() {
    local filter="${1:-}"
    shift

    if [[ -z "${DEV_TOOLING_STATE_FILE:-}" ]]; then
        printf '%s\n' "DEV_TOOLING_STATE_FILE is not set, so the state file cannot be written."
        return 1
    fi

    local current="{}"
    if [[ -f "${DEV_TOOLING_STATE_FILE}" ]]; then
        local read_rc=0
        current=$(jq -c 'if type == "object" then . else empty end' "${DEV_TOOLING_STATE_FILE}" 2>/dev/null) || read_rc=$?
        if [[ "${read_rc}" -ne 0 || -z "${current}" ]]; then
            current="{}"
        fi
    fi

    local tmp rc=0
    tmp=$(mktemp "${DEV_TOOLING_STATE_FILE}.XXXXXX") || rc=$?
    if [[ "${rc}" -ne 0 || -z "${tmp}" ]]; then
        printf '%s\n' "Could not create a temporary file next to ${DEV_TOOLING_STATE_FILE}."
        return 1
    fi

    rc=0
    printf '%s' "${current}" | jq "$@" "${filter}" > "${tmp}" 2>/dev/null || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        rm -f -- "${tmp}"
        printf '%s\n' "Could not write the new content of the state file ${DEV_TOOLING_STATE_FILE}."
        return 1
    fi

    # Same directory, therefore the same filesystem, therefore an atomic rename.
    if ! mv -f -- "${tmp}" "${DEV_TOOLING_STATE_FILE}"; then
        rm -f -- "${tmp}"
        printf '%s\n' "Could not replace the state file ${DEV_TOOLING_STATE_FILE}."
        return 1
    fi

    return 0
}

# _worktree_state_write_sticky [project root]
# An empty argument removes sticky_root and leaves every other key alone.
# Globals: reads DEV_TOOLING_STATE_FILE
# Stdout: nothing on success, the message naming the failure otherwise
# Returns: 0 on success, 1 otherwise
_worktree_state_write_sticky() {
    local value="${1:-}"

    if [[ -z "${value}" ]]; then
        _worktree_state_update 'del(.sticky_root)'
        return $?
    fi

    # shellcheck disable=SC2016  # the jq filter is single-quoted so jq, not the shell, reads $root
    _worktree_state_update '.sticky_root = $root' --arg root "${value}"
}

# _worktree_state_write_probe <environment> <effective root> <mapped path>
# Records that the root was reached at this environment AND mapping, so a later
# call for the same triple reads the entry instead of running the probe again.
# The mapped path is part of the key because it derives from the worktree's own
# configuration, which is re-read every call: an edited workdir changes what
# the probe would measure while (environment, root) stays identical, and a
# cache keyed on the pair alone answered for a path nothing ever probed.
# Globals: reads DEV_TOOLING_STATE_FILE
# Stdout: nothing on success, the message naming the failure otherwise
# Returns: 0 on success, 1 otherwise
_worktree_state_write_probe() {
    local environment="$1"
    local root="$2"
    local mapped="$3"

    # shellcheck disable=SC2016  # the jq filter is single-quoted so jq, not the shell, reads $env, $root and $mapped
    _worktree_state_update '.probe_cache[$env][$root][$mapped] = true' \
        --arg env "${environment}" --arg root "${root}" --arg mapped "${mapped}"
}

# _worktree_state_read_probe <environment> <effective root> <mapped path>
# Stdout: "true" when a passing probe for this triple is recorded, empty when
#         it is not
# Returns: 0 always — an absent or unreadable entry reads as "not probed",
#          which sends the caller to the probe rather than past it. Reading a
#          broken state file as a hit would be the failure that matters; this
#          direction can only probe one time too many.
_worktree_state_read_probe() {
    local environment="$1"
    local root="$2"
    local mapped="$3"

    local value=""
    if [[ -n "${DEV_TOOLING_STATE_FILE:-}" && -f "${DEV_TOOLING_STATE_FILE}" ]]; then
        value=$(jq -r --arg env "${environment}" --arg root "${root}" --arg mapped "${mapped}" \
            '.probe_cache[$env][$root][$mapped] // empty' "${DEV_TOOLING_STATE_FILE}" 2>/dev/null) || value=""
    fi

    printf '%s\n' "${value}"
}

# =============================================================================
# Pure units
#
# Arguments in, stdout and exit status out. Each is covered by a table in
# worktree_resolution.bats and reached in production through the thin wrapper
# named under it, so the verdict a suite asserts is the verdict the call gets.
# =============================================================================

# _worktree_classify_gitdir <gitdir line>
# Classifies the pointer a linked worktree's ".git" file carries.
#
# "invalid" is a class rather than an error because a suite has to be able to
# assert it: the resolution path reaches the classifier only for a ".git" file
# git itself already parsed, so this is the verdict a hand-written or
# truncated pointer gets, and the caller refuses it like the other non-relative
# verdict rather than falling through.
# Pure: the line is the only input.
# Args: $1 = the contents of the worktree's ".git" file
# Stdout: "absolute", "relative", or "invalid"
# Returns: 0 always
_worktree_classify_gitdir() {
    local line="${1:-}"

    case "${line}" in
        "gitdir: "*) ;;
        *)
            printf '%s\n' "invalid"
            return 0
            ;;
    esac

    local target="${line#gitdir: }"
    target="${target%$'\n'}"
    target="${target%$'\r'}"

    # A pointer carrying a control character cannot be one path, and every
    # message naming it would be split by the same character.
    if [[ -z "${target}" || "${target}" == *[[:cntrl:]]* ]]; then
        printf '%s\n' "invalid"
        return 0
    fi

    if [[ "${target}" == /* ]]; then
        printf '%s\n' "absolute"
        return 0
    fi

    printf '%s\n' "relative"
}

# _worktree_gitdir_linkage <root>
# Reads the ".git" file and hands its line to the classifier. The file read is
# the one effect the classifier cannot carry and still be a pure unit.
# Args: $1 = worktree root
# Stdout: "absolute", "relative", or "invalid"
# Returns: 0 always
_worktree_gitdir_linkage() {
    local root="$1"

    local line=""
    line=$(< "${root}/.git") || line=""

    _worktree_classify_gitdir "${line}"
}

# _worktree_classify_root_charset <root> <environment>
# The class of character that keeps a root out of a container command, for the
# four environments whose wrapper embeds a working directory inside a
# single-quoted `bash -c` string. Nothing is quoted at that position, so a space
# ends the directory name — `cd /a b` changes to /a and then runs a command
# named b — and every character the container's shell acts on becomes syntax.
#
# The set is READ from the shared environment module rather than restated here,
# so this and the guard the wrappers themselves apply cannot answer differently
# about the same value. It is the wider of the two: the guard applies it to a
# worktree root under ddev only, because that is where a value is parsed twice,
# while this applies it under all four.
#
# Native is deliberately outside the case: its wrapper emits no `cd` and no
# directory at all, so a space or a metacharacter in the root reaches no shell.
# Pure: both values are arguments.
# Args: $1 = candidate root, $2 = the environment the call runs under
# Stdout: "ok", "whitespace", or "metachar"
# Returns: 0 always
_worktree_classify_root_charset() {
    local root="$1"
    local environment="$2"

    if ! _env_is_container_environment "${environment}"; then
        printf '%s\n' "ok"
        return 0
    fi

    if [[ "${root}" == *[[:space:]]* ]]; then
        printf '%s\n' "whitespace"
        return 0
    fi

    if [[ "${root}" == *["${SHELL_HOSTILE_METACHARS}"]* ]]; then
        printf '%s\n' "metachar"
        return 0
    fi

    printf '%s\n' "ok"
}

# _worktree_assert_charset <root> <environment>
# Refuses a root the command wrappers cannot carry.
#
# Two questions, and the order is deliberate.
#
# The container class is asked first because it answers for all four container
# environments at once, with one sentence, and because the guard below would
# otherwise answer for ddev alone on a metacharacter and leave docker,
# docker-compose and vagrant reaching the same character through a different
# verdict. A caller reading the message should not have to know which of the
# four it was to know whether the refusal was the same one.
#
# The universal class — a single quote that would terminate a single-quoted
# wrapper string, and a line break that would split the path probes' compound
# command — is then put to the shared environment module's own guard, with the
# environment supplied as an argument rather than left to the global, so the
# verdict AND the message are the ones the wrappers themselves apply, and the
# one place that knows how a wrapper quotes a value owns the sentence about it.
# Args: $1 = candidate root, $2 = the environment the call runs under
# Globals: LINT_ENV is set and restored around the guard call
# Stdout: the refusal message
# Returns: 0 when the root is embeddable, 1 otherwise
_worktree_assert_charset() {
    local root="$1"
    local environment="$2"

    local verdict
    verdict=$(_worktree_classify_root_charset "${root}" "${environment}")
    case "${verdict}" in
        ok)
            ;;
        whitespace)
            printf '%s\n' "Refusing to run: the \"${environment}\" environment sends this path into the container as part of the working directory its command runs in, where a space ends the directory name — the command would change to a directory that is not the one this call targets. Rename the directory without a space, or use the native environment."
            return 1
            ;;
        *)
            # The matched prefix ends where the offender begins, so its length
            # is the offender's index; %q renders it visibly, as the path-shape
            # check above does for a control character.
            local prefix="${root%%["${SHELL_HOSTILE_METACHARS}"]*}"
            local rendered
            printf -v rendered '%q' "${root:${#prefix}:1}"

            printf '%s\n' "Refusing to run: the \"${environment}\" environment sends this path into the container as part of the working directory its command runs in, where the container's shell acts on the character ${rendered} it carries. Rename the directory without that character, or use the native environment."
            return 1
            ;;
    esac

    local inherited="${LINT_ENV:-}"
    LINT_ENV="${environment}"
    local message="" rc=0
    message=$(assert_no_shell_hostile_chars "project root" "${root}") || rc=$?
    LINT_ENV="${inherited}"

    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "${message}"
        return 1
    fi

    return 0
}

# _worktree_root_label <host root> <environment-side path>
# Names a root the way every message here should: the host path alone when the
# environment reaches it at that same path, and both when it does not. A caller
# comparing a diagnostic against the path they typed and against a path a
# container tool printed needs the mapping stated, and only this module knows
# it.
# Pure: both values are arguments.
# Args: $1 = the host path, $2 = the environment-side path, empty when equal
# Stdout: the label
_worktree_root_label() {
    local host="$1"
    local environment_side="$2"

    if [[ -z "${environment_side}" || "${environment_side}" == "${host}" ]]; then
        printf '%s' "${host}"
        return 0
    fi

    printf '%s (reached as %s)' "${host}" "${environment_side}"
}

# _worktree_probe_command <mapped root>
# The command the existence probe runs: a directory test on the path the
# effective root maps to on the environment side. A plain compound command, so
# it is parsed exactly once whichever wrapper carries it.
# Pure: the path is the only input.
# Args: $1 = the environment-side path of the effective root
# Stdout: the probe command
_worktree_probe_command() {
    printf 'test -d %s\n' "$(shell_quote_arg "$1")"
}

# _worktree_probe_applicable <environment>
# True when the environment reaches the root at a path of its own, which is
# what there is to probe. Under native — and under any name the wrappers run
# locally — the mapped path IS the host path the resolution already found to
# exist, so the probe would restate that finding through a subprocess.
# Pure: the environment is the only input.
# Args: $1 = the environment this call runs under
# Returns: 0 when the probe applies, 1 when it does not
_worktree_probe_applicable() {
    _env_is_container_environment "$1"
}

# =============================================================================
# Validation
# =============================================================================

# _worktree_assert_path_shape <root>
# Refuses a project root that is empty, not absolute, or carrying a control
# character.
#
# This is the shape test alone. Which characters the command wrappers cannot
# carry is a separate step, because the answer depends on the environment the do
# call runs under and that is not known until the configuration has been
# selected and read — see _worktree_assert_charset.
#
# A control character is refused for diagnosability, not safety: a newline in
# the root splits the banner, and every log line and message naming the root,
# into fragments that read as separate records. Absolute is required because a
# relative root resolves against the directory the server was launched in.
# Args: $1 = the candidate project root
# Globals: sets WORKTREE_VALIDATION_MESSAGE on failure
# Returns: 0 when the root is usable, 1 otherwise
_worktree_assert_path_shape() {
    local root="$1"

    if [[ -z "${root}" ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run: the project root is empty."
        return 1
    fi

    if [[ "${root}" != /* ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the project root must be an absolute path. A relative one resolves against the directory the server was launched in, which is never the tree the caller meant."
        return 1
    fi

    if [[ "${root}" == *[[:cntrl:]]* ]]; then
        # The matched prefix ends where the offender begins, so its length is
        # the offender's index; %q renders a newline or a tab visibly.
        local prefix="${root%%[[:cntrl:]]*}"
        local rendered
        printf -v rendered '%q' "${root:${#prefix}:1}"

        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": it contains a control character, ${rendered}, which breaks the single line every banner, log entry and message naming this root is written as. Rename the worktree directory without it."
        return 1
    fi

    return 0
}

# _worktree_git_dir_pair <directory>
# --path-format=absolute is required: the plain form prints a relative ".git"
# from a main checkout and an absolute path from a linked worktree, so comparing
# plain output rejects every valid worktree. It also canonicalizes — on macOS
# /tmp becomes /private/tmp — so every value this module compares must come from
# this one function, or two spellings of one directory read as different.
#
# env -u is not decoration: git rev-parse honours GIT_DIR, GIT_WORK_TREE and
# GIT_COMMON_DIR over directory discovery, so an inherited value makes every
# identity test below read a different repository — measured, with GIT_DIR set
# to an unrelated checkout a valid worktree's common dir came back as that
# checkout's. Only this module's own validation is isolated; the wrapped tool
# commands keep their environment.
# Args: $1 = directory to run git in
# Stdout: two lines — the absolute git dir, then the absolute common git dir
# Returns: 0 on success, 1 when the directory is not inside a git repository,
#          2 when git is too old to understand --path-format
_worktree_git_dir_pair() {
    local dir="$1"

    local value rc=0
    value=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR \
        git -C "${dir}" rev-parse --path-format=absolute --git-dir --git-common-dir 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 || -z "${value}" ]]; then
        return 1
    fi

    # rev-parse answers an option it does not recognize by echoing it back, at
    # exit 0 — measured on git 2.55.0. Below git 2.31, which is the release that
    # added --path-format, the flag itself becomes the first line and every
    # value read after it shifts by one, so the caller ends up treating
    # "--path-format=absolute" as a git directory and says so in its refusal.
    # An absolute first line is what separates the two cases.
    if [[ "${value}" != /* ]]; then
        return 2
    fi

    printf '%s\n' "${value}"
    return 0
}

# _worktree_config_env_value
# The config.sh environment-variable override. An unset name is read as "no
# override" rather than raised: bare ${!CONFIG_ENV_VAR} aborts with "invalid
# indirect expansion" under set -u when the NAME is unset, which would take a
# tool call down with no text.
# Globals: reads CONFIG_ENV_VAR and the variable it names
# Stdout: the override path, or empty when there is none
_worktree_config_env_value() {
    local name="${CONFIG_ENV_VAR:-}"
    if [[ -z "${name}" ]]; then
        return 0
    fi
    printf '%s\n' "${!name:-}"
}

# _worktree_is_registered <root>
# Membership in `git worktree list --porcelain`, git's own registry. This ends
# the class of hand-written ".git" files: a directory git has not registered is
# refused however well its ".git" file is crafted.
#
# It does NOT settle forgery on its own. A directory registered by writing a
# per-worktree entry into <common>/worktrees/ IS a worktree as far as git is
# concerned, and this test accepts it; producing that entry needs write access
# to the repository's own git directory, where hooks run arbitrary code on the
# next git command, so it is a full compromise rather than something this
# module can defend against.
#
# Recorded paths are absolute but may be spelled differently from the caller's,
# so both sides go through `pwd -P`.
#
# Kept as a backstop rather than for a case of its own: with this function
# stubbed to return 0, every test in worktree_resolution.bats still passes. The
# checks in `_worktree_validate_root` ahead of it already refuse everything
# reachable — a candidate that satisfies all of them has an administrative
# directory under <common>/worktrees/ whose "gitdir" names it, which is exactly
# what makes git list it. Do not read the absence of a failing test here as
# missing coverage.
# Args: $1 = candidate root
# Globals: reads PROJECT_ROOT
# Returns: 0 when git lists the root as a worktree, 1 otherwise
_worktree_is_registered() {
    local root="$1"

    local canonical_root
    canonical_root=$(cd "${root}" >/dev/null 2>&1 && pwd -P) || return 1

    local listing rc=0
    listing=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR \
        git -C "${PROJECT_ROOT}" worktree list --porcelain 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 || -z "${listing}" ]]; then
        return 1
    fi

    local line entry canonical_entry
    while IFS= read -r line; do
        [[ "${line}" == "worktree "* ]] || continue
        entry="${line#worktree }"
        canonical_entry=$(cd "${entry}" >/dev/null 2>&1 && pwd -P) || continue
        if [[ "${canonical_entry}" == "${canonical_root}" ]]; then
            return 0
        fi
    done <<< "${listing}"

    return 1
}

# worktree_release_owned_temp
# Removes the merged-config temp file this call created, if any. Never touches
# the inherited _CONFIG_TEMP_FILE: removing that one makes _scope_jq read a
# missing LINT_CONFIG_FILE for the rest of the server's life, and every later
# launch-root call then runs unscoped at the project root with no error.
# Globals: reads and clears WORKTREE_OWNED_TEMP_FILE
# Returns: 0 always
worktree_release_owned_temp() {
    if [[ -n "${WORKTREE_OWNED_TEMP_FILE}" ]]; then
        rm -f -- "${WORKTREE_OWNED_TEMP_FILE}"
        WORKTREE_OWNED_TEMP_FILE=""
    fi

    # The derivation's own temp file, which holds a refusal rather than a
    # configuration and is removed here for the same reason: it may only be
    # removed by the call that created it, and this is that call's cleanup.
    if [[ -n "${WORKTREE_DERIVATION_LOG}" ]]; then
        rm -f -- "${WORKTREE_DERIVATION_LOG}"
        WORKTREE_DERIVATION_LOG=""
    fi

    return 0
}

# _worktree_select_config <project root>
# Picks the configuration that applies to a call targeting <project root>. The
# worktree's own config wins when it has one; with none, the launch root's
# configuration applies unchanged, which is the ordinary case — a worktree holds
# tracked files only and the tooling configs are user-local and untracked.
# Args: $1 = project root to load the configuration from
# Globals: reads CONFIG_ENV_VAR and _FOUND_CONFIGS; may set LINT_CONFIG_FILE
#          (via load_config); sets WORKTREE_SELECTED_CONFIG_FILE and
#          WORKTREE_OWNED_TEMP_FILE; restores _CONFIG_TEMP_FILE
# Returns: 0 always
_worktree_select_config() {
    local root="$1"

    WORKTREE_OWNED_TEMP_FILE=""
    local inherited_temp="${_CONFIG_TEMP_FILE:-}"
    local inherited_config="${LINT_CONFIG_FILE:-}"

    local rc=0
    load_config "${root}" || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        # load_config returns before assigning LINT_CONFIG_FILE on every failure
        # path, so the inherited launch configuration is still in force.
        _CONFIG_TEMP_FILE="${inherited_temp}"
        WORKTREE_SELECTED_CONFIG_FILE="${LINT_CONFIG_FILE:-}"
        return 0
    fi

    # _CONFIG_TEMP_FILE is NOT the signal that a merge happened: _merge_configs
    # assigns it inside the command substitution load_config captures, so it
    # reads empty here. The LINT_CONFIG_FILE inequality is the guard that makes
    # recording the inherited launch configuration as this call's property
    # impossible.
    local env_value
    env_value=$(_worktree_config_env_value)
    if [[ -z "${env_value}" ]]; then
        if [[ "${#_FOUND_CONFIGS[@]}" -gt 1 && "${LINT_CONFIG_FILE}" != "${inherited_config}" ]]; then
            WORKTREE_OWNED_TEMP_FILE="${LINT_CONFIG_FILE}"
        fi
    fi

    # A no-op today; keeps the invariant if _merge_configs' assignment ever reaches this shell.
    _CONFIG_TEMP_FILE="${inherited_temp}"
    WORKTREE_SELECTED_CONFIG_FILE="${LINT_CONFIG_FILE}"
    return 0
}

# _worktree_environment_in_force
# The environment the call runs under, decided from the configuration that is in
# force for it.
#
# When the selected configuration is the launch one, the environment is the
# value the server bound at startup and nothing is read: the launch
# configuration is read once, when the server starts, and an edit to that file
# mid-session is inert until a restart. Reading the file here instead is what
# let a call validate under the edited environment and then execute under the
# startup one the wrappers are keyed on — measured with a launch config edited
# from docker to native, where containment, the charset rule and the probe were
# all skipped while the command still ran in the startup container.
#
# A call whose selected configuration is the worktree's own has no startup value
# to answer with, so its environment is read from that file.
# Globals: reads WORKTREE_SELECTED_CONFIG_FILE, WORKTREE_LAUNCH_CONFIG_FILE and
#          LINT_ENV; reads LINT_CONFIG_FILE through _get_config_value
# Stdout: the environment name, empty when that configuration declares none
_worktree_environment_in_force() {
    if [[ "${WORKTREE_SELECTED_CONFIG_FILE}" == "${WORKTREE_LAUNCH_CONFIG_FILE}" ]]; then
        printf '%s\n' "${LINT_ENV}"
        return 0
    fi

    _get_config_value '.environment' ''
}

# _worktree_validate_root <project root>
# Validates a root that differs from the launch root, and selects the
# configuration that applies to it. Stops at the first step that fails.
# Args: $1 = the effective project root
# Globals: reads LINT_ENV; sets WORKTREE_VALIDATION_MESSAGE on failure; sets
#          WORKTREE_SELECTED_CONFIG_FILE and WORKTREE_OWNED_TEMP_FILE; may set
#          LINT_CONFIG_FILE
# Returns: 0 when the root is usable, 1 otherwise
_worktree_validate_root() {
    local root="$1"

    WORKTREE_VALIDATION_MESSAGE=""
    WORKTREE_OWNED_TEMP_FILE=""

    if ! _worktree_assert_path_shape "${root}"; then
        return 1
    fi

    if [[ ! -d "${root}" ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": it does not exist, or it is not a directory."
        return 1
    fi

    # Three tests, and each rejects something the others admit. Measured against
    # a fixture holding a main checkout, a subdirectory of it, a linked worktree,
    # that worktree's own subdirectory, and a directory carrying a hand-written
    # ".git" that points at the launch repository:
    #
    #   directory              .git    git-dir != common-dir
    #   main checkout          dir     no
    #   main subdirectory      absent  no
    #   worktree root          file    YES     <- the only one to accept
    #   worktree subdirectory  absent  YES
    #   forged ".git" file     file     no
    #
    # The file test alone admits the forgery; the inequality alone admits the
    # worktree's own subdirectory. Only the conjunction isolates the worktree
    # root, and the common-dir equality below is still needed on top of both,
    # because it is what proves the worktree belongs to THIS repository rather
    # than to a second checkout that has worktrees of its own.
    #
    # Preferred over comparing `rev-parse --show-toplevel` with the root:
    # --show-toplevel resolves symlinks, so it would falsely refuse a worktree
    # reached through one. Neither test here is affected by that.
    if [[ ! -f "${root}/.git" ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": it holds no \".git\" file, so it is not the root of a linked git worktree. A main checkout holds \".git\" as a directory and a subdirectory of a checkout holds no \".git\" at all; create a worktree with \`git worktree add\` and pass its root."
        return 1
    fi

    local pair pair_rc=0
    pair=$(_worktree_git_dir_pair "${root}") || pair_rc=$?
    if [[ "${pair_rc}" -eq 2 ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": this git does not understand \`git rev-parse --path-format\`, which git 2.31 added, so the git directory behind a worktree cannot be resolved. Worktree targeting needs git 2.31 or newer."
        return 1
    fi
    if [[ "${pair_rc}" -ne 0 ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": it is not inside a git repository."
        return 1
    fi
    local effective_gitdir effective_common
    { IFS= read -r effective_gitdir; IFS= read -r effective_common; } <<< "${pair}"

    # A real linked worktree's git directory is its own, under
    # <common>/worktrees/<name>. Equality here means the ".git" file resolves to
    # the repository's own git directory, which no worktree git creates does.
    if [[ "${effective_gitdir}" == "${effective_common}" ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": its \".git\" file resolves to the repository's own git directory \"${effective_gitdir}\" rather than to a per-worktree one under \"${effective_common}/worktrees/\", so it was not created by \`git worktree add\`."
        return 1
    fi

    # The inequality above still admits a hand-written ".git" pointing at a REAL
    # sibling worktree's per-worktree directory — every earlier test passes
    # while the commands run in the forged directory, and it reproduces. git's
    # own back-pointer closes it: each per-worktree directory holds a "gitdir"
    # file naming that worktree's own ".git", so a directory borrowing someone
    # else's fails here.
    local backpointer_file="${effective_gitdir}/gitdir"
    if [[ ! -f "${backpointer_file}" ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the git directory \"${effective_gitdir}\" its \".git\" file names holds no \"gitdir\" back-pointer, so it is not a per-worktree directory git maintains."
        return 1
    fi

    # git records the back-pointer canonically while the caller's spelling may
    # reach the same directory through a symlink — on macOS a /var/folders/…
    # path is /private/var/folders/…, and a literal comparison of the two was
    # measured to fail on a valid worktree.
    local backpointer
    backpointer=$(< "${backpointer_file}")
    # worktree.useRelativePaths writes the back-pointer relative to the
    # per-worktree directory that holds it, so that is the base it resolves
    # from — resolving from the process working directory refused every
    # worktree `git worktree add --relative-paths` created.
    local backpointer_dir="${backpointer%/.git}"
    if [[ "${backpointer_dir}" != /* ]]; then
        backpointer_dir="${effective_gitdir}/${backpointer_dir}"
    fi
    local canonical_backpointer="" canonical_root=""
    canonical_backpointer=$(cd "${backpointer_dir}" >/dev/null 2>&1 && pwd -P) || canonical_backpointer=""
    canonical_root=$(cd "${root}" >/dev/null 2>&1 && pwd -P) || canonical_root=""
    if [[ -z "${canonical_backpointer}" || -z "${canonical_root}" || "${canonical_backpointer}" != "${canonical_root}" ]]; then
        # The resolved directory when the back-pointer resolves; a relative
        # spelling alone names nothing the reader can visit.
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the git directory \"${effective_gitdir}\" belongs to the worktree at \"${canonical_backpointer:-${backpointer%/.git}}\", not to this directory, so its \".git\" file was hand-written rather than created by \`git worktree add\`."
        return 1
    fi

    if [[ -z "${WORKTREE_LAUNCH_COMMON}" ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the launch project root \"${PROJECT_ROOT}\" is not inside a git repository, so no worktree of it can be identified."
        return 1
    fi

    if [[ "${effective_common}" != "${WORKTREE_LAUNCH_COMMON}" ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": it belongs to the repository at \"${effective_common}\" and the launch root belongs to the one at \"${WORKTREE_LAUNCH_COMMON}\", so it is not a worktree of the launch root."
        return 1
    fi

    # Asked last, so a shape an earlier test already names specifically doesn't fall through to this generic backstop's message instead.
    if ! _worktree_is_registered "${root}"; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": \`git worktree list\` in \"${PROJECT_ROOT}\" does not list it, so it is not a worktree this repository created. Create one with \`git worktree add\`."
        return 1
    fi

    # An absolute pointer names a host path, and relinking a worktree is a
    # repository-level operation this module never performs, so the call is
    # refused and the remediation named instead.
    #
    # Refused in EVERY environment, native included. Which environment a call
    # runs under is a property of a configuration file, not of the pointer, so
    # a root accepted natively today is reached through a container the moment
    # one is configured — and the refusal would then arrive on a call the user
    # had no reason to expect it from.
    #
    # Measured: `git worktree add` writes an absolute pointer unless the
    # repository sets worktree.useRelativePaths, a key git 2.48 introduced, so
    # this refusal is the ordinary one on a fresh checkout and the remediation
    # is what relinks it.
    local linkage
    linkage=$(_worktree_gitdir_linkage "${root}")
    case "${linkage}" in
        relative)
            ;;
        absolute)
            WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": its \".git\" file carries an absolute gitdir pointer, which names a host path that does not exist inside a container. Relink it with \`git -c worktree.useRelativePaths=true worktree repair $(shell_quote_arg "${root}")\`, which needs git 2.48 or newer."
            return 1
            ;;
        *)
            WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": its \".git\" file carries no usable gitdir pointer, so the linked worktree it belongs to cannot be established. Recreate it with \`git worktree add\`."
            return 1
            ;;
    esac

    _worktree_select_config "${root}"

    # Every reader below swallows jq's exit status — _get_config_value and
    # _scope_jq both answer a failed read with an empty string — so a file
    # nothing can be read from passes the allowlist and scope_validate as though
    # it declared nothing, and the call then runs with no scopes and no per-tool
    # settings while the banner attributes the result to this worktree. The same
    # file at the launch root makes detect_environment exit and the server refuse
    # to start, so it is refused here too.
    #
    # `jq empty` is NOT the test, measured: it exits 0 on an empty file, on a
    # whitespace-only file and on a bare `null`, catching only syntactically
    # broken JSON. Asking for the object is what covers all four — rc 5 on
    # malformed, 4 on no JSON value at all, 1 on a value that is not an object.
    #
    # Whichever configuration ends up in force is checked, the worktree's own or
    # the inherited launch one. Exempting the launch config on the strength of
    # its startup parse was wrong: the file is user-editable and a session
    # outlives that parse, so a config edited into something unreadable
    # mid-session reached this point and the call ran with the scopes and every
    # per-tool setting reading as absent.
    #
    # This is the parse, not the binding. The environment the call runs under
    # comes from the startup binding either way — see
    # _worktree_environment_in_force — so a file that stopped parsing is the one
    # thing here that still has to be read afresh.
    if ! jq -e 'type == "object"' "${WORKTREE_SELECTED_CONFIG_FILE}" >/dev/null 2>&1; then
        worktree_release_owned_temp
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the configuration file in force (${WORKTREE_SELECTED_CONFIG_FILE}) does not parse as a JSON object, so nothing can be read from it — the environment, the scopes and every per-tool setting would all read as absent. Fix that file, or remove it so the launch root's configuration applies."
        return 1
    fi

    # The environment this call runs under, read from the configuration in
    # force — the worktree's own when it carries one, the launch root's
    # otherwise.
    #
    # An allowlist, deliberately: the name SELECTS which of the guards below
    # apply, so a name outside the known set is refused rather than treated as
    # native. detect_environment runs an unknown name locally, and a worktree
    # target inheriting that fallback skipped containment, the charset rule and
    # the probe in one step — a "docker " typo in the worktree's own config ran
    # the command on the host at the worktree root while the same config
    # spelled "docker" was refused as out-of-root. A launch configuration with
    # such a name is unaffected: this gate runs only for a differing target.
    local environment
    environment=$(_worktree_environment_in_force)
    WORKTREE_VALIDATED_ENVIRONMENT="${environment}"

    # Empty falls through: a configuration that declares NO environment gets
    # the dedicated refusal in the binding step, which names the file.
    if [[ -n "${environment}" && "${environment}" != "native" ]] && ! _env_is_container_environment "${environment}"; then
        worktree_release_owned_temp
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the configuration in force declares environment \"${environment}\", which worktree targeting does not recognize. Known environments: native, docker, docker-compose, vagrant, ddev."
        return 1
    fi

    # A container mounts the launch root, and no config field declares an
    # additional mount, so a worktree outside it has no path inside the
    # container at all.
    #
    # Both sides are canonicalized before they are compared, because the
    # comparison is what decides containment and a spelling must not decide it.
    # "<launch>/../elsewhere" is a registered worktree of the launch root that
    # sits outside it, and every test above accepts it — the back-pointer check
    # and `git worktree list` both compare canonical paths, so they agree it
    # belongs. Compared raw, this test then accepts it too and the suffix that
    # reaches the container is "../elsewhere", which names a directory outside
    # the mount when one happens to exist there.
    #
    # The pair is kept rather than discarded, because the path mapping that runs
    # later has to measure the same two paths this test just measured. It
    # compares a suffix against the launch root, so a raw effective root against
    # a canonical launch root — or the reverse — refuses a root this test has
    # already accepted: a worktree reached through a symlink, or one under
    # macOS's "/var" spelling, passes containment here and is then refused as
    # outside the launch root by the mapping. Both are cleared first so a
    # re-validation cannot read the previous target's pair.
    WORKTREE_CANONICAL_ROOT=""
    WORKTREE_CANONICAL_LAUNCH=""
    if _env_is_container_environment "${environment}"; then
        local canonical_root="" canonical_launch=""
        if ! canonical_root=$(_worktree_canonical_path "${root}"); then
            worktree_release_owned_temp
            WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": its location could not be resolved, so whether it sits inside the launch project root \"${PROJECT_ROOT}\" cannot be established."
            return 1
        fi
        if ! canonical_launch=$(_worktree_canonical_path "${PROJECT_ROOT%/}"); then
            worktree_release_owned_temp
            WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the launch project root \"${PROJECT_ROOT}\" could not be resolved, so whether this root sits inside it cannot be established."
            return 1
        fi

        if [[ "${canonical_root}" != "${canonical_launch}" && "${canonical_root}" != "${canonical_launch}"/* ]]; then
            worktree_release_owned_temp
            WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the \"${environment}\" environment runs commands inside a container that mounts the launch project root \"${PROJECT_ROOT}\" and nothing else, so no path inside the container reaches this root. The supported pattern is a worktree created inside the launch project root — \`git worktree add ${PROJECT_ROOT%/}/.claude/worktrees/<name>\`."
            return 1
        fi

        WORKTREE_CANONICAL_ROOT="${canonical_root}"
        WORKTREE_CANONICAL_LAUNCH="${canonical_launch}"
    fi

    # The characters the wrappers can carry, which is a different question per
    # environment and so cannot be asked before this one is known.
    local charset_error=""
    if ! charset_error=$(_worktree_assert_charset "${root}" "${environment}"); then
        worktree_release_owned_temp
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": ${charset_error}"
        return 1
    fi

    # The canonical spelling is the one that reaches a shell: the mapping is
    # built from the resolved path, and every wrapper embeds what the mapping
    # returned. A metacharacter that only the resolved path carries therefore
    # reaches the container's shell unquoted however clean the spelling the
    # caller typed, and the check above cannot see it — it classifies the string
    # the caller typed. A symlink to a directory named "a;b" is the ordinary way
    # to produce one, and it passes every other test here: the directory is a
    # registered worktree, it sits inside the launch root, and its link points
    # back at it.
    #
    # The container branch is the only place a canonical pair is established, so
    # this is that branch's second half. Both guards are the ones the raw
    # spelling already passed: the shape guard's control-character test, whose
    # message already names the spelling and the character and is passed through
    # unchanged, and the charset check, whose sentence about the character is
    # prefixed with the spelling it belongs to.
    if [[ -n "${WORKTREE_CANONICAL_ROOT}" && "${WORKTREE_CANONICAL_ROOT}" != "${root}" ]]; then
        if ! _worktree_assert_path_shape "${WORKTREE_CANONICAL_ROOT}"; then
            worktree_release_owned_temp
            return 1
        fi

        local canonical_charset_error=""
        if ! canonical_charset_error=$(_worktree_assert_charset "${WORKTREE_CANONICAL_ROOT}" "${environment}"); then
            worktree_release_owned_temp
            WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": that path resolves to \"${WORKTREE_CANONICAL_ROOT}\", which is the spelling the wrapped command carries. ${canonical_charset_error}"
            return 1
        fi
    fi

    # scope_validate is what server.sh runs at startup against the launch
    # config. Running it here makes a reserved scope name or an undeclared
    # default_scope in the worktree's own config fail with its own message
    # rather than as a per-call resolve_scope error or a silent fallback to the
    # "shopware" scope.
    local scope_error rc=0
    scope_error=$(scope_validate 2>&1 >/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        worktree_release_owned_temp
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": its configuration (${WORKTREE_SELECTED_CONFIG_FILE}) is not usable — ${scope_error}"
        return 1
    fi

    return 0
}

# =============================================================================
# Per-call resolution
# =============================================================================

# worktree_resolve_root <arguments JSON>
# The resolution half of worktree_enter: the call's own project_root argument,
# then sticky_root from the state file, then the launch root in PROJECT_ROOT.
# Args: $1 = the tool call's arguments JSON
# Globals: sets WORKTREE_EFFECTIVE_ROOT, WORKTREE_ROOT_SOURCE and LINT_WORKDIR;
#          reads PROJECT_ROOT
# Stdout: nothing on success, one sentence naming the failure otherwise
# Returns: 0 when the call may proceed, 1 otherwise
worktree_resolve_root() {
    local args="${1:-}"

    # One jq answers both questions — presence and value — because this runs on
    # every call's hot path. The marker letter carries presence: "//" alone
    # cannot, since it yields the empty string for an absent key AND for an
    # explicit "", and falling back for the second would silently substitute a
    # valid target for an invalid one.
    local marked rc=0
    marked=$(jq -r 'if has("project_root") then "P\(.project_root // "" | tostring)" else "A" end' <<< "${args}" 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "Refusing to run: the tool call's own arguments do not parse as a JSON object, so \"project_root\" could not be read from them."
        return 1
    fi

    local call_root=""
    if [[ "${marked}" == P* ]]; then
        call_root="${marked#P}"
        if [[ -z "${call_root}" ]]; then
            printf '%s\n' "Refusing to run: \"project_root\" was supplied as an empty string. Omit the parameter to target the sticky project root, or the root this server was launched in."
            return 1
        fi
    fi

    if [[ -n "${call_root}" ]]; then
        WORKTREE_EFFECTIVE_ROOT="${call_root}"
        WORKTREE_ROOT_SOURCE="call"
    else
        local sticky
        if ! sticky=$(_worktree_state_read_sticky); then
            printf '%s\n' "${sticky}"
            return 1
        fi
        if [[ -n "${sticky}" ]]; then
            WORKTREE_EFFECTIVE_ROOT="${sticky}"
            WORKTREE_ROOT_SOURCE="sticky"
        else
            WORKTREE_EFFECTIVE_ROOT="${PROJECT_ROOT}"
            WORKTREE_ROOT_SOURCE="launch"
        fi
    fi

    # Cleared before anything can read it: a call that re-resolves in the same
    # shell must not name the previous target's environment-side path.
    WORKTREE_ENV_WORKDIR=""

    # The launch root returns unvalidated — validation applies only to a differing target.
    if [[ "${WORKTREE_EFFECTIVE_ROOT}" == "${PROJECT_ROOT}" ]]; then
        return 0
    fi

    # Validation answers with its own message rather than reaching
    # detect_environment, which calls exit 1 on a missing or invalid config.
    # That exit is contained by the dispatch subshell and cannot stop the
    # server, but it yields a result with no usable text.
    if ! _worktree_validate_root "${WORKTREE_EFFECTIVE_ROOT}"; then
        printf '%s\n' "${WORKTREE_VALIDATION_MESSAGE}"
        return 1
    fi

    # The merged-config temp file _worktree_select_config may have just created
    # belongs to THIS call. The handler dispatches every tool inside an explicit
    # subshell, so a trap installed here fires when that subshell ends and
    # cannot reach the server's own EXIT trap — which is what lets it replace a
    # release call at every return path of every tool function. Installed only
    # on this branch; asserted by worktree_resolution.bats.
    trap 'worktree_release_owned_temp' EXIT

    if ! _worktree_bind_call_environment; then
        worktree_release_owned_temp
        return 1
    fi

    return 0
}

# _worktree_bind_call_environment
# Everything a call that targets a differing root does after validation: bind
# the environment the call runs under, map the root onto the environment's own
# path, enter the host root, and probe that the environment reaches it.
#
# Factored out because two tools owe the same work on the same terms —
# worktree_resolve_root for the call it is about to run, and
# tool_set_project_root before it commits a root that every later call will
# resolve through. A root one of them refuses and the other accepts is a set
# that appears to succeed and then fails on the next call, naming a reason the
# set never showed.
#
# The ORDER inside is load-bearing in two places, both measured:
#   - the environment is established before the mapping, because the mapping
#     dispatches on it and the re-derivation is what supplies the compose
#     scalars the compose arm reads;
#   - the root is entered before the probe, because the ddev, vagrant and
#     docker-compose wrappers discover their project by walking up from the
#     current directory, so a probe run from the launch root answers about the
#     launch project's container and caches that verdict under the worktree's
#     key.
# Globals: reads WORKTREE_EFFECTIVE_ROOT, WORKTREE_SELECTED_CONFIG_FILE,
#          WORKTREE_LAUNCH_CONFIG_FILE; sets LINT_ENV, LINT_WORKDIR,
#          WORKTREE_ENV_WORKDIR and the rest of the environment scalar family
# Stdout: nothing on success, the sentence naming the failure otherwise
# Returns: 0 when the call may proceed, 1 otherwise
_worktree_bind_call_environment() {
    if ! _worktree_map_call_environment; then
        printf '%s\n' "${WORKTREE_MAP_MESSAGE}"
        return 1
    fi

    # The dispatch subshell's own directory, which the rebinding above does not
    # reach: a relative path a caller passed, and anything that runs a wrapped
    # command without going through exec_command, both resolve against it.
    if ! cd "${WORKTREE_EFFECTIVE_ROOT}" >/dev/null; then
        printf '%s\n' "Refusing to run against \"$(_worktree_root_label "${WORKTREE_EFFECTIVE_ROOT}" "${WORKTREE_ENV_WORKDIR}")\": the working directory could not be changed to it."
        return 1
    fi

    if ! _worktree_probe_root "${WORKTREE_VALIDATED_ENVIRONMENT}" "${LINT_WORKDIR}"; then
        return 1
    fi

    return 0
}

# _worktree_map_call_environment
# The binding prefix _worktree_bind_call_environment and tool_cwd share:
# establish the environment in force, re-derive the worktree's own
# configuration when it is the selected one, and map the root onto the
# environment's path. The cd and the probe stay with the binding — a call
# enters and probes, a report must not — and the failure goes to
# WORKTREE_MAP_MESSAGE rather than stdout, because tool_cwd folds it into its
# report while the binding prints it, and a captured call would lose every
# global this function exists to set.
# Globals: reads WORKTREE_EFFECTIVE_ROOT, WORKTREE_VALIDATED_ENVIRONMENT,
#          WORKTREE_SELECTED_CONFIG_FILE, WORKTREE_LAUNCH_CONFIG_FILE,
#          WORKTREE_CANONICAL_ROOT, WORKTREE_CANONICAL_LAUNCH; sets LINT_ENV,
#          LINT_WORKDIR, WORKTREE_ENV_WORKDIR, WORKTREE_MAP_MESSAGE and the
#          rest of the environment scalar family
# Returns: 0 when the mapping is bound, 1 otherwise
_worktree_map_call_environment() {
    WORKTREE_MAP_MESSAGE=""

    # The environment this call runs under, as validation established it. A
    # call whose selected configuration is the launch one keeps the environment
    # the server bound at startup; a call whose selected configuration is the
    # worktree's own re-derives it from that file, into this dispatch subshell,
    # so the launch process's own values are untouched and a later launch-root
    # call still runs under the environment the server started with.
    local environment="${WORKTREE_VALIDATED_ENVIRONMENT}"

    if [[ "${WORKTREE_SELECTED_CONFIG_FILE}" != "${WORKTREE_LAUNCH_CONFIG_FILE}" ]]; then
        if [[ -z "${environment}" ]]; then
            WORKTREE_MAP_MESSAGE="Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": the configuration in force (${WORKTREE_SELECTED_CONFIG_FILE}) declares no \"environment\" field, so the environment this call runs under cannot be established."
            return 1
        fi

        if ! _worktree_run_derivation "${WORKTREE_SELECTED_CONFIG_FILE}" "${environment}"; then
            WORKTREE_MAP_MESSAGE="${WORKTREE_DERIVATION_MESSAGE}"
            return 1
        fi

        LINT_ENV="${environment}"
    fi

    # exec_command enters LINT_WORKDIR[/SCOPE_CWD] and exec_npm_command enters
    # get_js_workdir, derived from LINT_WORKDIR — which _set_workdir_from_config
    # bound to the LAUNCH root at startup. Without this rebinding every JS tool
    # and every scoped PHP tool would enter the launch tree and run there,
    # undoing the entry the binding performs.
    #
    # The value is the environment-side path, not the host path: under a
    # container environment those differ, and every bare call site —
    # get_workdir, wrap_command, wrap_npm_command, get_js_workdir and the
    # coverage strip — reads this global and takes no root parameter, so the
    # mapping has to have happened by the time tool code runs.
    #
    # Measured against the canonical pair the containment test resolved, not
    # against the raw spellings: the mapping's own containment comparison is the
    # one that decides whether a suffix exists at all, and the two paths it
    # measures have to be the two containment already agreed on. A raw effective
    # root against a raw launch root refuses a worktree reached through a
    # symlink that validation accepted, and a canonical root against a raw
    # launch root refuses one under macOS's "/var" spelling — the same defect
    # mirrored. The pair is empty outside a container environment, where this
    # branch's mapping is not reached.
    local env_workdir=""
    if ! env_workdir=$(resolve_env_workdir "${WORKTREE_CANONICAL_ROOT:-${WORKTREE_EFFECTIVE_ROOT}}" "${WORKTREE_CANONICAL_LAUNCH:-${PROJECT_ROOT:-}}"); then
        WORKTREE_MAP_MESSAGE="${env_workdir}"
        return 1
    fi

    LINT_WORKDIR="${env_workdir}"
    if [[ "${env_workdir}" == "${WORKTREE_EFFECTIVE_ROOT}" ]]; then
        WORKTREE_ENV_WORKDIR=""
    else
        WORKTREE_ENV_WORKDIR="${env_workdir}"
    fi

    return 0
}

# _worktree_run_derivation <config file> <environment>
# Re-derives the environment's scalars into THIS shell through the shared seam,
# and hands back the seam's own refusal when it has one.
#
# The seam writes its results through out-parameters, so it has to run in this
# shell: wrapping the call in a command substitution would discard the derived
# values along with the subshell. Its refusal therefore goes to a file rather
# than to a pipe, and stderr is folded in because the docker arm writes its
# refusal there — that arm is shared with the startup path, where stdout is the
# protocol stream and a message printed to it would corrupt the frame.
# The message goes to a global for the same reason the seam writes its results
# into the calling shell: a caller that read it through a command substitution
# would lose the derived scalars to the subshell, and one that redirected the
# seam's output to a pipe would have to leave those assignments behind anyway.
# Args: $1 = the configuration file, $2 = the environment it declares
# Globals: writes LINT_WORKDIR, DOCKER_CONTAINER, COMPOSE_SERVICE,
#          COMPOSE_WORKDIR_OVERRIDE, COMPOSE_FILE_OVERRIDE; sets
#          WORKTREE_DERIVATION_MESSAGE on failure and clears it on success
# Returns: 0 on success, 1 otherwise
_worktree_run_derivation() {
    local config_file="$1"
    local environment="$2"

    WORKTREE_DERIVATION_MESSAGE=""

    local log rc=0
    log=$(mktemp "${TMPDIR:-/tmp}/worktree-derivation.XXXXXX") || rc=$?
    if [[ "${rc}" -ne 0 || -z "${log}" ]]; then
        WORKTREE_DERIVATION_MESSAGE="Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": a temporary file could not be created under ${TMPDIR:-/tmp}, so the \"${environment}\" environment declared by ${config_file} cannot be derived."
        return 1
    fi

    # Recorded before the seam runs and removed by worktree_release_owned_temp,
    # which the dispatch subshell's EXIT trap calls, so a signal arriving while
    # the seam runs does not leave the file behind.
    WORKTREE_DERIVATION_LOG="${log}"

    rc=0
    _set_workdir_from_config "${WORKTREE_EFFECTIVE_ROOT}" "${config_file}" "${environment}" > "${log}" 2>&1 || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        # The seam writes nothing on some failure paths, so an empty log is not
        # a pass: the fallback sentence is what keeps this a refusal with text.
        if [[ -s "${log}" ]]; then
            WORKTREE_DERIVATION_MESSAGE=$(< "${log}")
        else
            WORKTREE_DERIVATION_MESSAGE="Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": the \"${environment}\" environment declared by ${config_file} could not be derived from it."
        fi
        return 1
    fi

    rm -f -- "${log}"
    WORKTREE_DERIVATION_LOG=""
    return 0
}

# _worktree_probe_root <environment> <mapped root>
# Runs the one existence probe: a directory test of the path this root maps to
# on the environment side, through the same command wrapper the tool call
# itself uses, so the probe answers for the environment the command will run
# in and not for the host.
#
# The result of a passing probe is recorded in the state file, and a later call
# for the same environment, effective root AND mapped path reads that entry
# instead of probing again. A failing probe is deliberately NOT recorded: the
# cache is keyed on values that do not change while the environment they name
# does, so a recorded failure would keep refusing calls for the rest of the
# process after whatever caused it had been fixed.
# Args: $1 = the environment this call runs under, $2 = the mapped root
# Globals: reads WORKTREE_EFFECTIVE_ROOT, and LINT_ENV/LINT_WORKDIR through
#          exec_command's wrapper
# Stdout: the refusal message when the probe fails
# Returns: 0 when the environment reaches the root, or the probe does not apply
_worktree_probe_root() {
    local environment="$1"
    local mapped="$2"

    if ! _worktree_probe_applicable "${environment}"; then
        return 0
    fi

    local cached
    cached=$(_worktree_state_read_probe "${environment}" "${WORKTREE_EFFECTIVE_ROOT}" "${mapped}")
    if [[ "${cached}" == "true" ]]; then
        return 0
    fi

    local probe output="" rc=0
    probe=$(_worktree_probe_command "${mapped}")
    output=$(exec_command "${probe}") || rc=$?

    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": the \"${environment}\" environment does not reach \"${mapped}\", the path this root maps to there, so a command run against it would find nothing.${output:+ The probe said: ${output}}"
        return 1
    fi

    local write_error=""
    if ! write_error=$(_worktree_state_write_probe "${environment}" "${WORKTREE_EFFECTIVE_ROOT}" "${mapped}"); then
        # Reported, not fatal: the probe itself passed, and failing a call over
        # the bookkeeping that would have saved a later probe would refuse a
        # call whose every check succeeded. The cost of the failure is one more
        # probe next time, which is the stricter direction.
        log "ERROR" "The worktree probe result could not be recorded: ${write_error}"
    fi

    return 0
}

# worktree_enter <arguments JSON>
# Resolves the effective root for this call and names it in the banner. The
# first statement of every tool function except set_project_root and cwd —
# ludtwig's two tools reach it through _ludtwig_run instead.
#
# Call it directly as a statement, never through a command substitution:
# resolution sets the effective root, rebinds LINT_WORKDIR and changes the
# working directory, and a subshell would discard all three. Its refusal goes to
# the caller's own stdout, which is the tool result.
# Args: $1 = the tool call's arguments JSON
# Globals: as worktree_resolve_root
# Stdout: the banner on success, one sentence naming the failure otherwise
# Returns: 0 when the call may proceed, 1 otherwise
worktree_enter() {
    if ! worktree_resolve_root "$1"; then
        return 1
    fi
    worktree_root_banner
    return 0
}

# _worktree_dependency_workdir <kind>
# The directory the requested dependency tree is installed in: the full JS
# working directory including SCOPE_CWD and SCOPE_JS_SUBDIR for "js", because
# that is where node_modules sits, and the effective root for "php", because
# that is where vendor sits. Composing SCOPE_CWD onto the PHP side would look
# inside the scope's own directory, which holds no vendor of its own.
#
# Composed over the HOST root, not LINT_WORKDIR. The dependencies this looks
# for are the worktree's own files on the host, so the paths have to be
# host-side; under a container environment LINT_WORKDIR names a path inside the
# container and a host test of it finds nothing, refusing a worktree whose
# vendor directory is installed. get_js_workdir is still the one place the JS
# composition is written, so LINT_WORKDIR is bound to the host root for the
# duration of that one call and given back — the same binding
# _compose_wrap_npm_command performs for the same reason.
#
# Deliberately NOT the path guard's boundary — see
# worktree_assert_paths_within_root for why the two differ.
# Args: $1 = dependency kind, "php" or "js"
# Globals: reads WORKTREE_EFFECTIVE_ROOT, and SCOPE_CWD/SCOPE_JS_SUBDIR via
#          get_js_workdir
# Stdout: the directory the dependencies are installed in
_worktree_dependency_workdir() {
    if [[ "$1" == "js" ]]; then
        local inherited_workdir="${LINT_WORKDIR:-}"
        LINT_WORKDIR="${WORKTREE_EFFECTIVE_ROOT}"
        get_js_workdir
        LINT_WORKDIR="${inherited_workdir}"
        return 0
    fi

    printf '%s\n' "${WORKTREE_EFFECTIVE_ROOT}"
    return 0
}

# worktree_assert_dependencies [kind]
# Called after resolve_scope in tools that have a scope, and directly after
# worktree_enter in those that do not. It has to run after scope resolution:
# the JS working directory carries SCOPE_CWD[/SCOPE_JS_SUBDIR], so measuring it
# before SCOPE_CWD is set examines the unscoped path and refuses a valid
# worktree.
#
# The kind defaults to the server's own — "js" when JS_CONTEXT is set, "php"
# otherwise — which is right for every tool that runs the toolchain its server
# is named for. A tool that runs the other one states its kind instead, as
# ludtwig does: it sits on the storefront server and runs composer, so the
# inferred "js" would demand an npm install it has no use for and accept a tree
# with no vendor.
# Args: $1 = optional dependency kind, "php" or "js"
# Globals: reads WORKTREE_EFFECTIVE_ROOT, PROJECT_ROOT, JS_CONTEXT
# Stdout: nothing when the dependencies are present, one sentence naming the
#         missing path and the command that creates it otherwise
# Returns: 0 when the call may proceed, 1 otherwise
worktree_assert_dependencies() {
    local kind="${1:-}"
    if [[ -z "${kind}" ]]; then
        kind="php"
        [[ -n "${JS_CONTEXT:-}" ]] && kind="js"
    fi

    case "${kind}" in
        php|js)
            ;;
        *)
            printf '%s\n' "Refusing to run: unknown dependency kind \"${kind}\" — worktree_assert_dependencies takes \"php\" or \"js\"."
            return 1
            ;;
    esac

    if [[ "${WORKTREE_EFFECTIVE_ROOT}" == "${PROJECT_ROOT}" ]]; then
        return 0
    fi

    local workdir label
    workdir=$(_worktree_dependency_workdir "${kind}")
    label=$(_worktree_root_label "${WORKTREE_EFFECTIVE_ROOT}" "${WORKTREE_ENV_WORKDIR}")

    # A worktree holds tracked files only, so the installed dependencies of the
    # launch tree are not in it.
    if [[ "${kind}" == "js" ]]; then
        if [[ ! -d "${workdir}/node_modules" ]]; then
            printf '%s\n' "Refusing to run against \"${label}\": \"${workdir}/node_modules\" does not exist. Call worktree_prepare on this server, or run \`npm ci\` in \"${workdir}\" yourself."
            return 1
        fi
        return 0
    fi

    if [[ ! -f "${workdir}/vendor/autoload.php" ]]; then
        printf '%s\n' "Refusing to run against \"${label}\": \"${workdir}/vendor/autoload.php\" does not exist. Call worktree_prepare on the php-tooling server, or run \`composer install\` in \"${workdir}\" yourself."
        return 1
    fi

    return 0
}

# worktree_prepare_execute <command> <runner> <label>
# The install-and-summarize contract shared by every server's
# tool_worktree_prepare, in one place so the three tools cannot drift: an
# install prints hundreds of per-package lines nobody acts on when it
# succeeds, so a success returns a short summary and a failure returns
# everything.
# Args: $1 = the install command, $2 = the executing function
#       (exec_command or exec_npm_command), $3 = the log label
# Stdout: the summary or the full output
# Returns: the install's exit status
worktree_prepare_execute() {
    local cmd="$1"
    local runner="$2"
    local label="$3"

    log "INFO" "Preparing dependencies (${label}): ${cmd}"

    local output rc=0
    output=$("${runner}" "${cmd}" 2>&1) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "${output}"
        return "${rc}"
    fi

    local total tool_word subcommand_word
    total=$(printf '%s\n' "${output}" | wc -l | tr -d ' ')
    read -r tool_word subcommand_word _ <<< "${cmd}"
    printf '%s\n' "${tool_word} ${subcommand_word} completed. Showing the last 3 of ${total} installer output lines:"
    printf '%s\n' "${output}" | tail -n 3
}

# _worktree_canonical_path <absolute path>
# The canonicalization the containment tests measure with, delegated to the
# shared environment module's `_env_canonical_path` so one implementation serves
# both the path guard here and the docker-compose bind-mount comparison there.
# A second copy would be free to drift from this one, and the two are read
# against each other: a boundary canonicalized one way and a mount source
# another would compare unequal for the same directory.
# Args: $1 = absolute path
# Outputs: the resolved path on stdout
# Returns: 0 when the path resolved, 1 when it did not, or when the argument is
#          not absolute — the ancestor walk has no root to stop at
_worktree_canonical_path() {
    _env_canonical_path "$1"
}

# _worktree_path_is_within <path> <boundary>
# Args: $1 = path, $2 = boundary directory
# Returns: 0 when the path is the boundary or sits under it, 1 otherwise and
#          whenever the boundary is empty
_worktree_path_is_within() {
    local path="$1"
    local boundary="$2"

    [[ -n "${boundary}" ]] || return 1

    # The root is the one boundary whose trailing slash is the boundary. Letting
    # the strip below reach it would leave an empty string and refuse every
    # absolute path.
    if [[ "${boundary}" == "/" ]]; then
        [[ "${path}" == /* ]]
        return
    fi

    boundary="${boundary%/}"
    [[ "${path}" == "${boundary}" || "${path}" == "${boundary}"/* ]]
}

# worktree_assert_paths_within_root <paths JSON array>
# Called by every tool that takes a "paths" parameter, after the paths are
# parsed and before they are embedded in a command. The two path forms are
# answered differently, because only the absolute one has a base this guard
# knows. An absolute path is canonicalized and measured against the boundary.
# A relative path is resolved by the tool itself, against a base that varies
# per tool and per path — the storefront tools accept a repo-root-relative, a
# tree-relative and a package-prefixed spelling of one file and tell them apart
# in their own routing, and "views/components/x.js" does not exist relative to
# the effective root at all — so resolving it here would refuse a documented
# form. It is checked lexically instead: every accepted spelling reaches its
# file without climbing, so a ".." segment is the one construct that can leave
# the tree whatever base applies. The tools' own "../.." bases
# (STOREFRONT_ESLINT_COMPONENTS_BASE, VITEST_COMPONENTS_BASE) are built after
# this guard runs and never pass through it.
#
# The boundary is the HOST-side effective root, WORKTREE_EFFECTIVE_ROOT. A
# caller path is a host path, so only a host-side boundary can be measured
# against it: under a container environment LINT_WORKDIR names a path inside
# the container or guest, and no host path compares with one. Under native the
# two coincide, which is why LINT_WORKDIR read correctly as the boundary there
# and nowhere else. WORKTREE_EFFECTIVE_ROOT is PROJECT_ROOT on a call that
# targets the launch root, so the boundary exists on every call, and the early
# return below keeps a launch-root call from being measured at all.
#
# Deliberately NOT the JS working directory either. What this guard answers is
# whether a path belongs to the tree the call targets, and a path inside the
# worktree is inside it whichever package directory the tool happens to run
# from. The PHP server already measured the effective root; it is the two JS
# servers that stopped narrowing to the JS working directory, which put
# src/Storefront/Resources/views/components outside the boundary on an unscoped
# storefront call — the very paths _eslint_is_components_path and the vitest
# rebase route on purpose, and which a launch-root call accepts because it
# returns early — and put everything outside the scope's own cwd outside it on a
# scoped call.
# Args: $1 = the tool call's "paths" JSON array
# Globals: reads WORKTREE_EFFECTIVE_ROOT, PROJECT_ROOT, WORKTREE_ENV_WORKDIR
# Outputs: nothing when every path is usable, one sentence naming the paths
#          outside the boundary otherwise
# Returns: 0 when the call may proceed, 1 otherwise
worktree_assert_paths_within_root() {
    local paths_json="${1:-}"

    if [[ "${WORKTREE_EFFECTIVE_ROOT}" == "${PROJECT_ROOT}" ]]; then
        return 0
    fi

    if [[ -z "${paths_json}" || "${paths_json}" == "[]" ]]; then
        return 0
    fi

    local label
    label=$(_worktree_root_label "${WORKTREE_EFFECTIVE_ROOT}" "${WORKTREE_ENV_WORKDIR}")

    # type is tested before startswith because startswith raises on a non-string
    # and would take the whole read down with it.
    local absolute rc=0
    absolute=$(jq -r '.[] | select(type == "string") | select(startswith("/"))' <<< "${paths_json}" 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "Refusing to run against \"${label}\": \"paths\" could not be read as a JSON array, so its entries could not be checked against the working directory this call runs in."
        return 1
    fi

    # Bracketing with slashes makes one pattern cover every position a ".."
    # segment can hold: the whole path, a leading one, an interior one and a
    # trailing one. A file whose name merely begins with dots ("..gitignore")
    # is not a segment and does not match.
    local relative candidate
    relative=$(jq -r '.[] | select(type == "string") | select(startswith("/") | not)' <<< "${paths_json}" 2>/dev/null) || relative=""

    local -a traversing=()
    while IFS= read -r candidate; do
        [[ -n "${candidate}" ]] || continue
        case "/${candidate}/" in
            */../*) traversing+=("${candidate}") ;;
        esac
    done <<< "${relative}"

    if [[ ${#traversing[@]} -gt 0 ]]; then
        printf '%s\n' "Refusing to run against \"${label}\": these relative paths climb out of the tree this call runs against with a \"..\" segment: ${traversing[*]}. A call targeting a worktree resolves every relative path inside that worktree — pass one that stays within it, or set \"project_root\" to the tree these belong to."
        return 1
    fi

    if [[ -z "${absolute}" ]]; then
        return 0
    fi

    # Both sides are compared only in their fully resolved form. An unresolved
    # comparison lets "<boundary>/../outside/x" and a leaf symlink out of the
    # tree read as inside.
    local boundary canonical_boundary
    boundary="${WORKTREE_EFFECTIVE_ROOT}"
    if ! canonical_boundary=$(_worktree_canonical_path "${boundary}"); then
        printf '%s\n' "Refusing to run against \"${label}\": the project root \"${boundary}\" could not be resolved, so no path can be measured against it."
        return 1
    fi

    local -a outside=() unresolvable=()
    local path resolved
    while IFS= read -r path; do
        [[ -n "${path}" ]] || continue
        if ! resolved=$(_worktree_canonical_path "${path}"); then
            unresolvable+=("${path}")
            continue
        fi
        _worktree_path_is_within "${resolved}" "${canonical_boundary}" || outside+=("${path}")
    done <<< "${absolute}"

    local failed=0

    if [[ ${#unresolvable[@]} -gt 0 ]]; then
        printf '%s\n' "Refusing to run against \"${label}\": these absolute paths could not be resolved, so whether they sit inside \"${boundary}\" cannot be established: ${unresolvable[*]}. A broken symbolic link and an unreadable parent directory both land here."
        failed=1
    fi

    if [[ ${#outside[@]} -gt 0 ]]; then
        printf '%s\n' "Refusing to run against \"${label}\": these absolute paths resolve outside \"${boundary}\", the tree this call runs against: ${outside[*]}. A call targeting a worktree runs every path against that worktree — pass them relative to it, or set \"project_root\" to the tree they belong to."
        failed=1
    fi

    return "${failed}"
}

# worktree_root_banner
# Globals: reads WORKTREE_EFFECTIVE_ROOT, WORKTREE_ROOT_SOURCE
# Stdout: one line naming the tree the result refers to, so it is visible in
#         the transcript
worktree_root_banner() {
    printf 'Project root: %s (%s)\n' "${WORKTREE_EFFECTIVE_ROOT}" "${WORKTREE_ROOT_SOURCE}"
}

# =============================================================================
# Tools
# =============================================================================

# tool_set_project_root <arguments JSON>
# Sets or clears the sticky project root, which outlives the call that writes
# it. It does not call worktree_enter, so it still works when sticky_root names
# a directory that no longer exists — the state after ExitWorktree with remove,
# and the state the exit reminder has to recover from.
#
# A root it accepts is one every later call will accept: it runs the same
# validation a per-call root gets, and then the same environment binding and
# existence probe. Without the second half a set could be reported as
# succeeding and then refuse on every call after it, naming a reason the set
# never showed — which is the one failure mode this tool must not have, because
# the sticky value outlives the call that wrote it and the session has no way
# to tell it went wrong.
# Args: $1 = the tool call's arguments JSON
# Globals: reads PROJECT_ROOT; sets WORKTREE_EFFECTIVE_ROOT, WORKTREE_ROOT_SOURCE
#          and the environment scalar family for this call only
# Stdout: the resulting effective root, or the message naming the failure
# Returns: 0 on success, 1 otherwise
tool_set_project_root() {
    local args="${1:-}"

    # One jq answers both questions — presence and value — the same marked
    # read worktree_resolve_root performs: absent means "clear", an explicit
    # "" is a caller error, and "//" alone cannot tell the two apart.
    local marked rc=0
    marked=$(jq -r 'if has("project_root") then "P\(.project_root // "" | tostring)" else "A" end' <<< "${args}" 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "Refusing to set the project root: this call's own arguments do not parse as a JSON object, so \"project_root\" could not be read from them."
        return 1
    fi

    local write_error root=""
    if [[ "${marked}" == P* ]]; then
        root="${marked#P}"
        if [[ -z "${root}" ]]; then
            printf '%s\n' "Refusing to set the project root: \"project_root\" was supplied as an empty string. Omit the parameter entirely to clear the sticky project root."
            return 1
        fi
    fi

    if [[ -z "${root}" ]]; then
        # The value being discarded is deliberately not validated: clearing is
        # the recovery path from a sticky root whose directory is gone.
        if ! write_error=$(_worktree_state_write_sticky ""); then
            printf '%s\n' "${write_error}"
            return 1
        fi
        printf '%s\n' "Sticky project root cleared. Effective project root: ${PROJECT_ROOT} (launch)."
        return 0
    fi

    # Set before validation, which reads it: _worktree_validate_root selects the
    # configuration from this root and names it in every refusal, and the
    # binding below runs the derivation for that same root.
    WORKTREE_EFFECTIVE_ROOT="${root}"
    WORKTREE_ROOT_SOURCE="sticky"

    # The merged-config temp file _worktree_validate_root creates below, and the
    # derivation log _worktree_bind_call_environment creates after it, belong to
    # THIS call. This tool is not reached through worktree_resolve_root, so
    # without its own trap a call cancelled between those two leaves the file
    # behind — and the handler already dispatches every tool inside an explicit
    # subshell, so a trap installed here fires when that subshell ends and
    # cannot reach the server's own EXIT trap. Installed ahead of validation
    # rather than after it, because validation is what creates the merged file.
    # The clear path above writes no temp file and installs nothing.
    trap 'worktree_release_owned_temp' EXIT

    if ! _worktree_validate_root "${root}"; then
        worktree_release_owned_temp
        printf '%s\n' "${WORKTREE_VALIDATION_MESSAGE}"
        return 1
    fi

    # The same binding and probe a per-call root gets, so a root this accepts is
    # one the next call accepts. The probe's result lands in the same cache,
    # keyed by the same environment, root and mapped path, so the first call after a set
    # reads it instead of probing again.
    if ! _worktree_bind_call_environment; then
        worktree_release_owned_temp
        return 1
    fi
    worktree_release_owned_temp

    if ! write_error=$(_worktree_state_write_sticky "${root}"); then
        printf '%s\n' "${write_error}"
        return 1
    fi

    printf '%s\n' "Sticky project root set. Effective project root: ${root} (sticky). Every later call on this server targets it until set_project_root is called with no argument."
    return 0
}

# tool_cwd <arguments JSON>
# Reports where this server resolves to. It validates nothing and never fails
# on a sticky root that no longer resolves, for the same reason
# tool_set_project_root does not: this is the tool a session calls to see what
# state the server is in.
# Args: $1 = the tool call's arguments JSON, which carries no parameters
# Stdout: the effective root, its source, whether it resolves, the resolved
#         working directory, the environment, and the configuration in use
# Returns: 0 always
tool_cwd() {
    local launch_config="${LINT_CONFIG_FILE:-}"

    local sticky="" sticky_error=""
    if ! sticky=$(_worktree_state_read_sticky); then
        sticky_error="${sticky}"
        sticky=""
    fi

    local effective source
    if [[ -n "${sticky}" ]]; then
        effective="${sticky}"
        source="sticky"
    else
        effective="${PROJECT_ROOT}"
        source="launch"
    fi

    # LINT_ENV is what the command wrappers key on, so it is the environment a
    # call actually runs in whichever root it targets.
    local environment="${LINT_ENV:-}"
    local resolves="yes" resolve_detail=""
    WORKTREE_ENV_WORKDIR=""
    if [[ "${effective}" != "${PROJECT_ROOT}" ]]; then
        # Validation and the derivation below both create call-owned temp files
        # on this path, and this tool is not reached through
        # worktree_resolve_root, so it installs the same dispatch-subshell trap
        # itself: a report cancelled mid-way otherwise leaves them behind. A
        # launch-root call creates none and installs nothing.
        trap 'worktree_release_owned_temp' EXIT
        if _worktree_validate_root "${effective}"; then
            # The same binding prefix worktree_resolve_root performs for a
            # call, so the working directory and the environment reported below
            # are the ones a call would actually run under rather than the
            # launch ones. Only the cd and the existence probe are absent: a
            # report must not enter the root, and the probe's verdict belongs
            # to the call that pays for it — reference.md documents that a
            # "resolves: yes" here does not assert the probe.
            WORKTREE_EFFECTIVE_ROOT="${effective}"
            if _worktree_map_call_environment; then
                environment="${LINT_ENV}"
            else
                resolves="no"
                resolve_detail="${WORKTREE_MAP_MESSAGE}"
            fi
        else
            resolves="no"
            resolve_detail="${WORKTREE_VALIDATION_MESSAGE}"
        fi
        worktree_release_owned_temp
    fi

    local workdir
    if [[ "${resolves}" == "no" ]]; then
        # LINT_WORKDIR still holds the launch root here, because the rebinding
        # above only runs when validation succeeds. Reporting it would name the
        # launch tree's working directory as though it belonged to the effective
        # root, which is the opposite of what this tool is for.
        workdir="unresolved — the effective project root does not resolve"
    else
        local base rc=0
        base=$(get_workdir) || rc=$?
        if [[ "${rc}" -ne 0 ]]; then
            workdir="unresolved — ${base}"
        elif [[ -n "${JS_CONTEXT:-}" ]]; then
            LINT_WORKDIR="${base}"
            workdir=$(get_js_workdir)
        else
            workdir="${base}"
        fi
    fi

    # Discovery is re-run here rather than reported from LINT_CONFIG_FILE: the
    # validation above may have merged a set of files into a temp file that is
    # already released by now, and naming a path that no longer exists would be
    # worse than useless in a diagnostic.
    local config_line env_value
    env_value=$(_worktree_config_env_value)
    if [[ -n "${env_value}" ]]; then
        config_line="${env_value} (from ${CONFIG_ENV_VAR:-}; discovery is skipped)"
    else
        # Called directly rather than left to load_config, which skips discovery
        # entirely on the environment-override path — _FOUND_CONFIGS would then
        # still hold the launch root's findings.
        _discover_configs "${effective}"
        if [[ "${#_FOUND_CONFIGS[@]}" -eq 0 ]]; then
            config_line="none under ${effective} — the launch root's configuration applies: ${launch_config}"
        else
            config_line="${_FOUND_CONFIGS[*]}"
        fi
    fi

    printf '%s\n' "Effective project root: ${effective} (${source})"
    printf '%s\n' "Launch project root: ${PROJECT_ROOT}"
    if [[ -n "${sticky_error}" ]]; then
        printf '%s\n' "Sticky project root: unreadable — ${sticky_error}"
    elif [[ -n "${sticky}" ]]; then
        printf '%s\n' "Sticky project root: ${sticky}"
    else
        printf '%s\n' "Sticky project root: none"
    fi
    printf '%s\n' "Effective project root resolves: ${resolves}"
    if [[ -n "${resolve_detail}" ]]; then
        printf '%s\n' "  ${resolve_detail}"
    fi
    printf '%s\n' "Working directory, no scope applied: ${workdir}"
    if [[ -n "${WORKTREE_ENV_WORKDIR}" ]]; then
        # Named only when it differs: under native the effective root IS the
        # path a command runs against, and a second line repeating it would
        # read as a second path.
        printf '%s\n' "Effective project root reached as: ${WORKTREE_ENV_WORKDIR}"
    fi
    printf '%s\n' "Environment: ${environment}"
    printf '%s\n' "Configuration in use: ${config_line}"
    return 0
}
