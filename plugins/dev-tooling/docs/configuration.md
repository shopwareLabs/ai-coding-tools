# Configuration

## Recommended Setup (shopware/shopware)

For `shopware/shopware`, the `docker-compose` environment auto-detects the `web` service and its `/var/www/html` bind mount from your `compose.yaml` (and any `compose.override.yaml`). Docker does not need to be running when Claude Code starts — resolution happens at tool call time.

```json
{ "environment": "docker-compose" }
```

All sub-fields are optional overrides:

```json
{
  "environment": "docker-compose",
  "docker-compose": {
    "file": "docker/compose.yaml",
    "service": "app",
    "workdir": "/app"
  }
}
```

## PHP Configuration: `.mcp-php-tooling.json`

```json
{
  "environment": "docker-compose",
  "phpstan": { "memory_limit": "2G" },
  "phpunit": { "testsuite": "unit", "config": "phpunit.xml.dist" },
  "console": { "env": "dev", "no_interaction": true },
  "rector":  { "config": "rector.php" }
}
```

### Tool Options

| Field                     | Type    | Description                                                                  |
|---------------------------|---------|------------------------------------------------------------------------------|
| `phpstan.config`          | string  | PHPStan configuration file path                                              |
| `phpstan.memory_limit`    | string  | PHP memory limit (e.g., `2G`, `512M`)                                        |
| `ecs.config`              | string  | ECS/PHP-CS-Fixer configuration file path                                     |
| `phpunit.testsuite`       | string  | Default test suite                                                           |
| `phpunit.config`          | string  | PHPUnit configuration file path                                              |
| `phpunit.coverage_driver` | string  | `xdebug` (injects `XDEBUG_MODE=coverage`) or `pcov`                          |
| `console.env`             | string  | Symfony environment (`dev`, `prod`, `test`)                                  |
| `console.verbosity`       | string  | `quiet`, `normal`, `verbose`, `very-verbose`, `debug`                        |
| `console.no_debug`        | boolean | Disable debug mode                                                           |
| `console.no_interaction`  | boolean | Non-interactive mode                                                         |
| `rector.config`           | string  | Rector configuration file path                                               |
| `log_file`                | string  | Additional log file. Relative paths resolve against the project root.        |

## JavaScript Configuration: `.mcp-js-tooling.json`

Single file shared by `js-admin-tooling` and `js-storefront-tooling`. For `shopware/shopware`:

```json
{ "environment": "docker-compose" }
```

For non-compose Docker setups, `docker.container` is required:

```json
{
  "environment": "docker",
  "docker": { "container": "shopware_app", "workdir": "/var/www/html" }
}
```

## Configuration Priority

1. Env var: `MCP_PHP_TOOLING_CONFIG` / `MCP_JS_TOOLING_CONFIG`
2. File discovery (deep-merged, later wins): `.mcp-<prefix>.json` → `.aiassistant/` → `.amazonq/` → `.cline/` → `.cursor/` → `.kiro/` → `.windsurf/` → `.zed/` → `.claude/`

## Environment Options

| Field                    | Type   | Default                     | Description                                                      |
|--------------------------|--------|-----------------------------|------------------------------------------------------------------|
| `environment`            | string | **required**                | `docker-compose`, `native`, `docker`, `vagrant`, or `ddev`       |
| `docker-compose.file`    | string | Compose CLI discovery       | Path to compose file, relative to project root                   |
| `docker-compose.service` | string | `web`                       | Compose service name to exec into                                |
| `docker-compose.workdir` | string | auto-detect from bind mount | Working directory override inside container                      |
| `docker.container`       | string | **required for docker**     | Docker container name                                            |
| `docker.workdir`         | string | `/var/www/html`             | Working directory in container                                   |
| `vagrant.workdir`        | string | `/vagrant`                  | Working directory in VM                                          |
| `ddev.workdir`           | string | `/var/www/html`             | Working directory in DDEV                                        |
| `log_file`               | string | -                           | Additional log file; relative paths resolve against project root |

## 📌 Dependencies

`bash` 4.0+, `jq`, Node.js 20+ for JS tools. PHPStan/ECS/PHPUnit/Rector and ESLint/Stylelint/Prettier/Jest/TSC must be installed in the target project — the MCP servers shell out to the project's own binaries.

## 🩺 Troubleshooting

**MCP server not connecting** — check `/mcp` for status and confirm Claude Code was restarted after install. `jq` must be on PATH.

**Docker Compose service not found** — default is `web`. Override with `"docker-compose": {"service": "<name>"}`.

**Workdir not detected** — the service needs a bind mount mapping your project root. Otherwise set `"docker-compose": {"workdir": "/your/path"}` explicitly.

**Custom compose file** — set `"docker-compose": {"file": "path/to/compose.yaml"}`.
