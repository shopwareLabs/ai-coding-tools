# Tools Reference

30 tools across three MCP servers: 9 in `php-tooling`, 12 in `js-admin-tooling`, and 9 in `js-storefront-tooling`.

## 🐘 PHP Tools (`php-tooling`)

### `phpstan_analyze`

PHPStan static analysis. Returns type errors as JSON.

```
Use phpstan_analyze with paths ["src/Core/"] and level 8
```

| Parameter      | Type          | Description                            |
|----------------|---------------|----------------------------------------|
| `paths`        | array         | File paths or directories              |
| `level`        | integer (0-9) | Analysis strictness                    |
| `config`       | string        | PHPStan config file path               |
| `memory_limit` | string        | PHP memory limit (e.g. `2G`, `512M`)   |
| `error_format` | string        | `json`, `table`, or `raw`              |

### `ecs_check` / `ecs_fix`

ECS (PHP-CS-Fixer) code style. `ecs_fix` detects and fixes in one step and is preferred; `ecs_check` is a read-only preview.

```
Use ecs_fix to fix src/Core/Content/Product/
```

| Parameter       | Type   | Tool                    | Description                    |
|-----------------|--------|-------------------------|--------------------------------|
| `paths`         | array  | both                    | File paths or directories      |
| `config`        | string | both                    | ECS config file path           |
| `output_format` | string | `ecs_check` only        | Output format                  |

### `phpunit_run`

PHPUnit test runner.

```
Use phpunit_run with testsuite "unit"
Use phpunit_run with paths ["tests/unit/Core/Checkout/"] filter "testAddProduct"
```

| Parameter          | Type    | Description                                                                                                |
|--------------------|---------|------------------------------------------------------------------------------------------------------------|
| `testsuite`        | string  | Test suite (`unit`, `integration`, …)                                                                      |
| `paths`            | array   | Specific test files or directories                                                                         |
| `filter`           | string  | Filter tests by name pattern                                                                               |
| `config`           | string  | PHPUnit config file path                                                                                   |
| `coverage`         | boolean | Generate coverage report                                                                                   |
| `coverage_format`  | string  | `text` (default, aggregate only), `clover`/`cobertura` (per-line XML), `html` (visual report)              |
| `coverage_path`    | string  | Output path. Defaults: `clover`/`cobertura` → `coverage.xml`, `html` → `coverage/`. Ignored for `text`.    |
| `coverage_driver`  | string  | `xdebug` injects `XDEBUG_MODE=coverage` (Xdebug 3). `pcov` relies on the extension. Omit for auto-detect.  |
| `output_format`    | string  | `default` or `testdox`                                                                                     |
| `stop_on_failure`  | boolean | Stop on first failure                                                                                      |

### `phpunit_coverage_gaps`

Parse a Clover XML coverage report and surface uncovered methods and line ranges grouped by file (worst coverage first). Two-step workflow: run `phpunit_run` with `coverage: true, coverage_format: "clover"` first.

```
Use phpunit_run with coverage true coverage_format "clover"
Use phpunit_coverage_gaps with source_filter "src/Core/"
```

| Parameter       | Type   | Description                                                                                                       |
|-----------------|--------|-------------------------------------------------------------------------------------------------------------------|
| `clover_path`   | string | Clover XML path. Default: `coverage.xml`                                                                          |
| `source_filter` | string | Substring filter on file path. Use to drop framework base classes that leak into coverage (`AbstractFieldSerializer`, `CloneTrait`) |

### `console_run` / `console_list`

Symfony Console. `console_run` executes a command; `console_list` returns available commands (LLM-optimized output, optional namespace filter).

```
Use console_run with command "cache:clear"
Use console_run with command "plugin:install" arguments ["SwagPayPal"] options {"activate": true}
Use console_list with namespace "cache"
```

`console_run` parameters:

| Parameter        | Type          | Description                                    |
|------------------|---------------|------------------------------------------------|
| `command`        | string        | Console command (required)                     |
| `arguments`      | array         | Positional arguments                           |
| `options`        | object        | Options as key/value                           |
| `env`            | string        | Symfony env (`dev`, `prod`, `test`)            |
| `verbosity`      | string        | `quiet`, `normal`, `verbose`, `very-verbose`, `debug` |
| `no_debug`       | boolean       | Disable debug mode                             |
| `no_interaction` | boolean       | Non-interactive                                |

`console_list` parameters: `namespace` (string), `format` (string).

### `rector_fix` / `rector_check`

Rector refactoring. `rector_fix` detects and applies transformations (preferred); `rector_check` is a dry-run preview.

```
Use rector_fix with paths ["src/Core/Content/"]
Use rector_fix with only "CountArrayToEmptyArrayComparisonRector"
Use rector_fix with only_suffix "Controller"
```

| Parameter       | Type    | Description                                                      |
|-----------------|---------|------------------------------------------------------------------|
| `paths`         | array   | File paths or directories                                        |
| `config`        | string  | Rector config file path                                          |
| `only`          | string  | Filter to a single rule (FQCN or short name)                     |
| `only_suffix`   | string  | Filter files by name suffix (e.g. `Controller` → `*Controller.php`) |
| `output_format` | string  | `json` (default) or `console`                                    |
| `clear_cache`   | boolean | Clear Rector cache before processing                             |

## 🖥️ Administration Tools (`js-admin-tooling`)

Runs inside `src/Administration/Resources/app/administration`. No context parameter.

### `eslint_check` / `eslint_fix`

ESLint linting / auto-fix for Administration.

```
Use js-admin-tooling eslint_fix with paths ["src/app/component/"]
```

| Parameter       | Type   | Tool           | Description                                                                                     |
|-----------------|--------|----------------|-------------------------------------------------------------------------------------------------|
| `paths`         | array  | both           | File paths or directories, appended to the npm script's own targets. Omit to run the script's configured targets. |
| `output_format` | string | `eslint_check` | `stylish` (default) or `json`                                                                   |
| `scope`         | string | both           | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                 |

### `stylelint_check` / `stylelint_fix`

Stylelint SCSS linting / auto-fix.

```
Use js-admin-tooling stylelint_fix with paths ["src/**/*.scss"]
```

| Parameter       | Type   | Tool              | Description                                                     |
|-----------------|--------|-------------------|-------------------------------------------------------------------|
| `paths`         | array  | both              | File paths or glob patterns. Omit to run the script's own targets |
| `output_format` | string | `stylelint_check` | `string` (default), `json`, or `compact`                        |
| `scope`         | string | both              | Scope name from `.mcp-js-tooling.json`                          |

> [!NOTE]
> The stylelint tools do not validate their paths. Their schemas accept glob patterns, and the shared path validator refuses a glob because it tests each argument for existence. An unmatched glob therefore reaches Stylelint unchecked.

### `prettier_check` / `prettier_fix`

Runs `npm run format` / `npm run format:fix`. No parameters. Paths come from the project config.

### `jest_run`

Jest unit tests. Single run only. Watch mode isn't supported (see [mcp-enforcement.md](./mcp-enforcement.md)).

```
Use js-admin-tooling jest_run with testPathPatterns "component"
Use js-admin-tooling jest_run with coverage true
```

| Parameter          | Type    | Description                        |
|--------------------|---------|------------------------------------|
| `testPathPatterns` | string  | Regex on test file paths           |
| `testNamePattern`  | string  | Regex on test names                |
| `coverage`         | boolean | Generate coverage report           |
| `updateSnapshots`  | boolean | Update snapshots                   |

### `tsc_check`

`npm run lint:types` against the project tsconfig. No parameters.

### `lint_all`

Runs TypeScript, ESLint, Stylelint, and Prettier in one shot. Intended for pre-commit validation. No parameters.

### `lint_twig`

ESLint against `.html.twig` files. Validates Admin Vue component templates. No parameters.

### `unit_setup`

Regenerates the component import resolver map. Run it when Jest fails with import/module resolution errors. No parameters.

### `vite_build`

Vite build for Administration (Vue 3).

| Parameter | Type   | Description              |
|-----------|--------|--------------------------|
| `mode`    | string | `development` or `production` |

## 🛒 Storefront Tools (`js-storefront-tooling`)

Runs inside `src/Storefront/Resources/app/storefront`. No context parameter.

> [!NOTE]
> Prettier and TypeScript aren't exposed for Storefront. The Shopware 6 Storefront `package.json` has no corresponding npm scripts.

### `eslint_check` / `eslint_fix`

ESLint linting / auto-fix for Storefront. The Storefront splits ESLint across two npm scripts — `eslint:app` for the `app/storefront` package and `eslint:components` for the component tree under `src/Storefront/Resources/views/components` — so each supplied path is routed to the tree that owns it and both scripts run when both trees are targeted. A path containing `views/components` goes to the components tree; everything else goes to the app tree.

```
Use js-storefront-tooling eslint_fix with paths ["src/plugin/"]
Use js-storefront-tooling eslint_check with paths ["views/components/cms/"]
```

| Parameter       | Type   | Tool           | Description                                     |
|-----------------|--------|----------------|-------------------------------------------------|
| `paths`         | array  | both           | File paths or directories, in any of the three forms below |
| `output_format` | string | `eslint_check` | `stylish` (default) or `json`                   |
| `scope`         | string | both           | Scope name from `.mcp-js-tooling.json`          |

Three path forms are accepted, per path:

- repo-root-relative — `src/Storefront/Resources/views/components/…` or `src/Storefront/Resources/app/storefront/…`
- tree-relative — `views/components/…` for the components tree, `src/…` or `build/…` for the app tree
- a path already carrying the package prefix

Every path is validated before ESLint runs. A path that does not exist, or that resolves to no file carrying an extension the Storefront ESLint config reads (`js`, `ts`, `mjs`, `cjs`, `jsx`, `tsx`, `vue`, `json`), is refused with a message naming it — so `paths: ["src/scss"]` fails loudly instead of linting nothing and reporting success. A path containing a single quote, a newline, or a carriage return is refused as well; those characters cannot be quoted safely through the container command wrappers.

Omitting `paths` runs the aggregate `lint:js` / `lint:js:fix` script bare across both trees.

> [!WARNING]
> `output_format` is ignored on a no-paths `eslint_check`. The no-paths branch runs `npm run lint:js` bare, and that script chains bare `npm run` calls, so an appended reporter flag would never reach ESLint. Pass `paths` when you need `json` output.

> [!NOTE]
> A no-paths run under an active scope that selects its own ESLint config is refused rather than run, because the bare script would silently apply the package's own config instead. Pass `paths`, or call with `scope: "shopware"`.

### `stylelint_check` / `stylelint_fix`

Stylelint SCSS linting / auto-fix. Same shape as the Administration versions: `paths` (file paths or glob patterns, relative to the `app/storefront` package directory), `output_format` on the check tool (`string` default, `json`, `compact`), and `scope`. Omit `paths` to run the targets baked into the `lint:scss` / `lint:scss-fix` script. Like the Administration versions, these tools do not validate their paths.

```
Use js-storefront-tooling stylelint_fix with paths ["src/**/*.scss"]
```

### `jest_run`

Jest unit tests for the Storefront **`app/storefront` package suite only**. Jest's `rootDir` is that package and its `testMatch` collects `**/test/**/*.test.js`, so the component tests under `src/Storefront/Resources/views/components/` are never collected — run those with [`vitest_run`](#vitest_run). A `testPathPatterns` value naming `views/components` is rejected with a message pointing at `vitest_run`.

Same parameters as the Admin version: `testPathPatterns`, `testNamePattern`, `coverage`, `updateSnapshots`, plus `scope`.

### `vitest_run`

Vitest test runner for the Storefront component suite under `src/Storefront/Resources/views/components/`. This is the only runner that collects those tests. Runs `npm run unit:components`, or `unit:components:coverage` when `coverage` is true. Single run only — watch mode isn't exposed (see [mcp-enforcement.md](./mcp-enforcement.md)).

```
Use js-storefront-tooling vitest_run with paths ["views/components/cms/"]
Use js-storefront-tooling vitest_run with testNamePattern "renders the slider"
```

| Parameter         | Type    | Description                                                       |
|-------------------|---------|-------------------------------------------------------------------|
| `paths`           | array   | Test file or directory filters. Omit to run the whole component suite |
| `testNamePattern` | string  | Regex on test names (`-t`)                                        |
| `coverage`        | boolean | Run `unit:components:coverage` instead                            |
| `updateSnapshots` | boolean | Update Vitest snapshots (`-u`)                                    |
| `scope`           | string  | Scope name from `.mcp-js-tooling.json`                            |

`paths` accepts the same three forms as the Storefront ESLint tools (repo-root-relative, tree-relative `views/components/…`, or a path already carrying the package prefix) and each one is checked for existence before Vitest runs. A path containing a single quote or a line break is refused.

### `ludtwig_check` / `ludtwig_fix`

ludtwig linting / auto-fix for Storefront Twig templates. Runs `composer ludtwig:storefront` / `composer ludtwig:storefront:fix` from the project root against `src/Storefront/Resources/views`.

```
Use js-storefront-tooling ludtwig_check
```

No parameters. Neither tool takes `paths` and neither takes `scope`: the composer script body is `cd ./src/Storefront/Resources/views; ludtwig .`, whose `;` makes appended arguments impossible, and the run is pinned to the project root so a scope set by an earlier call in the same server process cannot move it.

> [!IMPORTANT]
> Both tools require a `ludtwig` binary where the command runs — on the host for a native setup, inside the container otherwise. No tool in this plugin installs it. When it is missing the composer script fails and the tool surfaces that failure.

### `webpack_build`

Webpack build for Storefront (vanilla JS).

| Parameter | Type   | Description                   |
|-----------|--------|-------------------------------|
| `mode`    | string | `development` or `production` |
