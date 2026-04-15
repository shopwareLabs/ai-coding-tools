#!/usr/bin/env bats

# Regression tests for shared/lsp_null.sh — the minimal LSP stub used when
# an LSP is disabled or the dispatcher preflight fails. The stub must:
#  - Respond to `initialize` with empty capabilities
#  - Respond to `shutdown` with null result
#  - Exit 0 on `exit` notification
#  - Respond to any unknown REQUEST (has id) with JSON-RPC -32601 Method not found
#  - Silently drop unknown NOTIFICATIONS (no id)
#  - Preserve the id's JSON type (number vs string) in responses

setup() {
    STUB="$(cd "${BATS_TEST_DIRNAME}/../../plugins/dev-tooling/shared" && pwd)/lsp_null.sh"
}

# Build an LSP frame for the given JSON body on stdout.
# Computes Content-Length from the body's byte length so tests don't hardcode
# fragile numeric header values that desynchronize when bodies change.
_frame() {
    local body="$1"
    local len
    len=$(printf '%s' "$body" | wc -c | tr -d ' ')
    printf 'Content-Length: %d\r\n\r\n%s' "$len" "$body"
}

@test "initialize returns empty capabilities with preserved numeric id" {
    local body='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
    run bash -c "$(declare -f _frame); _frame '$body' | bash '$STUB'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'{"jsonrpc":"2.0","id":1,"result":{"capabilities":{}}}'* ]]
}

@test "shutdown returns null result with preserved id" {
    run bash -c "
        {
            $(declare -f _frame)
            _frame '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}'
            _frame '{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"shutdown\"}'
            _frame '{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}'
        } | bash '$STUB'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *'{"jsonrpc":"2.0","id":2,"result":null}'* ]]
}

@test "exit notification terminates cleanly with no extra output after initialize response" {
    run bash -c "
        {
            $(declare -f _frame)
            _frame '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}'
            _frame '{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}'
        } | bash '$STUB'
    "
    [ "$status" -eq 0 ]
    # Only the initialize response frame should be present.
    frame_count=$(printf '%s' "$output" | grep -c '^Content-Length:' || true)
    [ "$frame_count" -eq 1 ]
}

@test "unknown request with numeric id returns MethodNotFound with preserved id" {
    local body='{"jsonrpc":"2.0","id":42,"method":"textDocument/documentSymbol","params":{}}'
    run bash -c "$(declare -f _frame); _frame '$body' | bash '$STUB'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"id":42'* ]]
    [[ "$output" == *'"code":-32601'* ]]
    [[ "$output" == *'"message":"Method not found"'* ]]
}

@test "unknown request with string id returns MethodNotFound with preserved id" {
    local body='{"jsonrpc":"2.0","id":"req-abc","method":"textDocument/hover","params":{}}'
    run bash -c "$(declare -f _frame); _frame '$body' | bash '$STUB'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"id":"req-abc"'* ]]
    [[ "$output" == *'"code":-32601'* ]]
}

@test "unknown notification (no id) produces no response and exits 0 on EOF" {
    local body='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{}}'
    run bash -c "$(declare -f _frame); _frame '$body' | bash '$STUB'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
