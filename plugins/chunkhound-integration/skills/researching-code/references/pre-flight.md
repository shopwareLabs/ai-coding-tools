# Pre-flight: daemon_status

Call `mcp__plugin_chunkhound-integration_ChunkHound__daemon_status` once per skill invocation when the planned approach uses any ChunkHound primitive (`code_research` or `search`). Skip only when the plan searches no code — a known-path `Read` and a path-pattern `bfs` both qualify, because neither consults the index. Every plan that searches code opens with a ChunkHound primitive and therefore reaches this gate. Do not cache between invocations — daemon state drifts.

## Hard gates — STOP if any fail

If any of these are wrong, **stop**. Return the structured failure shape below to the caller. Do not downgrade the plan to `ugrep` or `bfs` and answer anyway — native tools cannot answer the questions that required ChunkHound, and a downgrade produces results that look complete but aren't. A failed gate means the research did not happen; say so rather than substituting a word-based search.

- **`status`** must be `"ready"` — `"initializing"` and `"degraded"` are not usable states.
- **`query_ready`** must be `true` — otherwise no scan has ever completed and the index cannot answer queries.
- **`scan_progress.scan_error`** must be null or absent — a set value means the last scan failed and results would be unreliable. (The key does not exist before the first scan starts; absence is not a failure.)

## Embeddings gate (when the plan uses semantic search or `code_research`)

`daemon_status` can pass all three hard gates above while the index has chunks but no embeddings — typically because the embedding provider was misconfigured (or absent) during the initial index, and embeddings are not added retroactively to existing chunks. Semantic queries against such an index return nothing without any error, which would silently degrade `code_research` and `search` semantic results.

Run this gate only when the plan uses ChunkHound primitives that rely on embeddings: `search` with `type: "semantic"` or `code_research`. Skip it when the plan uses only `search` with `type: "regex"`.

The probe is cheap — `search` is fast, unlike `code_research`. Use a high-recall noise word:

```
mcp__plugin_chunkhound-integration_ChunkHound__search(
  type="semantic",
  query="function",
  page_size=1
)
```

The probe returns rendered text (result blocks plus a paging footer like `Page 1 of 3 (results 1–1 of 3)`), not a JSON object — there is no `total` field to read. Interpret what renders:

- At least one result block rendered → embeddings present; proceed to Step 3.
- No result blocks rendered → **missing embeddings**. Stop. Return failure (see the failure return shape below) with `embeddings_missing` in the failed-gates list. (The hard gates above already established that a scan completed, so an empty probe cannot be a freshly-started first index.)
- **Schema error rejecting `type: "semantic"`** → no embedding provider is registered. The daemon's tool schema restricts the `type` enum to `["regex"]` in this case (see `chunkhound/mcp_server/base.py` → `_build_filtered_tool_dicts`). Stop. Return failure with `no_embedding_provider` in the failed-gates list. This is the more severe variant: semantic search is structurally unavailable, not merely empty.

Remediation in both stop cases: re-run `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index` with the embedding provider configured correctly in `.chunkhound.json`. A forced reindex is required — embeddings are not added retroactively.

## Warnings — proceed, surface in synthesis

Collect any that fire and include them under "Index health notes" in the synthesis output so coverage caveats land inline with the findings rather than getting buried.

- **`scan_progress.realtime.failed_files` > 0** — "N files were skipped during indexing — results may miss them"
- **`scan_progress.realtime.pending_files` > 0** or **`scan_progress.realtime.pending_mutations.total` > 0** — "Index is catching up; recent file changes may not be reflected"
- **`scan_progress.realtime.service_state` != `"running"`** — "Live indexing is offline; results reflect the last full scan only"
- **`scan_progress.realtime.last_warning` or `last_error` not null** — surface the message verbatim
- **`scan_progress.is_scanning` is `true`** — "A re-scan is in progress; recent changes may not yet be indexed"
- **`scan_progress.realtime.resync.needs_resync` is `true`** — "Index has drifted from the filesystem; recommend running `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index`"

## Failure return shape

When a hard gate fails, return:

```
Status: unavailable
Failed gates: <list of gates that failed>
Daemon status (raw): <verbatim daemon_status payload>
Remediation:
  - status != "ready" → run the setup diagnostic below; restart Claude Code if the MCP server did not load
  - query_ready == false → if `scan_progress.is_scanning` is true, a scan is running: wait and retry; otherwise run `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index` in the project root
  - scan_error is set → read the scan_error message; re-run `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index`
  - embeddings_missing → re-run `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index` with an embedding provider configured in `.chunkhound.json` (forced reindex; embeddings are not added retroactively to existing chunks)
  - no_embedding_provider → configure an embedding provider in `.chunkhound.json` (voyageai or openai), then re-run `CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index`
```

Include only the remediation lines whose gate actually failed.

If `daemon_status` itself is not callable (the MCP tool is not registered or the server is not loaded), skip the gates and warnings and return the failure with the **Setup diagnostic** content below as the remediation block.

## Setup diagnostic

Use this when `daemon_status` is unavailable or when a caller wants a comprehensive health check beyond pre-flight gates. The skill itself cannot execute these checks (its `allowed-tools` does not include arbitrary Bash) — emit them as remediation steps for the caller to run.

### Diagnostic steps

1. **Check installation** — `chunkhound --version`. Verify chunkhound is installed.
2. **Check configuration** — look for `.chunkhound.json` in priority order (last wins): project root, `.ai/`, `.aider/`, `.cursor/`, `.kite/`, `.llm/`, `.tabnine/`, `.claude/`. Read the highest-priority config found.
3. **Check database** — read `database.path` from the config (defaults to `.chunkhound` if unspecified). Verify the directory exists.
4. **Re-test MCP connection** — call `daemon_status` again. If it now responds, drop back into the gate flow above.

### Report format

Summarize findings as a checklist, one line per component:

- **Installation** — OK / Missing (version, or error message if missing)
- **Config** — OK / Missing (provider and embedding model when present)
- **Database** — OK / Missing (path and last-modified timestamp when present)
- **MCP Tools** — OK / Unavailable (which tools, if any, respond)

### Common remediation

- **Index missing** (database path does not exist): `cd /path/to/project && CHUNKHOUND_DB_EXECUTE_TIMEOUT=120 chunkhound index`
- **Config missing**: provide a minimal `.chunkhound.json` template:

  ```json
  {
    "embedding": { "provider": "voyageai", "api_key": "YOUR_API_KEY" },
    "llm": { "provider": "claude-code-cli" }
  }
  ```

- **MCP tools unavailable**: restart Claude Code after plugin installation.
