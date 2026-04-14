#!/usr/bin/env python3
"""LSP stdio proxy with URI rewriting for containerized language servers.

Reads Content-Length-framed JSON-RPC messages from stdin, forwards them to a
spawned child process (typically `docker compose exec -T <svc> <lsp>`), reads
replies from the child's stdout, and writes them back to stdout. On every
frame, `file://` URIs are string-substituted in both directions to translate
between host and container paths.

Invoked from shared/lsp_bootstrap.sh for environments other than native.
Never invoked for `environment: native` — the dispatcher `exec`s directly
into the LSP binary in that case.

Dependencies: Python 3.12+ stdlib only. No third-party packages.
"""

from __future__ import annotations

import asyncio
import contextlib
import sys
from typing import BinaryIO, Protocol


class FramingError(Exception):
    """Raised when an LSP message frame is malformed beyond recovery."""


class _AsyncByteWriter(Protocol):
    """Minimal async writer interface the host→container pump needs."""

    def write(self, data: bytes) -> None: ...
    async def drain(self) -> None: ...
    def close(self) -> None: ...


async def read_frame(reader: asyncio.StreamReader) -> bytes | None:
    """Read exactly one LSP message frame from `reader`.

    Returns the body bytes on success, or None on clean EOF (before any
    header byte has been read). Raises FramingError on malformed headers
    or truncated bodies.
    """
    # Read headers line by line until the blank line that ends them.
    content_length: int | None = None
    header_seen = False
    while True:
        try:
            line = await reader.readuntil(b"\r\n")
        except asyncio.IncompleteReadError as exc:
            if not header_seen and not exc.partial:
                return None  # Clean EOF before any header byte
            raise FramingError(f"Unexpected EOF in LSP headers (partial={exc.partial!r})") from exc

        header_seen = True
        line = line[:-2]  # Strip trailing \r\n
        if line == b"":
            break  # End-of-headers blank line
        if line.lower().startswith(b"content-length:"):
            try:
                content_length = int(line.split(b":", 1)[1].strip())
            except (IndexError, ValueError) as exc:
                raise FramingError(f"Invalid Content-Length header: {line!r}") from exc
        # Other headers (Content-Type, etc.) are ignored per LSP spec §3.

    if content_length is None:
        raise FramingError("Frame headers missing required Content-Length")

    try:
        body = await reader.readexactly(content_length)
    except asyncio.IncompleteReadError as exc:
        raise FramingError(
            f"Truncated body: wanted {content_length} bytes, got {len(exc.partial)}"
        ) from exc
    return body


def write_frame(writer: BinaryIO, body: bytes) -> None:
    """Write one LSP message frame to `writer`.

    The Content-Length header is computed from the byte length of `body`,
    which is critical for correctness when the body contains multi-byte
    UTF-8 characters.
    """
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    writer.write(header)
    writer.write(body)


def rewrite_uris_host_to_container(body: bytes, host_root: str, container_root: str) -> bytes:
    """Rewrite `file://<host_root>` → `file://<container_root>` in `body`.

    Byte-level substitution on the serialized JSON. Deliberately does not
    parse JSON: the `file://<host_root>` prefix is specific enough that false
    positives are effectively impossible for any realistic `host_root`.
    """
    needle = f"file://{host_root}".encode()
    replacement = f"file://{container_root}".encode()
    return body.replace(needle, replacement)


def rewrite_uris_container_to_host(body: bytes, host_root: str, container_root: str) -> bytes:
    """Rewrite `file://<container_root>` → `file://<host_root>` in `body`."""
    needle = f"file://{container_root}".encode()
    replacement = f"file://{host_root}".encode()
    return body.replace(needle, replacement)


async def _pump_host_to_container(
    src: asyncio.StreamReader,
    dst: _AsyncByteWriter,
    host_root: str,
    container_root: str,
) -> None:
    """Read frames from `src`, rewrite host→container URIs, write to `dst`."""
    try:
        while True:
            body = await read_frame(src)
            if body is None:
                break
            rewritten = rewrite_uris_host_to_container(body, host_root, container_root)
            header = f"Content-Length: {len(rewritten)}\r\n\r\n".encode("ascii")
            dst.write(header)
            dst.write(rewritten)
            await dst.drain()
    finally:
        # Signal EOF to the child's stdin so it can exit cleanly after `exit`.
        with contextlib.suppress(BrokenPipeError, ConnectionResetError):
            dst.close()


async def _pump_container_to_host(
    src: asyncio.StreamReader,
    dst: BinaryIO,
    host_root: str,
    container_root: str,
) -> None:
    """Read frames from `src`, rewrite container→host URIs, write to `dst`."""
    while True:
        body = await read_frame(src)
        if body is None:
            break
        rewritten = rewrite_uris_container_to_host(body, host_root, container_root)
        header = f"Content-Length: {len(rewritten)}\r\n\r\n".encode("ascii")
        dst.write(header)
        dst.write(rewritten)
        try:
            dst.flush()
        except (BrokenPipeError, ConnectionResetError):
            break


async def run(
    *,
    host_root: str,
    container_root: str,
    wrapper: str,
    stdin_reader: asyncio.StreamReader | None = None,
    stdout_writer: BinaryIO | None = None,
) -> int:
    """Top-level proxy coroutine.

    Spawns the wrapped child command, runs both pump loops concurrently,
    and returns 0 on clean shutdown or non-zero on abnormal termination.

    `stdin_reader` and `stdout_writer` are injectable for tests. When None,
    real stdin/stdout are used (via `connect_read_pipe` / direct `sys.stdout.buffer`).
    """
    import shlex

    if stdin_reader is None:
        stdin_reader = await _connect_stdin()
    if stdout_writer is None:
        stdout_writer = sys.stdout.buffer

    argv = shlex.split(wrapper)
    try:
        child = await asyncio.create_subprocess_exec(
            *argv,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=None,  # Pass through to our stderr -> Claude Code's LSP log
        )
    except FileNotFoundError as exc:
        print(f"lsp_proxy: child spawn failed: {exc}", file=sys.stderr)
        return 1

    assert child.stdin is not None
    assert child.stdout is not None

    # Wrap the subprocess transport writer for the host→container pump.
    dst_writer = _StreamWriterWrapper(child.stdin)

    host_to_container = asyncio.create_task(
        _pump_host_to_container(stdin_reader, dst_writer, host_root, container_root)
    )
    container_to_host = asyncio.create_task(
        _pump_container_to_host(child.stdout, stdout_writer, host_root, container_root)
    )

    results = await asyncio.gather(host_to_container, container_to_host, return_exceptions=True)

    # Wait for the child to actually exit.
    try:
        returncode = await asyncio.wait_for(child.wait(), timeout=5.0)
    except TimeoutError:
        child.kill()
        returncode = await child.wait()

    # If either pump raised, surface it via stderr and exit non-zero.
    for r in results:
        if isinstance(r, Exception) and not isinstance(r, asyncio.CancelledError):
            print(f"lsp_proxy: pump error: {r!r}", file=sys.stderr)
            return 1

    return 0 if returncode == 0 else returncode


async def _connect_stdin() -> asyncio.StreamReader:
    """Wrap sys.stdin as an asyncio StreamReader."""
    loop = asyncio.get_event_loop()
    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await loop.connect_read_pipe(lambda: protocol, sys.stdin)
    return reader


class _StreamWriterWrapper:
    """Adapts an asyncio.StreamWriter to the subset of the API the pump uses.

    `asyncio.subprocess.Process.stdin` is already a StreamWriter, so this
    wrapper just forwards. It exists so tests can pass BytesIO-like objects
    into pump helpers that expect `.write/.drain/.close`.
    """

    def __init__(self, inner: asyncio.StreamWriter) -> None:
        self._inner = inner

    def write(self, data: bytes) -> None:
        self._inner.write(data)

    async def drain(self) -> None:
        await self._inner.drain()

    def close(self) -> None:
        self._inner.close()


def _main() -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="LSP stdio proxy with URI rewriting for containerized LSPs"
    )
    parser.add_argument("--host-root", required=True, help="Host project root path")
    parser.add_argument("--container-root", required=True, help="Container project root path")
    parser.add_argument(
        "--wrapper",
        required=True,
        help="Full command string (split with shlex) to spawn the LSP child",
    )
    args = parser.parse_args()

    try:
        return asyncio.run(
            run(
                host_root=args.host_root,
                container_root=args.container_root,
                wrapper=args.wrapper,
            )
        )
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(_main())
