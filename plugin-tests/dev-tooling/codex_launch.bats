#!/usr/bin/env bats
# bats file_tags=dev-tooling,launch
bats_require_minimum_version 1.11.0

# Starts the real servers the way each host does. Codex starts a plugin MCP
# server with its working directory at the plugin root, a cleared environment,
# and the command relative to that root; the server then has no project root
# until set_project_root binds one. Claude Code starts it in the project.

load 'test_helper/common_setup'

SOURCE_PLUGIN_DIR="${REPO_ROOT}/plugins/dev-tooling"

INITIALIZE='{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bats","version":"1"}}}'

setup() {
    # A copy laid out as an installed plugin, so the plugin root the servers
    # measure against is the copy's and their logs stay out of the checkout.
    PLUGIN="${BATS_TEST_TMPDIR}/plugin"
    mkdir -p "${PLUGIN}"
    cp -R "${SOURCE_PLUGIN_DIR}/shared" "${SOURCE_PLUGIN_DIR}/mcp-server-php" \
        "${SOURCE_PLUGIN_DIR}/mcp-server-js-admin" "${SOURCE_PLUGIN_DIR}/mcp-server-js-storefront" "${PLUGIN}/"
    rm -f "${PLUGIN}"/mcp-server-*/server.log
    PLUGIN=$(cd "${PLUGIN}" && pwd -P)

    PROJECT="${BATS_TEST_TMPDIR}/project"
    mkdir -p "${PROJECT}/src/Administration/Resources/app/administration" \
        "${PROJECT}/src/Storefront/Resources/app/storefront"
    printf '{"environment":"native"}\n' > "${PROJECT}/.mcp-php-tooling.json"
    printf '{"environment":"native"}\n' > "${PROJECT}/.mcp-js-tooling.json"
    PROJECT=$(cd "${PROJECT}" && pwd -P)

    # composer and npm stand-ins record where they ran and with what, so a
    # call that ran against the project — or ran at all — is visible.
    STUB_BIN="${BATS_TEST_TMPDIR}/bin"
    CALLS_LOG="${BATS_TEST_TMPDIR}/calls.log"
    mkdir -p "${STUB_BIN}"
    _write_stub composer
    _write_stub npm
    _write_stub ddev

    SERVER_TMP="${BATS_TEST_TMPDIR}/server-tmp"
    mkdir -p "${SERVER_TMP}"
    SERVER_ENV=()
}

_write_stub() {
    cat > "${STUB_BIN}/$1" <<STUB
#!/bin/sh
printf '%s|%s|%s\n' "$1" "\$(pwd -P)" "\$*" >> '${CALLS_LOG}'
STUB
    chmod +x "${STUB_BIN}/$1"
}

# One tools/call request line.
# Args: $1 = id, $2 = tool name, $3 = arguments JSON (default {})
_call() {
    local args="${3:-}"
    [[ -n "${args}" ]] || args='{}'
    jq -nc --argjson id "$1" --arg name "$2" --argjson args "${args}" \
        '{jsonrpc: "2.0", id: $id, method: "tools/call", params: {name: $name, arguments: $args}}'
}

# The set_project_root request binding $2.
# Args: $1 = id, $2 = project_root
_bind() {
    _call "$1" set_project_root "$(jq -nc --arg root "$2" '{project_root: $root}')"
}

# Runs one server over the given requests, preceded by initialize, with a
# cleared environment carrying HOME, PATH and TMPDIR plus SERVER_ENV.
# Args: $1 = working directory, $2 = command as the host passes it,
#       $3... = request lines
# Globals: sets RESPONSES, the file holding one response per line
_serve() {
    local cwd="$1" command="$2"
    shift 2
    local requests="${BATS_TEST_TMPDIR}/requests.jsonl"
    printf '%s\n' "${INITIALIZE}" "$@" > "${requests}"
    RESPONSES="${BATS_TEST_TMPDIR}/responses.jsonl"
    ( cd "${cwd}" && exec env -i HOME="${HOME}" PATH="${STUB_BIN}:${PATH}" TMPDIR="${SERVER_TMP}" \
        ${SERVER_ENV[@]+"${SERVER_ENV[@]}"} "${command}" ) \
        < "${requests}" > "${RESPONSES}" 2> "${BATS_TEST_TMPDIR}/server-stderr" || true
}

# Starts the server as Codex does: plugin root as cwd, command relative to it.
# Args: $1 = server directory suffix (php, js-admin, js-storefront), $2... = requests
_codex_serve() {
    local server="$1"
    shift
    _serve "${PLUGIN}" "./mcp-server-${server}/server.sh" "$@"
}

# Sets $output to the text of the response to request $1, prefixed "ERROR: "
# when the result is a tool error.
_result() {
    run jq -r --argjson id "$1" \
        'select(.id == $id) | (if .result.isError then "ERROR: " else "" end) + .result.content[0].text' "${RESPONSES}"
}

_assert_lists_tools() {
    local server="$1" name="$2"
    _codex_serve "${server}" '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

    run jq -r 'select(.id == 0) | .result.serverInfo.name' "${RESPONSES}"
    assert_output "${name}"
    run jq -r 'select(.id == 1) | .result.tools[].name' "${RESPONSES}"
    assert_line "set_project_root"
}

_assert_unbound_refusal() {
    local server="$1" name="$2" tool="$3"
    _codex_serve "${server}" "$(_call 1 "${tool}")"

    _result 1
    assert_output --partial "ERROR: Error executing ${tool}: No project root is set."
    assert_output --partial "Call \`set_project_root\` on the \`${name}\` MCP server with the absolute path of your project"
    assert [ ! -e "${CALLS_LOG}" ]
}

_assert_bound_call_runs_in() {
    local server="$1" tool="$2" expected_call="$3"
    _codex_serve "${server}" "$(_bind 1 "${PROJECT}")" "$(_call 2 "${tool}")"

    _result 2
    assert_output --partial "Project root: ${PROJECT} (launch)"
    run cat "${CALLS_LOG}"
    assert_output "${expected_call}"
}

_assert_bind_refused() {
    local root="$1" reason="$2"
    _codex_serve php "$(_bind 1 "${root}")"

    _result 1
    assert_output --partial "ERROR: Error executing set_project_root: "
    assert_output --partial "${reason}"
}

# The refusal a bind settled on is not one the server keeps: a refused root
# binds nothing, so the next ordinary call still refuses and a directory that
# does load binds afterwards.
# Args: $1 = directory to bind, $2 = expected refusal reason
_assert_bind_refused_leaves_unbound() {
    local root="$1" reason="$2"
    _codex_serve php "$(_bind 1 "${root}")" "$(_call 2 phpstan_analyze)" "$(_bind 3 "${PROJECT}")"

    _result 1
    assert_output --partial "ERROR: Error executing set_project_root: Refusing to bind \"${root}\": "
    assert_output --partial "${reason}"
    _result 2
    assert_output --partial "ERROR: Error executing phpstan_analyze: No project root is set."
    _result 3
    assert_output --partial "Project root bound: ${PROJECT} (configuration: ${PROJECT}/.mcp-php-tooling.json; environment: native)."
    assert [ ! -e "${CALLS_LOG}" ]
}

# A project directory holding one configuration file with the given content.
# Args: $1 = directory name, $2 = .mcp-php-tooling.json content
# Stdout: the directory
_project_with_config() {
    local dir="${BATS_TEST_TMPDIR}/$1"
    mkdir -p "${dir}"
    printf '%s\n' "$2" > "${dir}/.mcp-php-tooling.json"
    printf '%s\n' "${dir}"
}

@test "php-tooling started in its plugin directory answers initialize and lists its tools" {
    _assert_lists_tools php php-tooling
}

@test "js-admin-tooling started in its plugin directory answers initialize and lists its tools" {
    _assert_lists_tools js-admin js-admin-tooling
}

@test "js-storefront-tooling started in its plugin directory answers initialize and lists its tools" {
    _assert_lists_tools js-storefront js-storefront-tooling
}

@test "a bound php-tooling runs a tool in the project it was bound to" {
    _assert_bound_call_runs_in php phpstan_analyze "composer|${PROJECT}|phpstan -- --error-format=json"
}

@test "a bound js-admin-tooling runs a tool in the project's administration package" {
    _assert_bound_call_runs_in js-admin tsc_check \
        "npm|${PROJECT}/src/Administration/Resources/app/administration|run lint:types"
}

@test "a bound js-storefront-tooling runs a tool in the project's storefront package" {
    _assert_bound_call_runs_in js-storefront webpack_build \
        "npm|${PROJECT}/src/Storefront/Resources/app/storefront|run production"
}

# ddev finds its project from the directory it is run in, and a launch-root
# call enters none, so a bound server has to be standing in the project.
@test "a project bound under ddev runs its commands from the project directory" {
    printf '{"environment":"ddev"}\n' > "${PROJECT}/.mcp-php-tooling.json"

    _codex_serve php "$(_bind 1 "${PROJECT}")" "$(_call 2 phpstan_analyze)"

    run cat "${CALLS_LOG}"
    assert_output "ddev|${PROJECT}|composer phpstan -- --error-format=json"
}

# The compose resolver lives in a module a bound server loads at startup; a
# configured workdir answers without asking docker.
@test "a project bound under docker-compose resolves its configured container workdir" {
    printf '{"environment":"docker-compose","docker-compose":{"workdir":"/var/www/html"}}\n' \
        > "${PROJECT}/.mcp-php-tooling.json"

    _codex_serve php "$(_bind 1 "${PROJECT}")" "$(_call 2 cwd)"

    _result 2
    assert_line "Working directory, no scope applied: /var/www/html"
}

@test "binding a project reports the configuration and environment it loaded" {
    _codex_serve php "$(_bind 1 "${PROJECT}")"

    _result 1
    assert_output --partial "Project root bound: ${PROJECT} (configuration: ${PROJECT}/.mcp-php-tooling.json; environment: native)."
}

@test "binding the bound project again changes nothing" {
    _codex_serve php "$(_bind 1 "${PROJECT}")" "$(_bind 2 "${PROJECT}")"

    _result 2
    assert_output "Project root already bound: ${PROJECT}. Nothing changed."
}

# The bind is the server's launch root from then on, so another directory is
# held to the rules any launch root applies to a sticky root.
@test "a different directory after the bind is held to the worktree rules" {
    local other="${BATS_TEST_TMPDIR}/other"
    mkdir -p "${other}"
    _codex_serve php "$(_bind 1 "${PROJECT}")" "$(_bind 2 "${other}")"

    _result 2
    assert_output --partial "ERROR: Error executing set_project_root: Refusing to run against \"${other}\": it holds no \".git\" file"
}

# Accepting a worktree needs the bound root's common git directory, which the
# bind records for later calls the way startup records it for a bound server.
@test "a linked worktree of the bound project can become the sticky root" {
    git -C "${PROJECT}" init -q
    git -C "${PROJECT}" -c user.email=test@example.com -c user.name=Test commit -q --allow-empty -m seed
    local worktree="${PROJECT}/.claude/worktrees/feature"
    git -C "${PROJECT}" worktree add -q "${worktree}" -b feature
    worktree_gitdir_relative "${worktree}"

    _codex_serve php "$(_bind 1 "${PROJECT}")" "$(_bind 2 "${worktree}")"

    _result 2
    assert_output --partial "Sticky project root set. Effective project root: ${worktree} (sticky)."
}

# Every discovered file is merged into a temp file the bind hands to the
# process; a later call still reads it, here through the default scope only
# the second file declares.
@test "a bound project's merged configuration stays in force for later calls" {
    mkdir -p "${PROJECT}/.claude" "${PROJECT}/custom/plugins/Launch"
    printf '{"default_scope":"launch","scopes":{"launch":{"cwd":"custom/plugins/Launch"}}}\n' \
        > "${PROJECT}/.claude/.mcp-php-tooling.json"

    _codex_serve php "$(_bind 1 "${PROJECT}")" "$(_call 2 phpstan_analyze)"

    run cat "${CALLS_LOG}"
    assert_output "composer|${PROJECT}/custom/plugins/Launch|phpstan -- --error-format=json"
}

@test "a bound project's merged configuration is removed when the server exits" {
    mkdir -p "${PROJECT}/.claude"
    printf '{"default_scope":"shopware"}\n' > "${PROJECT}/.claude/.mcp-php-tooling.json"

    _codex_serve php "$(_bind 1 "${PROJECT}")"

    # The path comes from the server's log rather than from TMPDIR: macOS
    # mktemp without a template ignores TMPDIR. A missing line is the
    # precondition failing — no merge happened.
    run sed -n 's/^.*\[INFO\] Merged config created: //p' "${PLUGIN}/mcp-server-php/server.log"
    assert_output --regexp '^/.+'
    assert [ ! -e "${output}" ]
}

@test "the bind honors a configuration file named by MCP_PHP_TOOLING_CONFIG" {
    local bare="${BATS_TEST_TMPDIR}/bare-project"
    mkdir -p "${bare}"
    bare=$(cd "${bare}" && pwd -P)
    local override="${BATS_TEST_TMPDIR}/override.json"
    printf '{"environment":"native"}\n' > "${override}"
    SERVER_ENV=("MCP_PHP_TOOLING_CONFIG=${override}")

    _codex_serve php "$(_bind 1 "${bare}")"

    _result 1
    assert_output --partial "Project root bound: ${bare} (configuration: ${override}; environment: native)."
}

@test "php-tooling refuses an ordinary tool call before a project is bound" {
    _assert_unbound_refusal php php-tooling phpstan_analyze
}

@test "js-admin-tooling refuses an ordinary tool call before a project is bound" {
    _assert_unbound_refusal js-admin js-admin-tooling tsc_check
}

@test "js-storefront-tooling refuses an ordinary tool call before a project is bound" {
    _assert_unbound_refusal js-storefront js-storefront-tooling webpack_build
}

# A configuration override names a file, not a project: the plugin directory
# must not become the root the tools run in.
@test "a configuration override does not bind a server started in its plugin directory" {
    local override="${BATS_TEST_TMPDIR}/override.json"
    printf '{"environment":"native"}\n' > "${override}"
    SERVER_ENV=("MCP_PHP_TOOLING_CONFIG=${override}")

    _codex_serve php "$(_call 1 phpstan_analyze)"

    _result 1
    assert_output --partial "ERROR: Error executing phpstan_analyze: No project root is set."
    assert [ ! -e "${CALLS_LOG}" ]
}

# A host that does name a root can name one inside the plugin directory, which
# is not a project either: the plugin's own files must not become the root.
@test "a PROJECT_ROOT inside the plugin directory starts the server unbound" {
    SERVER_ENV=("PROJECT_ROOT=${PLUGIN}/mcp-server-php")

    _codex_serve php "$(_call 1 phpstan_analyze)"

    _result 1
    assert_output --partial "ERROR: Error executing phpstan_analyze: No project root is set."
    assert_output --partial "Call \`set_project_root\` on the \`php-tooling\` MCP server with the absolute path of your project"
    assert [ ! -e "${CALLS_LOG}" ]
}

@test "cwd before a project is bound reports no root and names set_project_root" {
    _codex_serve php "$(_call 1 cwd)"

    _result 1
    assert_line "Effective project root: none (unbound)"
    assert_line "Effective project root resolves: no"
    assert_output --partial "Call \`set_project_root\` on the \`php-tooling\` MCP server"
}

@test "set_project_root refuses a relative path" {
    _assert_bind_refused "project" "the project root must be an absolute path"
}

@test "set_project_root refuses a directory that does not exist" {
    _assert_bind_refused "${BATS_TEST_TMPDIR}/missing" "Refusing to bind \"${BATS_TEST_TMPDIR}/missing\": it does not exist, or it is not a directory."
}

@test "set_project_root refuses the plugin directory itself" {
    _assert_bind_refused "${PLUGIN}" "it is this server's own plugin directory ${PLUGIN}, or inside it"
}

@test "set_project_root refuses a directory inside the plugin directory" {
    _assert_bind_refused "${PLUGIN}/mcp-server-php" "it is this server's own plugin directory ${PLUGIN}, or inside it"
}

@test "set_project_root refuses a directory holding no configuration file" {
    local bare="${BATS_TEST_TMPDIR}/bare-project"
    mkdir -p "${bare}"
    _assert_bind_refused "${bare}" "it holds no configuration file for this server — one of .mcp-php-tooling.json,"
}

# load_config finds the file and succeeds whatever it holds, so the shape of
# its content is what the bind has to refuse.
@test "set_project_root refuses a configuration that is not valid JSON" {
    local broken
    broken=$(_project_with_config broken-project 'not json at all')

    _assert_bind_refused_leaves_unbound "${broken}" 'does not parse as a JSON object'
}

# Valid JSON of the wrong type reads as no keys at all through a reader that
# swallows the failure, so the type is checked before anything is read.
@test "set_project_root refuses a configuration that is a JSON array" {
    local broken
    broken=$(_project_with_config array-config-project '[1,2,3]')

    _assert_bind_refused_leaves_unbound "${broken}" 'does not parse as a JSON object'
}

@test "set_project_root refuses a configuration whose default scope is not declared" {
    local broken
    broken=$(_project_with_config unscoped-project '{"environment":"native","default_scope":"nope"}')

    _assert_bind_refused_leaves_unbound "${broken}" 'is not usable — Config error: default_scope "nope" is not declared in scopes.'
}

@test "set_project_root refuses a configuration declaring no environment" {
    local broken
    broken=$(_project_with_config environmentless-project '{"foo":1}')

    _assert_bind_refused_leaves_unbound "${broken}" 'declares no "environment" field'
}

@test "a refused bind leaves the server unbound" {
    local bare="${BATS_TEST_TMPDIR}/bare-project"
    mkdir -p "${bare}"

    _codex_serve php "$(_bind 1 "${bare}")" "$(_call 2 phpstan_analyze)"

    _result 2
    assert_output --partial "ERROR: Error executing phpstan_analyze: No project root is set."
}

# The bound launch is the Claude Code path and must behave as it always has.
@test "a server started in a project directory runs a tool there without a bind" {
    _serve "${PROJECT}" "${PLUGIN}/mcp-server-php/server.sh" "$(_call 1 phpstan_analyze)"

    _result 1
    assert_output --partial "Project root: ${PROJECT} (launch)"
    run cat "${CALLS_LOG}"
    assert_output "composer|${PROJECT}|phpstan -- --error-format=json"
}
