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

## 🌳 Worktree Configuration

A tool call may target a linked git worktree of the launch root by passing `project_root`, or by sticking one first with `set_project_root`. Targeting works in every environment: `native`, `docker`, `docker-compose`, `vagrant`, and `ddev`.

Under the four container environments the worktree has to sit inside the launch project root, because that root is the only tree the container or VM mounts and a worktree outside it has no path inside. The worktree is reached at its own position below the environment's working directory (`docker.workdir`, `vagrant.workdir`, `ddev.workdir`), and under `docker-compose` below a configured `docker-compose.workdir`, or below the destination of the longest matching bind mount when none is set. Once the mapping exists, `cwd` and the messages raised after it name both the host path and the environment-side path; the refusals that precede the mapping name the host path alone, since none exists yet.

Validation is the same in every environment: the root has to be one `git worktree add` created, its per-worktree git directory has to point back at that root, and its `.git` file has to carry a **relative** `gitdir` pointer. `git worktree add` writes an absolute one unless the repository sets `worktree.useRelativePaths`, and an absolute pointer names a host path that does not exist inside a container — so it is refused under `native` as well. Relink it with `git -c worktree.useRelativePaths=true worktree repair <worktree-path>`, which needs git 2.48 or newer, or create the worktree with `git worktree add --relative-paths`.

> [!TIP]
> Two one-time settings remove the recurring worktree friction. `git config worktree.useRelativePaths true` (git 2.48 or newer) makes every later worktree carry relative linkage from the start — including worktrees Claude Code's native `EnterWorktree` tool creates, which are otherwise absolute-linked and need the repair command before the first tool call. And the Claude Code setting `worktree.baseRef: head` makes `EnterWorktree` branch from your current HEAD; its default branches from the repository's default remote branch, so a native worktree would carry different code than the branch you are working on.

A root carrying a single quote or a control character is refused in every environment: a single quote would terminate the single-quoted string the `docker`, `docker-compose` and `vagrant` wrappers embed the command in, and a line break would split the probe's command. Under `docker`, `docker-compose`, `vagrant`, and `ddev` the root charset check refuses whitespace and the set `$`, backtick, backslash, `"`, `;`, `&`, `|`, `<`, `>`, `(`, `)`, `{`, `}`. For the first three the reason is that the wrapper embeds the working directory unquoted inside a single-quoted `bash -c` string, so a space ends the directory name; `ddev` quotes that directory but parses it a second time inside the container. Glob characters (`*`, `?`, bracket patterns) are admitted deliberately in every environment. `native` emits no `cd` and admits all of these.

After validation the tool probes that the environment reaches the mapped path, through the same wrapper the tool call itself uses. A missing directory — an unsynced Vagrant folder, say — refuses the call and names the path. The probe runs under the four container environments; under `native` the mapped path is the host path validation already checked. A passing result is cached for the server process, per environment and root; a failure is not cached.

**Configuration read timing** differs between the launch root and a worktree target:

- The launch root's configuration is discovered and bound once, when the server starts, and its environment scalars — the environment, the container name, and the environment-side working directory — are derived then. Individual values are still read out of that file on each use, but a mid-session edit to any of those three does not reach a worktree-targeted call until the server restarts: validation, the mapping and the existence probe all answer from the startup binding, so a running server keeps running against the environment it started with.
- A worktree's own configuration is discovered fresh on every call that targets it. A call targeting the launch root never picks up a worktree's file.

**Configuration selection for a worktree**: a worktree created under `.claude/worktrees/` holds tracked files only, and the tooling config files (`.mcp-php-tooling.json`, `.mcp-js-tooling.json`) are user-local and untracked — so a worktree ordinarily carries no configuration of its own. When it has none, the launch root's configuration applies unchanged: a worktree of the same checkout runs the same toolchain. When it has one, that configuration is discovered and applied for calls targeting that worktree, following the same discovery priority as the launch root — including the `environment` field it declares, so a worktree with its own configuration runs under that configuration's environment for that call, while a later call against the launch root still runs under the environment the server started with.

## 📌 Dependencies

You need `bash` 4.1+, `jq` 1.7+, and Node.js 20+ for the JS tools. The vendored protocol handler checks both floors at startup and refuses to run below either. Worktree targeting — the optional `project_root` parameter — additionally needs `git` 2.31+, the release that added `git rev-parse --path-format`; below it a worktree-targeted call is refused with a message naming that version, and every other tool is unaffected. The MCP servers don't bundle any of the actual linters or test runners. They shell out to whatever is already installed in the target project, so PHPStan, ECS, PHPUnit, Rector, ESLint, Stylelint, Prettier, Jest, and TypeScript all need to be available there (usually via `composer.json` or `package.json` in the Shopware checkout).

## 🩺 Troubleshooting

**MCP server not connecting.** Run `/mcp` to check the connection state. The most common cause is forgetting to restart Claude Code after installing the plugin. Also make sure `jq` is on `PATH`.

**Docker Compose service not found.** The default service name is `web`. Override it with `"docker-compose": {"service": "<name>"}` if your stack uses something else.

**Workdir not detected.** Auto-detection relies on a bind mount that maps your project root into the container. If your compose file stages the code differently, set `"docker-compose": {"workdir": "/your/path"}` explicitly.

**Custom compose file.** If `compose.yaml` lives somewhere other than the project root, point at it with `"docker-compose": {"file": "path/to/compose.yaml"}`.
