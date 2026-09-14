# Dev Tooling

PHP and JavaScript tooling for Shopware 6 exposed through three MCP servers, plus an optional PHP language server (phpactor) for active code discovery. Wraps the toolchain you already run on the command line: PHPStan, ECS, PHPUnit, Rector, Symfony Console, ESLint, Stylelint, Prettier, Jest, Vitest, ludtwig, TypeScript, and the Vite and Webpack builds. Works against native installs, Docker, Docker Compose, Vagrant, and DDEV, with the environment auto-detected from your config.

## 🧩 Features

### PHP Tools (`php-tooling`)
- `phpstan_analyze`: PHPStan static analysis
- `ecs_check`, `ecs_fix`: ECS / PHP-CS-Fixer code style
- `phpunit_run`: PHPUnit test runner
- `phpunit_coverage_gaps`: uncovered line and method discovery from a Clover report
- `console_run`, `console_list`: Symfony Console
- `rector_fix`, `rector_check`: Rector refactoring

### Administration Tools (`js-admin-tooling`)
- `eslint_check`, `eslint_fix`: ESLint
- `stylelint_check`, `stylelint_fix`: Stylelint SCSS
- `prettier_check`, `prettier_fix`: Prettier formatting
- `tsc_check`: TypeScript type checking
- `lint_all`: runs TSC, ESLint, Stylelint, and Prettier in one pass
- `lint_twig`: ESLint against Admin Vue Twig templates
- `jest_run`: Jest unit tests
- `unit_setup`: regenerate the component import resolver map
- `vite_build`: Vite build

### Storefront Tools (`js-storefront-tooling`)
- `eslint_check`, `eslint_fix`: ESLint
- `stylelint_check`, `stylelint_fix`: Stylelint SCSS
- `jest_run`: Jest unit tests for the `app/storefront` package suite
- `vitest_run`: Vitest tests for the component suite under `views/components/`
- `ludtwig_check`, `ludtwig_fix`: ludtwig linting for Twig templates
- `webpack_build`: Webpack build

> [!NOTE]
> Storefront tests are split across two runners. Jest's `rootDir` is the `app/storefront` package, so it never collects the component tests under `src/Storefront/Resources/views/components/` — those run through `vitest_run`, and `jest_run` rejects a `testPathPatterns` value naming that tree.

> [!IMPORTANT]
> `ludtwig_check` / `ludtwig_fix` need a `ludtwig` binary where the command runs (host or container). No tool in this plugin installs it.

> [!NOTE]
> Prettier and TypeScript aren't exposed for Storefront because the Shopware 6 Storefront `package.json` doesn't ship corresponding npm scripts.

### Shared Behavior

All three servers read a single JSON config per language (`.mcp-php-tooling.json`, `.mcp-js-tooling.json`) and discover it from the project root or any of the common AI-tool config directories (`.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, `.kiro/`). Multiple files are deep-merged so you can commit a base config and layer a personal override on top. Every command is wrapped for the declared environment (native, docker, docker-compose, vagrant, ddev). Known runtime noise such as Xdebug Step Debug connection failures is stripped from tool output before it reaches Claude, which keeps results clean without hiding actual errors.

### LSP Support (opt-in)

Optional Language Server Protocol integration for active PHP code discovery through [phpactor](https://github.com/phpactor/phpactor). See [docs/lsp.md](./docs/lsp.md) for installation, phpactor limitations, and troubleshooting.

## ⚡ Quick Start

### Installation

```bash
/plugin install dev-tooling@shopware-ai-coding-tools
```

> [!IMPORTANT]
> Restart Claude Code after installation so the three MCP servers come up.

### Interactive Setup

Install the `plugin-setup` plugin, then ask Claude to help you set up dev-tooling:

```bash
/plugin install plugin-setup@shopware-ai-coding-tools
```

```
Help me set up dev-tooling
```

The `dev-tooling-setting-up` skill checks prerequisites, walks you through config file creation, and validates the result. If you'd rather write the config by hand, [docs/configuration.md](./docs/configuration.md) covers the file formats, the discovery order, and the recommended `docker-compose` setup for the `shopware/shopware` repo.

### Verification

Run `/mcp` and confirm `php-tooling`, `js-admin-tooling`, and `js-storefront-tooling` are listed as connected servers.

## 🗜️ Tools Reference

The [full reference](./docs/reference.md) has parameter tables and examples for every tool; the table below is the quick scan, by server.

| Server                  | Tools                                                                                                                                                                                                       |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `php-tooling`           | `phpstan_analyze`, `ecs_check`, `ecs_fix`, `phpunit_run`, `phpunit_coverage_gaps`, `console_run`, `console_list`, `rector_fix`, `rector_check`, `set_project_root`, `cwd`                                   |
| `js-admin-tooling`      | `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `prettier_check`, `prettier_fix`, `jest_run`, `tsc_check`, `lint_all`, `lint_twig`, `unit_setup`, `vite_build`, `set_project_root`, `cwd` |
| `js-storefront-tooling` | `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `jest_run`, `vitest_run`, `ludtwig_check`, `ludtwig_fix`, `webpack_build`, `set_project_root`, `cwd`                                      |

## 🌳 Worktree Support

Every tool except `cwd`, on all three servers, takes an optional `project_root` to run one call against a linked git worktree of the root the server was launched in. `set_project_root` and `cwd` manage that state rather than targeting one call with it — `set_project_root` takes a `project_root` and sticks it for every later call on that server process (each server is a separate process holding its own sticky value), and omitting the argument clears it; `cwd` takes no parameters and reports what a server currently resolves to.

> [!NOTE]
> Worktree targeting is **native-only**. A worktree outside a container's mounted tree does not exist inside the container, so it is refused when the launch environment or the target's own configuration declares `docker`, `docker-compose`, `vagrant`, or `ddev` — create the worktree inside the mounted tree instead.

See [docs/reference.md](./docs/reference.md#-worktree-support) for the full parameter reference, and [docs/configuration.md](./docs/configuration.md) for how a worktree's own configuration is selected.

## 🤖 Agents

### dev-tooling-runner

A subagent that runs your dev-tooling checks — and, when you ask, the rule-driven fixers — and hands back a condensed pass/fail report, so a big `phpunit_run`, `phpstan_analyze`, coverage report, or Vite/Webpack build doesn't fill the conversation with output you read once and never reference again. It is built to run on **haiku**.

You decide what to check, whether to apply a fix, and which targets to give it. It maps each target to the right toolchain by path (PHP / admin JS / storefront JS), runs the matching MCP tools, and reports which checks passed, which failed (with capped `file:line` findings), any fixes it applied, and which remaining findings are mechanically auto-fixable. It only executes what you give it.

The SessionStart guidance steers Claude to delegate larger dev-tool runs to this agent. It is a soft default — a quick single-file check can still call the MCP tool inline.

> [!NOTE]
> The runner never freeform-edits and never decides scope on its own. It has no `Edit`/`Write`, so its only file changes come from the deterministic rule-driven fixers (`ecs_fix`, `rector_fix`, `eslint_fix`, `stylelint_fix`, `prettier_fix`, `ludtwig_fix`) — and only when your request asks for that fix. `console_run`, `console_list`, `unit_setup`, and `set_project_root` are denied via `disallowedTools` — `set_project_root`'s value is sticky and outlives the call that set it, so it would otherwise redirect every later dev-tooling call in your session.

## 🧭 Scopes

Use scopes when developing a Shopware plugin inside `custom/plugins/<name>/`. A scope declares the plugin cwd, per-tool configs (phpstan, rector, phpunit, style, eslint, stylelint, jest), and optional bootstrap prereqs.

### Config example (`.mcp-php-tooling.json`)

```json
{
  "environment": "docker-compose",
  "docker-compose": { "service": "web" },
  "default_scope": "swag-commercial",
  "scopes": {
    "swag-commercial": {
      "cwd": "custom/plugins/SwagCommercial",
      "phpstan": { "config": "phpstan.neon", "bootstrap": ["php tests/phpstan/bootstrap.php"] },
      "phpunit": { "config": "phpunit.xml.dist" },
      "style":   { "tool": "php-cs-fixer", "config": ".php-cs-fixer.dist.php" }
    }
  }
}
```

### Calling tools

- Omit `scope` → uses `default_scope` (or project-root behavior).
- Pass `scope: "swag-commercial"` → overrides the default for one call.
- Pass `scope: "shopware"` → forces project-root behavior.

Run the `setting-up` skill to let Claude probe the plugin and write the scope for you.

> [!NOTE]
> Scopes apply to MCP tools only, not to the LSP. phpactor always indexes the project root declared in `.lsp-php-tooling.json`. See [docs/lsp.md](./docs/lsp.md#-scopes-and-the-lsp) for the rationale.

## 📚 Documentation

The plugin docs are split by concern so the README stays scannable:

- [docs/configuration.md](./docs/configuration.md) covers config files, discovery priority, environment options, dependencies, and troubleshooting.
- [docs/mcp-enforcement.md](./docs/mcp-enforcement.md) explains the hook layer, how to turn it off, which bash commands get redirected, and how other plugins integrate with these tools.
- [docs/lsp.md](./docs/lsp.md) walks through the opt-in LSP setup, the known phpactor limitations, and container cleanup.
- [docs/reference.md](./docs/reference.md) is the full tool parameter reference.

## ⚖️ License

MIT
