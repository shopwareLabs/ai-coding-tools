ALWAYS use MCP dev tools for PHP and JavaScript operations — NEVER run these via Bash.

MCP tools auto-detect the development environment (native/docker/vagrant/ddev) and apply project configuration.

php-tooling: phpstan_analyze, ecs_check, ecs_fix, phpunit_run, phpunit_coverage_gaps, console_run, console_list, rector_fix, rector_check, set_project_root, cwd
js-admin-tooling: eslint_check/fix, stylelint_check/fix, prettier_check/fix, jest_run, tsc_check, lint_all, lint_twig, unit_setup, vite_build, set_project_root, cwd
js-storefront-tooling: eslint_check/fix, stylelint_check/fix, jest_run, vitest_run, ludtwig_check/fix, webpack_build, set_project_root, cwd

Every tool except cwd takes an optional project_root to target a linked git worktree of the launch root, in every environment. Under docker, docker-compose, vagrant and ddev that worktree has to sit inside the launch project root, which is the only tree the container is given. In every environment its .git file has to carry a relative gitdir pointer — `git worktree add` writes an absolute one unless the repository sets worktree.useRelativePaths, so relink with `git -c worktree.useRelativePaths=true worktree repair <worktree-path>`. After EnterWorktree/ExitWorktree, call set_project_root (with the worktree path, or with none to clear) on all three servers — each is a separate process with its own sticky value. Use cwd to check what a server currently resolves to.

Storefront tests are split across two runners: jest_run covers the app/storefront package suite, vitest_run covers the component suite under src/Storefront/Resources/views/components/. jest_run rejects views/components patterns.

Call tools on the SAME server sequentially — never in parallel. Tools on DIFFERENT servers CAN run in parallel (e.g. phpunit_run + js-storefront jest_run).

When a dev-tooling run (PHPStan, ECS, PHPUnit, Rector, ESLint, Stylelint, Prettier, TypeScript, Jest, Vitest, ludtwig, or a Vite/Webpack build) would produce more than a trivial single check — especially during a large implementation task — delegate it to the `dev-tooling-runner` subagent so the verbose output stays out of this conversation. You decide what to check: hand it the explicit paths and any affected tests, plus the kinds of checks to run and any mechanical fixes (e.g. ecs_fix) to apply. It executes and returns a condensed pass/fail report. For a quick single-file check you may still call the MCP tool inline.
