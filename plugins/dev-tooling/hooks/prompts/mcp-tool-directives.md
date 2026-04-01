ALWAYS use MCP dev tools for PHP and JavaScript operations — NEVER run these via Bash.

MCP tools auto-detect the development environment (native/docker/vagrant/ddev) and apply project configuration.

php-tooling: phpstan_analyze, ecs_check, ecs_fix, phpunit_run, phpunit_coverage_gaps, console_run, console_list
js-admin-tooling: eslint_check/fix, stylelint_check/fix, prettier_check/fix, jest_run, tsc_check, lint_all, lint_twig, unit_setup, vite_build
js-storefront-tooling: eslint_check/fix, stylelint_check/fix, jest_run, webpack_build

Call tools on the SAME server sequentially — never in parallel. Tools on DIFFERENT servers CAN run in parallel (e.g. phpunit_run + js-storefront jest_run).
