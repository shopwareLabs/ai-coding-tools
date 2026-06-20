# Error Handling

## Input Resolution Failures

| Scenario | Action |
|---|---|
| 0 files resolved | Abort before the review starts. Report strategies tried and why each produced no results. |
| Some files missing `#[CoversClass]` | Exclude those files, continue with the rest. Report excluded files. |
| A surviving file's `#[CoversClass]` source cannot be resolved | Abort before the review starts — the source line count is required for the track decision; never guess it. Report the unresolved file. |
| All files excluded after validation | Abort before the review starts. Report validation failures per file. |

## Run Failures

| Scenario | Action |
|---|---|
| Workflow tool unavailable / cannot start | Inform the user the multi-agent review could not start; offer the single-reviewer skill (`phpunit-unit-test-writing`). |
| Run aborts on the fail-hard guard (empty manifest, missing field) | This is the intended guard. Fix the manifest and run again; never re-run on empty input. |
| Run errors mid-flight | Re-run the review. If the tool can resume an interrupted run, prefer that so completed work is not repeated. |

## Partial-Wave Outcomes

A spawned agent that dies or returns nothing yields no result for that slot; it is dropped and the remaining stances are used.

| Scenario | Action |
|---|---|
| Some reviewers of a file fail | If fewer than 3 stances remain, fall to the consensus edge cases below. |
| All reviewers of a file fail | Exclude that file; report it as unreviewed. |
| An adversary fails | Skip the red team for that adversary's files; use the peer stances there. |
| A defense reconciler fails | Use that reviewer's peer stance; adversary challenges have no effect on it. |
| The cross-file agent fails | Omit the consistency section; note it in the report. |
| An arbiter fails | Leave the finding contested; do not include it in the body. |

## Consensus Edge Cases

| Scenario | Action |
|---|---|
| File has only 2 valid stances | 2-of-2 voting: both agree → include; disagree → contested. Note reduced confidence. |
| File has only 1 valid stance | Include all findings with the annotation "Single reviewer — no consensus possible." |
