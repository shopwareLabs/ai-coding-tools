#!/usr/bin/env bats
# bats file_tags=mcp-core,docker-compose
# Tests the shared docker-compose module: call-time resolution of the container
# name and the container working directory, and the wrappers built from them.
# Sources the template source of truth (templates/mcp-shared/docker-compose.sh);
# every plugin copy is kept byte-identical to it by the template-sync CI check,
# so this one suite covers the module in all consuming plugins.
bats_require_minimum_version 1.11.0

load "${BATS_TEST_DIRNAME}/../test_helper/common_setup"

TEMPLATE_DIR="${REPO_ROOT}/templates/mcp-shared"

setup() {
    log() { :; }
    COMPOSE_SERVICE="web"
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    # A test here constructs container commands; none of them may run one. This
    # is what makes that a property of the suite rather than of each fixture,
    # since a stub that falls through with `command docker "$@"` bypasses a
    # shell function and would otherwise reach the real binary on any machine
    # that has docker installed.
    container_cli_refuse_real
    # environment.sh first: the wrappers quote the resolved container name with
    # its shell_quote_arg, the same order detect_environment establishes.
    source "${TEMPLATE_DIR}/environment.sh"
    source "${TEMPLATE_DIR}/docker-compose.sh"
}

teardown() {
    unset COMPOSE_SERVICE COMPOSE_WORKDIR_OVERRIDE COMPOSE_FILE_OVERRIDE PROJECT_ROOT
    unset LINT_ENV LINT_WORKDIR DOCKER_CONTAINER WORKTREE_EFFECTIVE_ROOT
    unset CONTAINER_CLI_LOG COMPOSE_CWD_LOG COMPOSE_ELSEWHERE_DIR
}

# Drive the compose CLI through a stub that records the working directory each
# invocation actually ran from, and a directory that is not the project root for
# a test to invoke from.
#
# `docker compose` discovers its project from the working directory: the file it
# reads, the project name it derives and the sources its relative binds resolve
# against all come from there. So which directory the CLI ran in is the whole of
# what the anchoring decides, and it is invisible in the string the resolver
# returns — a worktree-targeted call that ran the CLI from the worktree would
# still return a plausible container path. Recording the directory is the
# observation; nothing here executes compose.
# Globals: sets COMPOSE_CWD_LOG and COMPOSE_ELSEWHERE_DIR
_compose_record_invocations() {
    COMPOSE_CWD_LOG="${BATS_TEST_TMPDIR}/compose-invocations-cwd"
    : > "${COMPOSE_CWD_LOG}"
    COMPOSE_ELSEWHERE_DIR="${BATS_TEST_TMPDIR}/elsewhere"
    mkdir -p "${COMPOSE_ELSEWHERE_DIR}"

    docker() {
        if [[ "$1" == "compose" && "$2" == "ps" ]]; then
            printf '%s\n' "${PWD}" >> "${COMPOSE_CWD_LOG}"
            printf '{"Service":"web","Name":"shopware-web-1","State":"running"}\n'
            return 0
        fi
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            printf '%s\n' "${PWD}" >> "${COMPOSE_CWD_LOG}"
            printf '{"services":{"web":{"volumes":[{"type":"bind","source":"%s","target":"/var/www/html"}]}}}\n' \
                "${BATS_TEST_TMPDIR}"
            return 0
        fi
        command docker "$@"
    }
}

# Where the recorded invocations ran. One line per invocation, so a call that
# reaches the CLI more than once asserts every one of them.
_compose_recorded_dirs() {
    cat "${COMPOSE_CWD_LOG}"
}

# --- _compose_cmd ---

@test "_compose_cmd: returns 'docker compose' without file override" {
    COMPOSE_FILE_OVERRIDE=""
    run _compose_cmd
    assert_success
    assert_output "docker compose"
}

@test "_compose_cmd: includes -f flag with file override" {
    COMPOSE_FILE_OVERRIDE="docker/compose.yaml"
    run _compose_cmd
    assert_success
    assert_output "docker compose -f \"${BATS_TEST_TMPDIR}/docker/compose.yaml\""
}

# The result is eval'd by every caller, so an unquoted path containing a space
# would reach docker compose as two arguments and -f would take only the first.
@test "_compose_cmd: keeps a compose path containing a space in one argument" {
    COMPOSE_FILE_OVERRIDE="my docker/compose.yaml"
    run _compose_cmd
    assert_success
    assert_output "docker compose -f \"${BATS_TEST_TMPDIR}/my docker/compose.yaml\""

    # One eval, the same single parse _compose_cmd's callers perform.
    local -a argv=()
    eval "argv=( ${output} )"
    assert_equal "${#argv[@]}" 4
    assert_equal "${argv[3]}" "${BATS_TEST_TMPDIR}/my docker/compose.yaml"
}

# --- _compose_check_prerequisites ---

@test "_compose_check_prerequisites: fails when docker not installed" {
    # Use a subshell with modified PATH to hide docker
    run bash -c "
        export PATH='/nonexistent'
        source '${TEMPLATE_DIR}/docker-compose.sh' 2>/dev/null
        log() { :; }
        COMPOSE_FILE_OVERRIDE=''
        _compose_check_prerequisites
    "
    assert_failure
    assert_output --partial "docker CLI not found"
}

@test "_compose_check_prerequisites: fails when compose plugin missing" {
    # Mock docker to exist but 'docker compose version' to fail
    run bash -c "
        docker() {
            if [[ \"\$1\" == 'compose' ]]; then
                echo \"docker: 'compose' is not a docker command\" >&2
                return 1
            fi
        }
        export -f docker
        log() { :; }
        source '${TEMPLATE_DIR}/docker-compose.sh' 2>/dev/null
        COMPOSE_FILE_OVERRIDE=''
        _compose_check_prerequisites
    "
    assert_failure
    assert_output --partial "docker compose not available"
}

# --- _compose_resolve_container ---

@test "_compose_resolve_container: finds running container for service" {
    # Mock docker compose ps output (one JSON object per line)
    docker() {
        if [[ "$1" == "compose" && "$2" == "ps" ]]; then
            echo '{"Service":"database","Name":"shopware-database-1","State":"running"}'
            echo '{"Service":"web","Name":"shopware-web-1","State":"running"}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    run _compose_resolve_container
    assert_success
    assert_output "shopware-web-1"
}

# The falling back to `config` is the branch under test, so the stub answers it
# explicitly. Leaving it to the fallthrough let the real CLI run here: `config`
# fails on a machine with docker and on one without it, for different reasons
# that happened to produce the same message, so the suite passed while
# asserting nothing about which reason it got.
@test "_compose_resolve_container: fails when service not running" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "ps" ]]; then
            echo '{"Service":"database","Name":"shopware-database-1","State":"running"}'
            return 0
        fi
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            echo 'no configuration file provided: not found'
            return 1
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    run _compose_resolve_container
    assert_failure
    refute container_cli_was_invoked
    assert_output --partial "Service 'web' is not running"
    assert_output --partial "docker compose up -d web"
}

@test "_compose_resolve_container: fails when no services running and lists available" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "ps" ]]; then
            # No output = no running services
            return 0
        fi
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            echo '{"services":{"web":{},"database":{}}}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    run _compose_resolve_container
    assert_failure
    assert_output --partial "Service 'web' is not running"
}

@test "_compose_resolve_container: fails when service not defined in compose" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "ps" ]]; then
            return 0
        fi
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            echo '{"services":{"database":{},"adminer":{}}}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    run _compose_resolve_container
    assert_failure
    assert_output --partial "Service 'web' not found in compose config"
    assert_output --partial "Available services:"
}

# --- _compose_resolve_workdir ---

# The resolver answers for the root the call targets, not for the launch tree:
# answering for the launch tree is what makes a worktree call cd into the launch
# tree's container path and run there under the worktree's name.
@test "_compose_resolve_workdir: resolves the targeted root rather than the launch root" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            cat <<JSONEOF
{"services":{"web":{"volumes":[{"type":"bind","source":"${BATS_TEST_TMPDIR}","target":"/var/www/html"}]}}}
JSONEOF
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    WORKTREE_EFFECTIVE_ROOT="${BATS_TEST_TMPDIR}/.claude/worktrees/x"

    run _compose_resolve_workdir
    assert_success
    assert_output "/var/www/html/.claude/worktrees/x"
}

@test "_compose_resolve_workdir: returns config override when set" {
    COMPOSE_WORKDIR_OVERRIDE="/custom/path"
    run _compose_resolve_workdir
    assert_success
    assert_output "/custom/path"
}

@test "_compose_resolve_workdir: detects bind mount target matching project root" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            cat <<JSONEOF
{"services":{"web":{"volumes":[{"type":"bind","source":"${BATS_TEST_TMPDIR}","target":"/var/www/html"}]}}}
JSONEOF
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    run _compose_resolve_workdir
    assert_success
    assert_output "/var/www/html"
}

@test "_compose_resolve_workdir: fails when no bind mount matches project root" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            echo '{"services":{"web":{"volumes":[{"type":"volume","source":"db-data","target":"/var/lib/mysql"}]}}}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    run _compose_resolve_workdir
    assert_failure
    assert_output --partial "No bind mount for"
    assert_output --partial "docker-compose.workdir"
}

@test "_compose_resolve_workdir: fails when service has no volumes" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            echo '{"services":{"web":{}}}'
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    run _compose_resolve_workdir
    assert_failure
    assert_output --partial "No bind mount for"
}

# --- launch-root anchoring ---

# Every compose CLI invocation runs from the project root, whichever directory
# the call itself is running in. A worktree-targeted call runs its dispatch
# subshell inside the worktree, and a worktree of a checkout whose compose file
# is tracked carries that file — so an unanchored invocation resolves the
# WORKTREE as the compose project: with a relative `.:/var/www/html` bind the
# service looks absent, and with a stable project name the command runs in the
# LAUNCH checkout while the banner names the worktree. One row per call path
# that reaches the CLI, since the anchoring is a call inside each of them.

@test "anchoring: container resolution invokes the compose CLI from the launch root" {
    _compose_record_invocations
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"

    _resolve_container_from_elsewhere() {
        cd "${COMPOSE_ELSEWHERE_DIR}"
        _compose_resolve_container
    }

    run _resolve_container_from_elsewhere
    assert_success
    assert_output "shopware-web-1"
    run _compose_recorded_dirs
    assert_output "${PROJECT_ROOT}"
}

@test "anchoring: a launch-root workdir resolution invokes the compose CLI from the launch root" {
    _compose_record_invocations
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"

    _resolve_launch_workdir_from_elsewhere() {
        cd "${COMPOSE_ELSEWHERE_DIR}"
        _compose_resolve_workdir_for "${PROJECT_ROOT}/custom/plugins/X"
    }

    run _resolve_launch_workdir_from_elsewhere
    assert_success
    assert_output "/var/www/html/custom/plugins/X"
    run _compose_recorded_dirs
    assert_output "${PROJECT_ROOT}"
}

@test "anchoring: a worktree-targeted workdir resolution invokes the compose CLI from the launch root" {
    _compose_record_invocations
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"
    WORKTREE_EFFECTIVE_ROOT="${PROJECT_ROOT}/.claude/worktrees/x"

    _resolve_worktree_workdir_from_elsewhere() {
        cd "${COMPOSE_ELSEWHERE_DIR}"
        _compose_resolve_workdir
    }

    run _resolve_worktree_workdir_from_elsewhere
    assert_success
    assert_output "/var/www/html/.claude/worktrees/x"
    run _compose_recorded_dirs
    assert_output "${PROJECT_ROOT}"
}

# --- _compose_match_mount ---

# The matcher takes the mount list as an argument, so every case below runs
# against a literal pair list instead of a stubbed docker CLI.

@test "_compose_match_mount: an exact source match returns its target" {
    run _compose_match_mount "/project" $'/project\t/var/www/html' "web"
    assert_success
    assert_output "/var/www/html"
}

@test "_compose_match_mount: a parent mount carries the remainder below its target" {
    run _compose_match_mount "/project/.claude/worktrees/x" $'/project\t/var/www/html' "web"
    assert_success
    assert_output "/var/www/html/.claude/worktrees/x"
}

@test "_compose_match_mount: the longest matching source wins over a shorter one" {
    run _compose_match_mount "/project/.claude/worktrees/x" \
        $'/project\t/var/www/html\n/project/.claude/worktrees\t/var/www/worktrees' "web"
    assert_success
    assert_output "/var/www/worktrees/x"
}

@test "_compose_match_mount: a non-matching source is not a prefix match" {
    run _compose_match_mount "/projectile" $'/project\t/var/www/html' "web"
    assert_failure 1
    assert_output --partial "/projectile"
}

# The compare decides the match, so a spelling must not decide it. A compose
# file records its bind-mount source the way the shell that wrote it spelled the
# directory — on macOS "/var/..." where the filesystem reaches "/private/var/..."
# — and compared raw those two spellings of one directory read as unrelated.
@test "_compose_match_mount: a mount source spelled through a symlink still covers its tree" {
    mkdir -p "${BATS_TEST_TMPDIR}/real/project/sub"
    ln -s "${BATS_TEST_TMPDIR}/real/project" "${BATS_TEST_TMPDIR}/link"

    run _compose_match_mount "${BATS_TEST_TMPDIR}/real/project/sub" \
        "${BATS_TEST_TMPDIR}/link"$'\t/var/www/html' "web"
    assert_success
    assert_output "/var/www/html/sub"
}

@test "_compose_match_mount: refuses a path no bind mount covers, naming it" {
    run _compose_match_mount "/elsewhere" $'/project\t/var/www/html' "web"
    assert_failure 1
    assert_output --partial "/elsewhere"
    assert_output --partial "docker-compose.workdir"
}

# A source of "/" is a mount of the whole host filesystem. The separator is
# appended to the source once for the prefix test, so "/" does not become "//"
# — a pattern that matches nothing and refuses every path the mount covers.
@test "_compose_match_mount: a root source covers a path below it" {
    run _compose_match_mount "/project/src" $'/\t/mnt/host' "web"
    assert_success
    assert_output "/mnt/host/project/src"
}

@test "_compose_match_mount: a root source covers a path carrying a trailing slash" {
    run _compose_match_mount "/project/" $'/\t/mnt/host' "web"
    assert_success
    assert_output "/mnt/host/project"
}

# --- _compose_resolve_workdir_for ---

@test "_compose_resolve_workdir_for: maps a worktree below the launch root through the mount" {
    docker() {
        if [[ "$1" == "compose" && "$2" == "config" ]]; then
            cat <<JSONEOF
{"services":{"web":{"volumes":[{"type":"bind","source":"${BATS_TEST_TMPDIR}","target":"/var/www/html"}]}}}
JSONEOF
            return 0
        fi
        command docker "$@"
    }
    export -f docker
    COMPOSE_WORKDIR_OVERRIDE=""
    COMPOSE_SERVICE="web"
    COMPOSE_FILE_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"

    run _compose_resolve_workdir_for "${BATS_TEST_TMPDIR}/.claude/worktrees/x"
    assert_success
    assert_output "/var/www/html/.claude/worktrees/x"
}

@test "_compose_resolve_workdir_for: the configured override is the base for a nested root" {
    COMPOSE_WORKDIR_OVERRIDE="/custom/path"
    PROJECT_ROOT="${BATS_TEST_TMPDIR}"

    run _compose_resolve_workdir_for "${BATS_TEST_TMPDIR}/.claude/worktrees/x"
    assert_success
    assert_output "/custom/path/.claude/worktrees/x"
}

@test "_compose_resolve_workdir_for: refuses a root outside the project root" {
    COMPOSE_WORKDIR_OVERRIDE=""
    PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"

    run _compose_resolve_workdir_for "${BATS_TEST_TMPDIR}/elsewhere"
    assert_failure 1
    assert_output --partial "${BATS_TEST_TMPDIR}/elsewhere"
}

# --- _compose_wrap_command ---

@test "_compose_wrap_command: produces correct docker exec string" {
    # Mock both resolution functions
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() { echo "/var/www/html"; }
    run _compose_wrap_command "vendor/bin/phpstan analyse"
    assert_success
    assert_output "docker exec -i \"shopware-web-1\" bash -c 'cd /var/www/html && vendor/bin/phpstan analyse'"
}

@test "_compose_wrap_command: a container name carrying a command separator becomes one quoted argument" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { printf '%s\n' 'web; id'; }
    _compose_resolve_workdir() { printf '%s\n' "/var/www/html"; }
    run _compose_wrap_command "vendor/bin/phpstan analyse"
    assert_success
    assert_output "docker exec -i \"web; id\" bash -c 'cd /var/www/html && vendor/bin/phpstan analyse'"
}

@test "_compose_wrap_command: propagates prerequisite check failure" {
    _compose_check_prerequisites() {
        echo "docker CLI not found. Install Docker: https://docs.docker.com/get-docker/"
        return 1
    }
    run _compose_wrap_command "vendor/bin/phpstan analyse"
    assert_failure
    assert_output --partial "docker CLI not found"
}

@test "_compose_wrap_command: propagates container resolution failure" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() {
        echo "Service 'web' is not running. Start it with: docker compose up -d web"
        return 1
    }
    run _compose_wrap_command "vendor/bin/phpstan analyse"
    assert_failure
    assert_output --partial "Service 'web' is not running"
}

@test "_compose_wrap_command: propagates workdir resolution failure" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() {
        echo "No bind mount for /project found on service 'web'. Set docker-compose.workdir in config."
        return 1
    }
    run _compose_wrap_command "vendor/bin/phpstan analyse"
    assert_failure
    assert_output --partial "No bind mount for"
}

# --- _compose_wrap_npm_command ---

@test "_compose_wrap_npm_command: appends admin JS context path" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() { echo "/var/www/html"; }
    JS_CONTEXT="admin"
    run _compose_wrap_npm_command "npm run lint"
    assert_success
    assert_output "docker exec -i \"shopware-web-1\" bash -c 'cd /var/www/html/src/Administration/Resources/app/administration && npm run lint'"
}

@test "_compose_wrap_npm_command: appends storefront JS context path" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() { echo "/var/www/html"; }
    JS_CONTEXT="storefront"
    run _compose_wrap_npm_command "npm run lint:js"
    assert_success
    assert_output "docker exec -i \"shopware-web-1\" bash -c 'cd /var/www/html/src/Storefront/Resources/app/storefront && npm run lint:js'"
}

@test "_compose_wrap_npm_command: a container name carrying a command separator becomes one quoted argument" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { printf '%s\n' 'web; id'; }
    _compose_resolve_workdir() { printf '%s\n' "/var/www/html"; }
    JS_CONTEXT="admin"
    run _compose_wrap_npm_command "npm run lint"
    assert_success
    assert_output "docker exec -i \"web; id\" bash -c 'cd /var/www/html/src/Administration/Resources/app/administration && npm run lint'"
}

@test "_compose_wrap_npm_command: a scoped call composes its path through get_js_workdir" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() { echo "/var/www/html"; }
    JS_CONTEXT="admin"
    SCOPE_CWD="custom/plugins/X"
    SCOPE_JS_SUBDIR="tests/jest/administration"
    run _compose_wrap_npm_command "npm run unit"
    assert_success
    assert_output "docker exec -i \"shopware-web-1\" bash -c 'cd /var/www/html/custom/plugins/X/tests/jest/administration && npm run unit'"
}

# The base resolved at call time is bound for the composition and then given
# back: LINT_WORKDIR carries the call-time sentinel for docker-compose, and the
# next command built from it reads whichever value is in force.
@test "_compose_wrap_npm_command: leaves LINT_WORKDIR holding the call-time sentinel" {
    _compose_check_prerequisites() { return 0; }
    _compose_resolve_container() { echo "shopware-web-1"; }
    _compose_resolve_workdir() { echo "/var/www/html"; }
    JS_CONTEXT="admin"
    SCOPE_CWD=""
    SCOPE_JS_SUBDIR=""
    LINT_WORKDIR="(resolved at call time)"

    local rc=0
    _compose_wrap_npm_command "npm run lint" >/dev/null || rc=$?

    assert_equal "${rc}" 0
    assert_equal "${LINT_WORKDIR}" "(resolved at call time)"
}

@test "_compose_wrap_npm_command: propagates prerequisite failure" {
    _compose_check_prerequisites() {
        echo "Docker daemon is not running. Start Docker Desktop or the Docker service."
        return 1
    }
    JS_CONTEXT="admin"
    run _compose_wrap_npm_command "npm run lint"
    assert_failure
    assert_output --partial "Docker daemon is not running"
}
