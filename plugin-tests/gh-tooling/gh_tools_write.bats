#!/usr/bin/env bats
# bats file_tags=gh-tooling,blocking,write
bats_require_minimum_version 1.11.0

load 'test_helper/common_setup'

CONFIG_PREFIX="gh-tooling"

gh_hook_blocks() { assert_hook_blocks "check-gh-tools.sh" "$1" "$2"; }

# PR write commands
bats_test_function --description "blocks gh pr create → suggests pr_create" \
    -- gh_hook_blocks "gh pr create --title 'test'" "pr_create"
bats_test_function --description "blocks gh pr edit → suggests pr_edit" \
    -- gh_hook_blocks "gh pr edit 100 --title 'new'" "pr_edit"
bats_test_function --description "blocks gh pr ready → suggests pr_ready" \
    -- gh_hook_blocks "gh pr ready 100" "pr_ready"
bats_test_function --description "blocks gh pr merge → suggests pr_merge" \
    -- gh_hook_blocks "gh pr merge 100 --squash" "pr_merge"
bats_test_function --description "blocks gh pr close → suggests pr_close" \
    -- gh_hook_blocks "gh pr close 100" "pr_close"
bats_test_function --description "blocks gh pr reopen → suggests pr_reopen" \
    -- gh_hook_blocks "gh pr reopen 100" "pr_reopen"
bats_test_function --description "blocks gh pr review → suggests pr_review_submit" \
    -- gh_hook_blocks "gh pr review 100 --approve" "pr_review_submit"
bats_test_function --description "blocks gh pr comment → suggests pr_comment" \
    -- gh_hook_blocks "gh pr comment 100 --body 'lgtm'" "pr_comment"

# Issue write commands
bats_test_function --description "blocks gh issue create → suggests issue_create" \
    -- gh_hook_blocks "gh issue create --title 'bug'" "issue_create"
bats_test_function --description "blocks gh issue edit → suggests issue_edit" \
    -- gh_hook_blocks "gh issue edit 50 --title 'updated'" "issue_edit"
bats_test_function --description "blocks gh issue close → suggests issue_close" \
    -- gh_hook_blocks "gh issue close 50" "issue_close"
bats_test_function --description "blocks gh issue reopen → suggests issue_reopen" \
    -- gh_hook_blocks "gh issue reopen 50" "issue_reopen"
bats_test_function --description "blocks gh issue comment → suggests issue_comment" \
    -- gh_hook_blocks "gh issue comment 50 --body 'fixed'" "issue_comment"

# Label commands
bats_test_function --description "blocks gh label list → suggests label_list" \
    -- gh_hook_blocks "gh label list --repo shopware/shopware" "label_list"

# Project commands
bats_test_function --description "blocks gh project list → suggests project_list" \
    -- gh_hook_blocks "gh project list --owner shopware" "project_list"
bats_test_function --description "blocks gh project view → suggests project_view" \
    -- gh_hook_blocks "gh project view 1 --owner shopware" "project_view"
bats_test_function --description "blocks gh project item-add → suggests project_item_add" \
    -- gh_hook_blocks "gh project item-add 1 --owner shopware --url https://github.com/shopware/shopware/issues/1" "project_item_add"
bats_test_function --description "blocks gh project item-edit → suggests project_status_set" \
    -- gh_hook_blocks "gh project item-edit --id PVTI_123" "project_status_set"
