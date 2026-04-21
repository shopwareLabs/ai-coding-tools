# Shopware Env

Bootstrap and maintain Shopware development environments. Exposes the full lifecycle toolchain — dependencies, database, frontend builds, and plugin management — through a single MCP server. A guided skill orchestrates the first-run flow from an empty directory to a running Shopware instance.

## 🧩 Features

### Setup Tools

- `install_dependencies`: Install PHP dependencies (composer) and JavaScript dependencies (admin + storefront); set `update: true` to regenerate lockfiles after bumping versions
- `database_install`: First-time database setup — drops, migrates, creates admin user and sales channel
- `database_reset`: Wipe and rebuild an existing database to a clean state
- `testdb_prepare`: Prepare the test database for integration tests

### Frontend Builds

- `frontend_build_admin`: Complete Administration build chain — bundle:dump, feature:dump, schema dumps, npm build, assets:install
- `frontend_build_storefront`: Complete Storefront build chain — bundle:dump, feature:dump, npm production build, theme:compile, assets:install

> [!NOTE]
> For quick iterative JS-only builds during active development, prefer `dev-tooling`'s `vite_build` (admin) and `webpack_build` (storefront). The lifecycle build tools run the full chain including Symfony console steps and are intended for initial setup and full rebuilds.

### Plugin Management

- `plugin_create`: Scaffold a new plugin skeleton in `custom/plugins/`, refresh the plugin list, install and activate
- `plugin_setup`: Register and activate an existing plugin from `custom/plugins/`

## ⚡ Quick Start

### Installation

```bash
/plugin install shopware-env@shopware-ai-coding-tools
```

> [!IMPORTANT]
> Restart Claude Code after installation so the `lifecycle-tooling` MCP server comes up.

### First-Time Setup

After restarting, ask Claude to set up your environment:

```
Set up a Shopware development environment
Bootstrap Shopware and a new plugin called SwagExample
Clone Shopware and SwagCommercial, set up everything
```

The `dev-environment-bootstrapping` skill activates automatically. It detects the current state of your working directory, presents a numbered action plan, asks for confirmation, then executes the steps via lifecycle MCP tools. When done, it prints a handoff message and stops.

## 🗜️ Tools Reference

All tools accept `environment`, `docker_service`, and `compose_file` as arguments. If `.mcp-php-tooling.json` is present, its environment settings take precedence over any arguments passed.

| Tool                        | Key Arguments                                                                      | Description                                                                 |
|-----------------------------|------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| `install_dependencies`      | `composer`, `administration`, `storefront`, `update` (booleans, all default false) | Install PHP and/or JS dependencies (`update: true` to regenerate lockfiles) |
| `database_install`          | `environment`, `docker_service`, `compose_file`                                    | First-time database setup                                                   |
| `database_reset`            | `environment`, `docker_service`, `compose_file`                                    | Wipe and rebuild to a clean state                                           |
| `testdb_prepare`            | `environment`, `docker_service`, `compose_file`                                    | Prepare test database                                                       |
| `frontend_build_admin`      | `environment`, `docker_service`, `compose_file`                                    | Full Administration build chain                                             |
| `frontend_build_storefront` | `environment`, `docker_service`, `compose_file`                                    | Full Storefront build chain                                                 |
| `plugin_create`             | `plugin_name` (required), `plugin_namespace` (required), environment args          | Scaffold and activate a new plugin                                          |
| `plugin_setup`              | `plugin_name` (required), environment args                                         | Register and activate an existing plugin                                    |

## 🎛️ Configuration

The `lifecycle-tooling` server reads the same `.mcp-php-tooling.json` config that `dev-tooling` uses. No separate config file is needed. If `dev-tooling` is already configured, lifecycle tools pick up that configuration automatically.

The config file is discovered from the project root and common AI-tool config directories (`.claude/`, `.cursor/`, `.windsurf/`, and others). Multiple files are deep-merged so you can layer a personal override on top of a committed base.

When a config file is present, `environment`, `docker_service`, and `compose_file` from the config override any arguments passed to the tool. The bootstrapping skill detects this and omits environment args from its MCP calls when a config file is found.

If no config file exists, tools use the `environment` argument you pass — or default to `native` if neither is provided.

## 🔗 Integration

`shopware-env` and `dev-tooling` are independent plugins installed separately. Installing one does not require the other. They are complementary: `shopware-env` gets the environment running, `dev-tooling` keeps it healthy during development.

The bootstrapping skill's final step prints install commands for `dev-tooling` and `gh-tooling`, then stops. From that point, `dev-tooling`'s `setting-up` skill takes over to configure the PHP and JS tooling for the running environment.

If `dev-tooling` is already installed, its tools (`vite_build`, `webpack_build`) are the better choice for iterative frontend work. The lifecycle `frontend_build_*` tools run the complete Symfony + npm chain and are meant for initial setup and full production-grade rebuilds.

## 🛡️ MCP Tool Enforcement

A `PreToolUse` hook intercepts bash commands that lifecycle MCP tools should handle instead. Blocked patterns:

| Bash Command                                                                         | Use Instead                                           |
|--------------------------------------------------------------------------------------|-------------------------------------------------------|
| `composer install`, `composer update`                                                | `install_dependencies`                                |
| `npm install`, `npm ci`                                                              | `install_dependencies`                                |
| `bin/console system:install`, `bin/console system:setup`                             | `database_install`                                    |
| `bin/console plugin:create`                                                          | `plugin_create`                                       |
| `bin/console plugin:install`, `plugin:refresh`, `plugin:activate`                    | `plugin_setup`                                        |
| `bin/console bundle:dump`, `assets:install`, `feature:dump`, `framework:schema:dump` | `frontend_build_admin` or `frontend_build_storefront` |
| `bin/console theme:compile`                                                          | `frontend_build_storefront`                           |

To disable enforcement, add `"enforce_mcp_tools": false` to `.mcp-php-tooling.json`.

A `SessionStart` hook injects lifecycle tool directives into the session context at startup so Claude knows which tools are available without being asked.

## 🚫 Not Supported / Out of Scope

- **HMR / watch mode** — hot module replacement requires a long-running process; MCP tools are single-shot. Use `npm run watch` directly for active development.
- **Docker Compose lifecycle** — starting, stopping, and recreating containers is not in scope. Bring your environment up before invoking lifecycle tools.
- **Database migrations only** — `testdb_prepare` prepares the test database; running incremental migrations on an already-installed database is not a supported workflow.
- **Multi-environment installs** — tools operate on one configured environment per call. Parallel installs to multiple targets are not supported.
- **Shopware Cloud / PaaS deploys** — tools wrap local CLI commands and are intended for local development environments only.

## ⚖️ License

MIT
