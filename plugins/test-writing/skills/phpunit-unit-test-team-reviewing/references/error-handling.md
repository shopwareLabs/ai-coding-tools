# Error Handling

## Input Resolution Failures

| Scenario | Action |
|---|---|
| 0 files resolved | Abort before launch. Report strategies tried and why each produced no results. |
| Some files missing `#[CoversClass]` | Exclude those files, continue with the rest. Report excluded files. |
| All files excluded after validation | Abort before launch. Report validation failures per file. |

## Workflow Launch & Run Failures

| Scenario | Action |
|---|---|
| Workflow tool unavailable / launch rejected | Inform the user the multi-agent workflow could not start; offer the single-reviewer skill (`phpunit-unit-test-writing`). |
| Script throws on launch (empty manifest, missing field) | This is the intended fail-hard guard. Fix the manifest and re-launch; never relaunch on empty input. |
| Workflow errors mid-run | Edit the returned `scriptPath` and resume from the run id — the unchanged agent prefix replays from cache, only the failed call onward re-runs. |

## Partial-Wave Outcomes

A spawned agent that dies or returns nothing comes back as a null result; the script filters it out.

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
