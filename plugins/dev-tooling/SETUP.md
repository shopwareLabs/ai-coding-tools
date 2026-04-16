# Dev Tooling Setup

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

When the PHP service runs inside a container whose base image does not ship phpactor — for example `ghcr.io/shopware/docker-dev` — the cleanest install is a one-shot sidecar that downloads the phar into a named volume, then a read-only mount of that volume into the PHP service. Zero image rebuild, zero `composer.json` pollution, survives `docker compose down` (the named volume persists across stack restarts; `down -v` is the only thing that drops it and forces a re-download).

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

Replace `web` with the actual service name if your stack uses something else. The binary path inside the container becomes `/opt/phpactor/phpactor` — use this value when the LSP setup flow asks for the binary path (question 10).

`PHPACTOR_UNCONDITIONAL_TRUST=1` silences phpactor's per-project trust prompt. Without it, any local `.phpactor.json` is ignored until you run `phpactor config:trust --trust` manually inside the container, and a fresh container re-prompts. The env var is the right default for containerized dev where you already trust the code you mount in.

Verify the install with `docker compose exec <service> /opt/phpactor/phpactor --version` before running the LSP dispatcher check.

## Configuration Files

### .mcp-php-tooling.json
- **Required**: Yes (the PHP tooling MCP server will not start without it)
- **Location**: Project root. Also discovered from `.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, and `.kiro/` — multiple files are deep-merged. See `docs/configuration.md` for the full discovery order.
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
- **Location**: Project root. Discovery rules match `.mcp-php-tooling.json` — see `docs/configuration.md` for the full list.
- **Schema reference**: `shared/mcp-js-tooling.schema.json` in the dev-tooling plugin

#### Setup Questions

1. **Environment**: What execution environment does your project use for JavaScript/Node.js?
   - `native` — Node.js is installed directly on your machine
   - `docker` — Node.js runs inside a standalone Docker container
   - `docker-compose` — Node.js runs as a service in a `docker-compose.yml` stack
   - `vagrant` — Node.js runs inside a Vagrant VM
   - `ddev` — You use DDEV for local development

   Note: This is typically the same environment as PHP. If your PHP runs in a container but you run npm/node natively, choose `native`.

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

**Location:** Project root or any supported tool directory (`.claude/`, `.cursor/`, etc.) — same discovery rules as `.mcp-php-tooling.json`.

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

### PHP Tooling
- Use the `mcp__php-tooling__phpstan_analyze` tool to analyze any PHP file in the project (e.g., `src/Kernel.php` or any file that exists)
- **Pass**: PHPStan output with analysis results (errors or "No errors")
- **Fail**: Connection error, "missing config file" error, or "container not found" error
- Common failure causes: wrong container name, container not running, PHP not installed

### JS Admin Tooling (only if .mcp-js-tooling.json was created)
- Use the `mcp__js-admin-tooling__eslint_check` tool on any JS or Vue file in `src/Administration/Resources/app/administration/`
- **Pass**: ESLint output with results
- **Fail**: Connection error or "command not found" error
- Common failure causes: node_modules not installed, wrong container

### JS Storefront Tooling (only if .mcp-js-tooling.json was created)
- Use the `mcp__js-storefront-tooling__eslint_check` tool on any JS file in `src/Storefront/Resources/app/storefront/`
- **Pass**: ESLint output with results
- **Fail**: Connection error or "command not found" error

### PHP LSP (only if .lsp-php-tooling.json was created)
- First confirm the `phpactor` binary is actually reachable where the LSP will run. For native environments, run `phpactor --version` on the host (or the absolute path you configured). For containerized environments, run the equivalent inside the container — for example `docker compose exec <service> /opt/phpactor/phpactor --version` when you used the phar-sidecar recipe. **Pass**: prints a version line. **Fail**: the binary is missing or not at the configured path. Fix the install before touching the LSP dispatcher — re-check the phar-sidecar volume mount or the container's `$PATH`, run `docker compose up -d` if the sidecar has not completed, and only then proceed to the dispatcher check below.
- Run the dispatcher in dry-run mode against the current project:
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
