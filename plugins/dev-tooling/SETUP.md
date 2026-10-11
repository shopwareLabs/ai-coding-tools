# Dev Tooling Setup

## Table of Contents

- [Prerequisites](#prerequisites)
- [Configuration Files](#configuration-files)
  - [.mcp-php-tooling.json](#mcp-php-toolingjson)
  - [.mcp-js-tooling.json](#mcp-js-toolingjson)
- [Plugin Scope Setup](#plugin-scope-setup)
- [Permission Groups](#permission-groups)
- [Validation](#validation)
  - [Stage 1 — Pre-restart](#stage-1--pre-restart)
  - [Stage 2 — Post-restart (live MCP dispatch)](#stage-2--post-restart-live-mcp-dispatch)
- [Post-Setup](#post-setup)

## Prerequisites

### jq
- **Check**: `jq --version`
- **Install**: https://jqlang.github.io/jq/download/
- **Required by**: All three MCP servers (php-tooling, js-admin-tooling, js-storefront-tooling)

## Configuration Files

### Scope of this setup

This skill configures MCP wiring only. It does not run `composer install`, initialize the database, install or activate plugins, or build `node_modules`. Without those project-readiness steps, MCP tools will start but most return errors at call time.

### .mcp-php-tooling.json
- **Required**: Yes (the PHP tooling MCP server will not start without it)
- **Location**: Project root, or one of the tool-config directories (`.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, `.kiro/`). Multiple files are deep-merged. See `docs/configuration.md` for the full discovery order. Plugin subdirectories such as `custom/plugins/<name>/` are NOT scanned — a file written there will be silently ignored. If the user proposes a plugin-subdir destination, refuse and restate the valid destinations.
- **Schema reference**: `mcp-server-php/mcp-php-tooling.schema.json` in the dev-tooling plugin

#### Setup Questions

1. **Environment**: What execution environment does your project use for PHP?
   - `native` — PHP is installed directly on your machine
   - `docker` — PHP runs inside a standalone Docker container
   - `docker-compose` — PHP runs as a service in a `docker-compose.yml` stack (recommended for the `shopware/shopware` repo)
   - `vagrant` — PHP runs inside a Vagrant VM
   - `ddev` — You use DDEV for local development

2. **Docker container name** (only if environment = docker): What is the name of your Docker container that runs PHP? This is the container name from `docker ps`, e.g. `shopware_app`.

3. **Docker working directory** (only if environment = docker, optional): What is the working directory inside the Docker container? Default: `/var/www/html`

4. **Compose service name** (only if environment = docker-compose): Which service in your `docker-compose.yml` runs PHP? Default: `web`

5. **Compose working directory** (only if environment = docker-compose, optional): Working directory inside the compose service. Leave blank to use the service's default `WORKDIR`.

6. **Compose file** (only if environment = docker-compose, optional): Path to a specific compose file. Leave blank to let `docker compose` auto-discover `docker-compose.yml` / `compose.yml` from the project root.

7. **Vagrant working directory** (only if environment = vagrant, optional): What is the working directory inside the Vagrant VM? Default: `/vagrant`

8. **DDEV working directory** (only if environment = ddev, optional): What is the working directory inside DDEV? Default: `/var/www/html`

9. **MCP tool enforcement**: Should PreToolUse hooks redirect direct CLI invocations of PHPStan, ECS, PHPUnit, and `bin/console` to the MCP tools?
   - `true` (default, recommended) — bash commands like `vendor/bin/phpstan analyze …` are blocked with a hint to use the MCP tool instead. See `docs/mcp-enforcement.md` for the full redirect list.
   - `false` — direct CLI invocations are allowed. Choose this if you rely on the CLI output format, run tools inside long bash pipelines, or find the redirect intrusive.

Stored as `enforce_mcp_tools` in the config.

10. **Set tool defaults?** (optional gate): Do you want to set default config paths or per-tool options for PHPStan, ECS, Rector, PHPUnit, or Symfony Console? Most projects can skip this — the underlying tools auto-discover their config files and every MCP tool accepts per-call overrides.
    - `no` (default) → skip the rest of this section
    - `yes` → continue with questions 11–14

11. **PHPStan memory limit** (only if set-tool-defaults = yes, optional): Override the PHP memory limit used for PHPStan runs? Large Shopware projects typically need `2G`. Leave blank to use the PHP default. Stored as `phpstan.memory_limit`.

12. **PHPStan config path** (only if set-tool-defaults = yes, optional): Path to a non-default `phpstan.neon` / `phpstan.dist.neon`. Leave blank to let PHPStan auto-discover. Stored as `phpstan.config`.

13. **PHPUnit defaults** (only if set-tool-defaults = yes, optional): If you want a default test suite, coverage driver, or non-default `phpunit.xml`, provide them. Leave any field blank to skip. Stored under `phpunit.testsuite`, `phpunit.coverage_driver` (`xdebug` or `pcov`), `phpunit.config`.

14. **ECS and Rector config paths** (only if set-tool-defaults = yes, optional): Paths to non-default `ecs.php` and `rector.php`. Leave blank to auto-discover. Stored as `ecs.config` and `rector.config`.

Symfony Console defaults (`console.env`, `console.verbosity`, `console.no_debug`, `console.no_interaction`) are configurable but almost never need project-wide defaults — the `console_run` tool takes them per call. Add them to the config by hand if you need them; see the schema for the full list.

#### Minimal Config

```json
{
  "environment": "native"
}
```

#### Full Config Example

```json
{
  "environment": "docker",
  "docker": {
    "container": "shopware_app",
    "workdir": "/var/www/html"
  },
  "enforce_mcp_tools": true,
  "phpstan": {
    "memory_limit": "2G"
  }
}
```

### .mcp-js-tooling.json
- **Required**: No (only needed if you want Administration or Storefront JavaScript tooling: ESLint, Stylelint, Prettier, Jest, TypeScript, Vite, Webpack)
- **Location**: Project root, or one of the tool-config directories listed for `.mcp-php-tooling.json`. Plugin subdirectories are NOT scanned — same rule as the PHP config. See `docs/configuration.md`.
- **Schema reference**: `shared/mcp-js-tooling.schema.json` in the dev-tooling plugin

#### Setup Questions

1. **Environment**: What execution environment does your project use for JavaScript/Node.js?
   - `native` — Node.js is installed directly on your machine
   - `docker` — Node.js runs inside a standalone Docker container
   - `docker-compose` — Node.js runs as a service in a `docker-compose.yml` stack
   - `vagrant` — Node.js runs inside a Vagrant VM
   - `ddev` — You use DDEV for local development

   This is typically the same environment as PHP. If your PHP runs in a container but you run npm/node natively, choose `native`.

2. **Docker container name** (only if environment = docker): What is the name of your Docker container that runs Node.js? This may be the same container as PHP.

3. **Docker working directory** (only if environment = docker, optional): What is the working directory inside the Docker container? Default: `/var/www/html`

4. **Compose service name** (only if environment = docker-compose): Which service in your `docker-compose.yml` runs Node.js? Default: `web`

5. **Compose working directory** (only if environment = docker-compose, optional): Working directory inside the compose service. Leave blank to use the service's default `WORKDIR`.

6. **Compose file** (only if environment = docker-compose, optional): Path to a specific compose file. Leave blank to let `docker compose` auto-discover `docker-compose.yml` / `compose.yml` from the project root.

7. **Vagrant working directory** (only if environment = vagrant, optional): Working directory inside the Vagrant VM. Default: `/vagrant`

8. **DDEV working directory** (only if environment = ddev, optional): Working directory inside DDEV. Default: `/var/www/html`

9. **MCP tool enforcement**: Should PreToolUse hooks redirect direct CLI invocations of ESLint, Stylelint, Prettier, Jest, TSC, Vite, and Webpack to the MCP tools?
   - `true` (default, recommended) — bash commands like `npm run lint` are blocked with a hint to use the MCP tool instead. The hook scopes by context (admin vs storefront), so it only blocks the commands your JS work actually runs. See `docs/mcp-enforcement.md` for the full redirect list.
   - `false` — direct CLI invocations are allowed.

Stored as `enforce_mcp_tools` in the config.

#### Minimal Config

```json
{
  "environment": "native"
}
```

#### Full Config Example

```json
{
  "environment": "docker",
  "docker": {
    "container": "shopware_app",
    "workdir": "/var/www/html"
  },
  "enforce_mcp_tools": true
}
```

## Plugin Scope Setup

Optional phase. Writes one or more scopes into `.mcp-php-tooling.json` and/or `.mcp-js-tooling.json` and optionally pins one as `default_scope` when the user develops against a Shopware plugin in `custom/plugins/<name>/`.

### Gate Question

**Are you developing a Shopware plugin in this project?** — If No, skip this phase entirely.

### Setup Questions

1. **Plugin discovery**: Glob `custom/plugins/*/composer.json` and filter to entries with `"type": "shopware-platform-plugin"`.
   - 0 matches → ask the user to enter a relative plugin path manually.
   - 1 match → confirm it.
   - N matches → present a multi-choice list via AskUserQuestion.

2. **Scope name**: Default = plugin directory name kebab-cased. Offer the default and accept any non-empty override. Reject `"shopware"` (it is reserved for project-root behavior).

3. **Always-written field**: `cwd = <plugin-directory-relative-to-project-root>` (schema-required). Every other path the skill collects is interpreted relative to this `cwd`.

4. **Probing**: For each probe below that is found inside the plugin root, ask the corresponding question. Every path written into the scope is relative to the scope's `cwd`.

| Probe                                          | Question if found                                                                 | Writes into scope (relative to scope.cwd)                                         |
|------------------------------------------------|-----------------------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| `phpstan.neon`                                 | "Plugin has phpstan.neon — use it?"                                               | `phpstan.config`                                                                  |
| `tests/phpstan/bootstrap.php`                  | "Add `php tests/phpstan/bootstrap.php` as phpstan bootstrap prereq?"              | `phpstan.bootstrap` array                                                         |
| `rector.php`                                   | "Plugin has rector.php — use it?"                                                 | `rector.config` + same bootstrap as phpstan if user said yes to phpstan bootstrap |
| `phpunit.xml.dist`                             | "Plugin has phpunit.xml.dist — use it?"                                           | `phpunit.config`                                                                  |
| `.php-cs-fixer.dist.php` or `.php-cs-fixer.php`| "Plugin uses php-cs-fixer — route ecs_* tools through it?"                        | `style.tool = "php-cs-fixer"`, `style.config`                                     |
| `eslint.config.*`                              | "Plugin has eslint config — use it?"                                              | `eslint.config` in JS config                                                      |
| `stylelint.config.*`                           | "Plugin has stylelint config — use it?"                                           | `stylelint.config` in JS config                                                   |
| `tests/jest/administration/package.json`       | "Plugin has plugin-local Jest admin tests. Wire them up?"                         | `jest.cwd = "tests/jest/administration"`, `jest.env.ADMIN_PATH`, `install_if_missing = true` |
| `tests/jest/storefront/package.json`           | "Plugin has plugin-local Jest storefront tests. Wire them up?"                    | `jest.cwd` + `STOREFRONT_PATH` analog (see Multi-context Jest below)              |

5. **Multi-context Jest**: The JS schema allows only one `jest` object per scope (single `jest.cwd`). When both `tests/jest/administration/package.json` and `tests/jest/storefront/package.json` are present and the user opts into both, emit **two scopes** sharing the same `cwd`:
   - `<scope-name>` — admin Jest (`jest.cwd = "tests/jest/administration"`, `ADMIN_PATH`)
   - `<scope-name>-storefront` — storefront Jest (`jest.cwd = "tests/jest/storefront"`, `STOREFRONT_PATH`)

`default_scope` selects admin. Storefront tests are invoked with `--scope=<scope-name>-storefront`.

6. **ADMIN_PATH / STOREFRONT_PATH**: Computed automatically by the skill. Value is the relative path from `<scope.cwd>/<jest.cwd>` back to the project root, followed by `src/<Context>/Resources/app/<context>`.

Worked example — SwagCommercial (`cwd = custom/plugins/SwagCommercial`, `jest.cwd = tests/jest/administration`, 6 segments from the combined path back to the project root): `ADMIN_PATH = "../../../../../../src/Administration/Resources/app/administration"`.

Worked example — shallow plugin (`cwd = custom/plugins/Foo`, `jest.cwd = tests/jest/administration`, 5 segments): `ADMIN_PATH = "../../../../../src/Administration/Resources/app/administration"`.

7. **Why phpstan.bootstrap exists**: Shopware plugins commonly ship a `tests/phpstan/bootstrap.php` that generates a plugin-specific Symfony container XML (the plugin's `phpstan.neon` references it via `containerXmlPath`). The plugin's composer `phpstan` script chains this bootstrap with `vendor/bin/phpstan analyze`. The MCP tool calls phpstan directly, so without `phpstan.bootstrap` the container XML is never built and phpstan fails with `XmlContainerNotExistsException`. The same pattern applies to `rector.bootstrap` if the plugin's `rector.php` depends on generated artefacts.

8. **Schema semantics** (undefined in schema docstrings, spelled out here so the skill can answer user questions):
   - `phpstan.bootstrap` / `rector.bootstrap`: array of shell commands. Run sequentially in `scope.cwd` once per tool invocation. Non-zero exit aborts the tool call.
   - `jest.install_if_missing`: when `true`, the server runs `npm ci` in `<scope.cwd>/<jest.cwd>` if `node_modules` is absent. Install failures abort the jest call.
   - `style.tool`: the MCP tool names `ecs_check` / `ecs_fix` dispatch to ECS by default and to php-cs-fixer when this field is `"php-cs-fixer"`. The tool name does not change with the dispatch target.

9. **Merging with existing root-level settings**: If root-level keys in `.mcp-php-tooling.json` / `.mcp-js-tooling.json` already point at paths inside the plugin being scoped (e.g. `phpstan.config: "custom/plugins/SwagCommercial/phpstan.neon"`), ask: "Migrate these root-level settings into the scope?"
   - Yes → move the matching keys into the new scope (rewriting paths to be scope-relative) and delete them from root.
   - No → leave both; tell the user the root entries act as fallback when no scope is active.

Never leave duplicates silently.

10. **Write scope**: Merge the collected answers into `.mcp-php-tooling.json` and/or `.mcp-js-tooling.json`. Only touch the file(s) that gained content — if the probes produced PHP-only answers, do not touch the JS config.

11. **Default pin**: Ask "Set `<scope-name>` as the default scope?" — if yes, write `default_scope` to the same file(s) that gained content.

12. **Re-run behavior**: On a second invocation where the chosen scope name already exists, offer three options: replace the existing scope, add a second scope under a different name, or change `default_scope`. Never overwrite a scope silently. If new probe types have been added to the plugin since the previous run (e.g. jest storefront appeared), offer to wire them as additions, not replacements.

### Boundaries

- No `.gitignore` edits, no git operations, no cross-config copying.
- Only touches `.mcp-php-tooling.json` and `.mcp-js-tooling.json`.
- Does not invoke any MCP tool — writes config and returns.

## Permission Groups

### PHP tooling
- **Recommended**: allow
- **Optional**: Yes (skip if `.mcp-php-tooling.json` was not created)
- **Description**: All PHP MCP tools — PHPStan, ECS, PHPUnit, coverage gap analysis, Symfony Console, and Rector. These are local analysis and test operations with no remote side effects.
- **Patterns**:
  - `mcp__plugin_dev-tooling_php-tooling__*`

### Administration JS tooling
- **Recommended**: allow
- **Optional**: Yes (skip if `.mcp-js-tooling.json` was not created)
- **Description**: ESLint, Stylelint, Prettier, Jest, TypeScript, `lint_all`, `lint_twig`, `unit_setup`, and Vite build for the Administration app.
- **Patterns**:
  - `mcp__plugin_dev-tooling_js-admin-tooling__*`

### Storefront JS tooling
- **Recommended**: allow
- **Optional**: Yes (skip if `.mcp-js-tooling.json` was not created)
- **Description**: ESLint, Stylelint, Jest, and Webpack build for the Storefront app.
- **Patterns**:
  - `mcp__plugin_dev-tooling_js-storefront-tooling__*`

## Validation

Validation runs in two stages. Stage 1 checks config-file existence and shape before restart. Stage 2 exercises live MCP tool dispatch and requires a Claude Code restart first, because MCP servers load config at startup. If Phase 4 created or modified scopes, Stage 2 must wait until after Post-Setup (restart).

### Stage 1 — Pre-restart

- `.mcp-php-tooling.json` exists at a valid discovery location, parses as JSON, and matches the schema.
- `.mcp-js-tooling.json` (if created) exists, parses, matches schema.
- Every scope has a `cwd` pointing at an existing directory relative to the project root.

### Stage 2 — Post-restart (live MCP dispatch)

Run each applicable check below. Skip any whose config file was not created. If Phase 4 created or modified scopes this session, defer all of Stage 2 until after restart.

#### PHP Tooling
- Use the `mcp__plugin_dev-tooling_php-tooling__phpstan_analyze` tool to analyze any PHP file in the project (e.g., `src/Kernel.php` or any file that exists)
- **Pass**: PHPStan output with analysis results (errors or "No errors")
- **Fail**: Connection error, "missing config file" error, or "container not found" error
- Common failure causes: wrong container name, container not running, PHP not installed

#### JS Admin Tooling (only if .mcp-js-tooling.json was created)
- Use the `mcp__plugin_dev-tooling_js-admin-tooling__eslint_check` tool on any JS or Vue file in `src/Administration/Resources/app/administration/`
- **Pass**: ESLint output with results
- **Fail**: Connection error or "command not found" error
- Common failure causes: node_modules not installed, wrong container

#### JS Storefront Tooling (only if .mcp-js-tooling.json was created)
- Use the `mcp__plugin_dev-tooling_js-storefront-tooling__eslint_check` tool on any JS file in `src/Storefront/Resources/app/storefront/`
- **Pass**: ESLint output with results
- **Fail**: Connection error or "command not found" error

## Post-Setup

- Restart Claude Code after creating configuration files. The MCP servers are loaded at startup and will not pick up new config files until restart.
- If you change a configuration file later, you also need to restart Claude Code.
- After restart, the dev-tooling MCP tools will appear in your tool list. You can verify by asking Claude to run PHPStan on a file.
