"""Shared fixtures for lsp_proxy tests.

`fake_lsp_child_script` returns a path to a Python script that acts as a
minimal LSP child for the proxy to drive. The script reads frames from its
own stdin and replies predictably so pump-loop tests can verify the proxy's
full-duplex behavior without needing a real language server.

If the `LSP_CHILD_LOG` env var is set, the fake child appends each received
frame body (as raw bytes, newline-separated) to that file. Tests use this to
verify what the proxy delivered to the child — i.e. to observe the result of
host→container URI rewriting on the forward path.
"""

from pathlib import Path

import pytest

FAKE_CHILD_SOURCE = '''\
#!/usr/bin/env python3
"""Minimal LSP child for proxy tests.

Reads frames from stdin and replies based on the method:
- initialize -> empty capabilities, echoes id
- shutdown -> null result, echoes id
- exit -> exits 0
- echo/<anything> -> response with `result: <body>` (for request tracing)
- Everything else -> MethodNotFound if id present, drop if notification

Intentionally single-threaded and synchronous. Good enough for tests; not a
real LSP implementation.
"""
from __future__ import annotations
import json
import os
import sys


def read_frame() -> bytes | None:
    content_length = None
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        line = line.rstrip(b"\\r\\n")
        if line == b"":
            break
        if line.lower().startswith(b"content-length:"):
            content_length = int(line.split(b":", 1)[1].strip())
    if content_length is None:
        return None
    return sys.stdin.buffer.read(content_length)


def write_frame(body: bytes) -> None:
    header = f"Content-Length: {len(body)}\\r\\n\\r\\n".encode("ascii")
    sys.stdout.buffer.write(header)
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()


def main() -> int:
    log_path = os.environ.get("LSP_CHILD_LOG")
    while True:
        raw = read_frame()
        if raw is None:
            return 0
        if log_path:
            with open(log_path, "ab") as f:
                f.write(raw + b"\\n")
        msg = json.loads(raw.decode("utf-8"))
        method = msg.get("method", "")
        msg_id = msg.get("id")

        if method == "initialize":
            resp = {"jsonrpc": "2.0", "id": msg_id, "result": {"capabilities": {}}}
            write_frame(json.dumps(resp, separators=(",", ":")).encode("utf-8"))
        elif method == "shutdown":
            resp = {"jsonrpc": "2.0", "id": msg_id, "result": None}
            write_frame(json.dumps(resp, separators=(",", ":")).encode("utf-8"))
        elif method == "exit":
            return 0
        elif method.startswith("echo/"):
            resp = {"jsonrpc": "2.0", "id": msg_id, "result": raw.decode("utf-8")}
            write_frame(json.dumps(resp, separators=(",", ":")).encode("utf-8"))
        elif msg_id is not None:
            resp = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": "Method not found"},
            }
            write_frame(json.dumps(resp, separators=(",", ":")).encode("utf-8"))
        # Else: notification, dropped.


if __name__ == "__main__":
    sys.exit(main())
'''


@pytest.fixture
def fake_lsp_child_script(tmp_path: Path) -> Path:
    """Write the fake-child script to a temp path and return it."""
    script = tmp_path / "fake_lsp_child.py"
    script.write_text(FAKE_CHILD_SOURCE)
    script.chmod(0o755)
    return script
