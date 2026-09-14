#!/usr/bin/env bash
# MCP Server Core - JSON-RPC 2.0 Protocol Handler
# Based on Model Context Protocol specification
# Requires: bash 4.1+, jq 1.7+

# Pre-flight dependency guards for the two floors the header line declares.
# This block alone uses no construct newer than bash 3.2, sits above the file's
# own `set -euo pipefail`, and diagnoses on stderr. AGENTS.md §Pre-flight
# guards.

# Print remediation lines for a failed dependency check. `dep` is `bash` or
# `jq`. Output lands on stdout so the function stays pure and testable, which
# makes the `>&2` at every call site mandatory: a call site that forgets it
# writes the hint into the JSON-RPC stream. `uname` is the only external command
# reached for, and an absent or failing `uname` falls through to the generic
# line rather than failing the hint.
_mcp_install_hint() {
    local dep="$1"

    local floor="${dep}"
    case "${dep}" in
        bash) floor="bash 4.1 or newer" ;;
        jq) floor="jq 1.7 or newer" ;;
    esac

    local platform=""
    if command -v uname >/dev/null 2>&1; then
        platform=$(uname -s 2>/dev/null) || platform=""
    fi

    case "${platform}" in
        Darwin)
            # Probe for brew, as the Linux arm probes its package managers: a
            # Mac with no Homebrew — MacPorts, nix, a managed image — would
            # otherwise be handed a command that does not exist. The generic
            # line stands in for it, so such a Mac still gets remediation.
            if command -v brew >/dev/null 2>&1; then
                printf '%s\n' "  brew install ${dep}"
            else
                printf '%s\n' "  install ${floor} with your platform's package manager"
            fi
            if [[ "${dep}" == "bash" ]]; then
                # The install on its own changes nothing: macOS keeps 3.2.57 at
                # /bin/bash, and both usual launch paths — a
                # `#!/usr/bin/env bash` shebang, and a host manifest whose
                # command is `bash` — resolve through PATH. A GUI-launched MCP
                # host reads no shell profile, so the PATH it hands the server
                # is the one that has to be ordered. Printed whether or not brew
                # was found: a GUI host hands the server a PATH with no brew on
                # it, and that is precisely the case where the fix is a PATH
                # fix, so this advice cannot sit inside the brew probe.
                printf '%s\n' "  then place its directory before /usr/bin in the PATH the MCP host launches this server with"
            fi
            return 0
            ;;
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                printf '%s\n' "  apt-get install ${dep}"
                return 0
            fi
            if command -v apk >/dev/null 2>&1; then
                printf '%s\n' "  apk add ${dep}"
                return 0
            fi
            if command -v dnf >/dev/null 2>&1; then
                printf '%s\n' "  dnf install ${dep}"
                return 0
            fi
            ;;
    esac

    printf '%s\n' "  install ${floor} with your platform's package manager"
    return 0
}

# Whether bash <major>.<minor> is at or above the 4.1 floor. Takes the version
# as arguments so a suite can drive it from a table. AGENTS.md §Pre-flight
# guards. A non-numeric or empty component reads as below the floor.
_mcp_bash_meets_floor() {
    local major="${1:-}"
    local minor="${2:-}"

    case "${major}" in ''|*[!0-9]*) return 1 ;; esac
    case "${minor}" in ''|*[!0-9]*) return 1 ;; esac

    # Arithmetic comparison, with `10#` forcing base 10: the guards above admit
    # any all-digit string, and a leading zero is otherwise read as octal, where
    # `08` is not a number and bash writes its own complaint to stderr.
    # `(( ))` rather than `[[ -gt ]]`: both evaluate an operand arithmetically
    # and agree on every value that reaches them here, but ShellCheck's SC2309
    # flags a built-up operand handed to `[[ ]]`'s numeric operators, and the
    # arithmetic form states the intent without needing a directive.
    if (( 10#${major} > 4 )); then
        return 0
    fi
    if (( 10#${major} == 4 && 10#${minor} >= 1 )); then
        return 0
    fi
    return 1
}

# Whether a raw `jq --version` string is at or above the 1.7 floor.
# The comparison is numeric, not lexical: `jq-1.10` is above `jq-1.7` and a
# string comparison gets that backwards. A patch component, and any distro
# suffix — attached to the minor or trailing the patch — is ignored, so
# `jq-1.7.1-Debian-1` and `jq-1.7-Debian-1` are both above the floor.
# Anything that does not parse as `jq-<major>.<minor>` is below it, a
# prerelease included: `jq-1.7rc1` is not evidence of released 1.7 behavior,
# and refusing what cannot be read is the direction that fails loudly.
# The `case`-based technique is the one the test images use
# (docker/debian.Dockerfile, docker/alpine.Dockerfile), but this helper admits a
# non-numeric patch or distro suffix they reject: the images gate their own
# build, where a version they cannot fully parse is a reason to fail it, while
# this helper decides whether a consumer's server may run.
_mcp_jq_meets_floor() {
    local raw="${1:-}"

    case "${raw}" in
        jq-*) ;;
        *) return 1 ;;
    esac

    local version="${raw#jq-}"
    case "${version}" in
        *.*) ;;
        *) return 1 ;;
    esac

    local major="${version%%.*}"
    local rest="${version#*.}"
    local minor="${rest%%.*}"
    # A distro suffix may attach to the minor with no patch component between
    # them (`jq-1.8-1`); strip it so it cannot reach the digit guard and refuse a
    # version that meets the floor. jq's own prereleases append alphanumerics
    # with no hyphen (`jq-1.7rc1`) and stay refused; a hyphenated one would
    # survive this strip, and no jq release carries one. Major is left
    # unstripped: no real version needs it.
    minor="${minor%%-*}"

    case "${major}" in ''|*[!0-9]*) return 1 ;; esac
    case "${minor}" in ''|*[!0-9]*) return 1 ;; esac

    # Same shape and same reason as _mcp_bash_meets_floor: a leading zero would
    # otherwise be read as octal, and `jq-1.08` would fail arithmetically rather
    # than compare.
    if (( 10#${major} > 1 )); then
        return 0
    fi
    if (( 10#${major} == 1 && 10#${minor} >= 7 )); then
        return 0
    fi
    return 1
}

# bash floor. Below 4.1 the file still parses, so there is no early error to go
# on: `run_mcp_server` dies on the `exec {_MCP_LIFELINE_FD}<>` redirection with
# `{_MCP_LIFELINE_FD}: not found`, which an MCP host reports as nothing more
# than a server that failed to start.
if [[ -z "${BASH_VERSINFO[0]:-}" ]] \
    || ! _mcp_bash_meets_floor "${BASH_VERSINFO[0]:-}" "${BASH_VERSINFO[1]:-}"; then
    printf '%s\n' "bash-mcp-sdk: bash 4.1 or newer is required; this shell reports ${BASH_VERSION:-unknown}." >&2
    _mcp_install_hint bash >&2
    # `return` when this file is sourced, `exit` when it is executed; the
    # complaint `return` raises outside a function is suppressed because it is
    # only ever raised on the executed path.
    # Known gap: a consumer that sources this file without `set -e` carries on
    # past the refusal and reaches `run_mcp_server: command not found`, with the
    # message above already on stderr. An unconditional `exit` would close that
    # gap and take the BATS runner down with it — the suites source this file
    # into the test process.
    # shellcheck disable=SC2317 # `return` succeeds only on the sourced path; on the executed path it fails and `exit 1` is what runs.
    return 1 2>/dev/null || exit 1
fi

# jq presence.
if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' "bash-mcp-sdk: jq was not found on PATH; jq 1.7 or newer is required." >&2
    _mcp_install_hint jq >&2
    # shellcheck disable=SC2317 # `return` succeeds only on the sourced path; on the executed path it fails and `exit 1` is what runs.
    return 1 2>/dev/null || exit 1
fi

# jq floor. Below 1.7 the server starts and answers every request, and the
# damage is silent: `validate_tool_arguments` reads a number back through
# `tojson` to catch a fraction the conversion to a double rounded away, and
# that depends on jq preserving the number literal — jq 1.7's "use decimal
# number literals to preserve precision". Older jq parses every number to a
# double, so `4503599627370496.5` renders whole and passes as an integer.
# Probed once here, at source time, never on the request path.
_mcp_jq_version=$(jq --version 2>/dev/null) || _mcp_jq_version=""
if ! _mcp_jq_meets_floor "${_mcp_jq_version}"; then
    if [[ -z "${_mcp_jq_version}" ]]; then
        # The presence check above resolved a path, so jq is installed; it just
        # did not answer. Wrong architecture, a missing shared library, a file
        # that cannot execute. Naming the resolved path points the operator at
        # the binary that is broken, and neither a version nor the
        # distro-package warning below applies to a jq that is already on the
        # machine.
        printf '%s\n' "bash-mcp-sdk: jq was found on PATH but could not be run; jq 1.7 or newer is required." >&2
        printf '%s\n' "  the jq at $(command -v jq) did not answer 'jq --version'" >&2
    else
        printf '%s\n' "bash-mcp-sdk: jq 1.7 or newer is required; jq reports '${_mcp_jq_version}'." >&2
        printf '%s\n' "  a distribution package may itself sit below the floor; a newer jq may have to come from elsewhere" >&2
    fi
    _mcp_install_hint jq >&2
    # shellcheck disable=SC2317 # `return` succeeds only on the sourced path; on the executed path it fails and `exit 1` is what runs.
    return 1 2>/dev/null || exit 1
fi
unset _mcp_jq_version

set -euo pipefail

: "${MCP_CONFIG_FILE:=config.json}"
: "${MCP_TOOLS_LIST_FILE:=tools.json}"
: "${MCP_LOG_FILE:=/dev/null}"
: "${MCP_EXTRA_LOG_FILE:=}"
: "${MCP_LOG_STDERR:=0}"

# Seconds a cancelled tool call gets to die after SIGTERM before SIGKILL, and
# a tool_<name>_cancel hook gets before it is abandoned. Internal constant:
# the README configuration table lists the MCP_* variables a consumer sets,
# and this is not one of them.
# Guarded so the file can be sourced twice in one shell: a second `readonly` on
# a name the first source already marked fails under `set -e` and takes the
# shell with it.
if [[ -z "${_MCP_CANCEL_GRACE_SECONDS:-}" ]]; then
    readonly _MCP_CANCEL_GRACE_SECONDS=2
fi

log() {
    local level="$1"
    local message="$2"
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
    echo "$line" >> "$MCP_LOG_FILE"
    [[ -n "${MCP_EXTRA_LOG_FILE}" ]] && echo "$line" >> "$MCP_EXTRA_LOG_FILE"
    [[ "${MCP_LOG_STDERR}" == "1" ]] && printf '%s\n' "$line" >&2
    return 0
}

# Configure an additional log file from user config.
# Relative paths are resolved against PROJECT_ROOT.
# If the parent directory does not exist, logs a warning and skips.
_configure_extra_log_file() {
    local raw_path="${1:-}"
    [[ -z "$raw_path" ]] && return 0

    local resolved="$raw_path"
    if [[ "$raw_path" != /* ]]; then
        resolved="${PROJECT_ROOT}/${raw_path}"
    fi

    local parent_dir
    parent_dir="$(dirname "$resolved")"
    if [[ ! -d "$parent_dir" ]]; then
        log "WARN" "log_file parent directory does not exist: ${parent_dir} — extra log file disabled"
        return 0
    fi

    MCP_EXTRA_LOG_FILE="$resolved"
    export MCP_EXTRA_LOG_FILE
    log "INFO" "Extra log file configured: ${MCP_EXTRA_LOG_FILE}"
}

# Read one JSON document from a file and print it compact when it is a JSON
# object; prints nothing and returns 1 otherwise. README.md §API.
# The callers both hand this output to `--argjson` and index it — `.tools` in
# handle_tools_list, `.protocolVersion`, `.serverInfo` and `.capabilities` in
# handle_initialize — so only an object is usable: an index of any other type
# either errors or yields `null` in place of the caller's key, and a `null` or
# `false` document is that accident rather than a configuration. Never a
# fallback: each caller answers the failure instead of treating the
# configuration as empty, so a degraded result is not passed off as a correct
# one. `jq -e` is not used to decide the parse — its exit status comes from the
# truthiness of the output rather than from whether the input parsed, and the
# object test this function needs is made explicitly in the program below.
read_json_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log "ERROR" "File not found: $file"
        return 1
    fi
    local parsed
    if ! parsed=$(jq -cs 'if length == 1 and (.[0] | type) == "object" then .[0] else ("expected exactly one JSON object" | halt_error) end' -- "$file" 2>/dev/null); then
        log "ERROR" "Not exactly one parseable JSON object: ${file}"
        return 1
    fi
    printf '%s\n' "$parsed"
}

create_response() {
    local id="$1"
    local result="$2"

    jq -n -c \
        --argjson id "$id" \
        --argjson result "$result" \
        '{"jsonrpc": "2.0", "id": $id, "result": $result}'
}

create_error_response() {
    local id="$1"
    local code="$2"
    local message="$3"
    local data="${4:-}"

    if [[ -z "$data" ]]; then
        jq -n -c \
            --argjson id "$id" \
            --argjson code "$code" \
            --arg message "$message" \
            '{"jsonrpc": "2.0", "id": $id, "error": {"code": $code, "message": $message}}'
    else
        jq -n -c \
            --argjson id "$id" \
            --argjson code "$code" \
            --arg message "$message" \
            --argjson data "$data" \
            '{"jsonrpc": "2.0", "id": $id, "error": {"code": $code, "message": $message, "data": $data}}'
    fi
}

handle_initialize() {
    local id="$1"
    local params="$2"

    log "INFO" "Handling initialize request"

    local config
    if ! config=$(read_json_file "$MCP_CONFIG_FILE"); then
        create_error_response "$id" -32603 "Cannot read server configuration: ${MCP_CONFIG_FILE}"
        return
    fi

    local result
    result=$(jq -n -c \
        --argjson config "$config" \
        '{
            "protocolVersion": ($config.protocolVersion // "2024-11-05"),
            "serverInfo": ($config.serverInfo // {"name": "mcp-server", "version": "1.0.0"}),
            "capabilities": ($config.capabilities // {"tools": {}})
        }')

    create_response "$id" "$result"
}

handle_tools_list() {
    local id="$1"

    log "INFO" "Handling tools/list request"

    local tools_config
    if ! tools_config=$(read_json_file "$MCP_TOOLS_LIST_FILE"); then
        create_error_response "$id" -32603 "Cannot read tools list: ${MCP_TOOLS_LIST_FILE}"
        return
    fi

    local tools
    tools=$(echo "$tools_config" | jq -c '.tools // []')

    local result
    result=$(jq -n -c --argjson tools "$tools" '{"tools": $tools}')

    create_response "$id" "$result"
}

# Validate call arguments against the tool's declared inputSchema, rejecting
# arguments that are not a JSON object. The enforced keywords, the union-type
# rule, the range-bound rule and the diagnostic precedence order are
# README.md §API.
# A declared `integer` is satisfied by a whole-valued number, decided from the
# number as jq renders it and not from its double value alone, so a fractional
# literal at or above 2^52 = 4503599627370496 is rejected instead of being read
# as whole; a rendering that carries an exponent keeps the double-based verdict,
# which admits a fractional value below the smallest subnormal double.
# A tool with no entry in the tools list, or whose entry declares no
# inputSchema, is not validated. A tools list that cannot be read is a
# rejection, whether it is missing, unparseable, or holds a document that is
# not a JSON object, so an unreadable list never becomes a silent skip. A jq
# failure is a rejection and never a skip:
# a validator that could not evaluate its input has not validated it, and
# reporting success there would wave every constraint through. That branch is
# defense-in-depth for a direct call rather than a live remote-input guard —
# process_request admits only one JSON document per line and answers anything
# that is not a JSON object before dispatch, so arguments arriving over the
# protocol are always parseable JSON. The non-object branch is NOT in that
# category: `null`, `false` and every other JSON scalar are parseable, and
# `arguments` may be any JSON value, so a client can send them and they reach
# this validator.
# Args: $1 = tool name, $2 = arguments JSON
# On violation: prints a human-readable message to stdout and returns 1.
validate_tool_arguments() {
    local tool_name="$1"
    local arguments="$2"

    local tools_config schema rc
    # errexit is off inside this function — handle_tools_call tests it in a
    # conditional — so each failure below is handled explicitly rather than
    # left to the call site's shape. A tools list that cannot be read is a
    # rejection and never a skip: a validator that could not read its schemas
    # has not validated anything, and reporting success there would wave every
    # declared constraint through, which is how the absent-list fallback read.
    # The jq failure below is a second such branch. read_json_file's object
    # gate catches a file-borne document that is not an object in the branch
    # above, but the jq branch stays reachable through a file: an object whose
    # `tools` holds a non-object element passes the gate, and `select` then
    # errors on that element — the trailing `?` guards only the iteration.
    rc=0
    tools_config=$(read_json_file "$MCP_TOOLS_LIST_FILE" 2>/dev/null) || rc=$?
    if [[ $rc -ne 0 ]]; then
        printf '%s' "Cannot validate arguments for ${tool_name}: the tool list at ${MCP_TOOLS_LIST_FILE} is missing or does not hold one JSON object."
        return 1
    fi
    rc=0
    schema=$(echo "$tools_config" | jq -c --arg n "$tool_name" \
        '(.tools[]? | select(.name == $n) | .inputSchema) // empty' 2>/dev/null) || rc=$?
    if [[ $rc -ne 0 ]]; then
        printf '%s' "Cannot validate arguments for ${tool_name}: the tool list at ${MCP_TOOLS_LIST_FILE} does not hold a usable tools list."
        return 1
    fi
    [[ -z "$schema" || "$schema" == "null" ]] && return 0

    # A non-object `arguments` is rejected in the first branch because every
    # constraint below reads `$args | keys`, which errors on any other type and
    # would take the whole schema down with it.
    local message
    rc=0
    message=$(jq -n -r \
        --argjson schema "$schema" \
        --argjson args "$arguments" \
        '
        # A declared `type` is one name or a list of alternatives, so it is
        # normalized to a list and one comparison serves both forms.
        # `"integer"` treats a whole-valued JSON number as satisfying it (JSON
        # has no distinct integer type); every other name is a plain jq `type`
        # comparison.
        def type_names(want):
            if (want | type) == "array" then want else [want] end;
        # The whole-value test reads the number as jq renders it as well as its
        # double value. `floor` converts its input to an IEEE-754 double, and at
        # or above 2^52 = 4503599627370496 the double spacing reaches 1, so a
        # literal such as `4503599627370496.5` is already whole as a double and
        # `floor` cannot see the fraction the check exists to find. `tojson`
        # renders the number from the literal jq parsed, which still carries it.
        # `floor` is kept as a conjunct rather than replaced: it rejects, at the
        # cost of one comparison, every non-integer whose fraction survives the
        # conversion to a double, leaving the literal test only what the double
        # rounded away.
        # Known gap, not an oversight: expanding an exponent rendering exactly
        # would mean decimal arithmetic in jq, so a rendering that keeps an
        # exponent falls back to the double-based verdict alone. jq renders an
        # exponent when the value is an exact multiple of ten — necessarily an
        # integer, so no gap there — or when its magnitude is below about
        # 1e-6, where `floor` still rejects a fraction unless the double
        # underflows to zero. What the gap admits is therefore a fractional
        # value smaller than the smallest subnormal double: `1.5e-400` is
        # accepted as an integer.
        def type_ok(want; val):
            any(type_names(want)[];
                if . == "integer" then
                    (val | type) == "number"
                    and (val == (val | floor))
                    and ((val | tojson) as $literal
                         | if ($literal | test("[eE]")) then true
                           else ($literal | test("\\.[0-9]*[1-9]") | not)
                           end)
                else
                    (val | type) == .
                end);
        # Only reached after `type_ok` failed, so a number here has already
        # failed every declared alternative: with `integer` offered it is
        # necessarily non-integer and reads "number (non-integer)". A list
        # offering `number` accepts every number, so the `number` conjunct
        # cannot fire at either call site — it keeps the label correct if the
        # function is ever called somewhere `type_ok` did not gate.
        def type_label(want; val):
            (type_names(want)) as $w
            | if (val | type) == "number"
                 and ($w | index("integer")) != null
                 and ($w | index("number")) == null then
                "number (non-integer)"
              else
                (val | type)
              end;
        def type_expected(want):
            type_names(want) | join(" or ");
        if ($args | type) != "object" then
            "Invalid arguments: expected a JSON object, got "
            + ($args | type) + "."
        else
          ($schema.required // [])               as $req
        | ($args | keys)                        as $present
        | (($schema.properties // {}) | keys)   as $allowed
        | (($schema.properties // {}))          as $props
        | [ $req[]     | . as $r | select(($present | index($r)) == null) ] as $missing
        | ( if ($schema.additionalProperties == false)
            then [ $present[] | . as $p | select(($allowed | index($p)) == null) ]
            else [] end )                        as $unknown
        | [ $present[] | . as $p
            | ($props[$p].type // empty)          as $t
            | select($t != null)
            | (type_names($t))                     as $tn
            # A malformed `type` — an empty list, or one carrying a non-string
            # member — is left unenforced rather than rejecting every value.
            | select(($tn | length) > 0 and all($tn[]; type == "string"))
            | ($args[$p])                          as $v
            | select((type_ok($t; $v)) | not)
            | {p: $p, expected: type_expected($t), actual: type_label($t; $v), v: $v}
          ]                                      as $invalid_type
        | [ $present[] | . as $p
            | ($props[$p].pattern // empty)       as $pat
            | select($pat != null)
            | ($args[$p])                          as $v
            | select(($v | type) == "string")
            | select(($v | test($pat)) | not)
            | {p: $p, pattern: $pat, v: $v}
          ]                                      as $invalid_pattern
        | [ $present[] | . as $p
            | ($args[$p])                          as $v
            # The number gate mirrors how `pattern` skips a non-string value.
            # Where a `type` is declared, a non-number already failed the type
            # check; where none is, a range keyword must not start rejecting
            # strings. jq types `true` as "boolean", so a boolean is skipped
            # here too and never coerced to 1 or 0.
            | select(($v | type) == "number")
            # A property absent from `properties` yields null, and `// {}`
            # keeps the field access below valid: a property permitted by
            # `additionalProperties` carries no bound and no offender.
            | ($props[$p] // {})                   as $ps
            # A malformed or absent bound is left unenforced, mirroring the
            # malformed-`type` policy above: `select(type == "number")` yields
            # zero outputs for an absent or non-number bound, and a
            # zero-output expression contributes no element to the array
            # constructor. That also leaves the JSON Schema draft-04 boolean
            # form `"exclusiveMinimum": true` unenforced — its modifier
            # semantics are not implemented here.
            | ( [ ($ps.minimum          | select(type == "number") | {rel: "below minimum",              bound: ., ok: ($v >= .)}),
                  ($ps.maximum          | select(type == "number") | {rel: "above maximum",              bound: ., ok: ($v <= .)}),
                  ($ps.exclusiveMinimum | select(type == "number") | {rel: "not above exclusiveMinimum", bound: ., ok: ($v >  .)}),
                  ($ps.exclusiveMaximum | select(type == "number") | {rel: "not below exclusiveMaximum", bound: ., ok: ($v <  .)}) ][] )
            | select(.ok | not)
            | {p: $p, rel: .rel, bound: .bound, v: $v}
          ]                                      as $out_of_range
        | [ $present[] | . as $p
            | ($props[$p].items // empty)         as $items
            | select($items != null)
            | ($args[$p])                          as $v
            | select(($v | type) == "array")
            # Plain field access, not `// empty`: `.items` may declare only
            # one of `type`/`enum`. A missing key yields `null` here (one
            # output), so the other, present constraint still reaches the
            # comprehension below. `// empty` on either would yield zero
            # outputs when that key is absent, and an `as` binding with zero
            # outputs runs its body zero times — silently discarding every
            # element of this property, including violations of the
            # constraint that *was* declared.
            | ($items.type)                        as $it
            | ($items.enum)                        as $ie
            | ( $v | to_entries[]
                | . as $entry
                | ($entry.value)                    as $ev
                | ($entry.key)                       as $idx
                | if ($it != null
                      and ((type_names($it)) as $itn
                           | ($itn | length) > 0 and all($itn[]; type == "string"))
                      and (type_ok($it; $ev) | not)) then
                    {p: $p, index: $idx, issue: "type", expected: type_expected($it), actual: type_label($it; $ev), v: $ev}
                  elif ($ie != null and ($ie | index($ev)) == null) then
                    {p: $p, index: $idx, issue: "enum", enum: $ie, v: $ev}
                  else empty end
              )
          ]                                      as $invalid_items
        | [ $present[] | . as $p
            | ($props[$p].enum // empty) as $enum
            | ($args[$p])                            as $v
            | select(($enum | index($v)) == null)
            | {p: $p, v: $v, enum: $enum}
          ]                                      as $invalid_enum
        | if   ($missing | length) > 0 then
            "Missing required parameter(s): " + ($missing | join(", ")) + "."
          elif ($unknown | length) > 0 then
            "Unknown parameter(s): " + ($unknown | join(", "))
            + ". Allowed parameters: " + ($allowed | join(", ")) + "."
          elif ($invalid_type | length) > 0 then
            "Invalid type(s): " + ($invalid_type | map(
                .p + " expected " + .expected + ", got " + .actual
                + " (" + (.v | tojson) + ")"
              ) | join("; ")) + "."
          elif ($invalid_pattern | length) > 0 then
            "Invalid value(s): " + ($invalid_pattern | map(
                .p + "=" + (.v | tojson) + " does not match pattern " + .pattern
              ) | join("; ")) + "."
          elif ($out_of_range | length) > 0 then
            "Out-of-range value(s): " + ($out_of_range | map(
                .p + "=" + (.v | tojson) + " " + .rel + " " + (.bound | tojson)
              ) | join("; ")) + "."
          elif ($invalid_items | length) > 0 then
            "Invalid array item(s): " + ($invalid_items | map(
                if .issue == "type" then
                  .p + "[" + (.index | tostring) + "] expected " + .expected
                  + ", got " + .actual + " (" + (.v | tojson) + ")"
                else
                  .p + "[" + (.index | tostring) + "]=" + (.v | tojson)
                  + " (allowed: " + (.enum | join(", ")) + ")"
                end
              ) | join("; ")) + "."
          elif ($invalid_enum | length) > 0 then
            "Invalid value(s): " + ($invalid_enum | map(
                .p + "=\"" + (.v | tostring) + "\" (allowed: " + (.enum | join(", ")) + ")"
              ) | join("; ")) + "."
          else "" end
        end
        ' 2>/dev/null) || rc=$?
    if [[ $rc -ne 0 ]]; then
        printf '%s' "Cannot validate arguments for ${tool_name}: they could not be evaluated against its schema."
        return 1
    fi

    if [[ -n "$message" ]]; then
        printf '%s' "$message"
        return 1
    fi
    return 0
}

# Clear what a tool body must not inherit from the dispatch that runs it: a
# nested dispatch that kept the server-loop state would stop the server as soon
# as the outer call returned. docs/architecture.md §Tool containment.
# A nested dispatch needing cancellation or deferred replay of its own is out of
# scope; this restores the plain-call shape a direct caller gets.
_reset_tool_dispatch_state() {
    _MCP_IN_SERVER_LOOP=0
    unset _MCP_SHUTDOWN_FLAG_FILE _MCP_INFLIGHT_FILE _MCP_PARTIAL_FILE
}

handle_tools_call() {
    local id="$1"
    local params="$2"

    # A tools/call carries its arguments in a params object, so a params of any
    # other type is an Invalid params. This gate runs before `.name` and
    # `.arguments` are read, so those extractions only ever see an object and
    # none of them can fail. That is what makes the crash fix a property of this
    # function rather than of its caller: under `set -o posix` bash inherits
    # errexit into the command substitution those extractions run in, and a
    # failed one ends the whole server instead of answering the request. It also
    # keeps a non-object params' `Cannot index ...` jq diagnostics off the
    # process's stderr, unrouted through `log`. And it makes handle_tools_call
    # safe as a direct public entry point on its own: a caller passing invalid
    # JSON makes the `type` substitution print nothing, which is not "object",
    # so the gate fails closed.
    if [[ "$(printf '%s\n' "$params" | jq -r 'type')" != "object" ]]; then
        log "ERROR" "tools/call params is not a JSON object"
        create_error_response "$id" -32602 "Invalid params: expected an object"
        return
    fi

    local tool_name
    tool_name=$(echo "$params" | jq -r '.name // ""')

    # `.arguments // {}` would substitute {} for a present `null` or `false`,
    # because jq's `//` treats both as absent — the validator's non-object
    # branch would then never see either. Only a genuinely absent key defaults.
    local arguments
    arguments=$(echo "$params" | jq -c 'if has("arguments") then .arguments else {} end')

    log "INFO" "Handling tools/call: $tool_name"

    # Prevents command injection via tool name
    if [[ ! "$tool_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        create_error_response "$id" -32602 "Invalid tool name: $tool_name"
        return
    fi

    local func_name="tool_${tool_name}"
    if ! type "$func_name" &>/dev/null; then
        create_error_response "$id" -32601 "Tool not found: $tool_name"
        return
    fi

    local validation_error
    if ! validation_error=$(validate_tool_arguments "$tool_name" "$arguments"); then
        log "ERROR" "Tool $tool_name argument validation failed: $validation_error"
        local invalid_result
        invalid_result=$(jq -n -c \
            --arg text "$validation_error" \
            '{"content": [{"type": "text", "text": $text}], "isError": true}')
        create_response "$id" "$invalid_result"
        return
    fi

    # The tool runs in the background under `set -m` so an in-flight call can be
    # cancelled by process group. Job-control notices exist only for interactive
    # shells, so the `set -m` here adds nothing to stderr.
    # docs/architecture.md §Tool containment.
    local output_file
    output_file=$(mktemp "${TMPDIR:-/tmp}/mcp-tool-output.XXXXXX")
    # Where the wrapper below records the sentinel's pid; _sentinel_pid_file
    # carries the derivation and its reason.
    local sentinel_file
    sentinel_file="$(_sentinel_pid_file "$output_file")"
    local pid
    local monitor_was_enabled=0
    if [[ -o monitor ]]; then
        monitor_was_enabled=1
    fi
    set -m
    # A lifeline is identified by its directory and FIFO, never by
    # _MCP_LIFELINE_FD: process_request closed and cleared that descriptor on
    # the way in, so it is empty here on the one path that has a lifeline.
    if [[ -n "${_MCP_LIFELINE_DIR:-}" && -p "${_MCP_LIFELINE_DIR}/lifeline" ]]; then
        # The wrapper opens its own reader before it starts the tool, so a
        # server already gone leaves the wrapper blocked instead of starting an
        # orphaned tool.
        # The sentinel-pid record is best effort like the in-flight file. A
        # wrapper that cannot write it leaves the group's raw liveness as the
        # teardown's only measure, which is slower but not wrong.
        # docs/architecture.md §Tool containment.
        ( exec {lifeline_rd}<"${_MCP_LIFELINE_DIR}/lifeline"; _lifeline_sentinel "${lifeline_rd}" & sentinel_pid=$!; set +e; printf '%s\n' "$sentinel_pid" > "${sentinel_file}"; _reset_tool_dispatch_state; "$func_name" "$arguments" ) \
            >"$output_file" 2>&1 </dev/null &
    else
        # No lifeline: run_mcp_server never ran in this shell, so there is
        # nothing for a sentinel to watch. The wrapper keeps the shape of the
        # loop-driven path, so both give the tool the same process group.
        ( set +e; _reset_tool_dispatch_state; "$func_name" "$arguments" ) >"$output_file" 2>&1 </dev/null &
    fi
    pid=$!
    if [[ "$monitor_was_enabled" == "1" ]]; then
        set -m
    else
        set +m
    fi

    # The tool's process group, its name and its output file are written where a
    # trap can read them back: the main shell cannot see inside the command
    # substitution this dispatches in, and the output file's path exists nowhere
    # else once this dispatch is gone. docs/architecture.md §The in-flight record.
    if [[ "${_MCP_IN_SERVER_LOOP:-0}" == "1" && -n "${_MCP_INFLIGHT_FILE:-}" ]]; then
        printf '%s %s %s\n' "$pid" "$tool_name" "$output_file" > "${_MCP_INFLIGHT_FILE}"
    fi

    # The poll below reads the client's stdin, and only run_mcp_server's read
    # loop owns that stream. A caller that invokes this function directly owns
    # its own stdin instead, so it gets the same background child in the same
    # process group but a plain blocking wait: reading there would consume
    # bytes the caller means to handle, and an EOF on that stream is the
    # caller's business rather than a cancellation.
    if [[ "${_MCP_IN_SERVER_LOOP:-0}" == "1" ]]; then
        _await_tool_call "$id" "$pid" "$tool_name" "$arguments" "$output_file"
    else
        _wait_tool_call "$pid" "$tool_name" "$output_file"
    fi

    # The call's files are released and the in-flight record truncated before
    # anything is built from them, so neither the response construction nor the
    # deferred replay below can run ahead of the clear.
    # The output file and the sentinel pid file go first and the record second:
    # those two paths exist nowhere but this subshell, so a teardown landing
    # between the steps reads a record naming a path this dispatch has already
    # released, and its removal is idempotent, so it loses nothing.
    # docs/architecture.md §The in-flight record.
    local output=""
    if [[ "$_MCP_CANCELLED" -eq 1 ]]; then
        # A cancelled call was already answered by its teardown, which sends no
        # response for the id, so its output is discarded and only the call's
        # files are left to drop here.
        rm -f -- "$output_file" "$sentinel_file"
    else
        output=$(<"$output_file")
        rm -f -- "$output_file" "$sentinel_file"
    fi
    # Cleared once per dispatch, whichever way it ended — completed, cancelled,
    # or cleared by the teardown above. Clearing it is what keeps a shutdown from
    # signalling a process group that is already gone and whose id could by then
    # name something else.
    if [[ -n "${_MCP_INFLIGHT_FILE:-}" ]]; then
        : > "${_MCP_INFLIGHT_FILE}"
    fi

    if [[ "$_MCP_CANCELLED" -eq 0 ]]; then
        local exit_code="$_MCP_CHILD_STATUS"
        if [[ $exit_code -ne 0 ]]; then
            log "ERROR" "Tool $tool_name failed with exit code $exit_code"
            local error_result
            error_result=$(jq -n -c \
                --arg text "Error executing $tool_name: $output" \
                '{"content": [{"type": "text", "text": $text}], "isError": true}')
            create_response "$id" "$error_result"
        else
            local result
            result=$(jq -n -c \
                --arg text "$output" \
                '{"content": [{"type": "text", "text": $text}], "isError": false}')
            create_response "$id" "$result"
        fi
    fi

    # Requests that arrived while the tool ran are answered after the
    # in-flight response, in the order they were received.
    local deferred deferred_response
    if [[ ${#_MCP_DEFERRED_LINES[@]} -gt 0 ]]; then
        # A replayed line that is itself a tools/call must not read stdin. This
        # subshell is still the one that owns the stream while the replays run,
        # so a nested poll would take the bytes of the fragment this dispatch has
        # already handed to the read loop — or of the next request — as its own
        # deferred line and consume them. With the flag cleared the replay takes
        # the no-read path, a plain blocking call, so a replayed call runs to
        # completion with no cancellation window: a cancellation naming it
        # arrives later in the stream and is dropped as matching nothing. Only
        # this subshell's copy is cleared, and it is put back before the
        # EOF-drain check below reads the state this dispatch actually ended in.
        local outer_in_server_loop
        outer_in_server_loop="${_MCP_IN_SERVER_LOOP:-0}"
        _MCP_IN_SERVER_LOOP=0
        for deferred in "${_MCP_DEFERRED_LINES[@]}"; do
            if [[ -z "$deferred" ]]; then
                continue
            fi
            deferred_response=""
            deferred_response=$(process_request "$deferred")
            if [[ -n "$deferred_response" ]]; then
                printf '%s\n' "$deferred_response"
            fi
        done
        _MCP_IN_SERVER_LOOP="$outer_in_server_loop"
    fi

    # A line the client had left half-written when the tool ended has already
    # left this dispatch through the partial-line file, written by the poll loop
    # before it returned. The server's read loop completes it once this dispatch
    # has returned: completing it here would hold the response above back behind
    # a line the client might never finish.

    # Stdin reached EOF while the tool ran, so no further request can arrive.
    # This dispatch is fully answered by now, so the server stops after it. The
    # signal travels through a file rather than a variable because everything
    # above ran in the command substitution run_mcp_server dispatches in.
    if [[ "${_MCP_EOF_DRAIN:-0}" -eq 1 ]]; then
        if [[ -n "${_MCP_SHUTDOWN_FLAG_FILE:-}" ]]; then
            : >"$_MCP_SHUTDOWN_FLAG_FILE"
        else
            log "WARN" "No shutdown flag file set; the server loop cannot be signalled"
        fi
    fi
}

# Wait for a tool child when the call is not driven by the server's read loop.
# Nothing is read here, so there is no cancellation window: the dispatch is a
# plain blocking call, as it is for a consumer that invokes handle_tools_call
# or process_request itself. The child already leads its own process group, so
# the shape matches the in-loop one apart from the wait.
# Args: $1 = child pid, $2 = tool name, $3 = tool output file
# Sets: _MCP_CANCELLED, _MCP_CHILD_STATUS, _MCP_DEFERRED_LINES, _MCP_EOF_DRAIN
_wait_tool_call() {
    local pid="$1"
    local tool_name="$2"
    local output_file="$3"

    _MCP_CANCELLED=0
    _MCP_CHILD_STATUS=0
    _MCP_DEFERRED_LINES=()
    _MCP_EOF_DRAIN=0

    wait "$pid" || _MCP_CHILD_STATUS=$?
    _kill_tool_group "$pid" "$tool_name" "$output_file"
}

# Poll the client's stdin while a tool child runs, so an in-flight tools/call
# can be cancelled and so requests that arrive mid-call are answered in order
# once it finishes. Cancellation matching is docs/architecture.md §Cancellation;
# the EOF and fragment rules are docs/architecture.md §Partial-line handoff.
# Args: $1 = in-flight request id (JSON), $2 = child pid, $3 = tool name,
#       $4 = original arguments JSON, $5 = tool output file
# Sets: _MCP_CANCELLED (1 when the call was cancelled, else 0),
#       _MCP_CHILD_STATUS (the child's exit status), _MCP_DEFERRED_LINES,
#       _MCP_EOF_DRAIN (1 when stdin reached EOF, so the server loop stops
#       after this dispatch), and _MCP_PARTIAL_FILE (the fragment in hand when
#       the loop ended, empty when there is none)
_await_tool_call() {
    local id="$1"
    local pid="$2"
    local tool_name="$3"
    local arguments="$4"
    local output_file="$5"

    _MCP_CANCELLED=0
    _MCP_CHILD_STATUS=0
    _MCP_DEFERRED_LINES=()
    _MCP_EOF_DRAIN=0

    local buffer=""
    local chunk=""
    local line=""
    local fragment=""
    local line_ready=0
    local is_cancel=0
    local rc=0
    local status=0

    while kill -0 "$pid" 2>/dev/null; do
        chunk=""
        rc=0
        line_ready=0
        # On a timeout, and on EOF reached after some bytes were read, bash
        # still stores what it managed to read into the variable, and those
        # bytes are gone from the pipe: they have to be kept and joined to the
        # rest of the line, or a line the client wrote in more than one piece
        # would lose its first fragment.
        # The window is short because it is the latency every completed
        # tools/call pays when the tool outruns it: the read is what the wait
        # blocks on after the tool is already gone.
        IFS= read -r -t 0.05 chunk || rc=$?
        if [[ $rc -eq 0 ]]; then
            line="${buffer}${chunk}"
            buffer=""
            line_ready=1
        elif [[ $rc -gt 128 ]]; then
            buffer="${buffer}${chunk}"
        else
            # EOF on stdin: the client is gone and nothing further can be
            # read, but the call was accepted and its response is still owed
            # to whoever reads the stream. Reading stops here and the normal
            # completion below answers it; the shutdown flag is set by
            # handle_tools_call once that response and the deferred lines are
            # written. The last read carries bytes even at EOF, so the
            # fragment is the joined buffer and whatever that read stored.
            # A fragment is only dropped when it is not JSON: one that already
            # parses is the client's last request, sent with no trailing
            # newline that can now ever arrive, and it is answerable — 3.0.0's
            # `read || [[ -n "$line" ]]` answered it. It goes through the same
            # handling as a terminated line below, and the loop then stops.
            # A dropped fragment is unanswerable and its content is whatever
            # the client wrote, so only its length is recorded. The buffer is
            # cleared in both cases: the fragment has been accounted for, and
            # nothing below may treat it as still in hand.
            fragment="${buffer}${chunk}"
            buffer=""
            line=""
            if [[ -n "$fragment" ]]; then
                # The parse test is `jq empty`, which exits zero on any
                # parseable input: `jq -e '.'` set its status from the
                # truthiness of the output, so a fragment of `false` or `null`
                # — both valid JSON — read as a parse failure and was dropped.
                # `jq empty` also exits zero on input holding no documents, the
                # empty string and whitespace-only input alike, so the fragment
                # reaching this gate need not hold one: the `-n` guard above
                # excludes only the empty string, and a whitespace-only
                # fragment is handed on and answered -32700 — the same answer
                # the same bytes get when a newline follows them.
                if printf '%s\n' "$fragment" | jq empty >/dev/null 2>&1; then
                    line="$fragment"
                    line_ready=1
                else
                    log "WARN" "Discarding a partial line of ${#fragment} characters left by EOF during tools/call $id ($tool_name)"
                fi
            fi
            _MCP_EOF_DRAIN=1
            if [[ $line_ready -eq 0 ]]; then
                break
            fi
        fi

        if [[ $line_ready -eq 1 ]]; then
            is_cancel=0
            # The id is compared as a JSON value on both sides: `--argjson`
            # normalizes the in-flight id, jq compares it against the
            # requestId as parsed, so 1 does not match "1" and a malformed
            # line simply fails to parse and is queued instead of matching.
            # The requestId presence guard precedes the comparison: an absent
            # requestId reads as null, and a null in-flight id would then equal
            # it and cancel an unrelated call. Matched only when the key is
            # there, so the clause fails closed for an id no other message
            # reaches.
            if printf '%s\n' "$line" | jq -e --argjson id "$id" \
                '.jsonrpc == "2.0" and (has("id") | not) and .method == "notifications/cancelled" and (.params | has("requestId")) and .params.requestId == $id' \
                >/dev/null 2>&1; then
                is_cancel=1
            fi
            if [[ $is_cancel -eq 1 ]]; then
                log "INFO" "Cancelling in-flight tools/call $id ($tool_name)"
                _teardown_tool_call "$tool_name" "$pid" "$arguments" "$id" "$output_file"
                _MCP_CANCELLED=1
                return 0
            fi
            _MCP_DEFERRED_LINES+=("$line")
            # The line above was the last one this loop can read; a terminated
            # line leaves the drain flag clear and the loop continues.
            if [[ $_MCP_EOF_DRAIN -eq 1 ]]; then
                break
            fi
        fi
    done

    # A fragment still in hand when the loop ended — the child died before the
    # line it began was finished — is written out for run_mcp_server's read loop
    # to complete, no trailing newline, so the byte stream the client wrote is
    # the byte stream that is joined. Nothing is written for an empty fragment,
    # and the EOF above already accounts for the one it discarded. The handoff is
    # logged for the call it left, never for the fragment: the fragment's content
    # is the client's, so only its length is recorded.
    if [[ -n "$buffer" && -n "${_MCP_PARTIAL_FILE:-}" ]]; then
        printf '%s' "$buffer" > "${_MCP_PARTIAL_FILE}"
        log "INFO" "Handing a partial line of ${#buffer} characters out of tools/call $id ($tool_name) to the read loop"
    fi

    wait "$pid" || status=$?
    _MCP_CHILD_STATUS="$status"
    _kill_tool_group "$pid" "$tool_name" "$output_file"
}

# Run a tool's optional tool_<name>_cancel hook, bounded at
# _MCP_CANCEL_GRACE_SECONDS so a wedged hook cannot wedge its caller. The hook
# is consumer code: it gets the call's arguments as its one argument, and
# neither the client's stdin nor the protocol stream.
# Args: $1 = tool name, $2 = the call's arguments JSON. The teardown that runs
#       from a signal handler passes an empty string: it reads the tool's name
#       and process group out of the in-flight file, which records no
#       arguments.
_run_cancel_hook() {
    local tool_name="$1"
    local arguments="$2"

    local hook="tool_${tool_name}_cancel"
    if ! type "$hook" &>/dev/null; then
        return 0
    fi

    local hook_pid
    local waited=0
    local hook_status=0
    local monitor_was_enabled=0
    if [[ -o monitor ]]; then
        monitor_was_enabled=1
    fi
    set -m
    ( if [[ -n "${_MCP_LIFELINE_FD:-}" ]]; then exec {_MCP_LIFELINE_FD}>&-; fi; set +e; "$hook" "$arguments" ) >/dev/null 2>&1 </dev/null &
    hook_pid=$!
    if [[ "$monitor_was_enabled" == "1" ]]; then
        set -m
    else
        set +m
    fi
    while kill -0 "$hook_pid" 2>/dev/null \
        && [[ $waited -lt $((_MCP_CANCEL_GRACE_SECONDS * 10)) ]]; do
        sleep 0.1
        waited=$((waited + 1))
    done
    if kill -0 "$hook_pid" 2>/dev/null; then
        kill -KILL -- "-$hook_pid" 2>/dev/null || true
        wait "$hook_pid" || true
        log "WARN" "Cancel hook ${hook} for ${tool_name} did not finish within ${_MCP_CANCEL_GRACE_SECONDS}s; killed"
    else
        wait "$hook_pid" || hook_status=$?
        if [[ $hook_status -ne 0 ]]; then
            log "WARN" "Cancel hook ${hook} for ${tool_name} exited with status ${hook_status}"
        fi
        # The hook leads a group of its own, which the in-flight record does not
        # name, so no tombstone is written for it: the call's group is still
        # live here and the record has to keep naming it.
        _kill_tool_group "$hook_pid" "" ""
    fi
    return 0
}

# Clear what is left of a tool's process group after its wrapper has been
# reaped: the group is the tool's containment boundary, so nothing the tool
# started outlives the call. docs/architecture.md §Tool containment.
#
# The tombstone is written ahead of the check-and-kill, not after it, because
# this function is the one place the group is deliberately emptied: any other
# order leaves a window where the group is empty and the record still names its
# id. Accepted cost of that order — a teardown racing the same sliver removes
# the call's files without signalling, and the lifeline sentinel remains the
# containment backstop. docs/architecture.md §The in-flight record.
# Args: $1 = the wrapper's pid, which is the group id it leads,
#       $2 = the call's tool name, $3 = the call's output file path. The last
#       two are empty when the group is not the call's own — the cancel hook's
#       group is a group of its own, and the record names the call's — and a
#       tombstone is written only when both are non-empty, on the server loop
#       only, where a trap can read the record.
_kill_tool_group() {
    local pid="$1"
    local tool_name="$2"
    local output_file="$3"

    if [[ "${_MCP_IN_SERVER_LOOP:-0}" == "1" && -n "${_MCP_INFLIGHT_FILE:-}" \
        && -n "$tool_name" && -n "$output_file" ]]; then
        printf '%s %s %s\n' "-" "$tool_name" "$output_file" > "${_MCP_INFLIGHT_FILE}"
    fi

    if kill -0 -- "-${pid}" 2>/dev/null; then
        kill -KILL -- "-${pid}" 2>/dev/null || true
    fi
    return 0
}

# The file a call's wrapper records its sentinel's pid in: a sibling of the
# call's output file, named from the output file's own name so it belongs to
# that call alone. It is derived rather than remembered because a shutdown
# teardown reaches a running call through the in-flight record, which holds the
# output file's path and nothing else. The name deliberately does not begin
# "mcp-tool-output", so it never reads as a second output file of the call.
# Args: $1 = the call's output file path
_sentinel_pid_file() {
    local output_file="$1"

    [[ -z "$output_file" ]] && return 0
    printf '%s/mcp-sentinel.%s' "${output_file%/*}" "${output_file##*/}"
}

# The pid recorded in a call's sentinel file. Empty when no record was written —
# no lifeline, or the wrapper had not reached it yet — which a grace poll reads
# as "unknown" and falls back to the group's raw liveness.
# Args: $1 = the sentinel pid file path
_sentinel_pid_for() {
    local sentinel_file="$1"
    local sentinel_pid=""

    if [[ -n "$sentinel_file" && -s "$sentinel_file" ]]; then
        IFS= read -r sentinel_pid < "$sentinel_file" || true
    fi
    printf '%s' "$sentinel_pid"
}

# Whether a tool's process group still holds a live member other than the
# lifeline sentinel. The sentinel waits on the server's lifeline rather than on
# the tool and ignores TERM, so it outlives a tool that dies on the first TERM;
# counting it would hold every cancellation open for the whole grace period.
# A group whose only live member is the sentinel therefore reads as dead, and
# the caller's grace loop ends. The sentinel is not forgotten: _kill_tool_group
# clears whatever is left of the group once the tool is reaped.
# A group the kernel has already released is dead here too — the scan matches
# nothing — but a caller that must not signal a recycled group id gates on
# `kill -0 -- "-<pgid>"` for that, not on this.
# The members come from a full `ps` listing filtered here rather than from a
# selecting call, which cannot tell an emptied group from a probe that never
# ran. A `ps` that fails at all is unknown liveness, never an empty group: read
# as empty it would end the caller's grace loop at once and skip the SIGKILL
# after it, leaving a tool that ignores TERM alive.
# docs/architecture.md §Cancellation.
# Args: $1 = group id, $2 = sentinel pid (empty when unknown)
_tool_group_has_live_member() {
    local pgid="$1"
    local sentinel_pid="$2"

    local listing=""
    local ps_rc=0
    # Guarded so a missing binary, which reaches a subshell as a 127 exit rather
    # than through errexit, cannot end the caller.
    listing="$(ps -A -o pgid=,pid= 2>/dev/null)" || ps_rc=$?
    if [[ ${ps_rc} -ne 0 ]]; then
        kill -0 -- "-${pgid}" 2>/dev/null
        return
    fi

    local entry_pgid member
    while read -r entry_pgid member _; do
        if [[ "${entry_pgid}" != "${pgid}" || -z "${member}" || "${member}" == "${sentinel_pid}" ]]; then
            continue
        fi
        return 0
    done <<< "${listing}"
    return 1
}

# Stop a cancelled tool call: run its optional cancel hook, terminate the
# child's process group, and reap it. A hook or a child that ignores SIGTERM
# gets _MCP_CANCEL_GRACE_SECONDS before being killed, so a wedged consumer tool
# cannot wedge the server; the grace is measured against the group's live
# members other than the sentinel, so a tool that dies on the first TERM is
# reaped at once rather than two seconds later.
# Args: $1 = tool name, $2 = child pid, $3 = original arguments JSON,
#       $4 = in-flight request id (JSON), $5 = tool output file
_teardown_tool_call() {
    local tool_name="$1"
    local pid="$2"
    local arguments="$3"
    local id="$4"
    local output_file="$5"

    _run_cancel_hook "$tool_name" "$arguments"

    local sentinel_file
    sentinel_file="$(_sentinel_pid_file "$output_file")"
    local sentinel_pid
    sentinel_pid="$(_sentinel_pid_for "$sentinel_file")"

    local alive_waited=0
    if kill -0 -- "-$pid" 2>/dev/null; then
        # The child leads its own process group, so the negative pid reaches
        # the tool and everything it spawned.
        kill -TERM -- "-$pid" 2>/dev/null || true
        while _tool_group_has_live_member "$pid" "$sentinel_pid" \
            && [[ $alive_waited -lt $((_MCP_CANCEL_GRACE_SECONDS * 10)) ]]; do
            sleep 0.1
            alive_waited=$((alive_waited + 1))
        done
        if _tool_group_has_live_member "$pid" "$sentinel_pid"; then
            kill -KILL -- "-$pid" 2>/dev/null || true
            log "WARN" "Tool ${tool_name} ignored SIGTERM; process group killed"
        fi
    fi
    # Reaped once, after the last signal: the status reflects the signal,
    # which is what a cancellation is expected to look like.
    wait "$pid" || true
    _kill_tool_group "$pid" "$tool_name" "$output_file"
    rm -f -- "$output_file" "$sentinel_file"
    log "INFO" "Cancelled tools/call $id ($tool_name)"
}

process_request() {
    local request="$1"

    if [[ "${_MCP_IN_SERVER_LOOP:-0}" == "1" && -n "${_MCP_LIFELINE_FD:-}" ]]; then
        exec {_MCP_LIFELINE_FD}>&-
        _MCP_LIFELINE_FD=""
    fi

    # Parse gate: exactly one JSON document, of any type. `jq -e '.'` accepted a
    # line holding two documents — it reports only its last output — and the id
    # filter below then emitted one line per document, so the joined text
    # reached `--argjson`, whose rejection ended the server. It also exits
    # non-zero on a whole document that is `null` or `false`, both of which are
    # parseable, which is why those two answered -32700 while every other
    # scalar reached the version arm and answered -32600. The count is read the
    # way read_json_file reads a file's, with `jq -cs` and a length test; a line
    # jq cannot parse at all fails the substitution, and any other count is a
    # line that is not one document.
    local doc_count
    if ! doc_count=$(printf '%s\n' "$request" | jq -cs 'length' 2>/dev/null); then
        log "ERROR" "Invalid JSON received"
        create_error_response "null" -32700 "Parse error: Invalid JSON"
        return
    fi
    if [[ "$doc_count" != "1" ]]; then
        log "ERROR" "Received a line holding ${doc_count} JSON documents; expected exactly one"
        create_error_response "null" -32700 "Parse error: Expected exactly one JSON document per line"
        return
    fi

    # JSON-RPC 2.0 represents a call as a Request object, so a document of any
    # other type is an Invalid Request. This gate runs before `.jsonrpc`, `.id`,
    # `.method` and `.params` are read, so those extractions only ever see an
    # object and none of them can fail. That is what makes the crash fix a
    # property of this function rather than of its caller: process_request no
    # longer depends on the dispatch site clearing errexit inside the command
    # substitution. It also keeps a non-object line's `Cannot index ...` jq
    # diagnostics off the process's stderr, unrouted through `log`.
    if [[ "$(printf '%s\n' "$request" | jq -r 'type')" != "object" ]]; then
        log "ERROR" "JSON-RPC request is not a JSON object"
        create_error_response "null" -32600 "Invalid Request: expected a JSON object"
        return
    fi

    local jsonrpc id id_is_valid method params
    jsonrpc=$(echo "$request" | jq -r '.jsonrpc // ""')
    # The id is read by key presence, not with `//`: that operator maps an
    # absent key and a present null to the same output, so a request carrying
    # `"id": null` was indistinguishable from a notification. `tojson` keeps
    # the JSON type of a present id, so 7 stays an integer and "7" a string,
    # and an absent key leaves the empty sentinel the notification gate reads.
    id=$(echo "$request" | jq -r 'if has("id") then (.id | tojson) else "" end')
    method=$(echo "$request" | jq -r '.method // ""')
    params=$(echo "$request" | jq -c '.params // {}')

    # Whether the id is of a type a response can echo back: a JSON string or
    # integer. JSON-RPC 2.0 §5 allows a response id to be a String, Number or
    # Null, so every other type — and the absent id, whose sentinel is the
    # empty string — must be answered with a null id rather than reflected.
    # Computed once here, because both the version arm below and the id-type
    # gate read this verdict; a second test would be the same question twice.
    #
    # The integer test is `validate_tool_arguments`' `type_ok` test for a
    # declared `integer`, restated for a whole document: `$id` is already the
    # id's `tojson` rendering, so the value under test is the document jq reads
    # rather than a sub-value. The duplication is deliberate — the validator's
    # copy sits inside a large jq program string, and factoring the two
    # together is a refactor with its own risk. The comment above that copy
    # explains why a bare `floor` comparison is not enough.
    id_is_valid=0
    if [[ -n "$id" ]] && printf '%s\n' "$id" | jq -e '
        (type == "string")
        or (
            (type == "number")
            and (. == (. | floor))
            and ((tojson) as $literal
                 | if ($literal | test("[eE]")) then true
                   else ($literal | test("\\.[0-9]*[1-9]") | not)
                   end)
        )' >/dev/null 2>&1; then
        id_is_valid=1
    fi

    if [[ "$jsonrpc" != "2.0" ]]; then
        log "ERROR" "Invalid JSON-RPC version: $jsonrpc"
        # This arm runs ahead of the id-type gate, so it settles the response
        # id itself: a string or integer is reflected, and the absent sentinel,
        # a null, a boolean, a fractional number, an object or an array all
        # answer null, which is the response id JSON-RPC reserves for an id
        # that could not be echoed.
        local response_id="null"
        if [[ "$id_is_valid" == "1" ]]; then
            response_id="$id"
        fi
        create_error_response "$response_id" -32600 "Invalid Request: jsonrpc must be 2.0"
        return
    fi

    # A message with no id key is a JSON-RPC notification and requires no
    # response, so none of the arms below can emit one. The id is empty exactly
    # when the key is absent. Between requests nothing is in flight: a
    # cancellation that arrives here matches no call and is dropped.
    if [[ -z "$id" ]]; then
        case "$method" in
            "notifications/initialized")
                log "INFO" "Client initialized"
                ;;
            "notifications/cancelled")
                log "INFO" "Cancellation received with nothing in flight; dropped"
                ;;
            *)
                log "INFO" "Received notification: $method"
                ;;
        esac
        return
    fi

    # An id that is neither a string nor an integer is neither a request nor a
    # notification: MCP requires a request id to be a string or an integer and
    # forbids null, and a notification carries no id at all, so an id of any
    # other type — including a fractional number — is answered rather than
    # dispatched. The validity test above enforces that rule in full; its
    # verdict is read here rather than re-run.
    if [[ "$id_is_valid" != "1" ]]; then
        log "ERROR" "Request id must be a string or an integer"
        create_error_response "null" -32600 "Invalid Request: id must be a string or an integer"
        return
    fi

    case "$method" in
        "initialize")
            handle_initialize "$id" "$params"
            ;;
        "tools/list")
            handle_tools_list "$id"
            ;;
        "tools/call")
            handle_tools_call "$id" "$params"
            ;;
        "ping")
            create_response "$id" '{}'
            ;;
        *)
            log "ERROR" "Unknown method: $method"
            create_error_response "$id" -32601 "Method not found: $method"
            ;;
    esac
}

# SIGKILL the tool's process group once the server is gone, however it went.
# This sentinel blocks on a read of the server's lifeline FIFO.
# docs/architecture.md §The lifeline.
# Nothing is ever expected to arrive on that read: a byte would end the wait
# early and kill the group while the server is still alive, and the only writer
# in this design never writes.
_lifeline_sentinel() {
    local read_fd="$1"

    trap '' TERM INT HUP

    local pgid=""
    local entry_pid entry_pgid
    while read -r entry_pid entry_pgid _; do
        if [[ "${entry_pid}" == "${BASHPID}" ]]; then
            pgid="${entry_pgid}"
            break
        fi
    done < <(ps -A -o pid=,pgid= 2>/dev/null)

    local line=""
    IFS= read -r -u "${read_fd}" line || true

    kill -KILL -- "-${pgid}" 2>/dev/null || true
}

# Stop whatever the server still holds, however the server is going down.
# The in-flight group is not this shell's child — it was the dispatch
# subshell's, and that subshell is often already gone — so it is reaped by
# polling the group, never by `wait`. docs/architecture.md §Shutdown.
_server_teardown() {
    # A signal that arrives while this is already running would otherwise enter
    # it a second time and re-signal a group, and re-run a hook, that the first
    # pass has already dealt with. The flag is cleared on the way out rather
    # than left set, so a shell that runs a second server still tears that one
    # down.
    if [[ "${_MCP_TEARDOWN_RUNNING:-0}" == "1" ]]; then
        return 0
    fi
    _MCP_TEARDOWN_RUNNING=1

    local inflight_pid=""
    local inflight_tool=""
    local inflight_output=""
    local inflight_sentinel_file=""
    if [[ -n "${_MCP_INFLIGHT_FILE:-}" && -s "${_MCP_INFLIGHT_FILE}" ]]; then
        read -r inflight_pid inflight_tool inflight_output < "${_MCP_INFLIGHT_FILE}" || true
        inflight_sentinel_file="$(_sentinel_pid_file "${inflight_output}")"
    fi

    # A pgid field of `-` is the tombstone: _kill_tool_group wrote it as it
    # emptied the group, so the id it once named is free to belong to some other
    # process group by now. Nothing is signalled for it, no cancel hook runs,
    # and no grace is polled — only the files the tombstone still names are
    # released below. A numeric pgid is a call still running, and keeps today's
    # behaviour.
    if [[ -n "${inflight_pid}" && "${inflight_pid}" != "-" ]] \
        && kill -0 -- "-${inflight_pid}" 2>/dev/null; then
        _run_cancel_hook "${inflight_tool}" ""
        # The sentinel this call's wrapper recorded beside the output file is
        # left out of the group's liveness exactly as in _teardown_tool_call: it
        # ignores TERM and waits on the lifeline, so counting it would hold this
        # teardown for the whole grace on every shutdown.
        local inflight_sentinel
        inflight_sentinel="$(_sentinel_pid_for "${inflight_sentinel_file}")"
        kill -TERM -- "-${inflight_pid}" 2>/dev/null || true
        local waited=0
        while _tool_group_has_live_member "${inflight_pid}" "${inflight_sentinel}" \
            && [[ $waited -lt $((_MCP_CANCEL_GRACE_SECONDS * 10)) ]]; do
            sleep 0.1
            waited=$((waited + 1))
        done
        if _tool_group_has_live_member "${inflight_pid}" "${inflight_sentinel}"; then
            kill -KILL -- "-${inflight_pid}" 2>/dev/null || true
            log "WARN" "Tool ${inflight_tool} ignored SIGTERM; process group killed"
        fi
        log "INFO" "Stopped in-flight tool ${inflight_tool} (group ${inflight_pid}) on shutdown"
    fi

    # The tool's output file is named nowhere but the dispatch subshell that
    # created it, so a server going down on a signal has only the record to
    # reach it; the sentinel pid file beside it is derived from that same path
    # and is removed with it. This removal runs for a tombstone record too,
    # which is the point of keeping the path in it. A teardown that found no
    # call to stop leaves nothing to remove either way.
    if [[ -n "${inflight_output}" ]]; then
        rm -f -- "${inflight_output}" "${inflight_sentinel_file}"
    fi

    # The variables are cleared with the files they name: a later step in this
    # shell cannot recreate a path the teardown has released, and a second pass
    # over a cleared name skips the removal instead of repeating it against a
    # path the shell may since have given to something else.
    if [[ -n "${_MCP_INFLIGHT_FILE:-}" ]]; then
        rm -f -- "${_MCP_INFLIGHT_FILE}"
        _MCP_INFLIGHT_FILE=""
    fi
    if [[ -n "${_MCP_SHUTDOWN_FLAG_FILE:-}" ]]; then
        rm -f -- "${_MCP_SHUTDOWN_FLAG_FILE}"
        _MCP_SHUTDOWN_FLAG_FILE=""
    fi
    # The partial-line handoff is the one of these the server holds for its own
    # use rather than a dispatch's, so a teardown that runs at the end of a
    # normal loop lifetime removes it here, exactly as the loop's own exit does.
    if [[ -n "${_MCP_PARTIAL_FILE:-}" ]]; then
        rm -f -- "${_MCP_PARTIAL_FILE}"
        _MCP_PARTIAL_FILE=""
    fi
    # Dropping the last writer is what releases a sentinel still waiting; the
    # group already killed above is the normal way out. The variable is cleared
    # with the descriptor so a second teardown cannot close a number the shell
    # has since given to something else.
    if [[ -n "${_MCP_LIFELINE_FD:-}" ]]; then
        exec {_MCP_LIFELINE_FD}>&-
        _MCP_LIFELINE_FD=""
    fi
    if [[ -n "${_MCP_LIFELINE_DIR:-}" ]]; then
        rm -rf -- "${_MCP_LIFELINE_DIR}"
        _MCP_LIFELINE_DIR=""
    fi

    # The caller's own EXIT handler runs here, after the SDK has released its
    # files: the one point both routes into this function reach with the cleanup
    # done and the shell still alive. It runs in its own background group under
    # the cancel-hook grace, because bash defers a trapped signal until a
    # foreground subshell finishes, so a handler that blocked would stall
    # shutdown — an overrun is killed and logged. `set +e` and a logged, not
    # returned, failure give it the no-errexit shape its contract states. Its
    # stdout goes to stderr, and its stdin is `/dev/null` rather than the
    # inherited client stream a handler could otherwise consume. The variable is
    # cleared after the one run, so no later pass over this function — the
    # loop's own teardown, then the EXIT trap — can run the handler a second
    # time. docs/architecture.md §Shutdown.
    if [[ -n "${_MCP_CHAINED_EXIT_TRAP:-}" ]]; then
        local chained_pid=""
        local chained_waited=0
        local chained_status=0
        local chained_monitor_was_enabled=0
        if [[ -o monitor ]]; then
            chained_monitor_was_enabled=1
        fi
        set -m
        ( set +e; eval "${_MCP_CHAINED_EXIT_TRAP}" ) >&2 </dev/null &
        chained_pid=$!
        if [[ "$chained_monitor_was_enabled" == "1" ]]; then
            set -m
        else
            set +m
        fi
        while kill -0 "$chained_pid" 2>/dev/null \
            && [[ $chained_waited -lt $((_MCP_CANCEL_GRACE_SECONDS * 10)) ]]; do
            sleep 0.1
            chained_waited=$((chained_waited + 1))
        done
        if kill -0 "$chained_pid" 2>/dev/null; then
            kill -KILL -- "-$chained_pid" 2>/dev/null || true
            wait "$chained_pid" || true
            log "WARN" "Chained caller EXIT trap did not finish within ${_MCP_CANCEL_GRACE_SECONDS}s; killed"
        else
            wait "$chained_pid" || chained_status=$?
            if [[ $chained_status -ne 0 ]]; then
                log "WARN" "Chained caller EXIT trap failed with status ${chained_status}"
            fi
            _kill_tool_group "$chained_pid" "" ""
        fi
        _MCP_CHAINED_EXIT_TRAP=""
    fi

    _MCP_TEARDOWN_RUNNING=0

    # A signal a trap recorded while this pass ran is what the shell now dies
    # by. The re-raise runs at the end of every pass, not only a trap-driven
    # one, so a signal recorded during a clean-exit teardown still ends the
    # shell by that signal. docs/architecture.md §Shutdown.
    if [[ -n "${_MCP_PENDING_SIGNAL:-}" ]]; then
        local pending_signal
        pending_signal="${_MCP_PENDING_SIGNAL}"
        _MCP_PENDING_SIGNAL=""
        trap - "$pending_signal"
        kill -s "$pending_signal" "$BASHPID"
    fi
    return 0
}

# What every signal trap runs: tear the server down, then die by the signal that
# was sent, with its default disposition restored, so the exit status reports
# death by signal rather than a plain zero.
# A signal that arrives while a teardown is already running cannot re-enter it.
# It is recorded instead, and the pass in progress re-raises it when it ends:
# the teardown finishes its cleanup, and the shell still dies by the signal.
# Re-raising from here instead would abort that pass part-way, skipping the
# SIGKILL to the tool group and the removal of the call's files.
# Args: $1 = the signal name, as the trap spells it
_mcp_teardown_on_signal() {
    local signal="$1"

    if [[ "${_MCP_TEARDOWN_RUNNING:-0}" == "1" ]]; then
        _MCP_PENDING_SIGNAL="$signal"
        return 0
    fi

    _server_teardown
    trap - "$signal"
    kill -s "$signal" "$BASHPID"
}

run_mcp_server() {
    log "INFO" "MCP Server starting..."

    # A cancellation handler runs inside the command substitution below, so a
    # shell variable cannot carry its shutdown signal back out. The flag is a
    # file instead, created only when the client closes stdin mid-call.
    local shutdown_flag
    shutdown_flag=$(mktemp "${TMPDIR:-/tmp}/mcp-shutdown.XXXXXX")
    rm -f -- "$shutdown_flag"
    export _MCP_SHUTDOWN_FLAG_FILE="$shutdown_flag"

    # Where a dispatch records the tool group it started, the tool's name, and
    # the file its output is collected in, for the teardown below to find.
    # Created once and left in place: its content, not its existence, is the
    # signal, and every dispatch clears it on the way out.
    local inflight_file
    inflight_file=$(mktemp "${TMPDIR:-/tmp}/mcp-inflight.XXXXXX")
    export _MCP_INFLIGHT_FILE="$inflight_file"

    # Where a dispatch hands out a line the client had left half-written when
    # the call ended. A fragment cannot travel back out of the command
    # substitution above as anything but part of its stdout, and prepending it
    # there would mean the dispatch had to read the rest of the line first —
    # holding back the response the call already earned. The file is created
    # empty and never deleted while the server runs: the loop below empties it
    # after every read, so its content, not its existence, is the signal.
    local partial_file
    partial_file=$(mktemp "${TMPDIR:-/tmp}/mcp-partial.XXXXXX")
    export _MCP_PARTIAL_FILE="$partial_file"

    # The lifeline: a FIFO the server holds open read-write and never writes to,
    # which every tool wrapper's sentinel reads. A writer disappears exactly when
    # the last server process holding it dies, whatever killed it — SIGKILL
    # included, which no trap can observe. The read-write open never blocks, and
    # the descriptor is what makes the server a writer.
    local lifeline_dir
    lifeline_dir=$(mktemp -d "${TMPDIR:-/tmp}/mcp-lifeline.XXXXXX")
    mkfifo "${lifeline_dir}/lifeline"
    export _MCP_LIFELINE_DIR="$lifeline_dir"
    exec {_MCP_LIFELINE_FD}<>"${lifeline_dir}/lifeline"

    # Known and accepted limitation, at the point it bites: a signal to this
    # shell's pid alone while a dispatch runs takes effect only when that
    # dispatch returns, so the in-flight call finishes first and the teardown
    # then finds the tool already reaped. README.md §Cancelling and shutting
    # down.
    # The EXIT handler a caller installed before this call is kept rather than
    # dropped: the trap below replaces it, and the teardown runs it afterwards.
    # Captured only in the shell the caller's trap was installed in — a caller
    # that isolates this call in a subshell keeps its handler in the parent, and
    # chaining it from the subshell would run it in two shells. A plain variable
    # rather than a `local`, because the EXIT trap reads it after this function
    # has returned. docs/architecture.md §Shutdown.
    _MCP_CHAINED_EXIT_TRAP=""
    if [[ "${BASHPID}" == "$$" ]]; then
        # A bash subshell inherits its parent's trap table, and `trap -p` reports
        # the parent's handler until the subshell itself changes a trap — so
        # this substitution's subshell reports this shell's own handler, and the
        # handler does not run there. Should a future bash reset traps in a
        # subshell the way POSIX describes, this capture would come back empty
        # and a handler would be missed, never fired a second time.
        local incumbent_trap_text
        incumbent_trap_text=$(trap -p EXIT)
        # An empty capture is a shell with no EXIT handler; under `set -o posix`
        # an unset trap reports `trap -- - EXIT`, whose `-` is not a handler.
        # Both store nothing.
        if [[ -n "${incumbent_trap_text}" ]]; then
            # The re-input form is `trap -- '<handler>' EXIT`, so the handler is
            # the third word once that line is parsed as the shell would.
            eval "set -- ${incumbent_trap_text}"
            if [[ -n "${3-}" && "${3-}" != "-" ]]; then
                _MCP_CHAINED_EXIT_TRAP="${3-}"
            fi
        fi
    fi

    # The caller's handler on a signal is replaced here: it expects the shell to
    # keep running, and this shell has to die by the signal. The EXIT trap is
    # the SDK's own, and the caller's EXIT handler runs from the teardown
    # instead. docs/architecture.md §Shutdown.
    trap '_server_teardown' EXIT
    trap '_mcp_teardown_on_signal INT' INT
    trap '_mcp_teardown_on_signal TERM' TERM
    trap '_mcp_teardown_on_signal HUP' HUP
    trap '_mcp_teardown_on_signal PIPE' PIPE

    # This loop is what owns the client's stdin, so it is what licenses the
    # mid-call poll in _await_tool_call to read that stream. A plain variable,
    # not an export: the poll runs in the command substitution below, a
    # subshell of this shell, and no other process has any business reading
    # the client's side of the protocol.
    _MCP_IN_SERVER_LOOP=1

    # A fragment a dispatch could not finish is prepended to the next line this
    # loop reads, so the line is dispatched as the client wrote it. The variable
    # lives across iterations because the read that completes the line happens
    # after the dispatch that carried the fragment is already gone.
    # A fragment may only be joined to a line whose read succeeded: a read that
    # fails leaves whatever it stored unterminated, so joining there would form
    # a request the client never finished writing and answer a line it left
    # open. The one exception is a joined fragment that already parses as JSON
    # — a request the client did finish writing and never terminated — and the
    # EOF branch below tells that case from an unterminated line by parsing it.
    # A line a failed read stored with no fragment in hand is dispatched as
    # before — a client that sent its last request without a trailing newline
    # is answered rather than ignored.
    local partial=""
    local read_rc=0
    while true; do
        read_rc=0
        IFS= read -r line || read_rc=$?
        if [[ $read_rc -ne 0 && -n "$partial" ]]; then
            # Nothing further can arrive, so no later read can complete this
            # line, and the bytes this read stored are its tail. The joined
            # fragment is still a line when it parses as JSON: a client that
            # sent its last request with no trailing newline wrote exactly
            # that, and 3.0.0's `read || [[ -n "$line" ]]` answered it. It
            # falls through to the dispatch below like any other line.
            # Otherwise both pieces are dropped together, with only their
            # length logged: the content is the client's.
            local eof_fragment
            eof_fragment="${partial}${line}"
            partial=""
            # `jq empty`, not `jq -e '.'`: `-e` takes its status from the
            # output's truthiness, so a fragment of `false` or `null` read as a
            # parse failure. Full reason at the same test in _await_tool_call.
            if ! printf '%s\n' "$eof_fragment" | jq empty >/dev/null 2>&1; then
                log "WARN" "Discarding a partial line of ${#eof_fragment} characters left by EOF"
                break
            fi
            line="$eof_fragment"
        fi
        if [[ $read_rc -ne 0 && -z "$line" ]]; then
            break
        fi

        if [[ -n "$partial" ]]; then
            line="${partial}${line}"
            partial=""
        fi
        [[ -z "$line" ]] && continue

        log "INFO" "Received: ${line:0:100}..."

        local response
        response=$(process_request "$line")

        if [[ -n "$response" ]]; then
            log "RESPONSE" "${response:0:100}..."
            echo "$response"
        fi

        # Read after the response is out, so a dispatch's fragment never holds
        # back the response that dispatch owed. Emptying the file hands the next
        # fragment a clean slate, and the next dispatch writes one only if it
        # ends with a line still unfinished.
        if [[ -n "${_MCP_PARTIAL_FILE:-}" && -s "${_MCP_PARTIAL_FILE}" ]]; then
            partial="$(<"${_MCP_PARTIAL_FILE}")"
            : > "${_MCP_PARTIAL_FILE}"
        fi

        if [[ -e "$_MCP_SHUTDOWN_FLAG_FILE" ]]; then
            log "INFO" "Client closed stdin during an in-flight call; shutting down"
            break
        fi
    done

    _MCP_IN_SERVER_LOOP=0
    _server_teardown
    rm -f -- "$shutdown_flag"
    unset _MCP_SHUTDOWN_FLAG_FILE
    rm -f -- "$partial_file"
    unset _MCP_PARTIAL_FILE
    log "INFO" "MCP Server shutting down"
}
