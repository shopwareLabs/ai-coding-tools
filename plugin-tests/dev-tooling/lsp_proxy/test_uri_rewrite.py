"""Unit tests for URI rewriting in lsp_proxy.

The rewrite is a raw byte-level string substitution on the serialized JSON
body. It deliberately does not parse JSON — any `file://<host_root>` prefix
is replaced with `file://<container_root>` and vice versa. Because the prefix
is long and specific, false positives are effectively impossible.
"""

import sys
from pathlib import Path

PROXY_DIR = Path(__file__).resolve().parents[3] / "plugins/dev-tooling/shared"
sys.path.insert(0, str(PROXY_DIR))

import lsp_proxy  # noqa: E402

HOST = "/Users/dev/Software/shopware/shopware"
CONTAINER = "/var/www/html"


def test_host_to_container_rewrites_didopen_uri():
    body = (
        b'{"jsonrpc":"2.0","method":"textDocument/didOpen","params":'
        b'{"textDocument":{"uri":"file:///Users/dev/Software/shopware/shopware/src/Kernel.php"}}}'
    )

    result = lsp_proxy.rewrite_uris_host_to_container(body, HOST, CONTAINER)

    assert b"file:///var/www/html/src/Kernel.php" in result
    assert b"file:///Users/dev" not in result


def test_container_to_host_rewrites_publishdiagnostics_uri():
    body = (
        b'{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":'
        b'{"uri":"file:///var/www/html/src/Kernel.php","diagnostics":[]}}'
    )

    result = lsp_proxy.rewrite_uris_container_to_host(body, HOST, CONTAINER)

    assert b"file:///Users/dev/Software/shopware/shopware/src/Kernel.php" in result
    assert b"file:///var/www/html/src" not in result


def test_roundtrip_host_to_container_to_host_is_identity():
    original = b'{"uri":"file:///Users/dev/Software/shopware/shopware/src/Kernel.php"}'

    forward = lsp_proxy.rewrite_uris_host_to_container(original, HOST, CONTAINER)
    back = lsp_proxy.rewrite_uris_container_to_host(forward, HOST, CONTAINER)

    assert back == original


def test_rewrite_handles_multiple_uris_in_one_message():
    body = (
        b'{"result":[{"uri":"file:///Users/dev/Software/shopware/shopware/a.php"},'
        b'{"uri":"file:///Users/dev/Software/shopware/shopware/b.php"}]}'
    )

    result = lsp_proxy.rewrite_uris_host_to_container(body, HOST, CONTAINER)

    assert result.count(b"file:///var/www/html/") == 2
    assert b"/Users/dev/" not in result


def test_rewrite_leaves_non_matching_uris_alone():
    body = b'{"uri":"file:///tmp/unrelated.txt"}'

    result = lsp_proxy.rewrite_uris_host_to_container(body, HOST, CONTAINER)

    assert result == body


def test_rewrite_leaves_non_file_uris_alone():
    body = b'{"uri":"https://example.com/docs","url":"git://foo"}'

    result = lsp_proxy.rewrite_uris_host_to_container(body, HOST, CONTAINER)

    assert result == body


def test_rewrite_preserves_multibyte_utf8_elsewhere_in_body():
    # The substitution must not decode/re-encode the whole body, so non-ASCII
    # bytes in unrelated fields must pass through unchanged.
    em_dash = "—".encode()  # 3 bytes
    body = (
        b'{"uri":"file:///Users/dev/Software/shopware/shopware/src/Kernel.php",'
        b'"message":"hello ' + em_dash + b' world"}'
    )

    result = lsp_proxy.rewrite_uris_host_to_container(body, HOST, CONTAINER)

    assert em_dash in result
    assert b"/var/www/html/src/Kernel.php" in result


def test_rewrite_is_byte_exact_not_path_aware():
    # If a field happens to contain the exact host-root prefix but isn't a
    # file:// URI, it will NOT be rewritten because the substitution looks
    # for the "file://" prefix.
    body = b'{"cwd":"/Users/dev/Software/shopware/shopware"}'

    result = lsp_proxy.rewrite_uris_host_to_container(body, HOST, CONTAINER)

    assert result == body  # cwd field left alone
