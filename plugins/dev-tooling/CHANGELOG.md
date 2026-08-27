# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.17.2] - 2026-08-27

### Fixed
- **A `scope` argument could execute arbitrary commands on the host.** `resolve_scope` interpolated the caller's scope name directly into a jq *filter program* rather than passing it as data, so a name carrying a double quote escaped the filter's string literal and injected jq of its own. A payload of `" // {"cwd":"$(printf PWNED)"} // .scopes."missing` was accepted where an ordinary undeclared name is refused — the injected `//` alternative made the filter return an object, bypassing the declared-scope check — and left `SCOPE_CWD` holding the command substitution. `wrap_command`'s native and ddev branches place the workdir inside double quotes at the local level, so `eval` in `exec_command` then expanded it on the host. Every scope value now reaches jq through `--arg` as data and the filters index with `$name`; the same treatment covers `scope_get_tool_field`, `scope_get_bootstrap`, `scope_validate`, and the `install_if_missing` lookups in both JS servers, all of which read the same caller-supplied name through `SCOPE_NAME`.
- **A tool-call `arguments` value that was not a JSON object skipped every schema constraint.** `validate_tool_arguments` ended its jq pipeline with `|| true`, so when `arguments` was a string, array, or null, `$args | keys` errored, the failure was masked, the message stayed empty, and the validator returned success. `required`, `additionalProperties`, and `enum` were all bypassed for any tool on any server. Non-object arguments are now rejected by name and type, and a jq failure is no longer treated as a passing validation. Synced from `templates/mcp-shared/mcpserver_core.sh`.
- **The docker container name was interpolated unquoted into the command string that `eval` runs.** A configured container carrying a shell metacharacter split the generated `docker exec -i <name> bash -c '…'` into two commands. The name now passes through `shell_quote_arg` at construction in both the plain and npm wrappers, and in both docker-compose wrappers. Synced from `templates/mcp-shared/environment.sh` and `docker-compose.sh`.
- **Malformed tool arguments ran the tool against synthesized defaults instead of being refused.** Every PHP tool parsed its arguments with a `|| echo '{…}'` fallback that turned a jq failure into a complete default object, so a caller's broken JSON produced a successful run over the wrong targets. All eight sites — `phpstan_analyze`, `ecs_check`, `ecs_fix`, `phpunit_run`, `phpunit_coverage_gaps`, `console_run`, `console_list`, and both rector tools through their shared parser — now refuse and name the payload that failed to parse.
- **`phpunit_coverage_gaps` reported "No files with uncovered lines." when it had not parsed anything.** The `awk` invocation that parses the Clover report was unguarded, and because `handle_tools_call` dispatches tool functions on the left of `||`, errexit is disabled for the whole body — an `awk` failure fell through to the empty-result branch and returned 0, leaving the caller unable to distinguish a clean report from a failed parse. The status is now checked and a parse failure names the Clover path and awk's exit code.
- **`phpunit_coverage_gaps` built a broken Clover path under docker-compose.** It read `LINT_WORKDIR` directly, which under that environment carries the literal sentinel `(resolved at call time)` because the container path is read from the compose config per call. A new `get_workdir()` accessor in `shared/environment.sh` dispatches on the environment and delegates the compose case to the existing resolver, and the tool now sources its path prefix from it.
- **`error_format: "raw"` was declared in the tool schema but silently ignored.** The flag builder emitted `--error-format` only for `json` and `table`, so a caller passing the third declared value got PHPStan's default instead. All three enum values are now honored.
- **`check-phpstan-baseline.sh` aborted when `tool_input.paths` was not an array.** The hook extracted the value with `jq -r`, which strips the quotes from a JSON string, so the following parse received invalid JSON and the hook exited 5. It now extracts with `jq -c`, keeping the value valid JSON in every shape.
- **Four Storefront npm scripts were detected as Storefront context but matched no block rule.** `lint:js:app`, `lint:js:components`, and their `:fix` variants passed the context gate and were never redirected at the MCP tools. A bare `ludtwig` reached through a package runner — `composer exec ludtwig` and the `npx` / `pnpm exec` / `bunx` forms — was likewise unblocked, since the rule's leading boundary accepted only a command separator. Both gaps are closed; the ludtwig boundary matches a runner prefix rather than any whitespace, so a command that merely mentions the word in an argument is still allowed.
- **`_lsp_exec_direct` word-split and glob-expanded its command.** It now splits into an array, and refuses with a message when the configured `binary` contains a line break — which `read` would silently truncate — or resolves to an empty command, which `exec` would accept as a no-op returning success while starting no language server.
- **`vite_build` and `tsc_check` appended their flags without the append-safety probe** that the other appending tools run, so a change to the underlying npm script body could have produced a silently wrong command.
- **ludtwig invoked through a runner that takes its own options stayed unblocked.** The first runner allow-list matched only `composer exec ludtwig` and its bare siblings, so `composer exec -- ludtwig`, `npx -y ludtwig`, and `pnpm dlx -- ludtwig` passed. `composer exec --` is the form Composer requires when the invoked binary takes options, which made the most likely real invocation the one that escaped. The pattern now tolerates option words and `--` between the runner and the token, and a command that merely names ludtwig in an argument is still allowed.
- Synced `shared/mcpserver_core.sh` again: `handle_tools_call` derived the arguments object with `jq -c '.arguments // {}'`, and `//` treats a present `null` and a present `false` as absent, so both reached the tool as `{}` and never met the non-object rejection added earlier in this release. It now uses `has("arguments")`. On the MCP path `process_request` already gates the whole request through `jq -e '.'`, so this is defense in depth for direct invocation rather than a live remote-input fix.
- `exec_command`'s header described the wrapping for three of the five environments. The docker, docker-compose and vagrant branches embed the command in a single-quoted remote string; `native` has no remote shell; `ddev` emits bare argv, so the local `eval` consumes the escaping and ddev re-parses inside the container. A value reaching a ddev command is parsed twice while `shell_quote_arg` escapes for one. The header now states this per branch and names the ddev path as an open gap rather than implying it is covered.
- **A line break inside one `paths` element became two paths on every JS tool.** `parse_paths_json` decoded with `jq -r '.[]'` and read the result back through a line-oriented loop, so a newline *inside* an element was indistinguishable from the separator between elements, and `assert_no_shell_hostile_chars` ran after the split and saw two newline-free fragments. A single element of `src/app\n.` therefore produced `"src/app" "."`, and `.` is the whole tree — on `eslint_fix`, `stylelint_fix` and `prettier_fix` that is a write across the entire tree from a single-path request, reported as success. The top-level newline guard existed in all six PHP tool libs and none of the thirteen JS ones, so the tools whose purpose is path-scoping were the unprotected ones. `parse_paths_json` now refuses an element whose decoded value carries a line break, before the split. Refusal rather than NUL-delimited decoding because `jq --raw-output0` needs jq 1.7 and this repo declares no jq minimum, and a line break in a path is refused downstream regardless.
- **A caller value reaching a ddev command was parsed twice while quoted for one parse.** The docker, docker-compose and vagrant wrappers embed the command in a single-quoted remote string; `native` has no remote shell; `ddev` emits bare argv, so the local `eval` consumes `shell_quote_arg`'s escaping and ddev then joins the argv into `bash -c` inside the container. Escaping cannot close this: measured against a model of ddev's own `quoteArgs`, one layer executes a command substitution, two layers bake literal double quotes into every value, three are a syntax error — and no fixed depth is correct, because `quoteArgs` re-quotes only arguments containing `" \t\r\n#`, so the layer count depends on the value's own content and the sender cannot predict it. `assert_no_shell_hostile_chars` now refuses `$ \` \\ " ; & | < > ( ) { }` when the environment is ddev. Globs stay allowed (the container shell expands them, which changes which files a tool sees but cannot execute caller text) and so do spaces. This is a behavior change for ddev users: a glob-free path containing one of those characters is now refused rather than run. Reasoned from ddev's source and a stand-in; not verified against a live ddev project.
- **A scope `jest.env` value containing a space became its own command.** `_jest_scope_env_prefix` rendered `KEY=value` pairs joined by spaces, unquoted, ahead of the command handed to `eval`, so `NODE_OPTIONS=--require ./bootstrap.js` executed `./bootstrap.js`. Each value now passes through `shell_quote_arg` and a key or value carrying a line break is refused. Emitted output changes from `KEY=value` to `KEY="value"`.
- Synced `shared/docker-compose.sh`, which built `-f ${file_path}` unquoted into the string handed to `eval`, so a compose file path or project root containing a space split into two arguments.

## [3.17.1] - 2026-08-27

### Fixed
- **A tool command that read stdin hung the whole tool call.** `exec_command` and `exec_npm_command` ran every wrapped command with the server's stdin inherited — the JSON-RPC pipe from the MCP client, which the docker wrappers forward into the container via `docker exec -i`. A child that read stdin blocked forever on the open, never-delivering pipe: observed with `phpunit_run` on a test whose Symfony confirm prompt falls back to reading STDIN, where the call produced no result until the server was killed. Both functions now redirect the eval's stdin to `/dev/null` (synced from `templates/mcp-shared/environment.sh`), so such a child sees immediate EOF and interactive prompts fall back to their defaults.

## [3.17.0] - 2026-08-22

### Added
- **`paths` on `prettier_check` / `prettier_fix` (`js-admin-tooling`).** Both tools previously took no path argument at all and could only run the whole configured glob set. A supplied path now routes at the target-less `prettier:base` npm script and is the only target the run covers, which for `prettier_fix` is also the only file it can rewrite. Literal paths are checked for existence and for carrying a `js` or `ts` extension; glob patterns skip that check and reach Prettier for it to expand.
- **`ci` on `jest_run` (both JS servers).** Defaults to `false`, which is a behavior change: runs previously always went through `npm run unit`, whose body hardcodes `--ci`. What that costs differs per server, and the parameter descriptions differ accordingly. On Administration, `jest.config.ts` derives `isCi` from an exact `--ci` match in `process.argv` and uses it for both `collectCoverage` and a reporter swap to jest-silent-reporter plus jest-junit — so every run collected coverage regardless of the `coverage` argument, and the per-test lines and summary the caller wanted were suppressed. On Storefront, `jest.config.js` sets `collectCoverage` and its reporters unconditionally, so `--ci` there only makes Jest decline to write *new* snapshots — `updateSnapshots` still wins when it is set, because Jest resolves `--ci` without `--updateSnapshot` to snapshot mode `none` and an explicit `--updateSnapshot` to `all` either way. Appending `--ci=false` could not undo any of it, because the literal `--ci` stays in argv.
- **PreToolUse redirects for the target-less base scripts.** Admin `lint:debugging`, `stylelint:base`, `prettier:base`, and `jest:base`; Storefront `eslint:app`, `eslint:components`, `stylelint:app`, and `jest:base`. `is_admin_context()` and `is_storefront_context()` both gained the three Storefront-only names, without which the Admin hook's unknown-context fallback claimed them and named the wrong server's tool. `jest:base` is declared by both packages, so it carries no side-specific marker: the Storefront hook takes it when the command names the Storefront tree, and the Admin unknown-context fallback takes the bare form. A command naming both trees is still claimed by both detectors and blocked twice, which is a pre-existing property of path-first detection rather than something this change introduces.

### Fixed
- **`jest_run` reported a failure for suites that passed.** The tool took its result from the process exit code, so anything making Jest exit non-zero after the tests ran turned a correct result into a reported failure. On Storefront this was not an edge case: the config collects coverage unconditionally and enforces global thresholds, so every path-scoped run of a few files exited non-zero on the threshold while every test passed. Both servers now append `--json --outputFile=<path>` and decide from the report Jest itself writes — any failed test or suite fails; zero tests ran fails, naming the patterns that matched nothing; all-passed with a non-zero exit succeeds while stating the exit code prominently and keeping the output; and a missing or unparseable report falls back to the exit code and says the status came from there. The counts are echoed in a summary line, which is the only place they appear when `ci` is true, since that mode swaps in a reporter that prints none. The report path is cleared before each run rather than after: a report present afterwards then always belongs to the run that just finished, where reading a leftover one would have judged a crashed run by the previous run's results and could report a failing suite as a pass.
- **`eslint_fix` wrote to files far outside the paths it was given.** Every `paths`-taking tool on both JS servers appended the caller's paths to an npm script whose body already hardcoded its own targets, and npm appends `--` arguments to the end of the whole script body — so appending could only widen the run, never narrow it. Measured against current Shopware: `npm run lint -- --format json build.ts` linted 4019 files where the target-less script linted 1. A `paths`-scoped `eslint_fix` therefore ran `--fix` across the entire Administration tree and silently modified files nobody named, defeating any workflow fenced to a file set. Path-scoped runs now route at a target-less base script — Admin `lint:debugging`, `stylelint:base`, `prettier:base`; Storefront `eslint:app`, `eslint:components`, `stylelint:app` — where the caller's paths are the only targets. Affected `eslint_check` / `eslint_fix` and `stylelint_check` / `stylelint_fix` on `js-admin-tooling`, and `stylelint_check` / `stylelint_fix` on `js-storefront-tooling`; the Storefront ESLint tools were already routed this way in 3.16.0.
- **A path-scoped run is now refused rather than silently widened when its base script is unavailable.** Falling back to the aggregate script would reintroduce the defect above under a different name, so the refusal states the missing script, the tool, and why the aggregate is not a substitute. The `jest_run` fallback is the one exception and is announced: no path widening is at stake there, so it drops to `unit` after printing which of the caller's arguments that overrides.
- **Paths that exist but lint nothing no longer report success.** Admin ESLint accepts `js ts tsx vue json twig`, Admin Prettier `js ts`, and both Stylelint tools `scss css`; a path resolving to no file with an accepted extension is refused by name instead of running green over zero files. Admin ESLint additionally rebases a repo-root-relative path onto the package directory. Every path reaching a command string is shell-escaped, and glob patterns are partitioned out of the existence check rather than failing it.
- **Admin `jest_run` appended its flags without the append-safety probe** that every other appending tool runs, so a change to the `unit` script body could have produced a silently wrong command. The fallback route now gates before appending.

## [3.16.1] - 2026-08-21

### Fixed
- **A tool-call argument outside a parameter's declared `enum` reached the tool instead of being rejected.** `validate_tool_arguments` checked `required` and, under `additionalProperties: false`, unknown properties — but never the `enum` a property declares, so the enum was documentation rather than enforcement. Observed against `eslint_check` with `output_format: "compact"`: the call was dispatched and failed downstream with ESLint's own `The compact formatter is no longer part of core ESLint`. Every property present in a call whose schema declares an `enum` is now checked, all offenders are named in one message with the value received and the allowed values, and the call is rejected before dispatch. Precedence is unchanged: missing required parameters are reported first, then unknown parameters, then invalid values. Affects every tool on all three servers that declares an enum — `output_format`, `error_format`, `mode`, `testsuite`, `coverage_format`, `coverage_driver`, `env`, `verbosity`, and `format`.
- Removed the now-unreachable `compact` arm from both servers' `eslint_check` format switch. It existed so a caller passing `compact` would hit ESLint's own error rather than fall through to `stylish`; enum enforcement rejects the value before the tool runs, so the arm was dead. Stylelint's `compact` is untouched and remains valid — it is a working formatter in the pinned Stylelint version, unlike ESLint's.

## [3.16.0] - 2026-08-21

### Added
- **`vitest_run` tool (`js-storefront-tooling`).** Runs the Storefront component suite via `npm run unit:components` (`vitest run --config vitest.config.mts`), or `unit:components:coverage` when `coverage` is set. Accepts `paths` (rebased onto `views/components` and validated before the run), `testNamePattern` (`-t`), `updateSnapshots` (`-u`), and `scope`. Component tests live at `src/Storefront/Resources/views/components/**/*.test.{js,ts}` and are invisible to Jest, whose project roots at the `app/storefront` package with a `**/test/**/*.test.js` match — so before this tool there was no MCP path to them at all. Does not carry over `jest_run`'s scope `env` prefix or `install_if_missing` bootstrap; both are keyed on `scopes.<name>.jest.*`.
- **`ludtwig_check` / `ludtwig_fix` tools (`js-storefront-tooling`).** Run `composer ludtwig:storefront` and `composer ludtwig:storefront:fix` from the project root through the non-npm environment wrapper. Neither takes `paths` — the composer script body contains a `;` and cannot accept appended arguments — and neither takes `scope`, since both pin `resolve_scope "shopware"` so a preceding scoped call cannot move ludtwig out of the project root via the process-global `SCOPE_CWD`. Requires a `ludtwig` binary; when absent the composer script fails and the tool surfaces that failure rather than installing anything.
- **PreToolUse redirects for the new tools.** The Storefront hook now blocks `npm run unit:components` (plus `:watch` / `:coverage`), `npx vitest`, and `composer storefront:components:unit` toward `vitest_run`; and `composer ludtwig:storefront`, its `:fix` variant, and a bare `ludtwig` toward the ludtwig tools. `is_storefront_context()` gained matching clauses, without which those blocks were unreachable for the bare commands. The pre-existing `npm run unit` pattern is deliberately unchanged and still does not match `unit:components`.

### Fixed
- **Storefront ESLint tools were fully broken against current Shopware.** Both built `npm run <script> -- <args>`, and npm appends those arguments to the end of the entire script body. The Storefront `lint:js` body ends in a subshell close, so every `eslint_check` and `eslint_fix` call — including one with no arguments — died with `sh: syntax error: unexpected word`. Argument appends now pass an append-safety probe first: the script body is read with `npm pkg get`, and appending is refused when the body ends in `)` or `}`, contains `;` or `|`, or ends in a package-manager run-script invocation carrying no `--` (where npm's own CLI parser would swallow the arguments and leak their values through as positional targets). A refused append fails hard naming the script and quoting its body instead of emitting a wrong command.
- **Paths were never rebased and never validated, so a mistyped path linted nothing and reported success.** Every Storefront lint script carries `--no-error-on-unmatched-pattern`. Caller paths are now rebased onto the working directory, checked for existence inside the target environment, and checked for lintability — a file must carry an accepted extension, a directory must contain at least one file that does. A directory such as `src/scss` that exists but holds no JavaScript is refused rather than linted to a green zero-file result.
- **Caller-supplied values reached a shell unescaped.** A path containing `$( )` executed rather than being tested, and a value containing a space was silently split — a multi-word `--testNamePattern` was truncated at the first space under the docker, docker-compose and vagrant wrappers, narrowing the run without saying so. Values are now escaped through a shared helper and rejected outright when they contain a single quote, newline, or carriage return, none of which can survive the wrappers' single-quoted embedding. The nested `sh -c` in the path probe was removed so that every environment performs exactly one shell parse.
- **`jest_run` reported green for suites it structurally cannot run.** A `testPathPatterns` value naming `views/components` now fails hard and names `vitest_run`. `jest_run`'s own argument append also passes the append-safety probe, which it previously skipped.
- **A scoped Storefront `eslint_check` with no `paths` silently used the wrong config.** It read the scope's configured ESLint config and then emitted a bare `npm run lint:js`, substituting the package script's configuration. It now fails hard naming the scope, the config, and why a scoped no-path run cannot be constructed.
- **Malformed `paths` widened the run instead of failing.** `{"paths":[""]}` and a non-array `paths` both presented as "no paths supplied", and the tool then ran the npm script's own baked targets — a full-tree run reported as success for a request naming one file. Both are now refused, distinctly from an absent or empty `paths`, which keeps its existing behavior. The `jq` iteration's exit status is checked rather than discarded.
- **`composer ludtwig:storefront:fix` was redirected to `ludtwig_check`**, sending an agent that asked to fix to the dry-run tool.
- **The Jest hook message named `testPathPattern`**, singular, while the schema and implementation both use `testPathPatterns` — an agent following the hook had its test selection silently ignored and ran the whole suite.
- **`compact` was offered as an ESLint `output_format`** on both JS servers. ESLint 9 dropped that formatter from core, so the option errored. Removed from the enums; the `case` arm is retained so a caller passing it anyway gets ESLint's own error rather than a silent fall-through to `stylish`. Stylelint's `compact` is unaffected — Stylelint still ships it.
- **Admin `tools.json` documented a `paths` default of "current directory"** that the implementation no longer applies.
- **A symlink to a directory containing lintable files was refused.** `[ -d ]` follows a symlink but `find` does not traverse one given as its operand; the probe now passes `-L`.

### Changed
- **Omitting `paths` no longer appends a target.** Previously `paths` defaulted to `.` (or `**/*.scss`), which appended a target the caller never asked for. A call with no paths now runs the npm script with its own configured targets. Flags such as `-f <format>` and a scope `--config` are still appended when supplied.
- **Storefront `eslint_check` / `eslint_fix` route by tree.** Paths under `views/components/` go to the components tree and everything else to the `app/storefront` tree; a call spanning both runs both and fails if either fails. Repo-root-relative, tree-relative, and package-prefixed path forms are all accepted and normalized.

> [!NOTE]
> Storefront `eslint_check` with `output_format` set and no `paths` ignores the format: the no-paths branch runs the npm script bare, and a flags-only append to `lint:js` is correctly refused by the append-safety probe. The Stylelint tools do not validate paths, because their schemas accept glob patterns and the validator would refuse a glob.

## [3.15.1] - 2026-06-28

### Changed
- The `dev-tooling-runner` subagent now always passes paths relative to the project root on every tool call — both `targets` and any path inside `scope`. Absolute host paths do not resolve inside docker/docker-compose/vagrant/ddev, so the agent relativizes an absolute path before calling. Documented in the `targets` input definition and as a constraint in `agents/dev-tooling-runner.md`.

## [3.15.0] - 2026-06-26

### Added
- New `dev-tooling-runner` subagent (`agents/dev-tooling-runner.md`, runs on haiku) for executing Shopware dev-tooling checks — PHPStan, ECS, PHPUnit, Rector, ESLint, Stylelint, Prettier, TypeScript, Jest, and Vite/Webpack builds — and, on request, the rule-driven fixers (`ecs_fix`, `rector_fix`, `eslint_fix`, `stylelint_fix`, `prettier_fix`). Run it to keep verbose tool output out of the conversation: it returns a lean (~1–2k token) pass/fail report instead. It acts only on the targets and checks it is given — mapping each intent to a tool via an encoded `(file-type, check/fix-kind) → tool` table, running the matching MCP tools, and reporting findings with capped `file:line` excerpts plus any fixes applied — and never discovers or expands scope. The agent has no `Edit`/`Write`, so it cannot freeform-edit; its only file changes come from the deterministic rule-driven fixers, which apply a fixed ruleset rather than agent-chosen edits, while `console_run`, `console_list`, and `unit_setup` are denied via `disallowedTools` (applied before the wildcard `tools` grant). No `Bash`/`Glob`/`Grep`, and `permissionMode` is unused because it is ignored for plugin subagents. The SessionStart MCP-tool directives now also steer the active session to delegate larger dev-tool runs to the agent while keeping the inline escape hatch for quick single-file checks — a soft default with no PreToolUse block.

## [3.14.0] - 2026-06-25

### Added
- Tool-call arguments are now validated against the called tool's declared `inputSchema` before dispatch. Every field listed in `required` must be present, and when the schema sets `additionalProperties: false` any field outside `properties` is rejected — the call returns an `isError` result naming the missing or unknown parameters instead of running the tool. Applies to all three servers (`php-tooling`, `js-admin-tooling`, `js-storefront-tooling`); tools without a schema are left unvalidated. Added as `validate_tool_arguments` in the shared `mcpserver_core.sh`.

## [3.13.1] - 2026-04-19

### Changed
- Internal shellcheck cleanup. No behavior change. In `shared/mcpserver_core.sh`, the `log()` function now splits `local line` from its assignment so the `local` builtin no longer masks `date`'s exit status (SC2155). In `mcp-server-php/lib/phpunit_coverage.sh`, two unused variables in a `read -r` destructuring were replaced with `_` (SC2034).

## [3.13.0] - 2026-04-17

### Added
- **Scopes: plugin-directory aware tool invocation.** `.mcp-php-tooling.json` and `.mcp-js-tooling.json` gain optional `scopes` and `default_scope` top-level keys. A scope declares a plugin `cwd` (relative to project root) plus per-tool overrides for config paths, bootstrap commands, and style backend. Every MCP tool (all 9 PHP tools and all 18 JS tools across admin and storefront) accepts an optional `scope` argument. Resolution order is: explicit arg, then `default_scope`, then the reserved `"shopware"` scope for project-root behavior. Undeclared scope names hard-fail with an error listing the declared names; the reserved name `"shopware"` must not appear in the `scopes` map.
- **PHP bootstrap chaining for phpstan and rector.** `scope.phpstan.bootstrap` and `scope.rector.bootstrap` accept an array of shell commands that run sequentially before the analyzer. Each command runs in the same environment wrapping as the main tool (docker/docker-compose/vagrant/ddev) and with the scope cwd as its working directory. First non-zero exit aborts the whole tool call and surfaces the bootstrap stderr. Solves the SwagCommercial case where `phpstan.neon` references a Symfony container at `var/cache/static_commercial_phpstan/...` that only exists after `php tests/phpstan/bootstrap.php` runs first.
- **Style backend switch for `ecs_check` / `ecs_fix`.** When a scope sets `style.tool = "php-cs-fixer"`, both tools invoke `vendor/bin/php-cs-fixer` (dry-run with `--diff` for check, `fix -v` for fix) using `style.config` as the config path. Tool names stay `ecs_check` and `ecs_fix` because the intent (check style, fix style) is backend-agnostic. Default backend remains ECS.
- **`jest_run` scope fields.** `scope.jest.cwd` points jest at a plugin-local tree (e.g. `tests/jest/administration`). `scope.jest.env` exports environment variables verbatim before jest runs (for wiring `ADMIN_PATH` or `STOREFRONT_PATH` back to core). `scope.jest.install_if_missing: true` runs `npm ci` in the jest cwd when `node_modules` is absent. Existing `testPathPatterns`, `testNamePattern`, `coverage`, and `updateSnapshots` parameters are unchanged.
- **Environment wrap support for scope cwd across all 5 environments.** Native gains an explicit `cd "${LINT_WORKDIR}/${scope.cwd}" && …` (previously a passthrough relying on process cwd). ddev gains `ddev exec -d "<path>"` when scoped; scoped composer calls route through `ddev exec -d "<path>" composer …` since `ddev composer` has no working-dir flag. docker, docker-compose, and vagrant append the scope cwd to their existing `cd` target inside the wrap. Unscoped invocations in every environment keep their prior wrap exactly.
- **`wrap_npm_command` bypasses `JS_CONTEXT` when scoped.** Plugin layouts place their JS configs directly at the plugin root (not under `src/Administration/Resources/app/administration` or the storefront equivalent), so scoped calls use `${scope.cwd}[/${scope.jest.cwd}]` as the JS working directory instead of the core admin/storefront suffix. Unscoped calls keep the prior `JS_CONTEXT` behavior.
- **SessionStart hook renders a scopes-awareness section.** When `.mcp-php-tooling.json` or `.mcp-js-tooling.json` declares at least one scope, the hook appends a block listing the default scope and all declared names (including `shopware (implicit)`), plus a short how-to on overriding the default per call. Configs without scopes see no change.
- **`setting-up` skill gains an optional plugin-scope phase.** After env detection and the enforcement prompt, the skill probes `custom/plugins/*/composer.json` for `shopware-platform-plugin` entries, asks the user to pick one, and confirms each finding (phpstan bootstrap, php-cs-fixer over ECS, plugin-local jest trees with computed `ADMIN_PATH`/`STOREFRONT_PATH` relative paths, `install_if_missing`). Writes one scope and offers to pin it as `default_scope`. Re-runs offer replace / add-second / change-default rather than overwriting.
- **`shared/scope.sh` module.** New module exposes `scope_validate` (run once at server start, fails hard on reserved-name or missing-default violations), `resolve_scope <arg>` (sets `SCOPE_NAME` / `SCOPE_CWD`), `scope_get_tool_field <tool> <field>`, and `scope_get_bootstrap <tool>`. Errors write to stderr so they reach the MCP caller, not just the log file.
- **Documentation.** New README section with a full config example and call semantics, explicit `NOTE` admonition that scopes do not apply to the LSP, and a dedicated "Scopes and the LSP" section in `docs/lsp.md` explaining the rationale (phpactor already resolves cross-package symbols through composer autoload, scoping would mainly buy smaller index and faster startup, cross-boundary navigation would get worse).

### Backward compatibility

- Configs without `scopes` and `default_scope` behave identically to 3.12.x. No migration needed.
- Unscoped tool calls (no `scope` argument, no `default_scope` pin) use the same execution path as before.
- Existing env wraps for unscoped calls are byte-identical; the scope branch is gated on `SCOPE_CWD` being non-empty.
- No tool renames. `ecs_check` and `ecs_fix` keep their names even when routed to `vendor/bin/php-cs-fixer`.
- Existing `jest_run` parameters (`testPathPatterns`, `testNamePattern`, `coverage`, `updateSnapshots`) are unchanged.

## [3.12.3] - 2026-04-16

### Fixed
- `SETUP.md` phpactor prerequisite: removed the `brew install phpactor` suggestion from both locations (phpactor prerequisite, `.lsp-php-tooling.json` prerequisite binary). There is no Homebrew formula for phpactor, so the previous guidance sent users into a dead end. Replaced with the phar release and `composer global require` paths, plus an explicit note not to attempt `brew install`.
- `SETUP.md` phpactor install docs URL: updated from `/installation.html` to `/standalone.html` to match the current phpactor documentation structure.

### Added
- `SETUP.md` new containerized install recipe: phar-sidecar `compose.override.yaml` for docker-compose environments whose base image does not ship phpactor (e.g. `ghcr.io/shopware/docker-dev`). A one-shot `alpine/curl` sidecar downloads the phar into a named volume on `up`, and the PHP service mounts the volume read-only at `/opt/phpactor`. Zero image rebuild, zero `composer.json` pollution, survives `docker compose down`.
- `SETUP.md` `PHPACTOR_UNCONDITIONAL_TRUST=1` env var documentation in the phar-sidecar recipe: silences phpactor's per-project trust prompt for mounted code, so containerized LSPs do not repeatedly refuse to load the project's `.phpactor.json` on fresh containers.
- `SETUP.md` PHP LSP validation step: new phpactor binary reachability check (`phpactor --version` on the host, or `docker compose exec <service> /opt/phpactor/phpactor --version` inside the container) ahead of the dispatcher dry-run so install problems are distinguished from wiring problems.
- `SETUP.md` post-setup subsection on the project-root `.phpactor.json` side effect: recipe for excluding the file via `.git/info/exclude` without touching the committed `.gitignore`, for third-party repos.
- `SETUP.md` setup question 10 (LSP binary path): now names `/opt/phpactor/phpactor` as the canonical value when the phar-sidecar install is used, so the setup skill can prefill it.

## [3.12.2] - 2026-04-16

### Fixed
- `lsp-directives-header` session prompt: replaced the "ALWAYS use LSP for code navigation" blanket mandate with calibrated routing rules derived from benchmark data. Three parallel sections describe when LSP wins (symbol identity: rename safety, interface implementations, inheritance walks, vendor deprecation audits), when Grep wins (textual questions, public-API maps with signatures, private methods, `.stub`/baseline surfaces, very common symbols), and when Read wins (files under ~400 lines, visibility or phpdoc needs). The prior guidance pushed Claude toward LSP in cases where Grep or Read were strictly cheaper and more informative.
- `lsp-directives-header` session prompt: added a hard `NEVER` rule against running `findReferences` on class declarations or on widely-used vendor interface methods (`LoggerInterface::info`, `Request::get`, `EventDispatcherInterface::dispatch`, anything on `ContainerInterface`). Observed failure: `findReferences` on the `Framework` class returned 7694 references across 7643 files and had to fall back to persisted output because the result exceeded the context budget.
- `lsp-directives-php` session prompt: added seven documented failure modes agents now have to assume before trusting a result — asymmetric `hover` reliability (dense and useful on vendor class references, flaky on project methods), `documentSymbol` omitting visibility and types, `workspaceSymbol` being effectively unusable (250 cap, ignored query), `goToImplementation` returning empty on resolution failure, `findReferences` skipping `.stub`/baseline/phpdoc surfaces, 10–30 second cold-start latency on first request, and filesystem-view path rebasing needed when feeding LSP results to Read or Grep.
- `lsp-directives-php` session prompt: added an explicit scope statement noting that LSP ops cover project `src/`, `tests/`, the full `vendor/` tree, and PHP stdlib builtins with no additional setup for cross-boundary queries.
- Session prompts no longer mention implementation details (LSP server name, indexing mechanics). They describe only observable behavior, keeping the guidance portable if the LSP implementation changes.

## [3.12.1] - 2026-04-15

### Fixed
- `setting-up` skill reference: dropped the unrunnable `ENABLE_LSP_TOOL` prerequisite whose **Check** field was prose instead of a shell command, causing Phase 1 to trip. The flag stays documented in `docs/lsp.md`.
- `setting-up` skill reference: removed stale `shopware-lsp` prerequisite and replaced it with `phpactor`. The plugin switched to phpactor in 3.12.0 but the reference still pointed at the old binary.
- `setting-up` skill reference: PHP LSP validation step is now runnable. Phase 5 runs `LSP_DISPATCH_DRY_RUN=1` against `lsp-server-php/lsp.sh` and reads the `target=...` line, with a reason-to-remedy table for the null-stub fallback cases.
- PHP and JS MCP schemas: added `docker-compose` to the `environment` enum plus a `docker-compose` object (`service`, `workdir`, `file`). The runtime already supported this via `shared/docker-compose.sh`, but the schemas rejected it and the skill never offered it, blocking setup for users on the `shopware/shopware` docker-compose stack.
- `setting-up` skill reference: PHP and JS setup questions now offer `docker-compose` as an environment choice with follow-up questions for compose service, workdir, and file. LSP setup questions now cover all containerized environments (docker container, docker-compose service/workdir/file, vagrant workdir, ddev workdir).

### Added
- `enforce_mcp_tools` question in PHP and JS setup flows so users pick hook enforcement during setup instead of discovering it in the config file.
- Optional tool-defaults gate in the PHP setup flow: a single yes/no question unlocks `phpstan.memory_limit`, `phpstan.config`, `phpunit.{testsuite,coverage_driver,config}`, `ecs.config`, and `rector.config` without padding the happy path.

### Removed
- All `shopware-lsp` references from live documentation: root README.md, plugin AGENTS.md, setting-up skill reference, and SETUP.md. Historical references remain in CHANGELOG entries and superpowers plans/specs.

## [3.12.0] - 2026-04-14

### Added
- PHP LSP support via phpactor (`lsp-server-php/`)
- `.lsp-php-tooling.json` configuration file (independent from MCP config; same `environment` schema plus `enabled` and `binary` fields)
- Python URI-rewriting proxy (`shared/lsp_proxy.py`) for containerized LSPs — rewrites `file://` URIs between host and container paths transparently on every frame
- Common bash bootstrap for LSP dispatchers (`shared/lsp_bootstrap.sh`) with preflight check for containerized binaries
- Null LSP stub (`shared/lsp_null.sh`) — minimal JSON-RPC responder used when an LSP is disabled or its preflight fails, so sessions degrade cleanly instead of crashing
- Opt-in by default: LSPs run as the null stub unless explicitly enabled in the LSP config file
- Pytest test suite for the Python proxy (`plugin-tests/dev-tooling/lsp_proxy/`, 24 tests)
- BATS regression tests for `shared/lsp_null.sh`, `shared/config.sh` prefix parameterization, and `shared/lsp_bootstrap.sh` (18 new tests)

### Changed
- `shared/config.sh` now accepts optional `CONFIG_FILE_PREFIX` and `CONFIG_ENV_VAR_PREFIX` variables for LSP use. MCP behavior is byte-identical when these are unset.
- `.lsp.json` now contains a real `phpactor` entry — the temporary `null-test` entry from development has been removed.
- `setting-up` skill description regenerated from the template (plugin-specific setup guidance lives in SETUP.md and its synced copy at `skills/setting-up/references/plugin-setup.md`)

### Removed
- Previous unconfigured `shopware` LSP entry from `.lsp.json`

### Prerequisites (new, optional)
- `python3` ≥ 3.12 on the host — only when enabling LSP with a containerized environment. Not required for native LSP or when LSP is disabled.
- `ENABLE_LSP_TOOL=1` in the Claude Code environment — only required if you want Claude to actively call LSP operations as a tool.

## [3.10.0] - 2026-04-13

### Added
- **Permission configuration in `setting-up` skill** — new Phase 4 pre-approves dev-tooling MCP tools in `.claude/settings.local.json`. Three permission groups bundle related tools (PHP, Administration JS, Storefront JS); each is skipped when its config file was not created. Merges non-destructively into any existing settings.

## [3.9.1] - 2026-04-13

### Fixed
- `setting-up` SKILL.md: bare-path reference to `references/plugin-setup.md` so progressive disclosure loads it correctly.

## [3.9.0] - 2026-04-10

### Added
- **Interactive setup skill** — `setting-up` skill walks users through plugin configuration: checks prerequisites (jq, optionally shopware-lsp), creates `.mcp-php-tooling.json` and optionally `.mcp-js-tooling.json` with environment-specific settings, validates the MCP server connection, and reports post-setup steps. Activates when users ask about setup or when MCP tools fail due to missing config.

## [3.8.0] - 2026-04-09

### Added
- **PostToolUse baseline check hook** — After `phpstan_analyze` runs on specific files, automatically checks whether those files have entries in the PHPStan baseline (`phpstan-baseline.neon` or `phpstan-baseline.php`). If matches are found, injects a warning into the conversation prompting the developer to verify whether the baseline entries are still needed. Prevents stale baseline entries from causing CI failures that file-scoped local runs miss. Auto-detects baseline format and file location. Skips silently for full-project runs where PHPStan validates the baseline natively.

## [3.7.0] - 2026-04-09

### Added
- **Rector refactoring tools** — `rector_fix` applies configured Rector refactorings and reports diffs; `rector_check` previews changes without applying (dry-run). Both use `composer rector` for Shopware's bootstrap integration. Parameters: `paths`, `output_format` (json/console), `config`, `only` (single rule filter), `only_suffix` (file name filter), `clear_cache`. Hook enforcement blocks `vendor/bin/rector` and `composer rector`.

### Changed
- **ECS tool descriptions updated** — `ecs_fix` is now described as the preferred tool; `ecs_check` description directs users to prefer `ecs_fix` unless a read-only preview is needed. This steers LLMs toward the more efficient fix-first workflow.

## [3.6.0] - 2026-04-03

### Added
- **Docker Compose environment type** — New `docker-compose` environment that resolves container name and working directory from Docker Compose at tool call time. Reads `compose.yaml` (including overrides) via the `docker compose` CLI. Defaults to the `web` service with auto-detected workdir from bind mounts. All resolution happens per tool call — the MCP server starts cleanly without Docker running. Configurable via optional `docker-compose.file`, `docker-compose.service`, and `docker-compose.workdir` fields. Recommended environment for `shopware/shopware` development.

## [3.5.0] - 2026-04-01

### Added
- **SessionStart hook** — Injects MCP tool usage directives into conversation context at the start of every session. Lists all available tools across the three MCP servers and instructs Claude to use them instead of bash commands. Includes sequential invocation rule per server (parallel calls across different servers are allowed). Prompt is maintained in `hooks/prompts/mcp-tool-directives.md` and output uses the JSON `additionalContext` format. Respects `enforce_mcp_tools` setting per config prefix.

## [3.4.1] - 2026-04-01

### Fixed
- **Jest `--testPathPattern` renamed to `--testPathPatterns`** - Updated the Jest flag in both admin and storefront MCP servers to use the plural form required by recent Jest versions. The tool input parameter was also renamed from `testPathPattern` to `testPathPatterns`.
- **Misleading PHPStan/ECS config examples** - Removed `phpstan.config` and `ecs.config` from the README and schema examples. These referenced filenames (`phpstan.neon`, `ecs.php`) that don't exist in Shopware. Both tools auto-discover the correct config files (`phpstan.neon.dist`, `.php-cs-fixer.dist.php`) when no explicit config is set.

## [3.4.0] - 2026-03-30

### Added
- **Environment noise filtering** - Filters known environment warnings (e.g., Xdebug Step Debug connection failures) from all PHP and JS tool output. Uses a pattern list in `shared/environment.sh` (`ENV_NOISE_PATTERNS`) that is easy to extend. Only filters noise that is never useful in MCP context — errors and failures are never affected.

### Removed
- **`result-only` output format from `phpunit_run`** - LLMs default to this "efficient" format, which suppresses individual test failure details. When output is truncated, the summary line at the end gets cut too, leaving no signal about what failed. Removing it ensures test failures are always visible in the output.

## [3.3.0] - 2026-02-26

### Added
- **`result-only` output format for `phpunit_run`** - Suppresses per-test progress dots and detailed failure output, showing only the final summary line (e.g., "OK (42 tests, 108 assertions)"). Maps to PHPUnit 10+ `--no-progress` and `--no-results` flags.

## [3.2.0] - 2026-02-24

### Added
- **`phpunit_coverage_gaps` tool** - Discover uncovered lines and methods from Clover XML coverage reports. Accepts `clover_path` (default: `coverage.xml`) and `source_filter` (path substring) parameters. Shows per-file coverage percentage, uncovered method names, and line ranges grouped into consecutive ranges (e.g., `15-17, 25`). Sorted worst coverage first. Paths displayed relative to project root. Summary includes total file count and gap count. Two-step workflow: run `phpunit_run` with `coverage_format: "clover"` first, then `phpunit_coverage_gaps`. Uses portable awk-based XML parsing (no xmllint dependency). Works across all environments (native, Docker, Vagrant, DDEV) via `exec_command`.

## [3.1.1] - 2026-02-24

### Fixed
- **Shell quoting for PHP MCP tool parameters** - Single-quote user-provided values (PHPUnit filter patterns, file paths, console arguments, and option values) when embedding them in eval'd command strings. Shell metacharacters such as `|` in PHPUnit filter patterns (`testA|testB`) were previously interpreted as pipe operators instead of being passed as literal strings.

## [3.1.0] - 2026-02-23

### Added
- **`log_file` configuration option** - Route MCP server logs to a project-local file (e.g., `.claude/mcp-debug.log`) for easier debugging. Supported by all three MCP servers (php-tooling, js-admin-tooling, js-storefront-tooling). Relative paths resolve against the project root. The default `server.log` continues to be written; the extra file is strictly additive. Invalid paths (non-existent parent directory) emit a warning and are silently skipped.

## [3.0.0] - 2026-02-23

### Removed
- **BREAKING**: `gh-tooling` MCP server extracted into standalone `gh-tooling` plugin. Install separately: `/plugin install gh-tooling@shopware-ai-coding-tools`
- **BREAKING**: `check-gh-tools.sh` PreToolUse hook moved to `gh-tooling` plugin

### Migration

1. Install the new plugin: `/plugin install gh-tooling@shopware-ai-coding-tools`
2. Restart Claude Code
3. GitHub tools (`mcp__gh-tooling__*`) work unchanged — the MCP server name is preserved
4. `.mcp-gh-tooling.json` config files require no changes

## [2.7.0] - 2026-02-22

### Added
- **`commit_pulls` tool** - Lists GitHub pull requests associated with a pushed commit SHA. GitHub-only; no local git equivalent. Returns PR number, title, URL, and state by default. Supports `jq_filter`, `suppress_errors`, and `fallback` parameters.
- **`gh-tooling` server scope statement** - `instructions` now explicitly states that all tools require GitHub network connectivity and are not a replacement for local git commands. `git show`, `git log`, `git diff` etc. should be used via Bash for local operations.

### Removed
- **`commit_info` tool** - Removed because its primary use case (changed files list, commit message) is fully covered by `git show <sha>` locally. The only GitHub-exclusive feature (associated PR lookup) is now available via the focused `commit_pulls` tool. This prevents the model from incorrectly reaching for a GitHub API call when a local git command suffices.

### Changed
- Hook (`check-gh-tools.sh`): bare `commits/SHA` endpoint is no longer blocked (no MCP tool covers it; use `git show` locally). The `commits/SHA/pulls` pattern now redirects to `commit_pulls`.

## [2.6.0] - 2026-02-22

### Added
- **`coverage_path` parameter for `phpunit_run`** - Specify a custom output path for the coverage report file or directory. Defaults: `clover`/`cobertura` → `coverage.xml`, `html` → `coverage/`. Not applicable for `text` format.

### Changed
- **File-based coverage formats always emit a text summary** - When `coverage_format` is `clover`, `cobertura`, or `html`, PHPUnit now also runs `--coverage-text` in the same invocation so the MCP response always includes a human-readable coverage summary alongside the file output.

## [2.5.1] - 2026-02-22

### Changed
- `coverage_format` parameter description for `phpunit_run` now clarifies that `clover` is required to identify which specific lines are not covered (per-line XML with hit counts), `html` provides a visual line-by-line report, and `text` only provides aggregate percentages

## [2.5.0] - 2026-02-21

### Added
- **`suppress_errors` parameter** (all 19 gh-tooling tools) - Set to `true` to discard stderr; the tool returns empty output instead of an error message. Useful when a resource may not exist.
- **`fallback` parameter** (all 19 gh-tooling tools) - Text to return (with exit 0) when the gh command fails. Combine with `suppress_errors` for clean "not found" handling.
- **`jq_filter` parameter** (7 new tools: `pr_view`, `pr_list`, `issue_view`, `issue_list`, `run_view`, `run_list`, `search`) - jq expression applied as post-processing. Syntax is validated before execution.
- **jq syntax validation** on all existing `jq_filter` parameters (`pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`, `job_view`, `job_annotations`, `commit_info`, `api`) - compile errors are caught and reported before the gh command runs.
- **`max_lines` parameter** (`pr_view`, `pr_diff`, `pr_checks`, `pr_comments`, `pr_reviews`, `issue_view`, `api`) - Return only the first N lines of output.
- **`tail_lines` parameter** (`pr_diff`, `run_logs`, `job_logs`, `api`) - Return only the last N lines of output.
- **Grep parameters** (`pr_diff`, `run_logs`, `job_logs`): `grep_pattern` (extended regex filter), `grep_context_before`/`grep_context_after` (context lines), `grep_ignore_case`, `grep_invert`.
- **`_gh_validate_jq_filter()` helper** in `lib/common.sh` - validates jq syntax using `jq -n`; only rejects compile/parse/lexical errors, not runtime errors on null input.
- **`_gh_post_process()` helper** in `lib/common.sh` - applies jq → grep → head → tail pipeline steps in order; each step is a no-op when its parameter is empty/zero.
- **30 new BATS tests** in `plugin-tests/dev-tooling/mcp_tool_gh.bats` covering all new parameters and both helper functions.

### Changed
- `run_logs` and `job_logs`: refactored from piped `head` to `_gh_post_process` for consistent pipeline handling.
- All 19 gh-tooling tools: replaced bare `"${cmd[@]}" 2>&1` with structured execution block that captures exit code before branching on `suppress_errors`/`fallback`.

## [2.4.0] - 2026-02-21

### Added
- **`gh-tooling` MCP server** - GitHub CLI wrapper with 19 tools for repository operations:
  - **PR tools**: `pr_view`, `pr_diff`, `pr_list`, `pr_checks`, `pr_comments`, `pr_reviews`, `pr_files`, `pr_commits`
  - **Issue tools**: `issue_view`, `issue_list`
  - **CI/Actions tools**: `run_view`, `run_list`, `run_logs`, `job_view`, `job_logs`, `job_annotations`
  - **Commit tools**: `commit_info`
  - **Search tools**: `search`
  - **API escape hatch**: `api` for raw GitHub REST API calls
- Optional configuration via `.mcp-gh-tooling.json` (default repo, hook enforcement toggle)
- Array-based command execution for injection-safe argument passing
- `max_lines` parameter on log tools to truncate large CI log output

## [2.3.0] - 2026-02-18

### Added
- **`coverage_driver` parameter for `phpunit_run`** - Controls which coverage driver is activated at runtime
  - `xdebug` - Prepends `XDEBUG_MODE=coverage` to the PHPUnit command (required for Xdebug 3, which has coverage mode off by default)
  - `pcov` - No env var injection; requires pcov extension loaded in php.ini
  - Omit to rely on PHPUnit's own driver detection (backward-compatible default)
- **`phpunit.coverage_driver` config option** - Set a project-wide default driver in `.mcp-php-tooling.json`; overridable per tool call
- `XDEBUG_MODE=coverage` injection works across all environments (native, Docker, Vagrant, DDEV) without changes to the environment wrapper

## [2.2.0] - 2026-01-08

### Added
- **Shopware LSP** integration via `.lsp.json` - service ID completion, Twig templates, snippets, routes, feature flags
- Requires manual `shopware-lsp` binary installation from [GitHub releases](https://github.com/shopwareLabs/shopware-lsp/releases)

## [2.1.0] - 2025-12-19

### Added
- **PreToolUse hooks** to enforce MCP tool usage instead of direct bash commands:
  - `check-php-tools.sh` - Blocks PHPStan, ECS, PHPUnit, bin/console commands
  - `check-js-admin-tools.sh` - Blocks Administration npm/npx commands
  - `check-js-storefront-tools.sh` - Blocks Storefront npm/npx commands
- Shared hook library (`hooks/scripts/lib/common.sh`) with `parse_hook_input()`, `load_mcp_config()`, `block_tool()`
- `enforce_mcp_tools` configuration option (default: true) to disable hook enforcement
- BATS test suite in `plugin-tests/code-quality/dev-tooling/`

## [2.0.0] - 2025-12-18

### Added
- **js-admin-tooling MCP server** - Administration JavaScript tools:
  - `eslint_check`, `eslint_fix` - ESLint linting
  - `stylelint_check`, `stylelint_fix` - SCSS linting
  - `prettier_check`, `prettier_fix` - Code formatting
  - `jest_run` - Unit testing
  - `tsc_check` - TypeScript type checking
  - `lint_all` - Run all lint checks in one command
  - `lint_twig` - ESLint for Twig templates
  - `unit_setup` - Regenerate Jest import resolver
  - `vite_build` - Build with Vite
- **js-storefront-tooling MCP server** - Storefront JavaScript tools:
  - `eslint_check`, `eslint_fix` - ESLint linting
  - `stylelint_check`, `stylelint_fix` - SCSS linting
  - `jest_run` - Unit testing
  - `webpack_build` - Build with Webpack
- Shared configuration via `.mcp-js-tooling.json` for both JS servers

### Changed
- **BREAKING**: Plugin renamed from `php-tooling` to `dev-tooling`

### Migration

1. Uninstall: `/plugin uninstall php-tooling@shopware-ai-coding-tools`
2. Install: `/plugin install dev-tooling@shopware-ai-coding-tools`
3. Restart Claude Code
4. PHP tools work unchanged with existing `.mcp-php-tooling.json`
5. For JS tools: Create `.mcp-js-tooling.json` with environment configuration

## [1.5.0] - 2025-12-17

### Added
- Config discovery in popular LLM coding tool directories:
  - `.aiassistant/` (JetBrains AI Assistant)
  - `.amazonq/` (Amazon Q Developer)
  - `.cline/` (Cline / Claude Dev)
  - `.cursor/` (Cursor AI)
  - `.kiro/` (Kiro - Amazon Q CLI successor)
  - `.windsurf/` (Windsurf / Codeium)
  - `.zed/` (Zed editor)
- Cross-tool configuration sharing via deep-merge support

### Changed
- Improved error messages to list all supported config directories
- Config locations ordered alphabetically for deterministic merge behavior

## [1.4.0] - 2025-12-17

### Added
- `console_run` tool - Execute any Symfony console command with arguments and options
- `console_list` tool - List available console commands with namespace filtering
- Support for Symfony global options: env, verbosity, no_debug, no_interaction
- Flexible options handling: boolean flags, string values, and arrays
- Console configuration section in `.mcp-php-tooling.json`

## [1.3.1] - 2025-12-17

### Fixed
- Added missing `lib/config.sh` library file that was not included in 1.3.0 release

## [1.3.0] - 2025-12-16

### Added
- `MCP_PHP_TOOLING_CONFIG` environment variable for config path override
- Config discovery with deep merging (`.mcp-php-tooling.json` + `.claude/.mcp-php-tooling.json`)
- Extensible `CONFIG_LOCATIONS` array in new `lib/config.sh` module

### Changed
- Consolidated into single plugin (removed separate `php-tooling-mcp-config-location-*` plugins)
- Replaced `--config` argument with environment variable and auto-discovery

### Migration
Uninstall `php-tooling-mcp-config-location-*` plugins, update php-tooling, restart Claude Code.

## [1.2.0] - 2025-12-16

### Changed
- Split MCP server configuration into separate location-based plugins
- Removed `.mcp.json` from main plugin (requires separate config plugin to activate)
- Added `php-tooling-mcp-config-location-root` plugin (config at project root)
- Added `php-tooling-mcp-config-location-dotclaude` plugin (config in `.claude/` directory)

## [1.1.0] - 2025-12-16

### Changed
- **BREAKING**: Renamed configuration file from `.lintrc.local.json` to `.mcp-php-tooling.json`
- Added `--config` argument to override config file path

## [1.0.0] - 2025-12-15

### Added
- PHPStan static analysis tool (`phpstan_analyze`)
- ECS code style checking tool (`ecs_check`)
- ECS code style fixing tool (`ecs_fix`)
- PHPUnit test runner tool (`phpunit_run`)
- Multi-environment support: native, docker, vagrant, ddev
- Auto-detection of development environment from project files
- Configuration via `.lintrc.local.json` file
- Bash-based MCP server implementation (minimal dependencies)
