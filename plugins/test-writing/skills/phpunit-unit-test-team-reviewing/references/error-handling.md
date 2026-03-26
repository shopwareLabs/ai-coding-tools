# Error Handling

## Input Resolution Failures

| Scenario | Action |
|---|---|
| 0 files resolved | Abort. Report strategies tried and why each produced no results. |
| Some files missing `#[CoversClass]` | Exclude those files, continue with rest. Report excluded files. |
| All files excluded after validation | Abort. Report validation failures per file. |

## Reviewer Failures

| Scenario | Action |
|---|---|
| Reviewer fails to produce findings | Reminder, then abort on second failure. Shut down all reviewers, `TeamDelete`. |
| Findings for only some assigned files | Targeted reminder: "Missing findings for {paths}." On second failure, treat missing files as unreviewed — proceed with rest, note in report. |
| Reviewer hits context limits | Treat as partial failure above. |

## Debate Failures

| Scenario | Action |
|---|---|
| Doesn't engage with all peer findings | Send specific reminder referencing the missed file and findings. |
| Adds new findings during debate | Ignore. Notify: "Protocol rule 4: no new findings during debate." |
| Doesn't submit final stance | Use debate-round position as final stance. |
| Cross-file reference cites unassigned file | Ignore the reference. Reviewers can only cite files they reviewed. |

## Consensus Edge Cases

| Scenario | Action |
|---|---|
| File has only 2 valid final stances | 2-of-2 voting: both agree = include, disagree = contested. Note reduced confidence. |
| File has only 1 valid final stance | Include all findings with annotation: "Single reviewer — no consensus possible." |

## Team Lifecycle Failures

| Scenario | Action |
|---|---|
| `TeamCreate` fails | Inform user Agent Teams may not be available. Stop. |
| `TeamDelete` fails | Log warning, return results anyway. |
| User interrupts | Send shutdown to all reviewers, then `TeamDelete`. |

On ALL exit paths (success, failure, interruption), ensure `TeamDelete` is called.
