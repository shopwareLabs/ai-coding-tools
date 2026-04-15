# MCP Tool Enforcement & Integration

The plugin's value comes from Claude using the MCP tools instead of shelling out to `vendor/bin/phpstan` or `npm run lint`. Without help, Claude defaults to bash whenever it's faster to type, so this plugin layers hooks on top of the servers to keep it honest.

## 🚫 Watch Mode

MCP is a synchronous request-response protocol. A long-running watcher like `npm run hot` or `jest --watch` would block the server and hang every subsequent call, so watch commands aren't exposed as tools. Run them in a separate terminal and keep the MCP tools for one-shot builds, lint passes, and test runs.

## 🛡️ Enforcement Hooks

Three hooks work together. A **SessionStart** hook injects a directive at the top of every conversation that lists the available MCP tools and tells Claude to prefer them over bash; the prompt lives in `hooks/prompts/mcp-tool-directives.md` if you want to read or tweak it. A **PreToolUse** hook is the safety net: it intercepts bash commands that map to a known MCP tool and points Claude at the replacement, so even if the SessionStart directive got ignored or compacted away, the bad call gets caught before it runs. A **PostToolUse** hook watches `phpstan_analyze`. When it runs against specific files, it cross-references `phpstan-baseline.neon` (or `.php`) and surfaces a warning if any of the analyzed paths appear in the baseline, which usually means a baseline entry has gone stale. Full-project PHPStan runs skip the check because PHPStan validates the baseline natively there.

The SessionStart and PreToolUse hooks honor `enforce_mcp_tools` and turn off when it's `false`. The PostToolUse baseline check ignores the flag and always runs.

### Disabling Enforcement

Flip the switch per config file (`.mcp-php-tooling.json` or `.mcp-js-tooling.json`):

```json
{ "environment": "native", "enforce_mcp_tools": false }
```

### Blocked PHP Commands

| Bash Command                                                | MCP Tool                                         |
|-------------------------------------------------------------|--------------------------------------------------|
| `vendor/bin/phpstan`, `composer phpstan`                    | `mcp__php-tooling__phpstan_analyze`              |
| `vendor/bin/ecs`, `vendor/bin/php-cs-fixer`, `composer ecs` | `mcp__php-tooling__ecs_check` / `ecs_fix`        |
| `vendor/bin/phpunit`, `composer phpunit`                    | `mcp__php-tooling__phpunit_run`                  |
| `bin/console`, `php bin/console`                            | `mcp__php-tooling__console_run` / `console_list` |
| `vendor/bin/rector`, `composer rector`                      | `mcp__php-tooling__rector_fix` / `rector_check`  |

### Blocked JavaScript Commands

The JS hook picks Admin vs Storefront from path patterns in the command and redirects to the matching server.

| Bash Command                         | Admin MCP Tool    | Storefront MCP Tool |
|--------------------------------------|-------------------|---------------------|
| `npm run lint`, `npx eslint`         | `eslint_check`    | `eslint_check`      |
| `npm run lint:fix`                   | `eslint_fix`      | `eslint_fix`        |
| `npm run lint:scss`, `npx stylelint` | `stylelint_check` | `stylelint_check`   |
| `npm run format`, `npx prettier`     | `prettier_check`  | N/A (Admin only)    |
| `npm run unit`, `npx jest`           | `jest_run`        | `jest_run`          |
| `npm run lint:types`, `npx tsc`      | `tsc_check`       | N/A (Admin only)    |
| `npm run build`                      | `vite_build`      | N/A                 |
| `npm run production/development`     | N/A               | `webpack_build`     |

Commands that aren't blocked: `npm install`, `composer install`, watch-mode scripts, and any npm script that doesn't match one of the patterns above.

## 🔗 Plugin Integration

Other plugins can pull these tools into their own skills or agents by referencing them in frontmatter. The MCP tool name is `mcp__<server>__<tool>`:

```markdown
---
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check, mcp__js-admin-tooling__eslint_check
---
```

The `test-writing` plugin in this marketplace is a working example.
