# MCP Tool Enforcement & Integration

The plugin's value comes from Claude using the MCP tools instead of shelling out to `vendor/bin/phpstan` or `npm run lint`. Without help, Claude defaults to bash whenever it's faster to type, so this plugin layers hooks on top of the servers to keep it honest.

## 🚫 Watch Mode

MCP is a synchronous request-response protocol. A long-running watcher like `npm run hot` or `jest --watch` would block the server and hang every subsequent call, so watch commands aren't exposed as tools. Run them in a separate terminal and keep the MCP tools for one-shot builds, lint passes, and test runs.

## 🛡️ Enforcement Hooks

Three hook events carry scripts between them: SessionStart, PreToolUse, and PostToolUse.

**SessionStart** runs one script. It injects a directive at the top of every conversation that lists the available MCP tools and tells Claude to prefer them over bash; the prompt lives in `hooks/prompts/mcp-tool-directives.md` if you want to read or tweak it. On a host that names the session directory only in the hook input rather than in `CLAUDE_PROJECT_DIR` — Codex — the directive comes from `hooks/prompts/mcp-tool-directives-codex.md` instead, which leaves out the runner-agent and `EnterWorktree`/`ExitWorktree` guidance Codex has no counterpart for, and the hook also appends a short hint naming that directory and the `set_project_root` call that binds a server which started without a project root.

**PreToolUse** runs one script per server, and they are the safety net: they intercept bash commands that map to a known MCP tool and point Claude at the replacement, so even if the SessionStart directive got ignored or compacted away, the bad call gets caught before it runs. Each block message names the tool and its server — ``Use `phpstan_analyze` on the `php-tooling` MCP server instead!`` — which reads the same on Claude Code and on Codex, where the full tool name differs.

> [!NOTE]
> The PreToolUse hooks match each line of a command on its own. A heredoc body or a multi-line quoted string with a line that starts like a blocked command, such as a commit message line `npx eslint now runs` or `vendor/bin/phpstan is clean`, is blocked as if that line were a command. Write the text to a file with the Write tool and pass the file instead: `git commit -F <file>`, `gh pr create --body-file <file>`.

**PostToolUse** runs two. One watches `phpstan_analyze`: when it runs against specific files, it cross-references `phpstan-baseline.neon` (or `.php`) and surfaces a warning if any of the analyzed paths appear in the baseline, which usually means a baseline entry has gone stale. Full-project PHPStan runs skip the check because PHPStan validates the baseline natively there. Its matcher carries both host spellings of the tool name, so it fires for a Claude Code plugin install and for a Codex install alike. The other watches `EnterWorktree` and `ExitWorktree` — both Claude Code tools — and reminds the session to call `set_project_root` on all three servers, since each holds its own sticky root.

The SessionStart script, `session-start.sh`, honors `enforce_mcp_tools` and turns off when it's `false`; the project-root hint above is not gated on the flag, because a server started without a project root refuses every tool whatever the flag says. Every PreToolUse script honors the flag. Both PostToolUse scripts, the baseline check and the worktree-directives reminder, ignore the flag and always run.

On Codex, hooks run only once you trust them: its startup review and the `/hooks` command each record trust in your Codex user config, an untrusted hook is skipped, and a non-interactive `codex exec` runs the trusted hooks without asking or all of them with `--dangerously-bypass-hook-trust`. All of them are plugin hooks, so none runs there until you trust it.

### Disabling Enforcement

Flip the switch per config file (`.mcp-php-tooling.json` or `.mcp-js-tooling.json`):

```json
{ "environment": "native", "enforce_mcp_tools": false }
```

### Blocked PHP Commands

| Bash Command                                                       | MCP Tool on `php-tooling`      |
|--------------------------------------------------------------------|--------------------------------|
| `vendor/bin/phpstan`, `composer phpstan`                           | `phpstan_analyze`              |
| `vendor/bin/ecs`, `vendor/bin/php-cs-fixer`, `composer ecs`        | `ecs_check` / `ecs_fix`        |
| `vendor/bin/phpunit`, `composer phpunit`                           | `phpunit_run`                  |
| `bin/console`, `php bin/console`                                   | `console_run` / `console_list` |
| `vendor/bin/rector`, `composer rector`, `composer rector-fix`      | `rector_fix` / `rector_check`  |

### Blocked JavaScript Commands

The JS hook picks Admin vs Storefront from the command itself and redirects to the matching server. Detection is by path pattern first, then by script names that belong to one side — `lint:js`, `production`, `development`, `unit:components`, `eslint:app`, `eslint:components` and `stylelint:app` for Storefront, plus a bare `ludtwig`, which lints Storefront Twig templates and nothing else. `jest:base` carries no side-specific marker, so it cannot be classified this way: a command that also names the Storefront tree (path pattern or another Storefront-only script) is claimed by the Storefront hook, and every other `jest:base` invocation — including a bare one — falls to the Admin hook's unknown-context default.

> [!NOTE]
> Detection reads the whole command string, so a compound command that names both trees — `git diff -- src/Administration src/Storefront && npm run jest:base` — satisfies both detectors and is blocked twice, once per server. This applies to any command mentioning both trees, not only the base scripts.

Tool binaries are blocked when run directly at a command position, in three forms:

- `npx <binary>`, `npm exec <binary>` or its alias `npm x <binary>`, with an optional version suffix (`npx eslint@9`).
- `<path>/node_modules/.bin/<binary>`.
- The command-string form, `npx -c '<string>'`, `npm exec -c "<string>"` or `--call`, when the string runs the binary at its start or after `;`, `&&` or `|` (`npm exec --no -c "cd ../.. && eslint views/components"`).

The binaries are `eslint`, `stylelint` and `jest` on both servers, `prettier` and `tsc` on Administration only, and `vitest` on Storefront only. Between the runner and the binary the hooks look past `-y`, `--yes`, `--no`, `--no-install`, `-q`, `--quiet`, `--silent` and `--`. Before `-c` they look past the same flags except `--`, plus `--package`, `-p`, `--workspace` and `-w` with their value.

Not blocked:

- A flag that takes a value before the binary (`npx --package=eslint eslint`, `npm exec --workspace foo -- eslint`). Reading its value as the binary would also block `npm exec --package eslint some-other-tool`.
- A bare binary name (`eslint`, `jest`). A command-position match would block a commit message containing `; eslint config`.
- A binary name in an argument.

[reference.md](./reference.md) describes how each MCP tool routes its own path-scoped runs. The table still lists `stylelint:base`, `prettier:base`, `jest:base`, `eslint:app`, `eslint:components` and `stylelint:app`, which Shopware's `package.json` files do not define, because a project can define them.

| Bash Command                                                                                                                                               | Admin MCP Tool    | Storefront MCP Tool |
|------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------|---------------------|
| `npm run lint`, `npx eslint`, `npm exec eslint`, `node_modules/.bin/eslint`                                                                                | `eslint_check`    | `eslint_check`      |
| `npm run lint:js`                                                                                                                                          | N/A               | `eslint_check`      |
| `npm run lint:debugging`                                                                                                                                   | `eslint_check`    | N/A                 |
| `npm run eslint:app`, `npm run eslint:components`                                                                                                          | N/A               | `eslint_check`      |
| `npm run lint:fix`                                                                                                                                         | `eslint_fix`      | `eslint_fix`        |
| `npm run lint:js:fix`                                                                                                                                      | N/A               | `eslint_fix`        |
| `npm run lint:scss`, `npx stylelint`, `npm exec stylelint`, `node_modules/.bin/stylelint`                                                                  | `stylelint_check` | `stylelint_check`   |
| `npm run stylelint:base`                                                                                                                                   | `stylelint_check` | N/A                 |
| `npm run stylelint:app`                                                                                                                                    | N/A               | `stylelint_check`   |
| `npm run lint:scss-fix`                                                                                                                                    | `stylelint_fix`   | `stylelint_fix`     |
| `npm run format`, `npx prettier`, `npm exec prettier`, `node_modules/.bin/prettier`                                                                        | `prettier_check`  | N/A (Admin only)    |
| `npm run prettier:base`                                                                                                                                    | `prettier_check`  | N/A (Admin only)    |
| `npm run format:fix`                                                                                                                                       | `prettier_fix`    | N/A (Admin only)    |
| `npm run unit`, `npx jest`, `npm exec jest`, `node_modules/.bin/jest`                                                                                      | `jest_run`        | `jest_run`          |
| `npm run jest:base`                                                                                                                                        | `jest_run`        | `jest_run`          |
| `npm run lint:types`, `npx tsc`, `npm exec tsc`, `node_modules/.bin/tsc`                                                                                   | `tsc_check`       | N/A (Admin only)    |
| `npm run lint:all`                                                                                                                                         | `lint_all`        | N/A (Admin only)    |
| `npm run lint:twig`                                                                                                                                        | `lint_twig`       | N/A (Admin only)    |
| `npm run build`                                                                                                                                            | `vite_build`      | N/A                 |
| `npm run unit:components` (and `:watch` / `:coverage`), `npx vitest`, `npm exec vitest`, `node_modules/.bin/vitest`, `composer storefront:components:unit` | N/A               | `vitest_run`        |
| `composer ludtwig:storefront`, bare `ludtwig`                                                                                                              | N/A               | `ludtwig_check`     |
| `composer ludtwig:storefront:fix`                                                                                                                          | N/A               | `ludtwig_fix`       |
| `npm run production/development`                                                                                                                           | N/A               | `webpack_build`     |

`npm run unit` and `npm run unit:components` are matched by separate patterns, so the component suite is redirected to `vitest_run` and never to `jest_run`. The `:fix` ludtwig pattern is tested before the plain one, so `composer ludtwig:storefront:fix` resolves to `ludtwig_fix` rather than being shadowed by `ludtwig_check`.

Commands that aren't blocked: `npm install`, `composer install`, watch-mode scripts other than `npm run unit:components:watch`, any npm script that doesn't match one of the patterns above, the bare binary names described above, and `npx`, `npm exec` or `npm x` running a tool not named in the table.

## 🔗 Plugin Integration

Other plugins can pull these tools into their own skills or agents by referencing them in frontmatter. On Claude Code a plugin-provided server's tools are named `mcp__plugin_<plugin>_<server>__<tool_name>`, so the PHP tools here are `mcp__plugin_dev-tooling_php-tooling__<tool_name>`:

```markdown
---
tools: mcp__plugin_dev-tooling_php-tooling__phpstan_analyze, mcp__plugin_dev-tooling_php-tooling__ecs_check, mcp__plugin_dev-tooling_js-admin-tooling__eslint_check
---
```

On Codex the name keeps the plain MCP form and replaces every character outside `[A-Za-z0-9_]` in the server name with `_`, so those three become `mcp__php_tooling__phpstan_analyze`, `mcp__php_tooling__ecs_check`, and `mcp__js_admin_tooling__eslint_check`.

The `test-writing` plugin in this marketplace is a working example.
