"""Error-path tests for lsp_proxy."""

import asyncio
import io
import sys
from pathlib import Path

import pytest

PROXY_DIR = Path(__file__).resolve().parents[3] / "plugins/dev-tooling/shared"
sys.path.insert(0, str(PROXY_DIR))

import lsp_proxy  # noqa: E402

HOST = "/Users/dev/Software/shopware/shopware"
CONTAINER = "/var/www/html"


@pytest.mark.asyncio
async def test_spawn_failure_returns_one():
    stdin_reader = asyncio.StreamReader()
    stdin_reader.feed_eof()
    stdout_buf = io.BytesIO()

    result = await lsp_proxy.run(
        host_root=HOST,
        container_root=CONTAINER,
        wrapper="/definitely/not/a/real/binary",
        stdin_reader=stdin_reader,
        stdout_writer=stdout_buf,
    )

    assert result == 1


@pytest.mark.asyncio
async def test_malformed_content_length_raises():
    reader = asyncio.StreamReader()
    reader.feed_data(b"Content-Length: not-a-number\r\n\r\n{}")
    reader.feed_eof()

    with pytest.raises(lsp_proxy.FramingError, match="Invalid Content-Length header"):
        await lsp_proxy.read_frame(reader)


@pytest.mark.asyncio
async def test_truncated_body_raises():
    reader = asyncio.StreamReader()
    reader.feed_data(b"Content-Length: 100\r\n\r\nshort")
    reader.feed_eof()

    with pytest.raises(lsp_proxy.FramingError, match=r"Truncated body: wanted 100 bytes, got 5"):
        await lsp_proxy.read_frame(reader)
