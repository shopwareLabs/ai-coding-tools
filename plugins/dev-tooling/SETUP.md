# Dev Tooling Setup

## Table of Contents

- [Prerequisites](#prerequisites)
- [Configuration Files](#configuration-files)
  - [.mcp-php-tooling.json](#mcp-php-toolingjson)
  - [.mcp-js-tooling.json](#mcp-js-toolingjson)
  - [.lsp-php-tooling.json](#lsp-php-toolingjson)
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

### python3
- **Check**: `python3 --version`
- **Install**: Usually pre-installed on macOS (Monterey+) and Linux. If missing:
  - macOS: `brew install python@3.12`
  - Debian/Ubuntu: `apt install python3`
- **Required by**: Only for PHP LSP support when using a containerized `environment` (docker, docker-compose, vagrant, ddev). Not required for native LSP or when LSP is disabled. Must be version 3.12 or newer.

### phpactor (optional)
- **Check**: `phpactor --version`
- **Install (native/host)**: Download the phar release from https://github.com/phpactor/phpactor/releases/latest into `~/.local/bin/phpactor` (or anywhere on `$PATH`), then `chmod +x` it. Alternative: `composer global require phpactor/phpactor`. See https://phpactor.readthedocs.io/en/master/usage/standalone.html for details. Homebrew has no phpactor formula — do not attempt `brew install`.
- **Install (containerized)**: See the phar-sidecar recipe below. Do NOT use `composer require --dev phpactor/phpactor` in the project's `composer.json` for third-party repos like `shopware/shopware` — it pollutes the committed dependency list and pulls phpactor's transitive dependencies into the project's vendor tree.
- **Required by**: Optional PHP LSP integration (document symbols, hover, go-to-definition, references). The MCP servers work without it. For containerized environments the binary must be available inside the container; the host check can be skipped.

#### Containerized install — phar sidecar (recommended for docker-compose)

Use when the PHP service's base image does not ship phpactor (e.g. `ghcr.io/shopware/docker-dev`). A one-shot sidecar downloads the phar into a named volume; the PHP service mounts the volume read-only. No image rebuild, no `composer.json` pollution. The named volume persists across `docker compose down`; only `down -v` drops it and forces a re-download.

Create `compose.override.yaml` next to the project's `compose.yaml`:

```yaml
services:
    phpactor-installer:
        image: alpine/curl
        restart: "no"
        command:
            - sh
            - -c
            - |
                set -e
                if [ ! -x /out/phpactor ]; then
                    curl -fsSL -o /out/phpactor \
                        https://github.com/phpactor/phpactor/releases/latest/download/phpactor.phar
                    chmod +x /out/phpactor
                fi
        volumes:
            - phpactor-bin:/out

    web:
        depends_on:
            phpactor-installer:
                condition: service_completed_successfully
        environment:
            PHPACTOR_UNCONDITIONAL_TRUST: "1"
        volumes:
            - phpactor-bin:/opt/phpactor:ro

volumes:
    phpactor-bin:
```

Notes:
- Replace `web` with the actual service name if your stack differs.
- Binary path inside the container: `/opt/phpactor/phpactor`. Use this for the LSP binary-path question (question 10).
- `PHPACTOR_UNCONDITIONAL_TRUST=1` silences phpactor's per-project trust prompt. Without it, local `.phpactor.json` is ignored until you run `phpactor config:trust --trust` inside the container, and a fresh container re-prompts. The env var is the right default for containerized dev.
- Verify with `docker compose exec <service> /opt/phpactor/phpactor --version` before running the LSP dispatcher check.

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

### .lsp-php-tooling.json

**Required:** No — only create this file if you want PHP LSP support (phpactor).

**Location:** Project root or any supported tool directory (`.claude/`, `.cursor/`, etc.) — same discovery rules as `.mcp-php-tooling.json`. Plugin subdirectories are not scanned.

**Prerequisite binary:** `phpactor` must be installed where the LSP will run:
- Native: on your host — install the phar release (see the phpactor prerequisite section above)
- Containerized: inside the container — use the phar-sidecar recipe from the phpactor prerequisite section. For projects where adding phpactor to the committed dev dependencies is acceptable, `composer require --dev phpactor/phpactor` also works.

#### Setup Questions

1. **Do you want PHP LSP support enabled?**
   - Yes → continue with this section
   - No → skip this section entirely

2. **Where should the LSP run?**
   - `native` → runs on your host; file URIs pass through unchanged, no Python required
   - `docker` / `docker-compose` / `ddev` / `vagrant` → runs inside the container; requires `python3` ≥ 3.12 on the host and `phpactor` inside the container

3. **Docker container name** (only if environment = docker): Container name from `docker ps`, e.g. `shopware_app`.

4. **Docker working directory** (only if environment = docker, optional): Default `/var/www/html`.

5. **Compose service name** (only if environment = docker-compose): Which service in your `docker-compose.yml` runs phpactor? Default: `web`

6. **Compose working directory** (only if environment = docker-compose, optional): Working directory inside the compose service. Leave blank to use the service's default `WORKDIR`.

7. **Compose file** (only if environment = docker-compose, optional): Path to a specific compose file. Leave blank to auto-discover from the project root.

8. **Vagrant working directory** (only if environment = vagrant, optional): Default `/vagrant`.

9. **DDEV working directory** (only if environment = ddev, optional): Default `/var/www/html`.

10. **Binary path (optional)**
    - Leave blank to look up `phpactor` in `$PATH` (works for native installs and for containerized setups where phpactor is on the container's `$PATH`).
    - Containerized + phar-sidecar install: `/opt/phpactor/phpactor`. This matches the mount target from the recipe in the phpactor prerequisite section.
    - Or provide any other absolute path.

#### Minimal Config

Native:

```json
{
  "environment": "native",
  "enabled": true
}
```

Containerized (docker-compose, matches a typical Shopware setup):

```json
{
  "environment": "docker-compose",
  "docker-compose": {
    "service": "web",
    "workdir": "/var/www/html"
  },
  "enabled": true
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
- `.lsp-php-tooling.json` (if created) exists, parses, matches schema.
- Every scope has a `cwd` pointing at an existing directory relative to the project root.
- Dry-run the LSP dispatcher as described under "PHP LSP" below (does not require MCP server restart).

### Stage 2 — Post-restart (live MCP dispatch)

Run each applicable check below. Skip any whose config file was not created. If Phase 4 created or modified scopes this session, defer all of Stage 2 until after restart.

#### PHP Tooling
- Use the `mcp__php-tooling__phpstan_analyze` tool to analyze any PHP file in the project (e.g., `src/Kernel.php` or any file that exists)
- **Pass**: PHPStan output with analysis results (errors or "No errors")
- **Fail**: Connection error, "missing config file" error, or "container not found" error
- Common failure causes: wrong container name, container not running, PHP not installed

#### JS Admin Tooling (only if .mcp-js-tooling.json was created)
- Use the `mcp__js-admin-tooling__eslint_check` tool on any JS or Vue file in `src/Administration/Resources/app/administration/`
- **Pass**: ESLint output with results
- **Fail**: Connection error or "command not found" error
- Common failure causes: node_modules not installed, wrong container

#### JS Storefront Tooling (only if .mcp-js-tooling.json was created)
- Use the `mcp__js-storefront-tooling__eslint_check` tool on any JS file in `src/Storefront/Resources/app/storefront/`
- **Pass**: ESLint output with results
- **Fail**: Connection error or "command not found" error

#### PHP LSP (only if .lsp-php-tooling.json was created)

Step 1 — binary reachability:
- Native: run `phpactor --version` on the host (or the absolute path configured in `.lsp-php-tooling.json`).
- Containerized: run the equivalent inside the container, e.g. `docker compose exec <service> /opt/phpactor/phpactor --version` for the phar-sidecar recipe.
- **Pass**: prints a version line.
- **Fail**: binary missing or not at the configured path. Fix the install before the dispatcher check: re-check the sidecar volume mount or the container's `$PATH`; run `docker compose up -d` if the sidecar has not completed.

Step 2 — dispatcher dry-run against the current project:

```bash
LSP_DISPATCH_DRY_RUN=1 PROJECT_ROOT="$(pwd)" \
  bash "${CLAUDE_SKILL_DIR}/../../lsp-server-php/lsp.sh"
```

- **Pass**: output contains `target=direct-exec` (native) or `target=python-proxy` (containerized). The dispatcher resolved config, enabled flag, environment, and the phpactor preflight.
- **Fail**: output contains `target=null-stub reason=...`. Read the reason:
  - `no .lsp-php-tooling.json found` — config missing or unreadable
  - `enabled=false` — flip `enabled` to `true`
  - `preflight failed: phpactor not found in <env> context` — install phpactor inside the container (or on the host for native)
  - `unsupported environment` — environment value is not one of `native|docker|docker-compose|vagrant|ddev`
  - `failed to resolve docker-compose workdir` — the compose service can't be resolved; check `service`, `file`, and that the stack is up
- Note: this check validates dispatch only. Live LSP behavior (document symbols, hover, etc.) can only be exercised by opening a `.php` file in Claude Code after restart. The `Method not found from plugin:dev-tooling:phpactor` error at runtime means the null stub was selected — rerun the dry-run check to diagnose.

## Post-Setup

- Restart Claude Code after creating configuration files. The MCP servers are loaded at startup and will not pick up new config files until restart.
- If you change a configuration file later, you also need to restart Claude Code.
- After restart, the dev-tooling MCP tools will appear in your tool list. You can verify by asking Claude to run PHPStan on a file.

### Containerized LSP lifecycle

If you enabled an LSP with a containerized `environment` (docker, docker-compose, vagrant, ddev), **the container must be running before you open Claude Code**. Language servers start lazily — Claude Code spawns the LSP process the first time a matching file is opened in the session. If the container is down at that moment, the dispatcher's preflight check fails, falls back to the null stub, and the session continues without LSP support until you quit and restart Claude Code.

Practical recipe:

1. `docker compose up -d` (or `ddev start`, etc.)
2. `claude` (start Claude Code)
3. Open a file to trigger LSP lazy spawn

If you ever see `Method not found from plugin:dev-tooling:phpactor` when you expected real LSP behavior, the most likely cause is the container wasn't up at startup. Restart Claude Code after starting the container.

### Project-root `.phpactor.json` side effect

phpactor may write a `.phpactor.json` file into the project root on first LSP use to persist its own session state. For a project you own, commit it or add it to the repo's `.gitignore` as you see fit. For third-party repos such as `shopware/shopware` where you do not want to touch the committed `.gitignore` or any shared git configuration, add the file to your local clone's exclude list:

```bash
echo ".phpactor.json" >> .git/info/exclude
```

`.git/info/exclude` is per-clone, never committed, and uses the same syntax as `.gitignore`. `git status` will stop reporting the file without affecting any other developer's workflow.
