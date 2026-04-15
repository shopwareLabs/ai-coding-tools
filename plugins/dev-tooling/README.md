# Dev Tooling

Development tools for PHP and JavaScript operations via MCP (Model Context Protocol), plus an optional **PHP language server** (phpactor) for active code discovery. Provides PHPStan, ECS, PHPUnit, Symfony Console, ESLint, Stylelint, Prettier, Jest, TypeScript, and build tools. Supports multiple development environments with auto-detection.

## 🧩 Features

### PHP Tools (php-tooling MCP Server)
- **PHPStan** static analysis via `phpstan_analyze`
- **ECS** code style checking via `ecs_check` and `ecs_fix`
- **PHPUnit** test execution via `phpunit_run`
- **PHPUnit Coverage Gaps** uncovered line discovery via `phpunit_coverage_gaps`
- **Symfony Console** command execution via `console_run` and `console_list`
- **Rector** automated refactoring via `rector_fix` and `rector_check`

### Administration Tools (js-admin-tooling MCP Server)
- **ESLint** linting via `eslint_check` and `eslint_fix`
- **Stylelint** SCSS linting via `stylelint_check` and `stylelint_fix`
- **Prettier** formatting via `prettier_check` and `prettier_fix`
- **TypeScript** type checking via `tsc_check`
- **All Lints** combined via `lint_all` (TypeScript + ESLint + Stylelint + Prettier)
- **Twig** template linting via `lint_twig`
- **Jest** testing via `jest_run`
- **Unit Setup** import resolver via `unit_setup`
- **Vite build** via `vite_build`

### Storefront Tools (js-storefront-tooling MCP Server)
- **ESLint** linting via `eslint_check` and `eslint_fix`
- **Stylelint** SCSS linting via `stylelint_check` and `stylelint_fix`
- **Jest** testing via `jest_run`
- **Webpack build** via `webpack_build`

> [!NOTE]
> Prettier and TypeScript tools are NOT available for Storefront because the Shopware 6 Storefront `package.json` does not include these scripts.

### Shared Features
- **Multi-environment support**: native, docker, docker-compose, vagrant, ddev
- **Environment noise filtering**: automatically strips known runtime warnings (e.g., Xdebug Step Debug connection failures) from all tool output, keeping results clean without hiding errors
- **Flexible configuration**: environment variable, project root, or LLM tool directories
- **Cross-tool support**: config discovery in `.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, `.kiro/`
- **Config merging**: multiple config files are deep-merged (later locations override earlier)

### LSP Support (opt-in)

Optional Language Server Protocol integration for active PHP code discovery using [phpactor](https://github.com/phpactor/phpactor). See [docs/lsp.md](./docs/lsp.md) for installation, limitations, and troubleshooting.

## ⚡ Quick Start

### Installation

```bash
/plugin install dev-tooling@shopware-ai-coding-tools
```

> [!IMPORTANT]
> Restart Claude Code after installation for the MCP servers to initialize.

### Interactive Setup

After restarting, ask Claude to help you set up the plugin:

```
Help me set up dev-tooling
```

The `setting-up` skill checks prerequisites, walks you through config file creation, and validates the result. For manual configuration, environment options, and the recommended `docker-compose` setup for `shopware/shopware`, see [docs/configuration.md](./docs/configuration.md).

### Verification

After restarting, verify the MCP servers are running:

```bash
/mcp
```

You should see `php-tooling`, `js-admin-tooling`, and `js-storefront-tooling` listed as connected servers.

## 🗜️ Tools Reference

27 tools across 3 MCP servers. See [docs/reference.md](./docs/reference.md) for full parameter docs and examples.

| Server                  | Tools                                                                                                                                                                            |
|-------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `php-tooling`           | `phpstan_analyze`, `ecs_check`, `ecs_fix`, `phpunit_run`, `phpunit_coverage_gaps`, `console_run`, `console_list`, `rector_fix`, `rector_check`                                   |
| `js-admin-tooling`      | `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `prettier_check`, `prettier_fix`, `jest_run`, `tsc_check`, `lint_all`, `lint_twig`, `unit_setup`, `vite_build` |
| `js-storefront-tooling` | `eslint_check`, `eslint_fix`, `stylelint_check`, `stylelint_fix`, `jest_run`, `webpack_build`                                                                                    |

## 📚 Documentation

- [docs/configuration.md](./docs/configuration.md) — config files, priority, environment options, dependencies, troubleshooting
- [docs/mcp-enforcement.md](./docs/mcp-enforcement.md) — hook enforcement, disabling, blocked commands, watch mode limitations, plugin integration
- [docs/lsp.md](./docs/lsp.md) — LSP installation, phpactor limitations, LSP troubleshooting
- [docs/reference.md](./docs/reference.md) — full tool parameter reference

## ⚖️ License

MIT
