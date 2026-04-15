# Tools Reference

27 tools across three MCP servers: 9 in `php-tooling`, 12 in `js-admin-tooling`, and 6 in `js-storefront-tooling`.

## PHP Tools (`php-tooling`)

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

## Administration Tools (`js-admin-tooling`)

Runs inside `src/Administration/Resources/app/administration`. No context parameter.

### `eslint_check` / `eslint_fix`

ESLint linting / auto-fix for Administration.

```
Use js-admin-tooling eslint_fix with paths ["src/app/component/"]
```

| Parameter       | Type   | Tool              | Description                       |
|-----------------|--------|-------------------|-----------------------------------|
| `paths`         | array  | both              | File paths or directories         |
| `output_format` | string | `eslint_check`    | `stylish`, `json`, or `compact`   |

### `stylelint_check` / `stylelint_fix`

Stylelint SCSS linting / auto-fix.

```
Use js-admin-tooling stylelint_fix with paths ["src/**/*.scss"]
```

Same parameters as ESLint (`paths`, plus `output_format` on check).

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

## Storefront Tools (`js-storefront-tooling`)

Runs inside `src/Storefront/Resources/app/storefront`. No context parameter.

> [!NOTE]
> Prettier and TypeScript aren't exposed for Storefront. The Shopware 6 Storefront `package.json` has no corresponding npm scripts.

### `eslint_check` / `eslint_fix`, `stylelint_check` / `stylelint_fix`

Same shapes as the Administration versions (`paths`, plus `output_format` on the `*_check` tools), scoped to Storefront.

```
Use js-storefront-tooling eslint_fix with paths ["src/plugin/"]
Use js-storefront-tooling stylelint_fix with paths ["src/**/*.scss"]
```

### `jest_run`

Jest unit tests for Storefront. Same parameters as the Admin version: `testPathPatterns`, `testNamePattern`, `coverage`, `updateSnapshots`.

### `webpack_build`

Webpack build for Storefront (vanilla JS).

| Parameter | Type   | Description                   |
|-----------|--------|-------------------------------|
| `mode`    | string | `development` or `production` |
