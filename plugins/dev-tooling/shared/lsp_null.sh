#!/usr/bin/env bash
# Minimal LSP "null" server.
#
# Accepts an LSP `initialize` request and responds with empty server
# capabilities, then idles until the client sends `shutdown` + `exit`.
# Used to cleanly disable an LSP entry in .lsp.json without triggering
# Claude Code's crash-and-restart logic: Claude Code sees a valid,
# initialized language server that advertises zero capabilities, so it
# never issues further requests against it.
#
# Protocol: LSP over stdio with Content-Length framing (LSP spec §3).
# Dependencies: bash 4+, jq (already a dev-tooling prerequisite).
# No Python, Node, or other runtimes required.

set -uo pipefail  # no -e: read failures on client EOF are expected

# Read a single LSP message from stdin.
# Writes the JSON body to stdout; returns non-zero on EOF or malformed headers.
read_message() {
    local line content_length=0 raw

    # Parse headers until blank line (end-of-headers marker).
    while IFS= read -r line; do
        line="${line%$'\r'}"
        [[ -z "${line}" ]] && break
        if [[ "${line}" =~ ^Content-Length:[[:space:]]*([0-9]+)$ ]]; then
            content_length="${BASH_REMATCH[1]}"
        fi
    done

    [[ "${content_length}" -eq 0 ]] && return 1

    # Read exactly N bytes of body. We deliberately avoid `head -c` here:
    # `head` uses buffered stdin reads and may over-consume past byte N on
    # a pipe, dropping bytes that belong to the next LSP message. `dd bs=1`
    # reads one byte at a time, guaranteeing no over-read.
    # The trailing 'X' sentinel protects against command-substitution
    # stripping a legitimate trailing newline at byte N.
    raw=$(dd bs=1 count="${content_length}" 2>/dev/null; printf 'X')
    printf '%s' "${raw%X}"
}

# Write a single LSP message to stdout with Content-Length framing.
# Bash's builtin printf writes via write(2) with no libc buffering,
# so the frame is delivered immediately in a single syscall.
write_message() {
    local body="$1"
    printf 'Content-Length: %d\r\n\r\n%s' "${#body}" "${body}"
}

main() {
    local body method resp

    while body=$(read_message); do
        [[ -z "${body}" ]] && continue

        method=$(printf '%s' "${body}" | jq -r '.method // ""')

        case "${method}" in
            initialize)
                # Echo back the request id with its original JSON type
                # (number vs string) preserved by doing the transform in jq.
                resp=$(printf '%s' "${body}" \
                    | jq -c '{jsonrpc:"2.0",id:.id,result:{capabilities:{}}}')
                write_message "${resp}"
                ;;
            shutdown)
                resp=$(printf '%s' "${body}" \
                    | jq -c '{jsonrpc:"2.0",id:.id,result:null}')
                write_message "${resp}"
                ;;
            exit)
                # Per LSP spec: after shutdown, the client sends `exit`
                # and the server must terminate.
                exit 0
                ;;
            *)
                # Notifications (no id field) are dropped silently.
                # Requests (with id) MUST get a response or the client hangs.
                # Claude Code sends textDocument/documentSymbol unconditionally
                # regardless of advertised capabilities, so we cannot rely on
                # capability negotiation alone. Reply with JSON-RPC
                # MethodNotFound (-32601), preserving the request id type.
                if [[ "$(printf '%s' "${body}" | jq 'has("id")')" == "true" ]]; then
                    resp=$(printf '%s' "${body}" | jq -c '{
                        jsonrpc:"2.0",
                        id:.id,
                        error:{code:-32601,message:"Method not found"}
                    }')
                    write_message "${resp}"
                fi
                ;;
        esac
    done

    exit 0
}

main "$@"
