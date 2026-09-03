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
Use console_run with command "debug:container" env "staging" output_file "var/dump/staging-container.txt"
Use console_list with namespace "cache"
```

`console_run` parameters:

| Parameter        | Type          | Description                                    |
|------------------|---------------|------------------------------------------------|
| `command`        | string        | Console command (required)                     |
| `arguments`      | array         | Positional arguments                           |
| `options`        | object        | Options as key/value                           |
| `env`            | string        | Symfony env passed as `--env`. Any name the installation defines (`dev`, `prod`, `test`, `staging`, …); `^[A-Za-z0-9_]{1,32}$` |
| `output_file`    | string        | Write stdout to this file instead of returning it (see below) |
| `verbosity`      | string        | `quiet`, `normal`, `verbose`, `very-verbose`, `debug` |
| `no_debug`       | boolean       | Disable debug mode                             |
| `no_interaction` | boolean       | Non-interactive                                |

With `output_file` set, stdout goes to the file and the response carries only the resolved path, the byte count and the exit status — stderr still comes back in the response. A relative path resolves against the project root, parent directories are created, and the file is replaced only after the command exits zero. A failed command leaves the target as it was and returns its stdout in the response instead. The value is refused when it is longer than 4096 bytes, or when the target already exists as a symlink or as anything other than a regular file. Omit it (or pass an empty string) to get the output in the response as before.

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

ESLint linting / auto-fix for Administration. Two routes, selected by whether `paths` is supplied: with paths, the run goes to the target-less npm script `lint:debugging` so the given paths are the only targets; without paths, the aggregate `lint` / `lint:fix` script runs and its own baked-in targets stay authoritative. The aggregate is never a fallback for a path-scoped run — npm appends `--` arguments to the end of the whole script body, so appending a path to a body that already names its own targets would widen the run rather than narrow it to the path. A path-scoped run refuses outright when `lint:debugging` is unavailable or cannot take appended arguments.

```
Use js-admin-tooling eslint_fix with paths ["src/app/component/"]
```

| Parameter       | Type   | Tool           | Description                                                                                     |
|-----------------|--------|----------------|-------------------------------------------------------------------------------------------------|
| `paths`         | array  | both           | File paths or directories. When supplied, these are the ONLY targets the run covers; a path containing `app/administration/` is rebased onto the package directory by stripping everything up to and including that prefix. Omit to run the targets the aggregate `lint` / `lint:fix` script configures for itself. |
| `output_format` | string | `eslint_check` | `stylish` (default) or `json`                                                                   |
| `scope`         | string | both           | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                 |

Every path is validated before ESLint runs: it must exist and resolve to at least one file carrying an extension the Administration ESLint config reads (`js`, `ts`, `tsx`, `vue`, `json`, `twig`). A path that fails either check is refused with a message naming it, rather than linting nothing and reporting success.

### `stylelint_check` / `stylelint_fix`

Stylelint SCSS linting / auto-fix. Two routes, selected by whether `paths` is supplied: with paths, the run goes to the target-less npm script `stylelint:base` so the given paths are the only targets; without paths, the aggregate `lint:scss` / `lint:scss-fix` script runs (bare when there is nothing else to append) and its own `**/*.scss` target stays authoritative. The aggregate is never a fallback for a path-scoped run — appending a path to a body that already names `**/*.scss` would widen the run to every SCSS file plus the path, never narrow it. That matters most for `stylelint_fix`, which writes: a widened fix would modify files nobody named. A path-scoped run refuses outright when `stylelint:base` is unavailable.

```
Use js-admin-tooling stylelint_fix with paths ["src/**/*.scss"]
```

| Parameter       | Type   | Tool              | Description                                                     |
|-----------------|--------|-------------------|-------------------------------------------------------------------|
| `paths`         | array  | both              | File paths or glob patterns, relative to the Administration package directory. When supplied, these are the ONLY targets the run covers. Omit to run the targets the aggregate SCSS script configures for itself. |
| `output_format` | string | `stylelint_check` | `string` (default), `json`, or `compact`                        |
| `scope`         | string | both              | Scope name from `.mcp-js-tooling.json`                          |

> [!NOTE]
> A literal path is validated before Stylelint runs: it must exist and resolve to at least one `.scss` or `.css` file, or it is refused with a message naming it rather than linting nothing and reporting success. A glob pattern (containing `*`, `?`, or `[`) skips that check — the existence probe cannot resolve a glob — and reaches Stylelint unchecked for expansion there.

### `prettier_check` / `prettier_fix`

Prettier format check / auto-format for Administration. Two routes, selected by whether `paths` is supplied: with paths, the run goes to the target-less npm script `prettier:base`, with the `--check` / `--write` mode flag supplied by the tool, so the given paths are the only targets; without paths, the aggregate `format` / `format:fix` script runs bare (plus a `--config` override when a scope selects one) and its own glob targets stay authoritative. The aggregate is never a fallback for a path-scoped run, for the same reason as ESLint and Stylelint above — appending would widen, not narrow. That matters most for `prettier_fix`, which writes. A path-scoped run refuses outright when `prettier:base` is unavailable.

```
Use js-admin-tooling prettier_check with paths ["src/app/component/"]
```

| Parameter | Type   | Description                                                                                      |
|-----------|--------|-----------------------------------------------------------------------------------------------------|
| `paths`   | array  | File paths or glob patterns, relative to the Administration package directory. When supplied, these are the ONLY targets the run covers. Omit to check/format the targets the aggregate `format` / `format:fix` script configures for itself. |
| `scope`   | string | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior                     |

> [!NOTE]
> A literal path is validated before Prettier runs: it must exist and resolve to at least one `.js` or `.ts` file, or it is refused with a message naming it. A glob pattern (containing `*`, `?`, or `[`) skips that check and reaches Prettier unchecked for expansion there.

### `jest_run`

Jest unit tests. Single run only. Watch mode isn't supported (see [mcp-enforcement.md](./mcp-enforcement.md)).

Runs at the target-less npm script `jest:base`. When that script is unavailable, the tool falls back to the aggregate `unit` script instead of refusing — `jest_run` covers the same suite either way, so nothing is silently widened — but `unit`'s body hardcodes `--ci`, and the tool prints a notice naming the consequences (see the `ci` row below).

**The result comes from Jest's own JSON report, not the process exit code.** Every run appends `--json --outputFile=<path>`; the tool clears that path before starting, reads it afterwards, and decides from the counts it carries:

| Report says | Tool reports |
|--------------------------------------------|-----------------------------------------------------------------------|
| any failed test or suite                    | failure                                                               |
| zero tests ran                              | failure, naming the patterns that matched nothing                     |
| all passed, process exited 0                | success                                                               |
| all passed, process exited non-zero         | success, stating the exit code prominently and keeping the output      |
| report missing or unparseable               | falls back to the exit code, and says the status came from there       |

The last two rows are the point. A coverage-threshold breach or a post-run writer erroring makes Jest exit non-zero after every test passed, and that was previously reported as a failed run. The report also carries the counts when `ci` is true, where Jest's own summary line is suppressed.

> [!NOTE]
> The report path is cleared before each run rather than after. A report present afterwards therefore always belongs to the run that just finished — otherwise a run that crashed before writing one would be judged by the previous run's results, and a failing suite could be reported as a pass. One report file per server process may sit in the environment's `/tmp` between runs.

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
| `ci`               | boolean | Run Jest in CI mode (`--ci`, default `false`). `jest.config.ts` derives `isCi` from an exact `--ci` match in `process.argv` and uses it for both `collectCoverage` and the reporter choice, so turning this on collects coverage regardless of `coverage` and swaps the reporters to `jest-silent-reporter` plus `jest-junit`, suppressing the per-test lines and the summary. Forced on, without recourse, whenever the `unit` fallback above is in effect. Leave it off unless CI-identical output is needed. |
| `scope`            | string  | Scope name from `.mcp-js-tooling.json`; `shopware` forces project-root behavior |

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

Stylelint SCSS linting / auto-fix. Same routing as the Administration versions: with `paths` supplied, the run goes to the target-less npm script `stylelint:app` so the given paths are the only targets; without `paths`, the aggregate `lint:scss` / `lint:scss-fix` script runs and its own `./src/scss` target stays authoritative. The aggregate is never a fallback for a path-scoped run, and a path-scoped run refuses outright when `stylelint:app` is unavailable. Parameters: `paths` (file paths or glob patterns, relative to the `app/storefront` package directory), `output_format` on the check tool (`string` default, `json`, `compact`), and `scope`.

```
Use js-storefront-tooling stylelint_fix with paths ["src/**/*.scss"]
```

> [!NOTE]
> A literal path is validated before Stylelint runs: it must exist and resolve to at least one `.scss` or `.css` file, or it is refused with a message naming it. A glob pattern (containing `*`, `?`, or `[`) skips that check and reaches Stylelint unchecked for expansion there.

### `jest_run`

Jest unit tests for the Storefront **`app/storefront` package suite only**. Jest's `rootDir` is that package and its `testMatch` collects `**/test/**/*.test.js`, so the component tests under `src/Storefront/Resources/views/components/` are never collected — run those with [`vitest_run`](#vitest_run). A `testPathPatterns` value naming `views/components` is rejected with a message pointing at `vitest_run`.

Runs at the target-less npm script `jest:base`. When that script is unavailable, the tool falls back to the aggregate `unit` script instead of refusing — `jest_run` covers the same suite either way — but `unit`'s body hardcodes `--ci`, and the tool prints a notice naming the consequence: the `ci` argument is ignored and CI mode is forced.

The result comes from Jest's JSON report rather than the process exit code, exactly as described for [the Admin version](#jest_run) — including the cleared-before-each-run report path. This matters more here than on Administration: the Storefront config collects coverage unconditionally and enforces global thresholds, so a path-scoped run of a few files exits non-zero on the threshold while every test passes. Those runs previously reported as errors.

Same parameters as the Admin version — `testPathPatterns`, `testNamePattern`, `coverage`, `updateSnapshots`, `ci`, plus `scope` — except `ci`'s consequence differs here: the Storefront `jest.config.js` sets `collectCoverage: true` unconditionally, so `coverage` is unaffected either way and `ci` changes only Jest's own CI-mode behavior. Under CI mode Jest declines to write *new* snapshots — but an explicit `updateSnapshots` still wins, because Jest resolves `--ci` without `--updateSnapshot` to snapshot mode `none` and an explicit `--updateSnapshot` to `all` regardless of `--ci`.

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
