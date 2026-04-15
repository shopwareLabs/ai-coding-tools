# LSP Support

Optional LSP integration for active PHP code discovery. When enabled, Claude Code can invoke `documentSymbol`, `hover`, `goToDefinition`, `findReferences`, and diagnostics as tool calls. Backed by [phpactor](https://github.com/phpactor/phpactor) (MIT, pure-PHP).

For containerized environments, a stdlib Python URI-rewriting proxy (`shared/lsp_proxy.py`) translates `file://` URIs between host and container on every LSP frame so phpactor sees paths that exist in its filesystem. The dispatcher preflight-checks the binary inside the container and falls back to a null stub on failure, so missing LSPs don't crash-loop Claude Code.

> [!NOTE]
> Claude Code only issues LSP tool calls when `ENABLE_LSP_TOOL=1` is set in its environment (typically under `env` in `~/.claude/settings.json`). Without it, diagnostics still surface passively but the agent cannot call LSP operations directly.

## 📦 Installation

LSP is opt-in: create `.lsp-php-tooling.json` with `"enabled": true`. The `setting-up` skill walks through this.

Install [phpactor](https://phpactor.readthedocs.io/) wherever it will run — on the host for `native`, inside the container for `docker` / `docker-compose` / `ddev` / `vagrant`:

```bash
# host
brew install phpactor

# containerized
composer require --dev phpactor/phpactor
```

Minimal `.lsp-php-tooling.json` (docker-compose):

```json
{
  "environment": "docker-compose",
  "docker-compose": { "service": "web", "workdir": "/var/www/html" },
  "enabled": true
}
```

Containerized LSPs additionally need Python 3.12+ on the host PATH for the URI-rewriting proxy (stdlib-only, no packages). Native mode execs phpactor directly and has no Python dependency.

## 🚫 phpactor Limitations

Of the nine LSP operations Claude Code exposes:

- **Supported:** `documentSymbol`, `workspaceSymbol`, `hover`, `goToDefinition`, `goToImplementation`, `findReferences`
- **Not implemented by phpactor:** `prepareCallHierarchy`, `incomingCalls`, `outgoingCalls` — walk call chains with `findReferences` + `goToDefinition`
- **`workspaceSymbol` bug:** caps at 250 results and ignores the query string. Use `documentSymbol` on a specific file or fall back to Grep
- **Cold start:** first request against a PHP file takes 10–30s while phpactor parses and resolves dependencies. Subsequent requests are fast. No cache warmup today

These limits are injected as SessionStart context via `hooks/scripts/lsp-directives.sh` so Claude avoids unsupported operations.

## 🩺 Troubleshooting

**`Method not found from plugin:dev-tooling:phpactor`** — dispatcher fell back to the null stub. Check: `enabled: true` in the LSP config; container running when Claude Code spawned the LSP (LSPs start lazily on first matching file open, so start the container *before* launching Claude Code); `phpactor` installed inside the container; `python3` on the host PATH for containerized mode.

**LSP not loading at all** — check the `/plugin` Errors tab and confirm `ENABLE_LSP_TOOL=1`.

**LSP servers accumulating inside the container** — killing Claude Code (or a timed-out tool call) does not reap the container-side phpactor process. This is a `docker exec -i` signal-propagation gap ([moby/moby#9098](https://github.com/moby/moby/issues/9098)): when the host-side exec dies, the container child is not signaled. Each session spawns another server, which adds up over a day. Workarounds:

- Restart the service periodically: `docker compose restart <service>`
- Kill stale servers: `docker compose exec <service> pkill -f phpactor.phar` — only when you know no other live session owns them. Parallel Claude Code sessions on the same container are valid and should not be blanket-killed.
