ALWAYS use MCP dev tools for PHP and JavaScript operations — NEVER run these via Bash.

MCP tools auto-detect the development environment (native/docker/vagrant/ddev) and apply project configuration.

php-tooling: phpstan_analyze, ecs_check, ecs_fix, phpunit_run, phpunit_coverage_gaps, console_run, console_list, rector_fix, rector_check
js-admin-tooling: eslint_check/fix, stylelint_check/fix, prettier_check/fix, jest_run, tsc_check, lint_all, lint_twig, unit_setup, vite_build
js-storefront-tooling: eslint_check/fix, stylelint_check/fix, jest_run, webpack_build

Call tools on the SAME server sequentially — never in parallel. Tools on DIFFERENT servers CAN run in parallel (e.g. phpunit_run + js-storefront jest_run).

When a dev-tooling run (PHPStan, ECS, PHPUnit, Rector, ESLint, Stylelint, Prettier, TypeScript, Jest, or a Vite/Webpack build) would produce more than a trivial single check — especially during a large implementation task — delegate it to the `dev-tooling-runner` subagent so the verbose output stays out of this conversation. You decide what to check: hand it the explicit paths and any affected tests, plus the kinds of checks to run and any mechanical fixes (e.g. ecs_fix) to apply. It executes and returns a condensed pass/fail report. For a quick single-file check you may still call the MCP tool inline.
