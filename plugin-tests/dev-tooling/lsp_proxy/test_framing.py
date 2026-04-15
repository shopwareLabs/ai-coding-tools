"""Unit tests for LSP Content-Length frame read/write in lsp_proxy.

LSP protocol framing (LSP spec §3):
    Content-Length: <N>\r\n
    \r\n
    <N bytes of UTF-8 JSON body>

The proxy must read and write this framing exactly. Body length is in bytes,
not characters — multi-byte UTF-8 matters.
"""

import asyncio
import io
import sys
from pathlib import Path

import pytest

# Add the proxy module's directory to sys.path so we can import it directly.
PROXY_DIR = Path(__file__).resolve().parents[3] / "plugins/dev-tooling/shared"
sys.path.insert(0, str(PROXY_DIR))

import lsp_proxy  # noqa: E402


async def _stream_reader_from_bytes(data: bytes) -> asyncio.StreamReader:
    """Build an asyncio.StreamReader populated with `data` and marked EOF."""
    reader = asyncio.StreamReader()
    reader.feed_data(data)
    reader.feed_eof()
    return reader


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "body",
    [
        pytest.param(
            b'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
            id="ascii",
        ),
        pytest.param(
            b'{"jsonrpc":"2.0","method":"log","params":"line1\\nline2"}',
            id="body_contains_newline",
        ),
        pytest.param(
            '{"jsonrpc":"2.0","method":"log","params":"a — b"}'.encode(),
            id="multibyte_utf8",
        ),
    ],
)
async def test_read_frame_returns_body_verbatim(body: bytes):
    frame = b"Content-Length: %d\r\n\r\n%s" % (len(body), body)
    reader = await _stream_reader_from_bytes(frame)

    result = await lsp_proxy.read_frame(reader)

    assert result == body


@pytest.mark.asyncio
async def test_read_frame_consecutive_frames():
    body1 = b'{"id":1}'
    body2 = b'{"id":2}'
    frame1 = b"Content-Length: %d\r\n\r\n%s" % (len(body1), body1)
    frame2 = b"Content-Length: %d\r\n\r\n%s" % (len(body2), body2)
    reader = await _stream_reader_from_bytes(frame1 + frame2)

    assert await lsp_proxy.read_frame(reader) == body1
    assert await lsp_proxy.read_frame(reader) == body2


@pytest.mark.asyncio
async def test_read_frame_returns_none_on_eof():
    reader = await _stream_reader_from_bytes(b"")

    result = await lsp_proxy.read_frame(reader)

    assert result is None


@pytest.mark.asyncio
async def test_read_frame_raises_on_missing_content_length():
    reader = await _stream_reader_from_bytes(b"Foo: bar\r\n\r\n{}")

    with pytest.raises(lsp_proxy.FramingError, match="missing required Content-Length"):
        await lsp_proxy.read_frame(reader)


def test_write_frame_builds_correct_header_ascii():
    buf = io.BytesIO()
    body = b'{"jsonrpc":"2.0","id":1,"result":null}'

    lsp_proxy.write_frame(buf, body)

    expected = b"Content-Length: %d\r\n\r\n%s" % (len(body), body)
    assert buf.getvalue() == expected


def test_write_frame_uses_byte_length_not_char_length_for_multibyte():
    buf = io.BytesIO()
    body = '{"msg":"a — b"}'.encode()  # em-dash is 3 bytes

    lsp_proxy.write_frame(buf, body)

    result = buf.getvalue()
    assert result.startswith(b"Content-Length: %d\r\n\r\n" % len(body))
    assert result.endswith(body)


@pytest.mark.asyncio
async def test_roundtrip_multiple_frames():
    """Write two frames with different lengths, read them back, compare."""
    bodies = [b'{"id":1}', b'{"id":2,"params":{"deep":"value"}}']
    out = io.BytesIO()
    for body in bodies:
        lsp_proxy.write_frame(out, body)

    reader = await _stream_reader_from_bytes(out.getvalue())

    for expected in bodies:
        assert await lsp_proxy.read_frame(reader) == expected
