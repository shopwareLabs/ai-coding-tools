# LSP Support

The dev-tooling plugin ships an optional Language Server Protocol bridge for PHP, powered by [phpactor](https://github.com/phpactor/phpactor) (MIT, pure PHP). With it enabled, Claude Code can call `documentSymbol`, `hover`, `goToDefinition`, `findReferences`, and diagnostics as regular tool invocations instead of having to grep or read large swaths of code to locate symbols.

Containerized environments get a little extra machinery. A stdlib-only Python proxy (`shared/lsp_proxy.py`) sits between Claude Code and phpactor and rewrites `file://` URIs on every LSP frame, so the language server inside the container sees paths that exist on its filesystem. Before spawning a containerized LSP, the dispatcher preflight-checks that the binary is actually present. If it isn't, it falls back to a minimal null stub so Claude doesn't crash-loop against a missing server.

> [!NOTE]
> Claude Code only issues LSP tool calls when `ENABLE_LSP_TOOL=1` is set in its environment (typically under `env` in `~/.claude/settings.json`). Without the flag, LSP diagnostics still surface passively in context, but the agent can't invoke LSP operations directly.

## 📦 Installation

LSP support is opt-in. Create `.lsp-php-tooling.json` with `"enabled": true` to turn it on. The `setting-up` skill can walk you through this interactively if you prefer.

Install [phpactor](https://phpactor.readthedocs.io/) wherever the LSP will actually run: on the host for `native`, inside the container for `docker`, `docker-compose`, `ddev`, or `vagrant`.

```bash
# host
brew install phpactor

# containerized
composer require --dev phpactor/phpactor
```

Minimal `.lsp-php-tooling.json` for docker-compose:

```json
{
  "environment": "docker-compose",
  "docker-compose": { "service": "web", "workdir": "/var/www/html" },
  "enabled": true
}
```

Containerized LSPs also need Python 3.12+ on the host `PATH` for the URI-rewriting proxy. It uses the standard library only, so there are no packages to install. Native mode execs phpactor directly and doesn't touch Python at all.

## 🚫 phpactor Limitations

Claude Code exposes nine LSP operations; phpactor implements six of them. What works: `documentSymbol`, `workspaceSymbol`, `hover`, `goToDefinition`, `goToImplementation`, and `findReferences`. What's missing: the call-hierarchy trio (`prepareCallHierarchy`, `incomingCalls`, `outgoingCalls`). Phpactor has no handler for them, so walk call chains manually with `findReferences` plus `goToDefinition`.

There's one known bug worth flagging. `workspaceSymbol` currently caps results at 250 and ignores the query string, so it returns the first 250 symbols no matter what you ask for. Prefer `documentSymbol` on a specific file, or fall back to Grep for a workspace-wide identifier search.

Cold-start latency is also something to know about. The first LSP request against a PHP file takes 10 to 30 seconds while phpactor parses it and resolves its dependencies. Subsequent requests against the same file are fast. There's no cache warmup today.

These limits are injected as SessionStart context via `hooks/scripts/lsp-directives.sh`, so Claude avoids the unsupported operations automatically when the PHP LSP is enabled in your project.

## 🧭 Scopes and the LSP

MCP tool scopes (`scopes` / `default_scope` in `.mcp-*-tooling.json`) do not apply to the LSP. phpactor always launches at the project root declared in `.lsp-php-tooling.json`, regardless of which scope the MCP tools are using.

This is intentional. Plugin-scoped LSPs would primarily buy a smaller index and faster startup, not better symbol resolution: phpactor resolves through composer autoload, so `Shopware\Core\…` FQNs resolve correctly from a plugin root, and dynamic lookups (DI container IDs, event names, Twig refs) stay opaque either way. Scoping would also make cross-boundary navigation worse — jumping from a plugin file into core would land outside the indexed tree. The extra config surface isn't worth the trade-off unless someone reports that indexing a big monorepo is too slow in practice.

If phpactor's cold-start or memory profile becomes a real issue on your project, file an issue with numbers and we'll revisit.

## 🩺 Troubleshooting LSP

**`Method not found from plugin:dev-tooling:phpactor`.** The dispatcher fell back to the null stub. Usual suspects: `enabled` is missing or set to `false` in the LSP config; the container wasn't running when Claude Code spawned the LSP (LSPs start lazily on the first matching file open, so either start the container before launching Claude Code, or restart Claude Code after bringing the container up); phpactor isn't installed inside the container; or `python3` isn't on the host `PATH` for containerized mode.

**LSP doesn't load at all.** Check the `/plugin` Errors tab and confirm `ENABLE_LSP_TOOL=1` is set in your Claude Code environment.

**LSP servers piling up inside the container.** If you run containerized LSPs and kill Claude Code (or let it time out on an in-flight tool call) without a clean LSP shutdown, the container-side phpactor process isn't reaped. This is a `docker exec -i` signal-propagation gap ([moby/moby#9098](https://github.com/moby/moby/issues/9098)): when the host-side exec process dies, the container-side child doesn't get signaled. Each new session spawns another server alongside the old ones, which can add up over a working day. Until the plugin handles this automatically, the options are to restart the service periodically (`docker compose restart <service>`) or to kill the stale servers by hand (`docker compose exec <service> pkill -f phpactor.phar`). Parallel Claude Code sessions on the same container are a valid pattern, so only blanket-kill phpactor processes when you're sure no other live session owns them.
