# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.5] - 2026-08-27

### Fixed
- **Tool arguments reached the shell without quoting or validation.** `tool_plugin_setup` checked only that `plugin_name` was non-empty — the PascalCase pattern its sibling `tool_plugin_create` applies was inside that function alone — and `plugin_namespace` was never checked at all, while `resolve_lifecycle_env` exported `docker_service` and `compose_file` straight into `DOCKER_CONTAINER` / `COMPOSE_SERVICE` / `COMPOSE_FILE`. Every one of these values is embedded into a command string that `exec_command` runs through `eval`. `tool_plugin_setup` now applies the same PascalCase pattern and message as `tool_plugin_create`, `plugin_namespace` and both compose values pass `assert_no_shell_hostile_chars`, and every value embedded in a command goes through `shell_quote_arg` in place of hand-written single-quote wrapping. Note that the guard refuses only what quoting cannot express — a single quote or a line break — so the quoting is what makes the rest safe.
- **A failed step reported success.** `tool_install_dependencies` appended each `exec_command` result to its output without checking any status and printed the accumulated text last, so a failed composer or npm install returned 0 with the error text embedded in what read as a normal result; later steps ran regardless. `tool_plugin_create`'s three steps and `tool_plugin_setup`'s two behaved the same way, so a failed `plugin:create` still reached `plugin:refresh` and `plugin:install`. Each function now checks every step, stops at the first failure, and returns non-zero with the output collected so far and the failing command named. This matters here more than elsewhere because `mcpserver_core.sh` dispatches tool functions on the left of `||`, which disables errexit for the entire body — nothing was going to catch these implicitly.
- Synced `shared/mcpserver_core.sh` with `templates/mcp-shared/mcpserver_core.sh`, whose `validate_tool_arguments` previously returned success for any `arguments` value that was not a JSON object: the jq pipeline ended in `|| true`, so `$args | keys` failing on a string, array, or null was masked and `required`, `additionalProperties`, and `enum` were all skipped. For this plugin that bypass reached `database_reset`, whose run leads to `system:install --drop-database`. Non-object arguments are now rejected by name and type.
- Synced `shared/mcpserver_core.sh` again: `handle_tools_call` derived the arguments object with `jq -c '.arguments // {}'`, and `//` treats a present `null` and a present `false` as absent, so neither reached the non-object rejection added earlier in this release. It now uses `has("arguments")`. `process_request` already gates the whole request through `jq -e '.'` on the MCP path, so this is defense in depth for direct invocation.
- Synced `shared/environment.sh` and `shared/docker-compose.sh`, whose four `docker exec -i` sites interpolated the container name unquoted into the string handed to `eval`. Combined with the unvalidated `docker_service` above, a configured service name carrying a command separator ran as a second command; the name now passes through `shell_quote_arg` at construction.
- Synced `shared/environment.sh` again for two further defects in it. `parse_paths_json` split a `paths` element on any line break it contained, so one element carrying a newline became two paths and the guard, running after the split, saw two clean fragments; it now refuses such an element before splitting. And `assert_no_shell_hostile_chars` now refuses shell metacharacters when the environment is `ddev`, because the ddev wrapper emits bare argv and the value is parsed once locally and again inside the container, which no fixed escaping depth survives. No `lifecycle-tooling` tool passes a `paths` array, but the ddev refusal applies to this plugin's tool arguments and is a behavior change for ddev users.
- Synced `shared/docker-compose.sh`, which built `-f ${file_path}` unquoted into the string handed to `eval`, so a compose file path or project root containing a space split into two arguments.

## [1.2.4] - 2026-08-27

### Fixed
- Synced `shared/environment.sh` with `templates/mcp-shared/environment.sh`, whose `exec_command` and `exec_npm_command` now redirect the wrapped command's stdin to `/dev/null`. Previously the child inherited the server's stdin — the JSON-RPC pipe from the MCP client, forwarded into containers via `docker exec -i` — so a `lifecycle-tooling` command that read stdin (an interactive composer or console prompt, for example) blocked forever on the never-delivering pipe and hung the tool call. Such prompts now see immediate EOF and fall back to their defaults.

## [1.2.3] - 2026-08-21

### Fixed
- Synced `shared/mcpserver_core.sh` with `templates/mcp-shared/mcpserver_core.sh`, whose `validate_tool_arguments` now rejects a tool-call argument that falls outside a parameter's declared `enum`. Previously only `required` and unknown properties were checked, so an out-of-enum value was dispatched to the tool and failed downstream, or ran with a value the schema never sanctioned. This changes behavior for every `lifecycle-tooling` tool: the `environment` parameter on all eight declares an enum of `native`, `docker`, `docker-compose`, `vagrant`, `ddev`, and a value outside that set is now refused by name before the tool runs.

## [1.2.2] - 2026-08-21

### Changed
- Synced `shared/environment.sh` with `templates/mcp-shared/environment.sh`, which gained four helpers in the `dev-tooling` 3.16.0 release: `npm_script_body` and `npm_script_append_safe` (read an npm script body and decide whether appending arguments to it is safe), `shell_quote_arg` together with `assert_no_shell_hostile_chars` (escape a caller-supplied value for one shell parse, and refuse values carrying a single quote, newline, or carriage return), and the path guards behind `assert_paths_exist`. `parse_paths_json` additionally now refuses a non-array `paths` value and an array holding an empty or non-string entry, rather than treating either as "no paths supplied". No `lifecycle-tooling` tool calls the new helpers and none passes a `paths` array, so this plugin's behavior is unchanged; the bump exists because `.claude/rules/template-sync.md` requires the copy to stay byte-identical to the template.

## [1.2.1] - 2026-07-13

### Changed
- The `dev-environment-bootstrapping` Phase 5 handoff message and README §Integration now point users to `github-mcp@github-agent-tools` for GitHub tooling instead of the retired `gh-tooling@shopware-ai-coding-tools` — the GitHub tooling moved to the standalone `github-agent-tools` marketplace.

## [1.2.0] - 2026-06-25

### Added
- Tool-call arguments are now validated against the called tool's declared `inputSchema` before dispatch. Every field listed in `required` must be present, and when the schema sets `additionalProperties: false` any field outside `properties` is rejected — the call returns an `isError` result naming the missing or unknown parameters instead of running the tool. Applies to the `lifecycle-tooling` server; tools without a schema are left unvalidated. Added as `validate_tool_arguments` in the shared `mcpserver_core.sh` (kept byte-identical to the `templates/mcp-shared/` source).

## [1.1.1] - 2026-05-13

### Changed
- `dev-environment-bootstrapping` description rewritten to follow https://agentskills.io/skill-creation/optimizing-descriptions: leads with imperative "Use this skill when..." and lists explicit trigger phrases drawn from the README ("set up a Shopware dev environment", "clone and install Shopware", "bootstrap Shopware and a new plugin called X", etc.). No behavior change.

## [1.1.0] - 2026-04-21

### Added
- `install_dependencies` MCP tool now accepts an `update` boolean (default `false`). When `true`, runs `composer update` instead of `composer install`, and passes `install` instead of `clean-install` to the npm:admin / npm:storefront composer scripts. Use after bumping versions in `composer.json` or `package.json` to regenerate lockfiles. Applies to whichever of `composer`, `administration`, `storefront` are enabled.

### Changed
- `install_dependencies` no longer auto-detects install-vs-update from `composer.lock` presence. The default is always `composer install` / npm `clean-install`; updates are opt-in via the new `update` flag. `composer install` on a fresh clone (no lockfile) emits a warning and proceeds to generate one, matching Shopware's own CI setup.

## [1.0.1] - 2026-04-19

### Changed
- Internal shellcheck cleanup. No behavior change. In `shared/mcpserver_core.sh`, the `log()` function now splits `local line` from its assignment so the `local` builtin no longer masks `date`'s exit status (SC2155). In `shared/environment.sh`, obsolete inline shellcheck directives (SC2154 / SC2034) were removed now that the repo-level `.shellcheckrc` covers them.

## [1.0.0] - 2026-04-18

### Added
- MCP server `lifecycle-tooling` with 8 tools: `install_dependencies`, `database_install`, `database_reset`, `testdb_prepare`, `frontend_build_admin`, `frontend_build_storefront`, `plugin_create`, `plugin_setup`
- `dev-environment-bootstrapping` skill for first-run setup orchestration
- SessionStart hook with lifecycle tool directives
- PreToolUse hook enforcing MCP tools over bash equivalents
- Reads dev-tooling's `.mcp-php-tooling.json` as optional config fallback
