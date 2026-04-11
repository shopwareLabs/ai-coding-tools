#!/usr/bin/env bash
# Assignee tools for gh-tooling MCP server
# Write: assignee_add, assignee_remove

tool_assignee_add() { _gh_edit_list_param "$1" "assignees" "--add-assignee"; }
tool_assignee_remove() { _gh_edit_list_param "$1" "assignees" "--remove-assignee"; }
