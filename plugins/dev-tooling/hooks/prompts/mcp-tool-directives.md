ALWAYS use MCP dev tools for PHP and JavaScript operations — NEVER run these via Bash.

MCP tools auto-detect the development environment (native/docker/vagrant/ddev) and apply project configuration.

On the `php-tooling` MCP server: `phpstan_analyze`, `ecs_check`, `ecs_fix`, `phpunit_run`, `phpunit_coverage_gaps`, `console_run`, `console_list`, `rector_fix`, `rector_check`, `worktree_prepare`, `set_project_root`, `cwd`
On the `js-admin-tooling` MCP server: `eslint_check`/`eslint_fix`, `stylelint_check`/`stylelint_fix`, `prettier_check`/`prettier_fix`, `jest_run`, `tsc_check`, `lint_all`, `lint_twig`, `unit_setup`, `vite_build`, `worktree_prepare`, `set_project_root`, `cwd`
On the `js-storefront-tooling` MCP server: `eslint_check`/`eslint_fix`, `stylelint_check`/`stylelint_fix`, `jest_run`, `vitest_run`, `ludtwig_check`/`ludtwig_fix`, `webpack_build`, `worktree_prepare`, `set_project_root`, `cwd`

Every tool except `cwd` on each dev-tooling MCP server takes an optional project_root to target a linked git worktree of the launch root, in every environment; refusals name what to fix and how. After EnterWorktree/ExitWorktree, call `set_project_root` on each dev-tooling MCP server (with the worktree path, or with none to clear) — each is a separate process with its own sticky value; `cwd` on each dev-tooling MCP server reports that server's current state. A fresh worktree lacks vendor/ and node_modules — call `worktree_prepare` on the dev-tooling MCP server that refused instead of provisioning by hand, and NEVER symlink vendor/ from the launch tree (composer's autoloaders resolve through the symlink to the launch tree's classes).

Storefront tests are split across two runners: `jest_run` on the `js-storefront-tooling` MCP server covers the app/storefront package suite, `vitest_run` on the `js-storefront-tooling` MCP server covers the component suite under src/Storefront/Resources/views/components/. `jest_run` on the `js-storefront-tooling` MCP server rejects views/components patterns.

Call tools on the SAME server sequentially — never in parallel. Tools on DIFFERENT servers CAN run in parallel (e.g. `phpunit_run` on the `php-tooling` MCP server + `jest_run` on the `js-storefront-tooling` MCP server).

When a dev-tooling run (PHPStan, ECS, PHPUnit, Rector, ESLint, Stylelint, Prettier, TypeScript, Jest, Vitest, ludtwig, or a Vite/Webpack build) would produce more than a trivial single check — especially during a large implementation task — delegate it to the `dev-tooling-runner` subagent so the verbose output stays out of this conversation. You decide what to check: hand it the explicit paths and any affected tests, plus the kinds of checks to run and any mechanical fixes (e.g. `ecs_fix` on the `php-tooling` MCP server) to apply. It executes and returns a condensed pass/fail report. For a quick single-file check you may still call the MCP tool inline.
