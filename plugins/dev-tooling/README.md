# Dev Tooling

Development tools for PHP, JavaScript, and GitHub operations via MCP (Model Context Protocol), plus **Shopware LSP** for intelligent code completion. Provides PHPStan, ECS, PHPUnit, Symfony Console, ESLint, Stylelint, Prettier, Jest, TypeScript, build tools, and full GitHub CLI integration. Supports multiple development environments with auto-detection.

## Features

### GitHub Tools (gh-tooling MCP Server)
- **PR inspection** via `pr_view`, `pr_diff`, `pr_list`, `pr_checks`
- **PR review data** via `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`
- **Issue operations** via `issue_view`, `issue_list`
- **GitHub Actions CI** via `run_view`, `run_list`, `run_logs`
- **Job-level CI debugging** via `job_view`, `job_logs`, `job_annotations`
- **Commit inspection** via `commit_info`
- **Cross-repo search** via `search` (issues and PRs)
- **Raw API access** via `api` for any GitHub REST endpoint

### PHP Tools (php-tooling MCP Server)
- **PHPStan** static analysis via `phpstan_analyze`
- **ECS** code style checking via `ecs_check` and `ecs_fix`
- **PHPUnit** test execution via `phpunit_run`
- **Symfony Console** command execution via `console_run` and `console_list`

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

> **Note**: Prettier and TypeScript tools are NOT available for Storefront because the Shopware 6 Storefront `package.json` does not include these scripts.

### Shared Features
- **Multi-environment support**: native, docker, vagrant, ddev
- **Flexible configuration**: environment variable, project root, or LLM tool directories
- **Cross-tool support**: config discovery in `.claude/`, `.cursor/`, `.windsurf/`, `.zed/`, `.cline/`, `.aiassistant/`, `.amazonq/`, `.kiro/`
- **Config merging**: multiple config files are deep-merged (later locations override earlier)

### Shopware LSP (Language Server Protocol)

Intelligent code completion and navigation for Shopware 6 development:

- **Service ID completion**: PHP, XML, and YAML files with navigation and code lens
- **Twig template support**: completion, navigation, icon previews for `sw_icon` tags
- **Snippet handling**: validation, completion, and diagnostics for missing snippets
- **Route completion**: route name completion with parameter support
- **Feature flags**: detection and completion

**Supported file types**: PHP, XML, YAML, Twig (`.twig`, `.html.twig`)

> **Note**: LSP requires the `shopware-lsp` binary to be installed separately. See [Shopware LSP Installation](#shopware-lsp-installation) below.

## Quick Start

### Installation

```bash
/plugin install dev-tooling@shopware-plugins
```

**IMPORTANT**: Restart Claude Code after installation for the MCP servers to initialize.

### Verification

After restarting, verify the MCP servers are running:

```bash
/mcp
```

You should see `php-tooling`, `js-admin-tooling`, and `js-storefront-tooling` listed as connected servers.

## Configuration

### GitHub Configuration: `.mcp-gh-tooling.json`

The gh-tooling server is **configuration-optional** - it works without any config file as long as `gh` is authenticated. A config file adds a default repository so you don't need to pass `repo` to every tool call.

```json
{
  "repo": "shopware/shopware"
}
```

With full enforcement (blocks both subcommands and known `gh api` endpoints):

```json
{
  "repo": "shopware/shopware",
  "enforce_mcp_tools": true,
  "block_api_commands": true
}
```

With enforcement disabled:

```json
{
  "repo": "shopware/shopware",
  "enforce_mcp_tools": false
}
```

#### Configuration Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `repo` | string | — | Default repository in `owner/repo` format. Used when `repo` is not passed to a tool call. |
| `enforce_mcp_tools` | boolean | `true` | Blocks high-level `gh` subcommands (`gh pr view`, `gh issue view`, `gh run view`, `gh search`, etc.) and redirects to MCP tools. Set to `false` to disable all gh hook enforcement. |
| `block_api_commands` | boolean | `false` | When `true` (and `enforce_mcp_tools` is also `true`), additionally blocks `gh api` calls for endpoints that have a dedicated MCP tool: `pulls/N/comments`, `pulls/N/reviews`, `pulls/N/files`, `pulls/N/commits`, `actions/jobs/N/logs`, `actions/jobs/N`, `check-runs/N/annotations`, `commits/SHA`. Other `gh api` calls remain unblocked. |

**Prerequisites:**
- `gh` CLI installed: `brew install gh` (macOS) or see [GitHub CLI installation](https://cli.github.com/)
- Authenticated: `gh auth login`

### PHP Configuration: `.mcp-php-tooling.json`

```json
{
  "environment": "docker",
  "docker": {
    "container": "shopware_app",
    "workdir": "/var/www/html"
  },
  "phpstan": {
    "config": "phpstan.neon",
    "memory_limit": "2G"
  },
  "ecs": {
    "config": "ecs.php"
  },
  "phpunit": {
    "testsuite": "unit",
    "config": "phpunit.xml.dist"
  },
  "console": {
    "env": "dev",
    "verbosity": "normal",
    "no_debug": false,
    "no_interaction": true
  }
}
```

#### Tool Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `phpstan.config` | string | - | PHPStan configuration file path |
| `phpstan.memory_limit` | string | - | PHP memory limit (e.g., `2G`, `512M`) |
| `ecs.config` | string | - | ECS/PHP-CS-Fixer configuration file path |
| `phpunit.testsuite` | string | - | Default test suite to run |
| `phpunit.config` | string | - | PHPUnit configuration file path |
| `phpunit.coverage_driver` | string | - | Default coverage driver: `xdebug` (injects `XDEBUG_MODE=coverage`) or `pcov` |
| `console.env` | string | - | Default Symfony environment (`dev`, `prod`, `test`) |
| `console.verbosity` | string | - | Output verbosity (`quiet`, `normal`, `verbose`, `very-verbose`, `debug`) |
| `console.no_debug` | boolean | - | Disable debug mode by default |
| `console.no_interaction` | boolean | - | Non-interactive mode by default |

### JavaScript Configuration: `.mcp-js-tooling.json`

Shared configuration for both `js-admin-tooling` and `js-storefront-tooling` MCP servers.

```json
{
  "environment": "native"
}
```

Docker example:

```json
{
  "environment": "docker",
  "docker": {
    "container": "shopware_app",
    "workdir": "/var/www/html"
  }
}
```

### Configuration Priority

Configuration is loaded in the following priority order:

1. **Environment variable**: `MCP_PHP_TOOLING_CONFIG` / `MCP_JS_TOOLING_CONFIG`
2. **Config file discovery** (checked in order, deep-merged if multiple exist):
   - `.mcp-<prefix>.json` (project root, base config)
   - `.aiassistant/.mcp-<prefix>.json` (JetBrains AI Assistant)
   - `.amazonq/.mcp-<prefix>.json` (Amazon Q Developer)
   - `.cline/.mcp-<prefix>.json` (Cline)
   - `.cursor/.mcp-<prefix>.json` (Cursor AI)
   - `.kiro/.mcp-<prefix>.json` (Kiro)
   - `.windsurf/.mcp-<prefix>.json` (Windsurf/Codeium)
   - `.zed/.mcp-<prefix>.json` (Zed editor)
   - `.claude/.mcp-<prefix>.json` (override, highest priority)

### Environment Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `environment` | string | **required** | `native`, `docker`, `vagrant`, or `ddev` |
| `docker.container` | string | **required for docker** | Docker container name |
| `docker.workdir` | string | `/var/www/html` | Working directory in container |
| `vagrant.workdir` | string | `/vagrant` | Working directory in VM |
| `ddev.workdir` | string | `/var/www/html` | Working directory in DDEV |

## GitHub Tools Reference

Tools are available via the `gh-tooling` MCP server. Requires `gh` CLI installed and authenticated.

### `pr_view`

View pull request details.

```
Use gh-tooling pr_view with number 14642
Use gh-tooling pr_view with number 14642 and fields "title,body,state,reviews"
Use gh-tooling pr_view with number 14642 and comments true
```

**Parameters:**
- `number` (integer, optional): PR number. Omit for the PR of the current branch.
- `repo` (string, optional): Repository in `owner/repo` format.
- `fields` (string, optional): Comma-separated JSON fields (e.g. `title,body,state,reviews,files`)
- `comments` (boolean, optional): Include PR comments in text output.

### `pr_diff`

Get the unified diff for a pull request.

```
Use gh-tooling pr_diff with number 14642
Use gh-tooling pr_diff with number 14642 and file "src/Core/Migration/V6_6/Migration1720094362.php"
Use gh-tooling pr_diff with number 14642 and name_only true
```

**Parameters:**
- `number` (integer, required): PR number.
- `file` (string, optional): Limit diff to a specific file path.
- `name_only` (boolean, optional): List only changed file names.

### `pr_list`

List pull requests with filters.

```
Use gh-tooling pr_list with author "mitelg" and state "merged" and limit 5
Use gh-tooling pr_list with search "NEXT-3412" and state "all"
Use gh-tooling pr_list with head "feature/my-branch"
```

### `pr_checks`

View CI status checks for a pull request.

```
Use gh-tooling pr_checks with number 14642
```

### `pr_comments`

Get inline review comments (code-level) for a PR.

```
Use gh-tooling pr_comments with number 14642
Use gh-tooling pr_comments with number 14642 and jq_filter ".[] | {path, body, line, user: .user.login}"
```

### `pr_reviews`

Get review decisions for a pull request.

```
Use gh-tooling pr_reviews with number 14642
Use gh-tooling pr_reviews with number 14642 and jq_filter ".[] | select(.state == \"CHANGES_REQUESTED\") | {user: .user.login, body}"
```

### `pr_files`

Get changed files with patch content.

```
Use gh-tooling pr_files with number 13911
Use gh-tooling pr_files with number 13911 and jq_filter ".[] | select(.filename | contains(\"Migration\")) | {filename, patch}"
```

### `pr_commits`

Get the commit history for a pull request.

```
Use gh-tooling pr_commits with number 14642
```

### `issue_view`

View a GitHub issue.

```
Use gh-tooling issue_view with number 8498
Use gh-tooling issue_view with number 8498 and with_comments true
Use gh-tooling issue_view with number 8498 and fields "title,body,state,labels,comments"
```

### `issue_list`

List issues with filters.

```
Use gh-tooling issue_list with search "TODO label:component/core" and limit 20
```

### `run_view`

View the status of a GitHub Actions workflow run.

```
Use gh-tooling run_view with run_id 21534190745
Use gh-tooling run_view with run_id 21534190745 and fields "status,conclusion"
```

### `run_list`

List recent GitHub Actions runs.

```
Use gh-tooling run_list with branch "tests/content-system-unit-tests" and limit 5
```

### `run_logs`

Get CI workflow run logs (failed steps by default).

```
Use gh-tooling run_logs with run_id 22245862281
Use gh-tooling run_logs with run_id 22245862281 and failed_only false and max_lines 500
```

**Parameters:**
- `run_id` (integer, required): Workflow run ID.
- `failed_only` (boolean): Return only failed step logs. Default: `true`.
- `max_lines` (integer, optional): Truncate to this many lines.

### `job_view`

Get details for a specific CI job including step statuses.

```
Use gh-tooling job_view with job_id 62056364818
Use gh-tooling job_view with job_id 62056364818 and jq_filter ".steps[] | select(.conclusion == \"failure\") | {name, number}"
```

### `job_logs`

Get raw log output for a specific CI job.

```
Use gh-tooling job_logs with job_id 62056364818
Use gh-tooling job_logs with job_id 62056364818 and max_lines 200
```

### `job_annotations`

Get inline error annotations from a CI check run.

```
Use gh-tooling job_annotations with check_run_id 62056364818
```

### `commit_info`

Get files changed and commit message for a SHA.

```
Use gh-tooling commit_info with sha "15a7c2bb86"
Use gh-tooling commit_info with sha "15a7c2bb86" and fields "files"
Use gh-tooling commit_info with sha "15a7c2bb86" and include_pulls true
```

**Parameters:**
- `sha` (string, required): Git commit SHA (7-40 hex characters).
- `fields` (string): `files`, `message`, or `files_and_message` (default).
- `include_pulls` (boolean): Also fetch associated PRs.

### `search`

Search for issues or pull requests.

```
Use gh-tooling search with query "NEXT-3412" and type "prs"
Use gh-tooling search with query "custom field translation" and type "issues" and limit 20
Use gh-tooling search with query "attribute entity" and state "closed"
```

### `api`

Raw GitHub REST API call (escape hatch for unsupported operations).

```
Use gh-tooling api with endpoint "repos/shopware/shopware/issues/8498/timeline"
Use gh-tooling api with endpoint "repos/shopware/shopware/pulls/14642/comments" and paginate true
Use gh-tooling api with endpoint "search/issues" and jq_filter ".items[] | {number, title, state}"
```

## PHP Tools Reference

### `phpstan_analyze`

Run PHPStan static analysis.

```
Use phpstan_analyze with paths ["src/Core/"] and level 8
```

**Parameters:**
- `paths` (array, optional): File paths or directories to analyze
- `level` (integer 0-9, optional): Analysis strictness level
- `error_format` (string, optional): Output format (`json`, `table`, `raw`)

### `ecs_check` / `ecs_fix`

Check or fix PHP coding standard violations.

```
Use ecs_check to check src/Core/Content/Product/
Use ecs_fix to fix src/Core/Content/Product/ProductEntity.php
```

### `phpunit_run`

Run PHPUnit tests.

```
Use phpunit_run with testsuite "unit"
Use phpunit_run with paths ["tests/unit/Core/Checkout/"]
Use phpunit_run with filter "testAddProduct"
```

**Parameters:**
- `testsuite` (string): Test suite to run (`unit`, `integration`, etc.)
- `paths` (array): Specific test file(s) or directories
- `filter` (string): Filter tests by name pattern
- `coverage` (boolean): Generate code coverage report
- `coverage_driver` (string): Coverage driver — `xdebug` injects `XDEBUG_MODE=coverage` (required for Xdebug 3), `pcov` relies on the pcov extension loaded in php.ini. Omit to use PHPUnit's own detection.
- `stop_on_failure` (boolean): Stop on first failure

### `console_run` / `console_list`

Execute Symfony console commands.

```
Use console_run with command "cache:clear"
Use console_run with command "plugin:install" arguments ["SwagPayPal"] options {"activate": true}
Use console_list with namespace "cache"
```

## Administration Tools Reference

Tools are available via the `js-admin-tooling` MCP server. No context parameter needed.

### `eslint_check` / `eslint_fix`

Run ESLint linting or auto-fix.

```
Use js-admin-tooling eslint_check
Use js-admin-tooling eslint_fix with paths ["src/app/component/"]
```

**Parameters:**
- `paths` (array): File paths or directories to lint
- `output_format` (string): `stylish`, `json`, or `compact`

### `stylelint_check` / `stylelint_fix`

Run Stylelint SCSS linting or auto-fix.

```
Use js-admin-tooling stylelint_check
Use js-admin-tooling stylelint_fix with paths ["src/**/*.scss"]
```

### `prettier_check` / `prettier_fix`

Check or auto-format with Prettier. Uses `npm run format` / `npm run format:fix` which runs with project-configured paths.

```
Use js-admin-tooling prettier_check
Use js-admin-tooling prettier_fix
```

### `jest_run`

Run Jest unit tests (single run, watch mode not supported).

```
Use js-admin-tooling jest_run
Use js-admin-tooling jest_run with testPathPattern "component"
Use js-admin-tooling jest_run with coverage true
```

**Parameters:**
- `testPathPattern` (string): Regex pattern for test file paths
- `testNamePattern` (string): Regex pattern for test names
- `coverage` (boolean): Generate code coverage report
- `updateSnapshots` (boolean): Update Jest snapshots

### `tsc_check`

Run TypeScript type checking. Uses `npm run lint:types` which runs with project tsconfig.

```
Use js-admin-tooling tsc_check
```

### `lint_all`

Run ALL lint checks (TypeScript, ESLint, Stylelint, Prettier) in one command. Ideal for pre-commit validation.

```
Use js-admin-tooling lint_all
```

### `lint_twig`

ESLint check for Twig templates (.html.twig files). Validates Admin Vue component templates.

```
Use js-admin-tooling lint_twig
```

### `unit_setup`

Regenerate component import resolver map. Run this when Jest tests fail with import/module resolution errors.

```
Use js-admin-tooling unit_setup
```

### `vite_build`

Build Administration assets with Vite.

```
Use js-admin-tooling vite_build
Use js-admin-tooling vite_build with mode "development"
```

**Parameters:**
- `mode` (string): `development` or `production`

## Storefront Tools Reference

Tools are available via the `js-storefront-tooling` MCP server. No context parameter needed.

> **Note**: Prettier and TypeScript tools are not available for Storefront (no npm scripts in package.json).

### `eslint_check` / `eslint_fix`

Run ESLint linting or auto-fix.

```
Use js-storefront-tooling eslint_check
Use js-storefront-tooling eslint_fix with paths ["src/plugin/"]
```

### `stylelint_check` / `stylelint_fix`

Run Stylelint SCSS linting or auto-fix.

```
Use js-storefront-tooling stylelint_check
Use js-storefront-tooling stylelint_fix with paths ["src/**/*.scss"]
```

### `jest_run`

Run Jest unit tests (single run, watch mode not supported).

```
Use js-storefront-tooling jest_run
Use js-storefront-tooling jest_run with testPathPattern "plugin"
```

### `webpack_build`

Build Storefront assets with Webpack.

```
Use js-storefront-tooling webpack_build
Use js-storefront-tooling webpack_build with mode "development"
```

**Parameters:**
- `mode` (string): `development` or `production`

## Watch Mode / Long-Running Tasks

**Watch mode is not supported via MCP tools.**

MCP servers use a synchronous request-response model. Watch tasks (like `npm run hot` or `jest --watch`) run indefinitely, which would hang the MCP server and block all subsequent requests.

### Running Watch Tasks

Run watch tasks directly in a separate terminal:

```bash
# Storefront hot reload (Webpack)
cd src/Storefront/Resources/app/storefront && npm run hot

# Administration hot reload (Vite)
cd src/Administration/Resources/app/administration && npm run dev

# Jest watch mode
cd src/Administration/Resources/app/administration && npm run unit-watch
cd src/Storefront/Resources/app/storefront && npm run unit-watch
```

Use MCP tools for **one-time operations** (builds, linting, testing), not continuous watching.

## MCP Tool Enforcement

This plugin includes three PreToolUse hooks (one per MCP server) that block bash commands in favor of MCP tools. The hooks ensure Claude uses the proper MCP tools which handle environment detection, project configuration, and directory context automatically.

### Disabling Enforcement

To allow direct CLI invocations, set `enforce_mcp_tools` to `false` in your config:

```json
{
  "environment": "native",
  "enforce_mcp_tools": false
}
```

This applies per-config file (`.mcp-php-tooling.json` or `.mcp-js-tooling.json`).

### Blocked PHP Commands

| Bash Command | MCP Tool |
|--------------|----------|
| `vendor/bin/phpstan`, `composer phpstan` | `mcp__php-tooling__phpstan_analyze` |
| `vendor/bin/ecs`, `vendor/bin/php-cs-fixer`, `composer ecs` | `mcp__php-tooling__ecs_check` / `ecs_fix` |
| `vendor/bin/phpunit`, `composer phpunit` | `mcp__php-tooling__phpunit_run` |
| `bin/console`, `php bin/console` | `mcp__php-tooling__console_run` / `console_list` |

### Blocked JavaScript Commands

The JS hook detects context (Administration vs Storefront) from path patterns in the command and recommends the appropriate MCP server.

| Bash Command | Admin MCP Tool | Storefront MCP Tool |
|--------------|----------------|---------------------|
| `npm run lint`, `npx eslint` | `eslint_check` | `eslint_check` |
| `npm run lint:fix` | `eslint_fix` | `eslint_fix` |
| `npm run lint:scss`, `npx stylelint` | `stylelint_check` | `stylelint_check` |
| `npm run format`, `npx prettier` | `prettier_check` | N/A (Admin only) |
| `npm run unit`, `npx jest` | `jest_run` | `jest_run` |
| `npm run lint:types`, `npx tsc` | `tsc_check` | N/A (Admin only) |
| `npm run build` | `vite_build` | N/A |
| `npm run production/development` | N/A | `webpack_build` |

### Commands NOT Blocked

- `npm install`, `composer install` (setup commands)
- `npm run hot`, `npm run unit-watch` (watch mode - not supported by MCP)
- Custom npm scripts not matching known patterns

**Testing:** BATS tests for hooks are in `plugin-tests/code-quality/dev-tooling/`.

## Integration with Other Plugins

Other plugins can use these tools by referencing them in their tool lists:

```markdown
---
tools: mcp__php-tooling__phpstan_analyze, mcp__php-tooling__ecs_check, mcp__js-admin-tooling__eslint_check
---

After generating code, run PHPStan analysis, ECS check, and ESLint check.
```

## Troubleshooting

### MCP Server Not Starting

1. Ensure Claude Code was restarted after plugin installation
2. Check `/mcp` for connection status
3. Verify `jq` is installed: `which jq`

### Docker Environment Not Detected

1. Verify `docker-compose.yml` exists in project root
2. Check container name matches configuration
3. Ensure container is running: `docker ps`

### JS Tools Not Finding Files

1. Ensure npm dependencies are installed in the target directory
2. Verify the npm script names exist in your package.json

## Dependencies

- **bash** (4.0+)
- **jq** (JSON processor)

### PHP Tools
- PHPStan, PHP-CS-Fixer/ECS, PHPUnit (installed in project)

### JavaScript Tools
- Node.js (20+), npm
- ESLint, Stylelint, Prettier, Jest, TypeScript (installed in project)

## Shopware LSP Installation

The Shopware LSP binary must be installed manually and available in your PATH.

### Download

Download the appropriate binary for your platform from [GitHub Releases](https://github.com/shopwareLabs/shopware-lsp/releases):

| Platform | File |
|----------|------|
| macOS ARM64 (Apple Silicon) | `shopware-lsp_0.0.13_darwin_arm64.zip` |
| macOS Intel | `shopware-lsp_0.0.13_darwin_amd64.zip` |
| Linux x86-64 | `shopware-lsp_0.0.13_linux_amd64.zip` |
| Linux ARM64 | `shopware-lsp_0.0.13_linux_arm64.zip` |

### Installation Steps

```bash
# macOS ARM64 example - adjust filename for your platform
curl -LO https://github.com/shopwareLabs/shopware-lsp/releases/download/v0.0.13/shopware-lsp_0.0.13_darwin_arm64.zip

# Extract
unzip shopware-lsp_0.0.13_darwin_arm64.zip

# Move to PATH
mkdir -p ~/.local/bin
mv shopware-lsp ~/.local/bin/
chmod +x ~/.local/bin/shopware-lsp

# Add to PATH if needed (add to ~/.zshrc or ~/.bashrc)
export PATH="$HOME/.local/bin:$PATH"

# Verify installation
shopware-lsp --version
```

### Verification

After installing and enabling LSP, verify it's working:

1. Open a Shopware project with Claude Code
2. Edit a PHP file that uses services
3. Claude should have access to go-to-definition, find-references, and hover information

### Troubleshooting LSP

**"Executable not found in $PATH"**
- Ensure `shopware-lsp` is in your PATH: `which shopware-lsp`
- Restart Claude Code after adding to PATH

**LSP not loading**
- Check `/plugin` Errors tab for LSP errors
- Note: LSP support may have issues in Claude Code versions ~2.0.69+

## License

MIT
