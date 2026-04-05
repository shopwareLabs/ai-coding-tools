# Error Handling

## Input Resolution Failures

| Scenario | Action |
|---|---|
| 0 files resolved | Abort. Report strategies tried and why each produced no results. |
| Some files missing `#[CoversClass]` | Exclude those files, continue with rest. Report excluded files. |
| All files excluded after validation | Abort. Report validation failures per file. |

## Wave-Level Recovery

| Scenario | Action |
|---|---|
| Agent fails to return | Wave times out. Log failure, continue with partial results if possible. |
| Agent returns malformed output | Validate output contract. Treat as failed for that agent's files. |
| All agents in a wave fail | Abort. Report failure. TeamDelete. |
| Some agents fail, some succeed | Continue with successful outputs. Note reduced coverage in report. |

## Per-Wave Recovery

| Wave | Failure | Recovery |
|---|---|---|
| Wave 0 (review) | Reviewer fails for some files | Exclude those files from subsequent waves. Report as unreviewed. |
| Wave 0 (review) | Adversary fails to return impressions | Red team runs without pre-formed impressions (adversarial skill runs Phase 1 instead of skipping). |
| Wave 1 (debate) | Reviewer fails to complete | Use that reviewer's Wave 0 findings as their final stance. |
| Wave 1 (debate) | SendMessage between peers fails | Debate skill produces final stance from own analysis only. |
| Wave 2 (red team) | Adversary fails | Skip red team for that adversary's files. Use Wave 1 stances. |
| Wave 3 (defense) | Reviewer fails | Use Wave 1 final stance (adversary challenges have no effect). |

## Consensus Edge Cases

| Scenario | Action |
|---|---|
| File has only 2 valid stances | 2-of-2 voting: both agree = include, disagree = contested. Note reduced confidence. |
| File has only 1 valid stance | Include all findings with annotation: "Single reviewer — no consensus possible." |

## Team Lifecycle Failures

| Scenario | Action |
|---|---|
| `TeamCreate` fails | Inform user Agent Teams may not be available. Stop. |
| `TeamDelete` fails | Log warning, return results anyway. |
| User interrupts | `TeamDelete` on all exit paths. |

On ALL exit paths (success, failure, interruption), ensure `TeamDelete` is called.
