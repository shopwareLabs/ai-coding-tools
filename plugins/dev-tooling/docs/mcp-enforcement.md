# MCP Tool Enforcement & Integration

## 🚫 Watch Mode

MCP is request-response, so long-running watchers (`npm run hot`, `jest --watch`) would block the server. Run them in a terminal instead — use the MCP tools for one-shot builds, lint, and test runs.

## 🛡️ Enforcement Hooks

- **SessionStart** — injects a directive listing the MCP tools and telling Claude to prefer them over bash. Prompt lives in `hooks/prompts/mcp-tool-directives.md`.
- **PreToolUse** — blocks bash commands that map to a known MCP tool and points Claude at the replacement. Safety net for when the SessionStart directive is ignored.
- **PostToolUse** — after `phpstan_analyze` on specific files, checks `phpstan-baseline.neon`/`.php` for matching entries and warns about potentially stale baseline lines. Skipped for full-project runs (PHPStan validates the baseline natively there).

SessionStart and PreToolUse respect `enforce_mcp_tools` and turn off when it's `false`. The PostToolUse baseline check always runs.

### Disabling Enforcement

Per config file (`.mcp-php-tooling.json` or `.mcp-js-tooling.json`):

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

The JS hook picks Admin vs Storefront from path patterns in the command.

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

Not blocked: `npm install`, `composer install`, watch-mode scripts, unknown npm scripts.

## 🔗 Plugin Integration

Reference these tools in another plugin's frontmatter:

```markdown
---
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check, mcp__js-admin-tooling__eslint_check
---
```
