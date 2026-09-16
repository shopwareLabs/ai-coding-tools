#!/bin/bash
# Claude Code Hook: Worktree Project-Root Directives (PostToolUse)
# ================================================================
# After EnterWorktree or ExitWorktree, reminds the session to repoint the three
# dev-tooling MCP servers. Each server is a separate process holding its own
# sticky project root, so one set_project_root call never reaches the other two.
#
# Exit codes:
#   0 - always; input this hook cannot use leaves the session untouched

set -euo pipefail

INPUT=$(cat)

# One jq process for the whole input. Every subprocess counts against the hook
# timeout, and this hook has no reason to spend more than one.
#
# The separator is the ASCII unit separator rather than a tab: a tab is an IFS
# whitespace character, so bash collapses a run of them into one delimiter and
# drops leading ones — an absent "worktreePath" would then shift "cwd" into its
# variable and the fallback would look like it never fired. \x1f is not IFS
# whitespace, so every empty field survives as an empty field.
#
# tool_response is type-tested before it is indexed: a tool that answers with a
# string rather than an object would otherwise abort the whole filter, and the
# hook would go quiet on exactly the shape change the diagnostic below exists to
# surface.
TOOL_NAME=""
RESPONSE_PATH=""
CWD_PATH=""
IFS=$'\x1f' read -r TOOL_NAME RESPONSE_PATH CWD_PATH < <(
    printf '%s' "$INPUT" | jq -r '[
        (.tool_name // ""),
        (if (.tool_response | type) == "object" then (.tool_response.worktreePath // "") else "" end),
        (.cwd // "")
    ] | join("")' 2>/dev/null
) || true

if [[ -z "$TOOL_NAME" ]]; then
    exit 0
fi

SERVERS="php-tooling, js-admin-tooling and js-storefront-tooling"

case "$TOOL_NAME" in
    EnterWorktree)
        WORKTREE_PATH="$RESPONSE_PATH"
        if [[ -z "$WORKTREE_PATH" ]]; then
            WORKTREE_PATH="$CWD_PATH"
        fi

        if [[ -z "$WORKTREE_PATH" ]]; then
            # Named fields, so a changed response shape reads as this message
            # rather than as a hook that quietly stopped firing.
            MESSAGE="dev-tooling worktree hook: EnterWorktree carried no worktree path — neither \"tool_response.worktreePath\" nor \"cwd\" held one — so this reminder cannot name the directory. The dev-tooling MCP servers ${SERVERS} each still target the root they were launched in; call set_project_root on all three with the worktree path before running any dev-tooling tool."
        else
            MESSAGE="Worktree entered: ${WORKTREE_PATH}. The dev-tooling MCP servers ${SERVERS} each hold their own project root, so call set_project_root with project_root \"${WORKTREE_PATH}\" on all three before running any dev-tooling tool. Three separate processes, three separate sticky values — one call does not cover the others."

            # EnterWorktree shells out to `git worktree add`, which writes an
            # absolute gitdir pointer unless the repository sets
            # worktree.useRelativePaths — and the servers refuse an absolute
            # pointer in every environment. Naming the repair here saves the
            # session the refusal round-trip on its first tool call.
            GITDIR_LINE=""
            if [[ -f "${WORKTREE_PATH}/.git" ]]; then
                IFS= read -r GITDIR_LINE < "${WORKTREE_PATH}/.git" || GITDIR_LINE=""
            fi
            case "$GITDIR_LINE" in
                "gitdir: /"*)
                    MESSAGE="${MESSAGE} This worktree's \".git\" file carries an absolute gitdir pointer, which the dev-tooling servers refuse in every environment; relink it first with \`git -c worktree.useRelativePaths=true worktree repair ${WORKTREE_PATH}\` (needs git 2.48 or newer)."
                    ;;
            esac

            MESSAGE="${MESSAGE} A worktree created by EnterWorktree branches from the repository's default remote branch unless the Claude Code setting worktree.baseRef is \"head\" — confirm the worktree carries the code you mean to test before running tools against it."
        fi
        ;;
    ExitWorktree)
        MESSAGE="Worktree exited. Call set_project_root with no project_root argument on each of the dev-tooling MCP servers ${SERVERS}, so all three return to the root they were launched in. Three separate processes, three separate sticky values — a sticky root left behind names a directory that may no longer exist."
        ;;
    *)
        exit 0
        ;;
esac

CONTEXT=$(printf '%s' "$MESSAGE" | jq -Rs '.')
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ${CONTEXT}
  }
}
EOF

exit 0
