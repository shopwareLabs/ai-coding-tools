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
#           scope_validate() from the shared modules; JS_CONTEXT set by the two JS servers only.
#
# Public:
#   worktree_state_init           - create the state file; once, from server.sh
#   worktree_state_cleanup        - remove it; from server.sh's EXIT trap
#   worktree_enter <args>         - resolve the effective root and banner it; first statement of every tool but set_project_root, cwd (ludtwig's two tools reach it via _ludtwig_run instead)
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

WORKTREE_SELECTED_CONFIG_FILE="${LINT_CONFIG_FILE:-}"

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

# _worktree_state_write_sticky [project root]
# Writes the whole object to a mktemp sibling and renames it onto the state
# file, so a call killed mid-write cannot leave a partial file. The object is
# rebuilt from nothing rather than edited in place, so a state file whose
# content became unreadable cannot lock out the reset path.
# An empty argument removes sticky_root.
# Globals: reads DEV_TOOLING_STATE_FILE
# Stdout: nothing on success, the message naming the failure otherwise
# Returns: 0 on success, 1 otherwise
_worktree_state_write_sticky() {
    local value="${1:-}"

    if [[ -z "${DEV_TOOLING_STATE_FILE:-}" ]]; then
        printf '%s\n' "DEV_TOOLING_STATE_FILE is not set, so the sticky project root cannot be written."
        return 1
    fi

    local tmp rc=0
    tmp=$(mktemp "${DEV_TOOLING_STATE_FILE}.XXXXXX") || rc=$?
    if [[ "${rc}" -ne 0 || -z "${tmp}" ]]; then
        printf '%s\n' "Could not create a temporary file next to ${DEV_TOOLING_STATE_FILE}."
        return 1
    fi

    rc=0
    if [[ -n "${value}" ]]; then
        jq -n --arg root "${value}" '{sticky_root: $root}' > "${tmp}" || rc=$?
    else
        printf '%s\n' '{}' > "${tmp}" || rc=$?
    fi
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

# =============================================================================
# Validation
# =============================================================================

# _worktree_assert_path_shape <root>
# Refuses a project root that is empty, not absolute, or carrying a control
# character.
#
# Shell-hostile characters are deliberately NOT refused: the root reaches a
# shell only as a quoted argument to cd, and the container branches that do
# interpolate a workdir into a command string are unreachable here because
# _worktree_validate_root refuses every non-native environment.
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
# Returns: 0 on success, 1 when the directory is not inside a git repository
_worktree_git_dir_pair() {
    local dir="$1"

    local value rc=0
    value=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR \
        git -C "${dir}" rev-parse --path-format=absolute --git-dir --git-common-dir 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 || -z "${value}" ]]; then
        return 1
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

    local pair
    if ! pair=$(_worktree_git_dir_pair "${root}"); then
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
    local canonical_backpointer="" canonical_root=""
    canonical_backpointer=$(cd "${backpointer%/.git}" >/dev/null 2>&1 && pwd -P) || canonical_backpointer=""
    canonical_root=$(cd "${root}" >/dev/null 2>&1 && pwd -P) || canonical_root=""
    if [[ -z "${canonical_backpointer}" || -z "${canonical_root}" || "${canonical_backpointer}" != "${canonical_root}" ]]; then
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the git directory \"${effective_gitdir}\" belongs to the worktree at \"${backpointer%/.git}\", not to this directory, so its \".git\" file was hand-written rather than created by \`git worktree add\`."
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

    local inherited_config="${LINT_CONFIG_FILE:-}"
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
    # Only a config the worktree itself supplied is checked: with none,
    # _worktree_select_config leaves the inherited launch configuration in force,
    # and that one already parsed at startup or no server would be running.
    if [[ "${WORKTREE_SELECTED_CONFIG_FILE}" != "${inherited_config}" ]] \
        && ! jq -e 'type == "object"' "${WORKTREE_SELECTED_CONFIG_FILE}" >/dev/null 2>&1; then
        worktree_release_owned_temp
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the configuration in force (${WORKTREE_SELECTED_CONFIG_FILE}) is not a JSON object, so nothing can be read from it — the environment, the scopes and every per-tool setting would all read as absent. Fix that file, or remove it so the launch root's configuration applies."
        return 1
    fi

    # An allowlist, read from the config selected above rather than the launch
    # config: nothing here rebinds LINT_ENV, so "podman" or a typo such as
    # "nativ" would otherwise be accepted and then silently run natively. An
    # empty declaration IS accepted — the LINT_ENV test below proves it native.
    local environment
    environment=$(_get_config_value '.environment' '')
    case "${environment}" in
        ""|native)
            ;;
        docker|docker-compose|vagrant|ddev)
            worktree_release_owned_temp
            WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the configuration in force (${WORKTREE_SELECTED_CONFIG_FILE}) declares the \"${environment}\" environment, and a worktree outside the mounted tree does not exist inside the container — the supported pattern is a worktree created inside the mounted tree."
            return 1
            ;;
        *)
            worktree_release_owned_temp
            WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": the configuration in force (${WORKTREE_SELECTED_CONFIG_FILE}) declares the \"${environment}\" environment, and only \"native\" is supported for a worktree target."
            return 1
            ;;
    esac

    # The test that decides what actually happens: the wrappers key on LINT_ENV,
    # which detect_environment bound at startup from the launch config. Under a
    # containerized launch the command runs in the launch tree, exits 0, and has
    # its result attributed to the worktree — the silent wrong answer.
    if [[ "${LINT_ENV:-}" != "native" ]]; then
        worktree_release_owned_temp
        WORKTREE_VALIDATION_MESSAGE="Refusing to run against \"${root}\": this server was launched in the \"${LINT_ENV:-}\" environment, and a worktree target is supported only when the launch environment is native."
        return 1
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

    local call_root rc=0
    call_root=$(jq -r '.project_root // empty' <<< "${args}" 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "Refusing to run: the tool arguments are not a JSON object, so \"project_root\" could not be read."
        return 1
    fi

    if [[ -z "${call_root}" ]]; then
        # `//` yields the empty string for an absent key AND for an explicit "":
        # jq treats only null and false as empty. Falling back for the second
        # silently substitutes a valid target for an invalid one, so the key's
        # presence is asked separately, on this path only.
        local has_key
        has_key=$(jq -r 'if has("project_root") then "yes" else "no" end' <<< "${args}" 2>/dev/null) || rc=$?
        if [[ "${rc}" -ne 0 ]]; then
            printf '%s\n' "Refusing to run: the tool arguments are not a JSON object, so \"project_root\" could not be read."
            return 1
        fi
        if [[ "${has_key}" == "yes" ]]; then
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
    # release call at every return path of thirty tool functions. Installed only
    # on this branch; asserted by worktree_resolution.bats.
    trap 'worktree_release_owned_temp' EXIT

    # The dispatch subshell's own directory, which the rebinding below does not
    # reach: a relative path a caller passed, and anything that runs a wrapped
    # command without going through exec_command, both resolve against it.
    if ! cd "${WORKTREE_EFFECTIVE_ROOT}" >/dev/null; then
        worktree_release_owned_temp
        printf '%s\n' "Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": the working directory could not be changed to it."
        return 1
    fi

    # exec_command enters LINT_WORKDIR[/SCOPE_CWD] and exec_npm_command enters
    # get_js_workdir, derived from LINT_WORKDIR — which _set_workdir_from_config
    # bound to the LAUNCH root at startup. Without this rebinding every JS tool
    # and every scoped PHP tool would enter the launch tree and run there,
    # undoing the cd above.
    LINT_WORKDIR="${WORKTREE_EFFECTIVE_ROOT}"
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
# Deliberately NOT the path guard's boundary — see
# worktree_assert_paths_within_root for why the two differ.
# Args: $1 = dependency kind, "php" or "js"
# Globals: reads LINT_WORKDIR, and SCOPE_CWD/SCOPE_JS_SUBDIR via get_js_workdir
# Stdout: the directory the dependencies are installed in
_worktree_dependency_workdir() {
    if [[ "$1" == "js" ]]; then
        get_js_workdir
        return 0
    fi

    printf '%s\n' "${LINT_WORKDIR}"
    return 0
}

# worktree_assert_dependencies [kind]
# Called after resolve_scope in tools that have a scope, and directly after
# worktree_enter in those that do not — which includes the six tools that
# declare a "scope" parameter in tools.json and never resolve it: vite_build,
# lint_all, lint_twig, unit_setup, webpack_build and phpunit_coverage_gaps.
# It has to run after scope resolution: the JS working directory carries
# SCOPE_CWD[/SCOPE_JS_SUBDIR], so measuring it before SCOPE_CWD is set examines
# the unscoped path and refuses a valid worktree.
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

    local workdir
    workdir=$(_worktree_dependency_workdir "${kind}")

    # A worktree holds tracked files only, so the installed dependencies of the
    # launch tree are not in it.
    if [[ "${kind}" == "js" ]]; then
        if [[ ! -d "${workdir}/node_modules" ]]; then
            printf '%s\n' "Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": \"${workdir}/node_modules\" does not exist. Run \`npm ci\` in \"${workdir}\" first."
            return 1
        fi
        return 0
    fi

    if [[ ! -f "${workdir}/vendor/autoload.php" ]]; then
        printf '%s\n' "Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": \"${workdir}/vendor/autoload.php\" does not exist. Run \`composer install\` in \"${workdir}\" first."
        return 1
    fi

    return 0
}

# _worktree_realpath <path>
# realpath rather than `cd … && pwd -P`: pwd resolves the directories a path
# passes through and stops at the leaf, so a final component that is itself a
# symlink out of the tree reads as inside it. realpath resolves the leaf too,
# and BSD has no `readlink -f`.
# Args: $1 = path
# Outputs: the fully resolved path on stdout when it resolves
# Returns: 0 when realpath resolved it, 1 otherwise — a broken symlink, an
#          unreadable directory, or no realpath on this host, each a path whose
#          location cannot be established and which the caller turns into a
#          refusal rather than a pass.
_worktree_realpath() {
    local resolved rc=0
    resolved=$(realpath -- "$1" 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 || -z "${resolved}" ]]; then
        return 1
    fi
    printf '%s\n' "${resolved}"
}

# _worktree_lexical_normalize <absolute path>
# Collapses ".", ".." and repeated slashes without touching the filesystem, so
# a containment test cannot be defeated by spelling alone.
# Args: $1 = absolute path
# Outputs: the normalized path on stdout, "/" when every segment cancels
# Returns: 0 always
_worktree_lexical_normalize() {
    local rest="$1"
    local normalized="" segment

    while [[ -n "${rest}" ]]; do
        segment="${rest%%/*}"
        if [[ "${rest}" == */* ]]; then
            rest="${rest#*/}"
        else
            rest=""
        fi

        case "${segment}" in
            ""|.)
                ;;
            ..)
                # Already at the root: ".." there is the root, as in the kernel.
                normalized="${normalized%/*}"
                ;;
            *)
                normalized="${normalized}/${segment}"
                ;;
        esac
    done

    printf '%s\n' "${normalized:-/}"
}

# _worktree_canonical_path <absolute path>
# The spelling the filesystem would actually reach for an absolute path,
# whether or not every component exists yet. The deepest existing ancestor is
# resolved with realpath, which follows every symlink including the leaf; the
# segments below it are collapsed lexically. Without this,
# "<boundary>/../outside/x" and a leaf symlink out of the tree read as inside
# the boundary on a string comparison while the command reads a file outside.
#
# Trailing components that do not exist resolve rather than fail: the guarded
# tools accept glob targets, and a glob never exists as a literal path. A
# deepest EXISTING component that cannot be resolved fails instead, because its
# location cannot be established and a pass would be a guess.
# Args: $1 = absolute path
# Outputs: the resolved path on stdout
# Returns: 0 when the path resolved, 1 when it did not, or when the argument is
#          not absolute — the ancestor walk has no root to stop at
_worktree_canonical_path() {
    local path="$1"

    if [[ "${path}" != /* ]]; then
        return 1
    fi

    # Walk up to the deepest ancestor that exists. -L is tested alongside -e so
    # a dangling symlink stops the walk at itself, and realpath below then fails
    # on it — refused rather than measured by its spelling.
    local head="${path}" tail="" segment parent
    while [[ "${head}" != "/" && ! -e "${head}" && ! -L "${head}" ]]; do
        segment="${head##*/}"
        parent="${head%/*}"
        [[ -z "${parent}" ]] && parent="/"
        if [[ -z "${tail}" ]]; then
            tail="${segment}"
        else
            tail="${segment}/${tail}"
        fi
        head="${parent}"
    done

    local resolved
    if ! resolved=$(_worktree_realpath "${head}"); then
        return 1
    fi

    if [[ -z "${tail}" ]]; then
        printf '%s\n' "${resolved}"
        return 0
    fi

    _worktree_lexical_normalize "${resolved}/${tail}"
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
# parsed and before they are embedded in a command — which is after
# worktree_enter changed the working directory, so a RELATIVE path already
# resolves against the effective root and needs no check. Relative paths that
# traverse upward within the boundary's own tree are deliberately left alone:
# that is what routes a Storefront components path from the app/storefront
# package directory.
#
# The boundary is the effective root, deliberately NOT the directory
# _worktree_dependency_workdir measures. What this guard answers is whether a
# path belongs to the tree the call targets, and a path inside the worktree is
# inside it whichever package directory the tool happens to run from. The PHP
# server already measured the effective root; it is the two JS servers that
# stopped narrowing to the JS working directory, which put
# src/Storefront/Resources/views/components outside the boundary on an unscoped
# storefront call — the very paths _eslint_is_components_path and the vitest
# rebase route on purpose, and which a launch-root call accepts because it
# returns early — and put everything outside the scope's own cwd outside it on a
# scoped call.
#
# A launch-root call returns immediately: under a container environment
# LINT_WORKDIR is not a host path and nothing can be measured against it.
# Args: $1 = the tool call's "paths" JSON array
# Globals: reads WORKTREE_EFFECTIVE_ROOT, PROJECT_ROOT, LINT_WORKDIR
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

    # type is tested before startswith because startswith raises on a non-string
    # and would take the whole read down with it.
    local absolute rc=0
    absolute=$(jq -r '.[] | select(type == "string") | select(startswith("/"))' <<< "${paths_json}" 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": \"paths\" could not be read as a JSON array, so its entries could not be checked against the working directory this call runs in."
        return 1
    fi

    if [[ -z "${absolute}" ]]; then
        return 0
    fi

    # Both sides are compared only in their fully resolved form. An unresolved
    # comparison lets "<boundary>/../outside/x" and a leaf symlink out of the
    # tree read as inside.
    local boundary canonical_boundary
    boundary="${LINT_WORKDIR}"
    if ! canonical_boundary=$(_worktree_canonical_path "${boundary}"); then
        printf '%s\n' "Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": the project root \"${boundary}\" could not be resolved, so no path can be measured against it."
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
        printf '%s\n' "Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": these absolute paths could not be resolved, so whether they sit inside \"${boundary}\" cannot be established: ${unresolvable[*]}. A broken symbolic link and an unreadable parent directory both land here."
        failed=1
    fi

    if [[ ${#outside[@]} -gt 0 ]]; then
        printf '%s\n' "Refusing to run against \"${WORKTREE_EFFECTIVE_ROOT}\": these absolute paths resolve outside \"${boundary}\", the tree this call runs against: ${outside[*]}. A call targeting a worktree runs every path against that worktree — pass them relative to it, or set \"project_root\" to the tree they belong to."
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
# Args: $1 = the tool call's arguments JSON
# Stdout: the resulting effective root, or the message naming the failure
# Returns: 0 on success, 1 otherwise
tool_set_project_root() {
    local args="${1:-}"

    local root rc=0
    root=$(jq -r '.project_root // empty' <<< "${args}" 2>/dev/null) || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf '%s\n' "Refusing to set the project root: the tool arguments are not a JSON object."
        return 1
    fi

    local write_error
    if [[ -z "${root}" ]]; then
        # Absent means "clear", an explicit "" is a caller error — the same
        # jq `//` distinction worktree_resolve_root turns on, deliberate here.
        local has_key
        has_key=$(jq -r 'if has("project_root") then "yes" else "no" end' <<< "${args}" 2>/dev/null) || rc=$?
        if [[ "${rc}" -ne 0 ]]; then
            printf '%s\n' "Refusing to set the project root: the tool arguments are not a JSON object."
            return 1
        fi
        if [[ "${has_key}" == "yes" ]]; then
            printf '%s\n' "Refusing to set the project root: \"project_root\" was supplied as an empty string. Omit the parameter entirely to clear the sticky project root."
            return 1
        fi

        # The value being discarded is deliberately not validated: clearing is
        # the recovery path from a sticky root whose directory is gone.
        if ! write_error=$(_worktree_state_write_sticky ""); then
            printf '%s\n' "${write_error}"
            return 1
        fi
        printf '%s\n' "Sticky project root cleared. Effective project root: ${PROJECT_ROOT} (launch)."
        return 0
    fi

    if ! _worktree_validate_root "${root}"; then
        worktree_release_owned_temp
        printf '%s\n' "${WORKTREE_VALIDATION_MESSAGE}"
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
    if [[ "${effective}" != "${PROJECT_ROOT}" ]]; then
        if _worktree_validate_root "${effective}"; then
            LINT_WORKDIR="${effective}"
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
    printf '%s\n' "Environment: ${environment}"
    printf '%s\n' "Configuration in use: ${config_line}"
    return 0
}
