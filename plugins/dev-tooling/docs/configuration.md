# Configuration

The three MCP servers share a simple rule: drop a JSON file in your project root, declare an `environment`, and they'll wrap every tool invocation for that environment. PHP and JavaScript have separate config files because they run against different parts of a Shopware project.

## Recommended Setup (`shopware/shopware`)

If you're working in the `shopware/shopware` monorepo, the `docker-compose` environment is the right default. It reads the service name and the working directory straight from your `compose.yaml` (and any `compose.override.yaml`), so the following one-liner is usually enough:

```json
{ "environment": "docker-compose" }
```

Out of the box it picks the `web` service and its `/var/www/html` bind mount. The containers don't need to be running when Claude Code starts. Resolution happens lazily on the first tool call, which means you can start the stack later without restarting Claude.

Override any of the sub-fields if your setup diverges from the default:

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

| Field                     | Type    | Description                                                                                               |
|---------------------------|---------|-----------------------------------------------------------------------------------------------------------|
| `phpstan.config`          | string  | PHPStan configuration file path                                                                          |
| `phpstan.memory_limit`    | string  | PHP memory limit, e.g. `2G` or `512M`                                                                    |
| `ecs.config`              | string  | ECS / PHP-CS-Fixer configuration file path                                                               |
| `phpunit.testsuite`       | string  | Default test suite                                                                                       |
| `phpunit.config`          | string  | PHPUnit configuration file path                                                                          |
| `phpunit.coverage_driver` | string  | `xdebug` (injects `XDEBUG_MODE=coverage`) or `pcov`                                                      |
| `console.env`             | string  | Symfony environment (`dev`, `prod`, `test`)                                                              |
| `console.verbosity`       | string  | `quiet`, `normal`, `verbose`, `very-verbose`, `debug`                                                    |
| `console.no_debug`        | boolean | Disable debug mode                                                                                       |
| `console.no_interaction`  | boolean | Non-interactive mode                                                                                     |
| `rector.config`           | string  | Rector configuration file path                                                                           |
| `log_file`                | string  | Additional log file. Relative paths resolve against the project root.                                    |

## JavaScript Configuration: `.mcp-js-tooling.json`

One file is shared between `js-admin-tooling` and `js-storefront-tooling`. Each server knows which Resources app to `cd` into, so you only declare the environment. For `shopware/shopware`:

```json
{ "environment": "docker-compose" }
```

For non-compose Docker setups you need to name the container explicitly, since there's no compose file to introspect:

```json
{
  "environment": "docker",
  "docker": { "container": "shopware_app", "workdir": "/var/www/html" }
}
```

## Configuration Priority

Config is resolved in two stages. The environment variable wins if it's set, otherwise the servers walk through a fixed list of config locations and deep-merge whatever they find, with later entries overriding earlier ones.

1. Environment variable: `MCP_PHP_TOOLING_CONFIG` / `MCP_JS_TOOLING_CONFIG`
2. File discovery (deep-merged, later wins): project-root `.mcp-<prefix>.json` → `.aiassistant/` → `.amazonq/` → `.cline/` → `.cursor/` → `.kiro/` → `.windsurf/` → `.zed/` → `.claude/`

A common pattern is to check a shared `.mcp-php-tooling.json` into git and keep a personal `.claude/.mcp-php-tooling.json` with your own overrides.

## Environment Options

| Field                    | Type   | Default                     | Description                                                      |
|--------------------------|--------|-----------------------------|------------------------------------------------------------------|
| `environment`            | string | **required**                | `docker-compose`, `native`, `docker`, `vagrant`, or `ddev`       |
| `docker-compose.file`    | string | Compose CLI discovery       | Path to compose file, relative to project root                   |
| `docker-compose.service` | string | `web`                       | Compose service name to exec into                                |
| `docker-compose.workdir` | string | auto-detect from bind mount | Working directory override inside the container                  |
| `docker.container`       | string | **required for docker**     | Docker container name                                            |
| `docker.workdir`         | string | `/var/www/html`             | Working directory in the container                               |
| `vagrant.workdir`        | string | `/vagrant`                  | Working directory inside the VM                                  |
| `ddev.workdir`           | string | `/var/www/html`             | Working directory inside DDEV                                    |
| `log_file`               | string | -                           | Additional log file; relative paths resolve against project root |

## 📌 Dependencies

You need `bash` 4.0+, `jq`, and Node.js 20+ for the JS tools. The MCP servers don't bundle any of the actual linters or test runners. They shell out to whatever is already installed in the target project, so PHPStan, ECS, PHPUnit, Rector, ESLint, Stylelint, Prettier, Jest, and TypeScript all need to be available there (usually via `composer.json` or `package.json` in the Shopware checkout).

## 🩺 Troubleshooting

**MCP server not connecting.** Run `/mcp` to check the connection state. The most common cause is forgetting to restart Claude Code after installing the plugin. Also make sure `jq` is on `PATH`.

**Docker Compose service not found.** The default service name is `web`. Override it with `"docker-compose": {"service": "<name>"}` if your stack uses something else.

**Workdir not detected.** Auto-detection relies on a bind mount that maps your project root into the container. If your compose file stages the code differently, set `"docker-compose": {"workdir": "/your/path"}` explicitly.

**Custom compose file.** If `compose.yaml` lives somewhere other than the project root, point at it with `"docker-compose": {"file": "path/to/compose.yaml"}`.
