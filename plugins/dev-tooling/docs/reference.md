# Tools Reference

Parameters and examples for every tool of the three MCP servers: `php-tooling`, `js-admin-tooling`, and `js-storefront-tooling`. Every tool except `cwd` takes an optional `project_root` (see [🌳 Worktree Support](#-worktree-support)), and each server adds `worktree_prepare`, `set_project_root`, and `cwd` — all three documented in that section.

## 🐘 PHP Tools (`php-tooling`)

### `phpstan_analyze`

PHPStan static analysis. Returns type errors as JSON.

```
Use phpstan_analyze with paths ["src/Core/"] and level 8
```

| Parameter      | Type          | Description                                                                                              |
|----------------|---------------|----------------------------------------------------------------------------------------------------------|
| `paths`        | array         | File paths or directories                                                                                |
| `level`        | integer (0-9) | Analysis strictness                                                                                      |
| `config`       | string        | PHPStan config file path                                                                                 |
| `memory_limit` | string        | PHP memory limit (e.g. `2G`, `512M`)                                                                     |
| `error_format` | string        | `json`, `table`, or `raw`                                                                                |
| `scope`        | string        | Scope name from `.mcp-php-tooling.json`; `shopware` forces project-root behavior                         |
| `project_root` | string        | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

### `ecs_check` / `ecs_fix`

ECS (PHP-CS-Fixer) code style. `ecs_fix` detects and fixes in one step and is preferred; `ecs_check` is a read-only preview.

```
Use ecs_fix to fix src/Core/Content/Product/
```

| Parameter       | Type   | Tool             | Description                                                                                              |
|-----------------|--------|------------------|----------------------------------------------------------------------------------------------------------|
| `paths`         | array  | both             | File paths or directories                                                                                |
| `config`        | string | both             | ECS config file path                                                                                     |
| `output_format` | string | `ecs_check` only | Output format                                                                                            |
| `scope`         | string | both             | Scope name from `.mcp-php-tooling.json`; `shopware` forces project-root behavior                         |
| `project_root`  | string | both             | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

### `phpunit_run`

PHPUnit test runner.

```
Use phpunit_run with testsuite "unit"
Use phpunit_run with paths ["tests/unit/Core/Checkout/"] filter "testAddProduct"
```

| Parameter         | Type    | Description                                                                                               |
|-------------------|---------|-----------------------------------------------------------------------------------------------------------|
| `testsuite`       | string  | Test suite (`unit`, `integration`, …)                                                                     |
| `paths`           | array   | Specific test files or directories                                                                        |
| `filter`          | string  | Filter tests by name pattern                                                                              |
| `config`          | string  | PHPUnit config file path                                                                                  |
| `coverage`        | boolean | Generate coverage report                                                                                  |
| `coverage_format` | string  | `text` (default, aggregate only), `clover`/`cobertura` (per-line XML), `html` (visual report)             |
| `coverage_path`   | string  | Output path. Defaults: `clover`/`cobertura` → `coverage.xml`, `html` → `coverage/`. Ignored for `text`.   |
| `coverage_driver` | string  | `xdebug` injects `XDEBUG_MODE=coverage` (Xdebug 3). `pcov` relies on the extension. Omit for auto-detect. |
| `output_format`   | string  | `default` or `testdox`                                                                                    |
| `stop_on_failure` | boolean | Stop on first failure                                                                                     |
| `scope`           | string  | Scope name from `.mcp-php-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root`    | string  | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support).  |

### `phpunit_coverage_gaps`

Parse a Clover XML coverage report and surface uncovered methods and line ranges grouped by file (worst coverage first). Two-step workflow: run `phpunit_run` with `coverage: true, coverage_format: "clover"` first.

> [!NOTE]
> This tool reads a file and runs no PHP, but it still asserts the PHP dependencies like every other tool on this server: against a `project_root` with no `vendor/autoload.php` it refuses rather than reading the report. That follows from the two-step workflow — the `phpunit_run` that produces the report needs those dependencies anyway — so the assertion costs nothing on the documented path. Reading a report generated somewhere else, in a tree with nothing installed, is not supported.

```
Use phpunit_run with coverage true coverage_format "clover"
Use phpunit_coverage_gaps with source_filter "src/Core/"
```

| Parameter       | Type   | Description                                                                                                                         |
|-----------------|--------|-------------------------------------------------------------------------------------------------------------------------------------|
| `clover_path`   | string | Clover XML path. Default: `coverage.xml`                                                                                            |
| `source_filter` | string | Substring filter on file path. Use to drop framework base classes that leak into coverage (`AbstractFieldSerializer`, `CloneTrait`) |
| `scope`         | string | Scope name from `.mcp-php-tooling.json`; `shopware` forces project-root behavior                                                    |
| `project_root`  | string | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support).                            |

### `console_run` / `console_list`

Symfony Console. `console_run` executes a command; `console_list` returns available commands (LLM-optimized output, optional namespace filter).

```
Use console_run with command "cache:clear"
Use console_run with command "plugin:install" arguments ["SwagPayPal"] options {"activate": true}
Use console_run with command "debug:container" env "staging" output_file "var/dump/staging-container.txt"
Use console_run with command "cache:clear" feature_all "major"
Use console_list with namespace "cache"
```

`console_run` parameters:

| Parameter        | Type    | Description                                                                                                                    |
|------------------|---------|--------------------------------------------------------------------------------------------------------------------------------|
| `command`        | string  | Console command (required)                                                                                                     |
| `arguments`      | array   | Positional arguments                                                                                                           |
| `options`        | object  | Options as key/value                                                                                                           |
| `env`            | string  | Symfony env passed as `--env`. Any name the installation defines (`dev`, `prod`, `test`, `staging`, …); `^[A-Za-z0-9_]{1,32}$` |
| `output_file`    | string  | Write stdout to this file instead of returning it (see below)                                                                  |
| `feature_all`    | string  | `major` or `true`. Sets `FEATURE_ALL` in the target environment; see below.                                                    |
| `verbosity`      | string  | `quiet`, `normal`, `verbose`, `very-verbose`, `debug`                                                                          |
| `no_debug`       | boolean | Disable debug mode                                                                                                             |
| `no_interaction` | boolean | Non-interactive                                                                                                                |
| `scope`          | string  | Scope name from `.mcp-php-tooling.json`; `shopware` forces project-root behavior                                               |
| `project_root`   | string  | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support).                       |

With `output_file` set, stdout goes to the file and the response carries only the resolved path, the byte count and the exit status — stderr still comes back in the response. A relative path resolves against the project root, parent directories are created, and the file is replaced only after the command exits zero. A failed command leaves the target as it was and returns its stdout in the response instead. The value is refused when it is longer than 4096 bytes or its final path component is `.git`. An existing symlink or non-regular target is also refused. Omit it (or pass an empty string) to get the output in the response as before.

`feature_all` sets `FEATURE_ALL=<value>` in the command's process environment inside the target environment. `feature_all "major"` with `command "cache:clear"` is the deprecation gate `FEATURE_ALL=major bin/console cache:clear`.

`console_list` parameters: `namespace` (string), `format` (string), `scope` (string — scope name from `.mcp-php-tooling.json`; `shopware` forces project-root behavior), `project_root` (string — see [🌳 Worktree Support](#-worktree-support)).

### `rector_fix` / `rector_check`

Rector refactoring. `rector_fix` detects and applies transformations (preferred); `rector_check` is a dry-run preview.

`rector_fix` reads `composer.json` at the effective root, or under the scope's `cwd` when one is set. It runs `composer rector-fix` when that file defines a `rector-fix` script; otherwise it runs `composer rector`. If only a `rector` script with `--dry-run` is available, the call is refused because the run would apply nothing.

```
Use rector_fix with paths ["src/Core/Content/"]
Use rector_fix with only "CountArrayToEmptyArrayComparisonRector"
Use rector_fix with only_suffix "Controller"
```

| Parameter       | Type    | Description                                                                                              |
|-----------------|---------|----------------------------------------------------------------------------------------------------------|
| `paths`         | array   | File paths or directories                                                                                |
| `config`        | string  | Rector config file path                                                                                  |
| `only`          | string  | Filter to a single rule (FQCN or short name)                                                             |
| `only_suffix`   | string  | Filter files by name suffix (e.g. `Controller` → `*Controller.php`)                                      |
| `output_format` | string  | `json` (default) or `console`                                                                            |
| `clear_cache`   | boolean | Clear Rector cache before processing                                                                     |
| `scope`         | string  | Scope name from `.mcp-php-tooling.json`; `shopware` forces project-root behavior                         |
| `project_root`  | string  | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

### `set_project_root`

Sets or clears the sticky project root for this server process, and binds a server that started without one.

- A server started in its own plugin directory — what this plugin's Codex manifest produces, since it launches each server with `cwd` `.` — has no project root, and the first call carrying a `project_root` binds it instead of sticking it. The root has to be a directory outside the plugin directory that holds this server's `.mcp-php-tooling.json`, at its top or in one of the supported tool directories, unless `MCP_PHP_TOOLING_CONFIG` names the configuration file (a relative value is read against the root being bound); on success the server loads that configuration, derives the environment, and records that root with symlinks resolved, which every later call enters before it runs. After the bind, a tool call may target the launch root itself, in any spelling that resolves to the same directory, or a linked git worktree of it; any other directory is refused. The bind is refused when the configuration cannot be loaded or declares an `environment` other than `native`, `docker`, `docker-compose`, `vagrant` or `ddev`. A call with no `project_root` while unbound is refused: there is no project root to return to.
- A server that has a project root — started in one, or bound as above — validates a `project_root` as a linked git worktree of that root and sticks it; every later call on this server targets it until `set_project_root` is called again with no argument. Without one, clears the sticky root unconditionally (no validation of the value discarded) and returns the server to its project root; naming the launch root itself, in any spelling that resolves to the same directory, does the same.

```
Use php-tooling set_project_root with project_root "/path/to/project"
Use php-tooling set_project_root with project_root "/path/to/worktree"
Use php-tooling set_project_root
```

| Parameter      | Type   | Description                                                                                |
|----------------|--------|--------------------------------------------------------------------------------------------|
| `project_root` | string | Absolute path to bind, or a linked worktree of the launch root. Once bound, omit to clear. |

### `cwd`

Reports this server's resolution state: the effective project root, its source (`launch` or `sticky` — `cwd` takes no `project_root`, so it never reports the `call` source the other tools' banners can show), whether it currently resolves, the resolved working directory, the environment, and the configuration file(s) in use. A server with no project root yet reports the root as `none (unbound)`, names the plugin directory it started in and the `set_project_root` call that binds it, and reports the configuration as pending until a bind loads one. No parameters, validates nothing, never fails — including when a sticky root names a directory that no longer exists.

"Resolves" reports resolution and mapping, not reachability: the existence probe runs on tool calls, not here, so a root `cwd` reports as resolving can still be refused by the next tool call's probe.

```
Use php-tooling cwd
```

## 🖥️ Administration Tools (`js-admin-tooling`)

Runs inside `src/Administration/Resources/app/administration`. No context parameter. ESLint, Stylelint, Prettier, and `tsc_check` reject shell-hostile scoped config paths and quote accepted paths before passing them to the command wrapper.

### `eslint_check` / `eslint_fix`

ESLint linting / auto-fix for Administration. With `paths`, the package's own ESLint binary runs through `npm exec --no -- eslint`; the supplied paths are its only targets. Without `paths`, the aggregate `lint` / `lint:fix` script runs with its own targets.

The aggregate cannot replace a path-scoped run because npm appends arguments after the script body's targets, widening the run. A path-scoped run refuses when the package's `node_modules/.bin/eslint` is missing because `npm exec --no` would otherwise run a global binary.

```
Use js-admin-tooling eslint_fix with paths ["src/app/component/"]
```

| Parameter       | Type   | Tool           | Description                                                                                              |
|-----------------|--------|----------------|----------------------------------------------------------------------------------------------------------|
| `paths`         | array  | both           | File paths or directories; see below.                                                                    |
| `output_format` | string | `eslint_check` | `stylish` (default) or `json`                                                                            |
| `scope`         | string | both           | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root`  | string | both           | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

When `paths` is supplied, these are the ONLY targets the run covers. Without a scope, a path containing `app/administration/` loses everything through that prefix. Under a scope, only a leading `<scope cwd>/` is stripped; the plugin's own `app/administration/` segment stays. Omit `paths` to run the targets the aggregate `lint` / `lint:fix` script configures for itself.

Every path is validated before ESLint runs: it must exist and resolve to at least one file carrying an extension the Administration ESLint config reads (`js`, `ts`, `tsx`, `vue`, `json`, `twig`). A path that fails either check is refused with a message naming it, rather than linting nothing and reporting success.

### `stylelint_check` / `stylelint_fix`

Stylelint SCSS linting / auto-fix. Two routes, selected by whether `paths` is supplied:

- With `paths`, the package's own Stylelint binary runs through `npm exec --no -- stylelint --cache`, the flags of the `lint:scss` script without its target. The given paths are the only targets.
- Without `paths`, the aggregate `lint:scss` / `lint:scss-fix` script runs, bare when there is nothing else to append. Its own `**/*.scss` target stays authoritative.

The aggregate is never a fallback for a path-scoped run. Appending a path to a body that already names `**/*.scss` would widen the run to every SCSS file plus the path. That matters most for `stylelint_fix`, which writes: a widened fix would modify files nobody named.

The run is refused when:

- A path-scoped run finds no `node_modules/.bin/stylelint` in the package directory. `npm exec --no` installs nothing but would run a globally installed `stylelint`, so the tool checks for the package's own binary first.
- A scoped config contains shell-hostile characters. The tool checks and quotes the config path before appending `--config`.
- A run without `paths` has a scoped config, and the aggregate script's own `stylelint` command already passes `--config`, `--config=`, `-c` or `-c=`. Stylelint takes its config option only once. The tool reads only that script's own body, not the body of a script it calls through `npm run`.

```
Use js-admin-tooling stylelint_fix with paths ["src/**/*.scss"]
```

| Parameter       | Type   | Tool              | Description                                                                                              |
|-----------------|--------|-------------------|----------------------------------------------------------------------------------------------------------|
| `paths`         | array  | both              | File paths or glob patterns, relative to the Administration package directory; see below.                |
| `output_format` | string | `stylelint_check` | `string` (default), `json`, or `compact`                                                                 |
| `scope`         | string | both              | Scope name from `.mcp-js-tooling.json`                                                                   |
| `project_root`  | string | both              | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

When `paths` is supplied, these are the ONLY targets the run covers. Omit `paths` to run the targets the aggregate SCSS script configures for itself.

> [!NOTE]
> A literal path is validated before Stylelint runs. A file must carry the `.scss` extension `lint:scss` lints, and a directory must hold at least one `.scss` file. Otherwise the path is refused with a message naming it, rather than linting nothing and reporting success.
>
> A directory, including one whose name ends in `.scss`, reaches Stylelint as the quoted pattern `<dir>/**/*.scss`. Stylelint expands it, so only `.scss` files are linted or fixed. Stylelint given a bare directory would read every file in it.
>
> A glob pattern (containing `*`, `?`, or `[`) skips the validation, because the existence probe cannot resolve a glob. It reaches Stylelint unchecked for expansion there.

> [!NOTE]
> Under `ddev`, directory and glob paths are refused. `ddev exec` re-parses the command in the container's shell, which would expand the pattern itself before Stylelint sees it. Pass file paths there. A directory or glob path holding a space, a tab or `#` is accepted because `ddev exec` quotes that argument again, so it reaches Stylelint intact.

### `prettier_check` / `prettier_fix`

Prettier format check / auto-format for Administration. Two routes, selected by whether `paths` is supplied:

- With `paths`, the package's own Prettier binary runs through `npm exec --no -- prettier` with `--check` (`prettier_check`) or `--write --cache` (`prettier_fix`), the flags of the `format` / `format:fix` scripts without their globs. The given paths are the only targets.
- Without `paths`, the aggregate `format` / `format:fix` script runs bare, plus a `--config` override when a scope selects one. Its own glob targets stay authoritative.

The aggregate is never a fallback for a path-scoped run, for the reason given for [Stylelint](#stylelint_check--stylelint_fix). That matters most for `prettier_fix`, which writes. A path-scoped run is refused when `node_modules/.bin/prettier` is missing from the package directory.

```
Use js-admin-tooling prettier_check with paths ["src/app/component/"]
```

| Parameter      | Type   | Description                                                                                              |
|----------------|--------|----------------------------------------------------------------------------------------------------------|
| `paths`        | array  | File paths or glob patterns, relative to the Administration package directory; see below.                |
| `scope`        | string | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root` | string | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

When `paths` is supplied, these are the ONLY targets the run covers. Omit `paths` to check/format the targets the aggregate `format` / `format:fix` script configures for itself.

> [!NOTE]
> A literal path is validated before Prettier runs. A file must carry one of the extensions the `format` globs name (`.js`, `.ts`, `.mjs`), and a directory must hold at least one such file. Otherwise the path is refused with a message naming it.
>
> A directory, including one whose name ends in one of those extensions, reaches Prettier as the quoted pattern `<dir>/**/*.{js,ts,mjs}`. Prettier expands it, so only those files are checked or rewritten. Prettier given a bare directory would format every file type it supports.
>
> A glob pattern (containing `*`, `?`, or `[`) skips the validation and reaches Prettier unchecked for expansion there.
>
> Under `ddev`, directory and glob paths are refused, as for [Stylelint](#stylelint_check--stylelint_fix).

### `jest_run`

Jest unit tests. Single run only. Watch mode isn't supported (see [mcp-enforcement.md](./mcp-enforcement.md)).

Every run uses the package's npm script `unit`. The core Administration `unit` script passes `--ci`. The tool checks scope and test-pattern arguments before attempting dependency installation, so those argument refusals install nothing.

**The result comes from Jest's own JSON report, not the process exit code.** Every run appends `--json --outputFile=<path>`; the tool clears that path before starting, reads it afterwards, and decides from the counts it carries:

| Report says                         | Tool reports                                                      |
|-------------------------------------|-------------------------------------------------------------------|
| any failed test or suite            | failure                                                           |
| zero tests ran                      | failure, naming the patterns that matched nothing                 |
| all passed, process exited 0        | success                                                           |
| all passed, process exited non-zero | success, stating the exit code prominently and keeping the output |
| report missing or unparseable       | falls back to the exit code, and says the status came from there  |

The last two rows are the point. A coverage-threshold breach or a post-run writer erroring makes Jest exit non-zero after every test passed, and that was previously reported as a failed run. The report also carries the counts under `unit`'s CI mode, where Jest's own summary line is suppressed.

> [!NOTE]
> The report path is cleared before each run rather than after. A report present afterwards therefore always belongs to the run that just finished — otherwise a run that crashed before writing one would be judged by the previous run's results, and a failing suite could be reported as a pass. One report file per server process may sit in the environment's `/tmp` between runs.

```
Use js-admin-tooling jest_run with testPathPatterns "component"
Use js-admin-tooling jest_run with coverage true
```

| Parameter          | Type    | Description                                                                                              |
|--------------------|---------|----------------------------------------------------------------------------------------------------------|
| `testPathPatterns` | string  | Regex on test file paths                                                                                 |
| `testNamePattern`  | string  | Regex on test names                                                                                      |
| `coverage`         | boolean | Append `--coverage`; core Administration already collects coverage on every run.                         |
| `updateSnapshots`  | boolean | Append `--updateSnapshot` to update snapshots                                                            |
| `ci`               | boolean | Append `--ci`. The core `unit` script already passes it, but a plugin scope's `unit` script may not.     |
| `scope`            | string  | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root`     | string  | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

The Administration `unit` script always passes `--ci`. Its Jest configuration derives `isCi` from that argument, collects coverage, and selects `jest-silent-reporter` plus `jest-junit`. Passing `coverage` adds `--coverage` but does not change core Administration coverage collection. `jest-silent-reporter` suppresses Jest's `Tests:` line, so the tool reads the counts from its JSON report.

### `tsc_check`

`npm run lint:types` against the project tsconfig. An explicit scope can supply a TypeScript project config; the tool rejects shell-hostile config paths and quotes accepted ones. Without `scope`, the tool uses `default_scope`, or the core Administration package when no default is set.

| Parameter      | Type   | Description                                                                                              |
|----------------|--------|----------------------------------------------------------------------------------------------------------|
| `scope`        | string | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root` | string | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

### `lint_all`

Runs TypeScript, ESLint, Stylelint, and Prettier in one shot. Intended for pre-commit validation. Without `scope`, `lint_all` ignores `default_scope` and runs the core script.

| Parameter      | Type   | Description                                                                                              |
|----------------|--------|----------------------------------------------------------------------------------------------------------|
| `scope`        | string | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root` | string | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

### `lint_twig`

ESLint against `.html.twig` files. Validates Admin Vue component templates. Without `scope`, `lint_twig` ignores `default_scope` and runs the core script.

| Parameter      | Type   | Description                                                                                              |
|----------------|--------|----------------------------------------------------------------------------------------------------------|
| `scope`        | string | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root` | string | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

### `unit_setup`

Regenerates the component import resolver map. Run it when Jest fails with import/module resolution errors. Without `scope`, `unit_setup` ignores `default_scope` and runs the core script.

| Parameter      | Type   | Description                                                                                              |
|----------------|--------|----------------------------------------------------------------------------------------------------------|
| `scope`        | string | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root` | string | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

### `vite_build`

Vite build for Administration (Vue 3). Without `scope`, `vite_build` ignores `default_scope` and runs the core build.

| Parameter      | Type   | Description                                                                                              |
|----------------|--------|----------------------------------------------------------------------------------------------------------|
| `mode`         | string | `development` or `production`                                                                            |
| `scope`        | string | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root` | string | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

### `set_project_root`

Sets or clears the sticky project root for this server process, and binds a server that started without one. Same behavior as the PHP server's `set_project_root` above — a separate process, a separate sticky value. A bind requires a directory holding this server's own `.mcp-js-tooling.json`, at its top or in one of the supported tool directories, unless `MCP_JS_TOOLING_CONFIG` names the configuration file; after the bind, a call may target that root itself or stick a linked git worktree of it.

| Parameter      | Type   | Description                                                                                |
|----------------|--------|--------------------------------------------------------------------------------------------|
| `project_root` | string | Absolute path to bind, or a linked worktree of the launch root. Once bound, omit to clear. |

### `cwd`

Reports this server's resolution state. No parameters. Same shape as the PHP server's `cwd` above.

## 🛒 Storefront Tools (`js-storefront-tooling`)

Runs inside `src/Storefront/Resources/app/storefront`. No context parameter. ESLint and Stylelint reject shell-hostile scoped config paths and quote accepted paths before passing them to the command wrapper.

> [!NOTE]
> Prettier and TypeScript aren't exposed for Storefront. The Shopware 6 Storefront `package.json` has no corresponding npm scripts.

### `eslint_check` / `eslint_fix`

ESLint linting / auto-fix for Storefront. The Storefront's `lint:js` script runs ESLint twice: once in the `app/storefront` package, and once from `src/Storefront/Resources` with `--config ./app/storefront/eslint.config.js` for the component tree under `views/components`. Each supplied path is routed to the tree that owns it, and both trees run when both are targeted. A path containing `views/components` goes to the components tree; everything else goes to the app tree.

With paths, each tree runs the package's own ESLint binary through `npm exec --no`, with the flags of its `lint:js` call (`--no-error-on-unmatched-pattern --report-unused-disable-directives`, plus the components config). The given paths are the only targets. The components call starts with `npm exec --no -c` in the package directory and changes to `../..` before ESLint runs. App-tree paths under a scope run with the scope's ESLint config.

A path-scoped run is refused when:

- `node_modules/.bin/eslint` is missing from the package directory.
- A scope other than `shopware` is active and a path routes to the components tree. That tree and `./app/storefront/eslint.config.js` belong to the core Storefront package, not to the scope's package. The refusal comes before anything runs.

```
Use js-storefront-tooling eslint_fix with paths ["src/plugin/"]
Use js-storefront-tooling eslint_check with paths ["views/components/cms/"]
```

| Parameter       | Type   | Tool           | Description                                                                                              |
|-----------------|--------|----------------|----------------------------------------------------------------------------------------------------------|
| `paths`         | array  | both           | File paths or directories, in any of the three forms below                                               |
| `output_format` | string | `eslint_check` | `stylish` (default) or `json`                                                                            |
| `scope`         | string | both           | Scope name from `.mcp-js-tooling.json`                                                                   |
| `project_root`  | string | both           | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

Three path forms are accepted, per path:

- repo-root-relative — `src/Storefront/Resources/views/components/…` or `src/Storefront/Resources/app/storefront/…`
- tree-relative — `views/components/…` for the components tree, `src/…` or `build/…` for the app tree
- a path already carrying the package prefix

Under a scope, app-tree paths lose only a leading `<scope cwd>/` prefix; the plugin's own `app/storefront/` segment stays.

Every path is validated before ESLint runs. A path that does not exist, or that resolves to no file carrying an extension the Storefront ESLint config reads (`js`, `ts`, `mjs`, `cjs`, `jsx`, `tsx`, `vue`, `json`), is refused with a message naming it — so `paths: ["src/scss"]` fails loudly instead of linting nothing and reporting success. A path containing a single quote, a newline, or a carriage return is refused as well; those characters cannot be quoted safely through the container command wrappers.

Omitting `paths` runs the aggregate `lint:js` / `lint:js:fix` script bare across both trees.

> [!WARNING]
> `output_format` is ignored on a no-paths `eslint_check`. The no-paths branch runs `npm run lint:js` bare, because that script chains two ESLint calls and ends in a subshell, so an appended reporter flag would land after the subshell instead of reaching either call. Pass `paths` when you need `json` output.

> [!NOTE]
> A no-paths run under an active scope that selects its own ESLint config is refused rather than run, because the bare script would silently apply the package's own config instead. Pass `paths`, or call with `scope: "shopware"`.

### `stylelint_check` / `stylelint_fix`

Stylelint SCSS linting / auto-fix. Same routing as the [Administration versions](#stylelint_check--stylelint_fix), selected by whether `paths` is supplied:

- With `paths`, the package's own Stylelint binary runs through `npm exec --no -- stylelint --config stylelint.config.js --cache`, the flags of the `lint:scss` script without its target. The given paths are the only targets.
- Without `paths`, the aggregate `lint:scss` / `lint:scss-fix` script runs, and its own `./src/scss` target stays authoritative.

The aggregate is never a fallback for a path-scoped run.

On the path route under a scope, `--config stylelint.config.js` is left out, because that file belongs to the core Storefront package. A scope's own Stylelint config is then the only `--config`. Without one, Stylelint finds the scope package's own config. Without `paths`, a scope's Stylelint config is appended to the aggregate script.

The run is refused when:

- A path-scoped run finds no `node_modules/.bin/stylelint` in the package directory.
- A scoped config path contains shell-hostile characters.
- A run without `paths` has a scoped config, and the aggregate script's own `stylelint` command already passes `--config`, `--config=`, `-c` or `-c=`, as the core `lint:scss` does. The tool reads only that script's own body, so `lint:scss-fix`, which calls `lint:scss` through `npm run`, is not refused by this check.

Parameters: `paths` (file paths or glob patterns, relative to the `app/storefront` package directory), `output_format` on the check tool (`string` default, `json`, `compact`), `scope`, and `project_root` (see [🌳 Worktree Support](#-worktree-support)).

```
Use js-storefront-tooling stylelint_fix with paths ["src/**/*.scss"]
```

> [!NOTE]
> A literal path is validated before Stylelint runs. A file must carry the `.scss` or `.css` extension, and a directory must hold at least one such file. Otherwise the path is refused with a message naming it.
>
> A directory, including one whose name ends in `.scss` or `.css`, reaches Stylelint as the quoted pattern `<dir>/**/*.{scss,css}`, so only those files are linted or fixed.
>
> A glob pattern (containing `*`, `?`, or `[`) skips the validation and reaches Stylelint unchecked for expansion there.
>
> Under `ddev`, directory and glob paths are refused unless they hold a space, a tab or `#`, as for [Administration Stylelint](#stylelint_check--stylelint_fix).

### `jest_run`

Jest unit tests for the Storefront **`app/storefront` package suite only**. Jest's `rootDir` is that package and its `testMatch` collects `**/test/**/*.test.js`, so the component tests under `src/Storefront/Resources/views/components/` are never collected — run those with [`vitest_run`](#vitest_run). A `testPathPatterns` value naming `views/components` is rejected. Under scope `shopware` the message points at `vitest_run`; under a plugin scope it states that `vitest_run` refuses every plugin scope.

Every run uses the package's npm script `unit`. The core Storefront `unit` script passes `--ci`. The `ci` argument appends `--ci` for a plugin scope's `unit` script that does not pass it. The tool checks scope and test-pattern arguments before attempting dependency installation, so those argument refusals install nothing.

The result comes from Jest's JSON report rather than the process exit code, exactly as described for [the Admin version](#jest_run) — including the cleared-before-each-run report path. This matters more here than on Administration: the Storefront config collects coverage unconditionally and enforces global thresholds, so a path-scoped run of a few files exits non-zero on the threshold while every test passes. Those runs previously reported as errors.

Same parameters as the Admin version: `testPathPatterns`, `testNamePattern`, `coverage`, `updateSnapshots`, `ci`, `scope`, and `project_root` (see [🌳 Worktree Support](#-worktree-support)). Storefront's Jest configuration always collects coverage, so the `coverage` flag adds `--coverage` without changing coverage collection. CI mode writes no missing snapshots; explicit `updateSnapshots` adds `--updateSnapshot` and permits snapshot updates.

### `vitest_run`

Vitest test runner for the Storefront component suite under `src/Storefront/Resources/views/components/`. This is the only runner that collects those tests. Runs `npm run unit:components`, or `unit:components:coverage` when `coverage` is true. Single run only — watch mode isn't exposed (see [mcp-enforcement.md](./mcp-enforcement.md)).

```
Use js-storefront-tooling vitest_run with paths ["views/components/cms/"]
Use js-storefront-tooling vitest_run with testNamePattern "renders the slider"
```

| Parameter         | Type    | Description                                                                                              |
|-------------------|---------|----------------------------------------------------------------------------------------------------------|
| `paths`           | array   | Test file or directory filters. Omit to run the whole component suite                                    |
| `testNamePattern` | string  | Regex on test names (`-t`)                                                                               |
| `coverage`        | boolean | Run `unit:components:coverage` instead                                                                   |
| `updateSnapshots` | boolean | Update Vitest snapshots (`-u`)                                                                           |
| `scope`           | string  | Only `shopware` is accepted; omitting it also selects core behavior. Plugin scopes are refused.          |
| `project_root`    | string  | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

`vitest_run` ignores `default_scope` when `scope` is omitted.

`paths` accepts the same three forms as the Storefront ESLint tools (repo-root-relative, tree-relative `views/components/…`, or a path already carrying the package prefix) and each one is checked for existence before Vitest runs. A path containing a single quote or a line break is refused.

### `ludtwig_check` / `ludtwig_fix`

ludtwig linting / auto-fix for Storefront Twig templates. Runs `composer ludtwig:storefront` / `composer ludtwig:storefront:fix` from the project root against `src/Storefront/Resources/views`.

```
Use js-storefront-tooling ludtwig_check
```

Neither tool takes `paths` and neither takes `scope`: the composer script body is `cd ./src/Storefront/Resources/views; ludtwig .`, whose `;` makes appended arguments impossible, and the scope is pinned to the project root rather than resolved from the call — a `default_scope` in the configuration would otherwise move the run into a plugin directory, and the composer script enters the core Storefront views tree relative to wherever composer is invoked.

| Parameter      | Type   | Description                                                                                              |
|----------------|--------|----------------------------------------------------------------------------------------------------------|
| `project_root` | string | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

> [!IMPORTANT]
> Both tools require a `ludtwig` binary where the command runs — on the host for a native setup, inside the container otherwise. No tool in this plugin installs it. When it is missing the composer script fails and the tool surfaces that failure.

### `webpack_build`

Webpack build for Storefront (vanilla JS). Without `scope`, `webpack_build` ignores `default_scope` and runs the core build. `mode` accepts `development` and `production`; omitting it selects `production`.

| Parameter      | Type   | Description                                                                                              |
|----------------|--------|----------------------------------------------------------------------------------------------------------|
| `mode`         | string | `development` or `production`                                                                            |
| `scope`        | string | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                          |
| `project_root` | string | Absolute path to a linked git worktree of the launch root. See [🌳 Worktree Support](#-worktree-support). |

### `set_project_root`

Sets or clears the sticky project root for this server process, and binds a server that started without one. Same behavior as the PHP server's `set_project_root` above — a separate process, a separate sticky value. A bind requires a directory holding this server's own `.mcp-js-tooling.json`, at its top or in one of the supported tool directories, unless `MCP_JS_TOOLING_CONFIG` names the configuration file; after the bind, a call may target that root itself or stick a linked git worktree of it.

| Parameter      | Type   | Description                                                                                |
|----------------|--------|--------------------------------------------------------------------------------------------|
| `project_root` | string | Absolute path to bind, or a linked worktree of the launch root. Once bound, omit to clear. |

### `cwd`

Reports this server's resolution state. No parameters. Same shape as the PHP server's `cwd` above.

## 🌳 Worktree Support

Every tool except `cwd`, on all three servers, accepts `project_root`. Pass it to run one call against a linked git worktree of the server's project root, instead of that root itself. Targeting works in every environment: `native`, `docker`, `docker-compose`, `vagrant`, and `ddev`.

**Binding a server that has no project root.** How the host starts a server decides whether it has one: Claude Code starts it in the session's project directory, while this plugin's Codex manifest starts it in the plugin's own directory (`cwd` `.` resolves against the plugin root), where it comes up unbound and refuses every tool except `set_project_root` and `cwd`. On such a server the first `set_project_root` call carrying a path binds it — the configuration, the environment and the working directory are derived from that root, and it stays the server's root for the rest of the process, so a later call may target that root itself or stick a linked git worktree of it. On Codex the recommended route is this on-demand bind: with the plugin hooks trusted, the SessionStart directive names the session directory and the call that binds it, so the model can do it without being asked (an untrusted SessionStart hook does not run, leaving only the refusal text, which names the call but not the path). Exporting `PROJECT_ROOT` with the project path before starting Codex binds at startup instead, but Codex's long-lived app-server process keeps the value, so later sessions it serves, including other projects and the IDE extension, start bound to that path until the process restarts. Throughout this section, "launch root" means the root the server is bound to, by either route.

What the environment adds:

- **In-root under containers.** `docker`, `docker-compose`, `vagrant`, and `ddev` refuse a worktree outside the launch project root, which is the only tree the container or VM mounts. An in-root worktree is reached at its own position below the environment's working directory; under `docker-compose` a configured `docker-compose.workdir` decides, or else the longest matching bind mount.
- **Relative linkage, under containers.** Under `docker`, `docker-compose`, `vagrant`, and `ddev` the worktree's `.git` file has to carry a relative `gitdir` pointer. `git worktree add` writes an absolute one unless the repository sets `worktree.useRelativePaths`, and an absolute pointer names a host path that does not exist inside a container, so the call is refused. `native` accepts an absolute pointer, because the command runs on the host where the pointer resolves. Relink the worktree with `git -c worktree.useRelativePaths=true worktree repair <worktree-path>` (git 2.48 or newer), or create it with `git worktree add --relative-paths`. Setting `git config worktree.useRelativePaths true` once makes every later worktree carry relative linkage from the start, including ones Claude Code's native `EnterWorktree` tool creates.
- **Dependency provisioning.** A fresh worktree holds tracked files only, so `vendor/` and `node_modules` are missing and the composer- and npm-backed tools refuse until they exist. Each server's `worktree_prepare` installs its own toolchain's dependencies in the target root through the configured environment: `composer install --no-interaction` on `php-tooling`, `npm ci` in the package directory on `js-admin-tooling` and `js-storefront-tooling`. It takes `project_root` like every other tool and skips the dependency check the other tools run. The JS variants also take `scope` — their install and dependency gate both derive the same package directory through `get_js_workdir`; the PHP variant deliberately does not, because the gate checks `vendor/autoload.php` at the effective root and a scoped install would land where the gate never looks. A successful install returns a short completion summary — the per-package installer output is suppressed — while a failed one returns the full output. Re-run it after the worktree's `composer.json`/`composer.lock` or `package-lock.json` changes — the dependency check only tests that the install directory exists. Admin Jest additionally needs `unit_setup` after the install plus the gitignored `test/_mocks_/entity-schema.json`, which `unit_setup` does not regenerate — dump it with `console_run` on `php-tooling` (env `prod`): `framework:schema -s entity-schema src/Administration/Resources/app/administration/test/_mocks_/entity-schema.json` (the flag is `-s`/`--schema-format`; `--schema` does not exist). `ludtwig` needs `worktree_prepare` on `php-tooling`, not on its own server, because it runs composer. Never symlink `vendor/` from the launch tree instead: composer's autoloaders resolve through the symlink and load the launch tree's classes.
- **Charset.** A root carrying a single quote or a control character is refused in every environment. Under `docker`, `docker-compose`, `vagrant`, and `ddev`, whitespace and the metacharacter set `$`, backtick, backslash, `"`, `;`, `&`, `|`, `<`, `>`, `(`, `)`, `{`, `}` are refused too — the first three embed the working directory unquoted, and `ddev` parses it a second time inside the container. Glob characters stay admitted.
- **Existence probe.** After validation the tool checks that the environment reaches the mapped path, through the same wrapper the call uses. A missing directory refuses the call and names the path; a passing result is cached for that server process per environment, root and mapped path, so an edited workdir in a worktree's own configuration probes again.
- **Per-worktree configuration.** A worktree carrying its own `.mcp-*-tooling.json` is read on every call that targets it, and the `environment` that configuration declares applies to that call.

Without `project_root`, a call targets the sticky root set by `set_project_root` on that server, or the launch root when no sticky root is set. Each server is a separate process holding its own sticky value, so pointing all three at a worktree takes three `set_project_root` calls, and returning to the launch root after an `ExitWorktree` takes three more with no argument. A `PostToolUse` hook fires on `EnterWorktree`/`ExitWorktree` to remind the session of this.

Every tool result that resolves a project root (i.e. every tool but `set_project_root` and `cwd`, which report their own state instead) begins with a banner line naming the effective root and its source, e.g. `Project root: /path/to/worktree (call)`.

See [docs/configuration.md](./configuration.md#-worktree-configuration) for the configuration discovery order, the read timing, and the path mapping.

> [!WARNING]
> `hooks/scripts/check-phpstan-baseline.sh` resolves the analyzed paths and the baseline file from the session's own tree, not from `project_root`. A worktree-targeted `phpstan_analyze` has its baseline overlap computed against the main checkout.
