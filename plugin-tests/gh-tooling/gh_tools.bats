#!/usr/bin/env bats
# bats file_tags=gh-tooling
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

CONFIG_PREFIX="gh-tooling"

gh_hook_blocks() { assert_hook_blocks "check-gh-tools.sh" "$1" "$2"; }

# gh_api_hook_blocks: sets block_api_commands: true before asserting.
# setup() already runs with the default config; this overwrites it.
gh_api_hook_blocks() {
    setup_config "gh-tooling" '{"enforce_mcp_tools": true, "block_api_commands": true}'
    assert_hook_blocks "check-gh-tools.sh" "$1" "$2"
}

# ============================================================================
# PR subcommand blocking (enforce_mcp_tools: true, default)
# ============================================================================

# bats test_tags=blocking,pr
bats_test_function --description "blocks gh pr view → suggests pr_view" \
    -- gh_hook_blocks "gh pr view 14642" "pr_view"
bats_test_function --description "blocks gh pr view with flags → suggests pr_view" \
    -- gh_hook_blocks "gh pr view 14642 --json title,body,state" "pr_view"
bats_test_function --description "blocks gh pr diff → suggests pr_diff" \
    -- gh_hook_blocks "gh pr diff 14642" "pr_diff"
bats_test_function --description "blocks gh pr diff with file filter → suggests pr_diff" \
    -- gh_hook_blocks "gh pr diff 14642 -- src/Core/Migration.php" "pr_diff"
bats_test_function --description "blocks gh pr list → suggests pr_list" \
    -- gh_hook_blocks "gh pr list --author mitelg --state merged" "pr_list"
bats_test_function --description "blocks gh pr checks → suggests pr_checks" \
    -- gh_hook_blocks "gh pr checks 14642" "pr_checks"

# ============================================================================
# Issue subcommand blocking
# ============================================================================

# bats test_tags=blocking,issue
bats_test_function --description "blocks gh issue view → suggests issue_view" \
    -- gh_hook_blocks "gh issue view 8498 --repo shopware/shopware" "issue_view"
bats_test_function --description "blocks gh issue list → suggests issue_list" \
    -- gh_hook_blocks "gh issue list --search 'label:component/core'" "issue_list"

# ============================================================================
# Run/CI subcommand blocking
# ============================================================================

# bats test_tags=blocking,run
bats_test_function --description "blocks gh run view → suggests run_view or run_logs" \
    -- gh_hook_blocks "gh run view 21534190745" "run_view or run_logs"
bats_test_function --description "blocks gh run view --log-failed → suggests run_view or run_logs" \
    -- gh_hook_blocks "gh run view 22245862281 --log-failed" "run_view or run_logs"
bats_test_function --description "blocks gh run list → suggests run_list" \
    -- gh_hook_blocks "gh run list --branch tests/content-system-unit-tests --limit 5" "run_list"

# ============================================================================
# Search subcommand blocking
# ============================================================================

# bats test_tags=blocking,search
bats_test_function --description "blocks gh search code → suggests search_code" \
    -- gh_hook_blocks "gh search code 'addClass' --repo shopware/shopware" "search_code"
bats_test_function --description "blocks gh search repos → suggests search_repos" \
    -- gh_hook_blocks "gh search repos 'ecommerce' --owner shopware" "search_repos"
bats_test_function --description "blocks gh search commits → suggests search_commits" \
    -- gh_hook_blocks "gh search commits 'NEXT-1234' --repo shopware/shopware" "search_commits"
bats_test_function --description "blocks gh search prs → suggests search" \
    -- gh_hook_blocks "gh search prs 'NEXT-3412' --repo shopware/shopware" "search"
bats_test_function --description "blocks gh search issues → suggests search" \
    -- gh_hook_blocks "gh search issues 'attribute entity' --repo shopware/shopware" "search"

# ============================================================================
# Compound command blocking
# ============================================================================

# bats test_tags=blocking,compound
bats_test_function --description "blocks gh pr view in && chain → suggests pr_view" \
    -- gh_hook_blocks "git fetch && gh pr view 14642" "pr_view"
bats_test_function --description "blocks gh run view in ; chain → suggests run_view or run_logs" \
    -- gh_hook_blocks "echo 'checking CI'; gh run view 21534190745" "run_view or run_logs"

# ============================================================================
# Allowed gh subcommands (no dedicated MCP tool → not blocked)
# ============================================================================

# bats test_tags=allow
@test "allows gh api (not blocked by enforce_mcp_tools)" {
    run_hook "check-gh-tools.sh" "gh api repos/shopware/shopware/pulls/14642/comments"
    assert_success
}

@test "allows gh auth login" {
    run_hook "check-gh-tools.sh" "gh auth login"
    assert_success
}

@test "allows gh run download" {
    run_hook "check-gh-tools.sh" "gh run download 21652562196 --repo shopware/shopware --name bc-check-output"
    assert_success
}

@test "allows unrelated commands" {
    run_hook "check-gh-tools.sh" "git status"
    assert_success
}

# ============================================================================
# enforce_mcp_tools: false — disables all blocking
# ============================================================================

# bats test_tags=config
@test "allows gh pr view when enforce_mcp_tools is false" {
    setup_config "gh-tooling" '{"enforce_mcp_tools": false}'
    run_hook "check-gh-tools.sh" "gh pr view 14642"
    assert_success
}

@test "allows gh run view when enforce_mcp_tools is false" {
    setup_config "gh-tooling" '{"enforce_mcp_tools": false}'
    run_hook "check-gh-tools.sh" "gh run view 21534190745 --log-failed"
    assert_success
}

@test "allows gh api with block_api_commands when enforce_mcp_tools is false" {
    setup_config "gh-tooling" '{"enforce_mcp_tools": false, "block_api_commands": true}'
    run_hook "check-gh-tools.sh" "gh api repos/shopware/shopware/pulls/14642/comments"
    assert_success
}

# ============================================================================
# block_api_commands: true — blocks gh api endpoints with dedicated MCP tools
# ============================================================================

# bats test_tags=blocking,api
bats_test_function \
    --description "blocks gh api .../pulls/N/comments → suggests pr_comments" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/pulls/14642/comments --paginate" \
    "pr_comments"

bats_test_function \
    --description "blocks gh api .../pulls/N/reviews → suggests pr_reviews" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/pulls/14642/reviews" \
    "pr_reviews"

bats_test_function \
    --description "blocks gh api .../pulls/N/files → suggests pr_files" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/pulls/13911/files" \
    "pr_files"

bats_test_function \
    --description "blocks gh api .../pulls/N/commits → suggests pr_commits" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/pulls/14642/commits" \
    "pr_commits"

bats_test_function \
    --description "blocks gh api .../actions/jobs/N/logs → suggests job_logs" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/actions/jobs/62056364818/logs" \
    "job_logs"

bats_test_function \
    --description "blocks gh api .../actions/jobs/N → suggests job_view" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/actions/jobs/62056364818" \
    "job_view"

bats_test_function \
    --description "blocks gh api .../check-runs/N/annotations → suggests job_annotations" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/check-runs/62056364818/annotations" \
    "job_annotations"

bats_test_function \
    --description "blocks gh api .../commits/SHA/pulls → suggests commit_pulls" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/commits/15a7c2bb86/pulls" \
    "commit_pulls"

bats_test_function \
    --description "blocks gh api .../git/trees/... → suggests repo_tree" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/git/trees/main?recursive=1" \
    "repo_tree"

bats_test_function \
    --description "blocks gh api .../contents/... → suggests repo_tree or repo_file" \
    -- gh_api_hook_blocks \
    "gh api repos/shopware/shopware/contents/src/Core" \
    "repo_tree or repo_file"

# ============================================================================
# block_api_commands: true — gh api endpoints without a dedicated MCP tool
# are NOT blocked (covered only by the api escape-hatch tool)
# ============================================================================

# bats test_tags=allow,api
@test "allows gh api .../actions/runs/.../jobs with block_api_commands (no dedicated tool)" {
    setup_config "gh-tooling" '{"enforce_mcp_tools": true, "block_api_commands": true}'
    run_hook "check-gh-tools.sh" "gh api repos/shopware/shopware/actions/runs/21534190745/jobs"
    assert_success
}

@test "allows gh api search/issues with block_api_commands (no dedicated tool)" {
    setup_config "gh-tooling" '{"enforce_mcp_tools": true, "block_api_commands": true}'
    run_hook "check-gh-tools.sh" "gh api search/issues -X GET -f q=repo:shopware/shopware"
    assert_success
}

@test "allows gh api .../issues/N/timeline with block_api_commands (no dedicated tool)" {
    setup_config "gh-tooling" '{"enforce_mcp_tools": true, "block_api_commands": true}'
    run_hook "check-gh-tools.sh" "gh api repos/shopware/shopware/issues/8498/timeline"
    assert_success
}

# ============================================================================
# block_api_commands: false (default) — gh api calls pass through regardless
# ============================================================================

# bats test_tags=config,api
@test "allows gh api .../pulls/N/comments when block_api_commands is false (default)" {
    run_hook "check-gh-tools.sh" "gh api repos/shopware/shopware/pulls/14642/comments --paginate"
    assert_success
}

@test "allows gh api .../actions/jobs/N/logs when block_api_commands is false (default)" {
    run_hook "check-gh-tools.sh" "gh api repos/shopware/shopware/actions/jobs/62056364818/logs"
    assert_success
}

@test "allows gh api .../commits/SHA when block_api_commands is false (default)" {
    run_hook "check-gh-tools.sh" "gh api repos/shopware/shopware/commits/15a7c2bb86"
    assert_success
}

@test "allows gh api .../commits/SHA with block_api_commands (no dedicated MCP tool; use git show instead)" {
    setup_config "gh-tooling" '{"enforce_mcp_tools": true, "block_api_commands": true}'
    run_hook "check-gh-tools.sh" "gh api repos/shopware/shopware/commits/15a7c2bb86"
    assert_success
}
