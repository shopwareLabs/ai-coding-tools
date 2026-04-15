"""Lifecycle tests for lsp_proxy: subprocess spawn, full-duplex pump, shutdown."""

import asyncio
import io
import json
import sys
from pathlib import Path

import pytest

PROXY_DIR = Path(__file__).resolve().parents[3] / "plugins/dev-tooling/shared"
sys.path.insert(0, str(PROXY_DIR))

import lsp_proxy  # noqa: E402

HOST = "/Users/dev/Software/shopware/shopware"
CONTAINER = "/var/www/html"


def _frame(body: bytes) -> bytes:
    return b"Content-Length: %d\r\n\r\n%s" % (len(body), body)


async def _drive_proxy(
    fake_child_script: Path,
    input_frames: bytes,
) -> tuple[bytes, int]:
    """Run lsp_proxy.run() with its stdin/stdout rewired to in-memory buffers.

    Returns (output_bytes, exit_code) where exit_code is the real return
    value from `lsp_proxy.run()`.
    """
    stdin_reader = asyncio.StreamReader()
    stdin_reader.feed_data(input_frames)
    stdin_reader.feed_eof()

    stdout_buf = io.BytesIO()

    # The child command wraps the fake LSP child script.
    wrapper = f"{sys.executable} {fake_child_script}"

    exit_code = await lsp_proxy.run(
        host_root=HOST,
        container_root=CONTAINER,
        wrapper=wrapper,
        stdin_reader=stdin_reader,
        stdout_writer=stdout_buf,
    )

    return stdout_buf.getvalue(), exit_code


@pytest.mark.asyncio
async def test_initialize_roundtrip_through_proxy(fake_lsp_child_script: Path):
    init_body = b'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
    exit_body = b'{"jsonrpc":"2.0","method":"exit"}'

    output, _ = await _drive_proxy(fake_lsp_child_script, _frame(init_body) + _frame(exit_body))

    assert b'"id":1' in output
    assert b'"capabilities":{}' in output


@pytest.mark.asyncio
async def test_host_to_container_rewrite_reaches_child(
    fake_lsp_child_script: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    """Forward-path verification: the child must receive the container URI.

    Asserts directly on what the child observed via LSP_CHILD_LOG, not on the
    round-trip output (which looks the same whether forward rewriting worked
    or not, because the return path flips back).
    """
    child_log = tmp_path / "child_received.log"
    monkeypatch.setenv("LSP_CHILD_LOG", str(child_log))

    host_uri = f"file://{HOST}/src/Kernel.php"
    container_uri = f"file://{CONTAINER}/src/Kernel.php"
    request_body = json.dumps(
        {"jsonrpc": "2.0", "id": 42, "method": "echo/uri", "params": {"uri": host_uri}}
    ).encode("utf-8")
    exit_body = b'{"jsonrpc":"2.0","method":"exit"}'

    await _drive_proxy(fake_lsp_child_script, _frame(request_body) + _frame(exit_body))

    received = child_log.read_bytes()
    assert container_uri.encode("utf-8") in received
    assert host_uri.encode("utf-8") not in received


@pytest.mark.asyncio
async def test_container_to_host_rewrite_on_return_path(
    fake_lsp_child_script: Path,
):
    """Return-path verification: the proxy's stdout must contain only host URIs.

    The fake child echoes the body it received (which contains container URIs
    after the forward rewrite) back as a string. The proxy's container→host
    rewrite flips those container URIs back to host URIs in the final output.
    """
    host_uri = f"file://{HOST}/src/Kernel.php"
    request_body = json.dumps(
        {"jsonrpc": "2.0", "id": 42, "method": "echo/uri", "params": {"uri": host_uri}}
    ).encode("utf-8")
    exit_body = b'{"jsonrpc":"2.0","method":"exit"}'

    output, _ = await _drive_proxy(fake_lsp_child_script, _frame(request_body) + _frame(exit_body))

    assert host_uri.encode("utf-8") in output
    assert f"file://{CONTAINER}".encode() not in output


@pytest.mark.asyncio
async def test_clean_shutdown_on_exit_notification(fake_lsp_child_script: Path):
    init_body = b'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
    exit_body = b'{"jsonrpc":"2.0","method":"exit"}'

    output, exit_code = await _drive_proxy(
        fake_lsp_child_script, _frame(init_body) + _frame(exit_body)
    )

    assert exit_code == 0
    # Only the initialize response should appear; exit is a notification.
    assert output.count(b"Content-Length:") == 1
