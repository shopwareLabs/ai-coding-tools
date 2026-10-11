#!/usr/bin/env bats
# bats file_tags=dev-tooling,js,admin
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

CONFIG_PREFIX="js-tooling"

# bats test_tags=context,blocking
@test "blocks generic commands (defaults to Admin context)" {
    run_hook "check-js-admin-tools.sh" "npm run lint"
    assert_failure 2
    assert_output --partial "eslint_check"
}

# bats test_tags=context,allow
@test "allows Storefront-specific commands" {
    run_hook "check-js-admin-tools.sh" "cd src/Storefront && npm run lint:js"
    assert_success
}

# The block message names the tool and its server; neither host's mcp__ form.
js_admin_hook_blocks() {
    assert_hook_blocks "check-js-admin-tools.sh" "$1" "$2"
    assert_output --partial "on the \`js-admin-tooling\` MCP server"
    refute_output --partial "mcp__"
}

# bats test_tags=cwd
@test "reads the config from the hook input cwd when CLAUDE_PROJECT_DIR is unset" {
    unset CLAUDE_PROJECT_DIR
    local project
    project=$(make_cwd_project "js-tooling" "ddev")
    run_hook_with_cwd "check-js-admin-tools.sh" "npm run lint" "$project"
    assert_failure 2
    assert_output --partial "'ddev' environment"
}

# bats test_tags=cwd
@test "CLAUDE_PROJECT_DIR wins over the hook input cwd when both are set" {
    local project
    project=$(make_cwd_project "js-tooling" "ddev")
    run_hook_with_cwd "check-js-admin-tools.sh" "npm run lint" "$project"
    assert_failure 2
    assert_output --partial "'native' environment"
    refute_output --partial "'ddev' environment"
}

# bats test_tags=blocking
bats_test_function --description "blocks npm run lint:scss → suggests stylelint_check" \
    -- js_admin_hook_blocks "npm run lint:scss" "stylelint_check"
bats_test_function --description "blocks npm run unit → suggests jest_run" \
    -- js_admin_hook_blocks "npm run unit" "jest_run"
bats_test_function --description "blocks npm run build → suggests vite_build" \
    -- js_admin_hook_blocks "npm run build" "vite_build"
bats_test_function --description "blocks npm run format → suggests prettier_check" \
    -- js_admin_hook_blocks "npm run format" "prettier_check"
bats_test_function --description "blocks npm run lint:types → suggests tsc_check" \
    -- js_admin_hook_blocks "npm run lint:types" "tsc_check"
bats_test_function --description "blocks npm run lint:all → suggests lint_all" \
    -- js_admin_hook_blocks "npm run lint:all" "lint_all"
bats_test_function --description "blocks npx eslint → suggests eslint_check" \
    -- js_admin_hook_blocks "npx eslint src/" "eslint_check"
bats_test_function --description "blocks npx jest → suggests jest_run" \
    -- js_admin_hook_blocks "npx jest --watch" "jest_run"

# The target-less base scripts. Only lint:debugging (Admin ESLint) and jest:base
# are still called by the MCP tools; Shopware defines none of the others, and
# the redirects stay for a project that does. None of them matched a pattern
# before: `:` is not in the `(\s|--|$)` tail the shorter names use, so
# `npm run lint` never covered `npm run lint:debugging`.
# bats test_tags=blocking,base-scripts
bats_test_function --description "blocks npm run lint:debugging → suggests eslint_check" \
    -- js_admin_hook_blocks "npm run lint:debugging" "eslint_check"
bats_test_function --description "blocks npm run stylelint:base → suggests stylelint_check" \
    -- js_admin_hook_blocks "npm run stylelint:base" "stylelint_check"
bats_test_function --description "blocks npm run prettier:base → suggests prettier_check" \
    -- js_admin_hook_blocks "npm run prettier:base" "prettier_check"
bats_test_function --description "blocks npm run jest:base → suggests jest_run" \
    -- js_admin_hook_blocks "npm run jest:base" "jest_run"

# A linter binary run through `npx`, `npm exec` or its node_modules/.bin path.
# The MCP servers run the binaries themselves through `npm exec --no --`, so an
# agent that copies that form from a server log reaches the hook with it.
# Each binary is checked in every form: a form missing for one binary fails.
# bats test_tags=blocking,binaries
for _entry in eslint:eslint_check stylelint:stylelint_check prettier:prettier_check; do
    _binary="${_entry%%:*}"
    _tool="${_entry##*:}"
    for _form in "npm exec BIN" "npm exec -- BIN" "npm exec --no -- BIN" \
                 "npx BIN" "npx --no-install BIN" "npx -y BIN" \
                 "npx BIN@9.1.0" "npm exec BIN@9.1.0" \
                 "node_modules/.bin/BIN" "./node_modules/.bin/BIN"; do
        _command="${_form//BIN/${_binary}} src/module"
        bats_test_function --description "blocks ${_command} → suggests ${_tool}" \
            -- js_admin_hook_blocks "${_command}" "${_tool}"
    done
    bats_test_function --description "blocks ${_binary} run through npm exec in the Administration tree → suggests ${_tool}" \
        -- js_admin_hook_blocks \
        "cd src/Administration/Resources/app/administration && npm exec --no -- ${_binary} src/module" "${_tool}"
done
unset _entry _binary _tool _form _command

# jest and tsc take the same forms as the linters, with the tool the npx rows
# above already name.
# bats test_tags=blocking,binaries
for _entry in jest:jest_run tsc:tsc_check; do
    _binary="${_entry%%:*}"
    _tool="${_entry##*:}"
    for _form in "npm exec BIN" "npm exec -- BIN" "npm exec --no -- BIN" \
                 "npx BIN" "npx --no-install BIN" "npx -y BIN" \
                 "npx BIN@9.1.0" "npm exec BIN@9.1.0" \
                 "node_modules/.bin/BIN" "./node_modules/.bin/BIN"; do
        _command="${_form//BIN/${_binary}} src/module"
        bats_test_function --description "blocks ${_command} → suggests ${_tool}" \
            -- js_admin_hook_blocks "${_command}" "${_tool}"
    done
    bats_test_function --description "blocks ${_binary} run through npm exec in the Administration tree → suggests ${_tool}" \
        -- js_admin_hook_blocks \
        "cd src/Administration/Resources/app/administration && npm exec --no -- ${_binary} src/module" "${_tool}"
done
unset _entry _binary _tool _form _command

# The binary forms follow the same context rule as the scripts: a command that
# names the Storefront tree belongs to the Storefront hook.
# bats test_tags=context,allow
admin_hook_allows_storefront_binary() {
    run_hook "check-js-admin-tools.sh" "cd src/Storefront/Resources/app/storefront && npm exec --no -- $1 src"
    assert_success
}
bats_test_function --description "allows npm exec eslint when the command names the Storefront tree" \
    -- admin_hook_allows_storefront_binary eslint
bats_test_function --description "allows npm exec stylelint when the command names the Storefront tree" \
    -- admin_hook_allows_storefront_binary stylelint
bats_test_function --description "allows npm exec prettier when the command names the Storefront tree" \
    -- admin_hook_allows_storefront_binary prettier
bats_test_function --description "allows npm exec jest when the command names the Storefront tree" \
    -- admin_hook_allows_storefront_binary jest
bats_test_function --description "allows npm exec tsc when the command names the Storefront tree" \
    -- admin_hook_allows_storefront_binary tsc

# `npx` and `npm exec` run other packages too, and a binary's name turns up in
# arguments and quoted text. None of these invokes a linter.
# bats test_tags=allow
admin_hook_allows() {
    run_hook "check-js-admin-tools.sh" "$1"
    assert_success
}
bats_test_function --description "allows npm exec vitest, which the Administration server has no tool for" \
    -- admin_hook_allows "npm exec -- vitest src"
bats_test_function --description "allows npm exec running another tool" \
    -- admin_hook_allows "npm exec -- some-other-tool src"
# `--package` takes a value, so the linter name after it is not the command.
bats_test_function --description "allows npm exec --package naming a linter but running another tool" \
    -- admin_hook_allows "npm exec --package eslint some-other-tool"
bats_test_function --description "allows npx running another tool" \
    -- admin_hook_allows "npx --yes some-other-tool src"
bats_test_function --description "allows a linter name after another tool in an npx command" \
    -- admin_hook_allows "npx --yes some-other-tool eslint"
bats_test_function --description "allows npm exec running a package whose name starts with eslint" \
    -- admin_hook_allows "npm exec -- eslint-plugin-foo"
bats_test_function --description "allows installing a linter" \
    -- admin_hook_allows "npm install eslint"
bats_test_function --description "allows reading a linter binary" \
    -- admin_hook_allows "cat node_modules/.bin/eslint"
bats_test_function --description "allows a linter name inside quoted text after a semicolon" \
    -- admin_hook_allows 'git commit -m "tidy; eslint config"'

# bats test_tags=context,allow
@test "allows npm run stylelint:app, a Storefront script name" {
    run_hook "check-js-admin-tools.sh" "npm run stylelint:app"
    assert_success
}

# bats test_tags=context,allow
@test "allows npm run eslint:app, a Storefront script name" {
    run_hook "check-js-admin-tools.sh" "npm run eslint:app"
    assert_success
}

# bats test_tags=context,allow
@test "allows npm run jest:base when the command names the Storefront tree" {
    run_hook "check-js-admin-tools.sh" "cd src/Storefront/Resources/app/storefront && npm run jest:base"
    assert_success
}

# bats test_tags=allow
@test "allows unrelated commands" {
    run_hook "check-js-admin-tools.sh" "npm install"
    assert_success
}

# bats test_tags=config
@test "allows all when enforce_mcp_tools is false" {
    setup_config "js-tooling" '{"environment": "native", "enforce_mcp_tools": false}'
    run_hook "check-js-admin-tools.sh" "npm run lint"
    assert_success
}

# `npm x` is the alias of `npm exec`; the -c / --call form runs a command
# string, and a binary at a command position inside it is blocked.
# bats test_tags=binary,blocking
for spec in "eslint eslint_check" "stylelint stylelint_check" "prettier prettier_check" "jest jest_run" "tsc tsc_check"; do
    read -r bin tool <<<"$spec"
    bats_test_function --description "blocks npm x running ${bin}" \
        -- js_admin_hook_blocks "npm x -- ${bin} src" "$tool"
    bats_test_function --description "blocks npm exec -c running ${bin} after cd" \
        -- js_admin_hook_blocks "npm exec --no -c \"cd ../.. && ${bin} src\"" "$tool"
done
bats_test_function --description "blocks the npm exec -c form the MCP tools run for the components tree" \
    -- js_admin_hook_blocks 'npm exec --no -c "cd ../.. && eslint views/components"' "eslint_check"
bats_test_function --description "blocks npx -c with a single-quoted string running stylelint" \
    -- js_admin_hook_blocks "npx -c 'stylelint src'" "stylelint_check"
bats_test_function --description "blocks npm exec --call running jest" \
    -- js_admin_hook_blocks 'npm exec --call "jest src"' "jest_run"
bats_test_function --description "blocks npm exec -c after --package with its value" \
    -- js_admin_hook_blocks 'npm exec --package foo -c "eslint src"' "eslint_check"
bats_test_function --description "blocks npm exec -c with leading blanks in the string" \
    -- js_admin_hook_blocks 'npm exec -c " eslint src"' "eslint_check"
bats_test_function --description "blocks npm exec -c with a variable assignment before the binary" \
    -- js_admin_hook_blocks 'npm exec -c "NODE_ENV=test jest src"' "jest_run"

# bats test_tags=binary,allow
bats_test_function --description "allows npm exec -c naming a linter as an argument" \
    -- admin_hook_allows 'npm exec -c "echo eslint"'
bats_test_function --description "allows npm x running another tool" \
    -- admin_hook_allows "npm x -- some-other-tool src"
