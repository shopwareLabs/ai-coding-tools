#!/usr/bin/env bats
# bats file_tags=dev-tooling,worktree,conformance
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

# Appends the tool_* conformance scan to the given script file: a recursive
# checker that accepts a direct call to worktree_enter or one level of
# delegation to a helper that calls it (tool_ludtwig_check/fix reach it only
# through the shared _ludtwig_run helper, per shared/worktree.sh's own docs),
# then walks every tool_* function actually defined in that process —
# `compgen -A function tool_` builds the enumeration from the live function
# set, so a stale or incomplete list cannot satisfy this check — printing
# "OK <name>" or "MISSING <name>" for each one not in EXEMPT_TOOLS.
# Written as a quoted heredoc so every "${...}" below resolves in the
# generated script when it runs, not in this outer shell.
# Requires: the generated script defines EXEMPT_TOOLS before this runs.
_append_conformance_scan() {
    local script="$1"
    cat >> "${script}" <<'SCAN'
_calls_resolver() {
    local fn="$1" depth="$2" body code_only
    body=$(declare -f "${fn}")
    # `declare -f` never carries a comment in its output — bash discards
    # comments while parsing a function body, so this strip guards against
    # nothing on its own. It is the statement-position requirement below that
    # does the real work: a bare "worktree_enter[[:space:]]+\"" substring match
    # is satisfied by a string literal holding that shape just as well as by a
    # real call, so the call must begin a line, or follow a command separator
    # (;, &&, ||) or a control keyword (then, do, else), to count.
    code_only=$(printf '%s\n' "${body}" | grep -v '^[[:space:]]*#')
    if printf '%s\n' "${code_only}" | grep -qE '(^|;|&&|\|\||[[:space:]](then|do|else))[[:space:]]*worktree_enter[[:space:]]+"'; then
        return 0
    fi
    [[ "${depth}" -le 0 ]] && return 1
    local other
    for other in $(compgen -A function); do
        [[ "${other}" == "${fn}" ]] && continue
        if printf '%s' "${body}" | grep -qw "${other}"; then
            _calls_resolver "${other}" $((depth - 1)) && return 0
        fi
    done
    return 1
}
for fn in $(compgen -A function tool_); do
    case " ${EXEMPT_TOOLS} " in
        *" ${fn} "*) continue ;;
    esac
    if _calls_resolver "${fn}" 1; then
        printf 'OK %s\n' "${fn}"
    else
        printf 'MISSING %s\n' "${fn}"
    fi
done
SCAN
}

# Sources one server's shared modules plus every lib/*.sh file it ships —
# globbed, not a hardcoded file list, so a new tool file is picked up without
# being told to — then runs the conformance scan against it.
# Args: $1 = server directory name, $2 = JS_CONTEXT value, or empty for PHP
_check_server_tools() {
    local server_dir="$1" js_context="$2"
    local script="${BATS_TEST_TMPDIR}/check-${BATS_TEST_NUMBER}.sh"
    local config_prefix="php-tooling"
    local js_context_line=""
    if [[ -n "${js_context}" ]]; then
        config_prefix="js-tooling"
        js_context_line="JS_CONTEXT=$(printf '%q' "${js_context}")"
    fi

    cat > "${script}" <<HEADER
#!/usr/bin/env bash
set -euo pipefail
PLUGIN_DIR=$(printf '%q' "${PLUGIN_DIR}")
CONFIG_PREFIX="${config_prefix}"
${js_context_line}
EXEMPT_TOOLS="tool_set_project_root tool_cwd"
log() { :; }
source "\${PLUGIN_DIR}/shared/config.sh"
source "\${PLUGIN_DIR}/shared/environment.sh"
source "\${PLUGIN_DIR}/shared/scope.sh"
PROJECT_ROOT=$(printf '%q' "${BATS_TEST_TMPDIR}")
export PROJECT_ROOT
LINT_CONFIG_FILE=$(printf '%q' "${BATS_TEST_TMPDIR}/.mcp-x.json")
LINT_ENV="native"
LINT_WORKDIR="\${PROJECT_ROOT}"
source "\${PLUGIN_DIR}/shared/worktree.sh"
worktree_state_init
trap worktree_state_cleanup EXIT
for f in "\${PLUGIN_DIR}/${server_dir}"/lib/*.sh; do
    # shellcheck disable=SC1090
    source "\${f}"
done
HEADER

    _append_conformance_scan "${script}"
    run bash "${script}"
}

@test "every php-tooling tool_* function except the two exemptions calls worktree_enter" {
    _check_server_tools mcp-server-php ""
    assert_success
    refute_output --partial "MISSING"
    assert_output --partial "OK tool_phpstan_analyze"
    assert_output --partial "OK tool_phpunit_coverage_gaps"
}

@test "every js-admin-tooling tool_* function except the two exemptions calls worktree_enter" {
    _check_server_tools mcp-server-js-admin admin
    assert_success
    refute_output --partial "MISSING"
    assert_output --partial "OK tool_lint_all"
    assert_output --partial "OK tool_lint_twig"
    assert_output --partial "OK tool_unit_setup"
    assert_output --partial "OK tool_vite_build"
}

@test "every js-storefront-tooling tool_* function except the two exemptions calls worktree_enter" {
    _check_server_tools mcp-server-js-storefront storefront
    assert_success
    refute_output --partial "MISSING"
    assert_output --partial "OK tool_webpack_build"
    assert_output --partial "OK tool_ludtwig_check"
    assert_output --partial "OK tool_ludtwig_fix"
}

# Guards the guard: a tool_* function that genuinely lacks the call, whether
# directly or through delegation, must be reported as MISSING — not silently
# absorbed by a loose grep, an early exit, or the one-level delegation
# allowance on its own.
@test "a tool function that does not call worktree_enter, directly or through delegation, is reported as MISSING" {
    local script="${BATS_TEST_TMPDIR}/negative.sh"
    cat > "${script}" <<'NEGATIVE'
#!/usr/bin/env bash
set -euo pipefail
EXEMPT_TOOLS="tool_set_project_root tool_cwd"
tool_without_resolver() { echo "no resolver call here"; }
_helper_without_resolver() { echo "no resolver call here either"; }
tool_delegates_to_empty_helper() { _helper_without_resolver; }
NEGATIVE

    _append_conformance_scan "${script}"
    run bash "${script}"
    assert_success
    assert_output --partial "MISSING tool_without_resolver"
    assert_output --partial "MISSING tool_delegates_to_empty_helper"
}

# Guards against the loosest possible false pass: a function whose only
# mention of "worktree_enter" is in a comment (documenting delegation the body
# never performs, as the fixture below does) must still be reported as
# MISSING — the name appearing in the source text is not the same as the call
# being made.
@test "a tool function mentioning worktree_enter only in a comment is reported as MISSING" {
    local script="${BATS_TEST_TMPDIR}/negative-comment.sh"
    cat > "${script}" <<'NEGATIVE'
#!/usr/bin/env bash
set -euo pipefail
EXEMPT_TOOLS="tool_set_project_root tool_cwd"
tool_mentions_resolver_in_comment() {
    # This tool relies on worktree_enter somewhere else, honest.
    echo "no call here, just the comment above"
}
NEGATIVE

    _append_conformance_scan "${script}"
    run bash "${script}"
    assert_success
    assert_output --partial "MISSING tool_mentions_resolver_in_comment"
}

# Closes the false pass: the old check matched "worktree_enter" followed by a
# quote anywhere in the body, so a string literal that happens to hold that
# shape read as a call. The call must sit at statement position to count.
@test "a tool function whose only occurrence of worktree_enter is inside a string literal is reported as MISSING" {
    local script="${BATS_TEST_TMPDIR}/negative-string-literal.sh"
    cat > "${script}" <<'NEGATIVE'
#!/usr/bin/env bash
set -euo pipefail
EXEMPT_TOOLS="tool_set_project_root tool_cwd"
tool_string_literal_only() {
    local msg='the sequence worktree_enter "never actually called" appears here'
    printf '%s\n' "${msg}"
}
NEGATIVE

    _append_conformance_scan "${script}"
    run bash "${script}"
    assert_success
    assert_output --partial "MISSING tool_string_literal_only"
}
