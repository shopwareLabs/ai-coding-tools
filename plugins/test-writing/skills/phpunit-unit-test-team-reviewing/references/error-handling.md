# Error Handling

## Input Resolution Failures

These abort **before** the run starts — the fail-hard guard, distinct from the mid-run recovery below.

| Scenario | Action |
|---|---|
| 0 files resolved | Abort before the review starts. Report strategies tried and why each produced no results. |
| Some files missing `#[CoversClass]` | Exclude those files, continue with the rest. Report excluded files. |
| A surviving file's `#[CoversClass]` source cannot be resolved | Abort before the review starts — the source line count is required for the track decision; never guess it. Report the unresolved file. |
| All files excluded after validation | Abort before the review starts. Report validation failures per file. |

## Mid-Run Agent Death — Recovery

A single agent dying mid-run (a "Prompt is too long" overflow or a transient `529 Overloaded`) is **not** a run failure and **never** triggers a whole-fleet re-run. Re-spawn the dead unit/agent up to `RESPAWN_MAX`; only when that is exhausted does the role's graceful degradation apply, and any lost adversary coverage is flagged — never hidden.

```dot
digraph mid_run_recovery {
  "Agent dies mid-run (overflow or 529)" [shape=doublecircle];
  "Re-run the whole fleet" [shape=octagon, style=filled, fillcolor=red, fontcolor=white];
  "Re-spawns for this unit < RESPAWN_MAX ?" [shape=diamond];
  "Re-spawn the dead unit/agent only, same scoped inputs" [shape=box];
  "Re-spawn returned a valid result ?" [shape=diamond];
  "Use the recovered result" [shape=box];
  "Cap reached: degrade by role" [shape=box];
  "Role of the dead agent ?" [shape=diamond];
  "Reviewer: fall to 2-of-2; exclude file if all reviewers dead" [shape=box];
  "All K adversaries of a file dead: mark it un-red-teamed" [shape=box];
  "Reconciler: keep the prior (Wave-0/peer) stance" [shape=box];
  "Cross-file: omit consistency; Arbiter: leave finding contested" [shape=box];
  "Raise the red_team coverage-gap flag for those files" [shape=box];
  "Render with honest run-integrity reporting" [shape=doublecircle];

  "Agent dies mid-run (overflow or 529)" -> "Re-run the whole fleet" [label="never", style=dashed];
  "Agent dies mid-run (overflow or 529)" -> "Re-spawns for this unit < RESPAWN_MAX ?";
  "Re-spawns for this unit < RESPAWN_MAX ?" -> "Re-spawn the dead unit/agent only, same scoped inputs" [label="yes"];
  "Re-spawn the dead unit/agent only, same scoped inputs" -> "Re-spawn returned a valid result ?";
  "Re-spawn returned a valid result ?" -> "Use the recovered result" [label="yes"];
  "Re-spawn returned a valid result ?" -> "Re-spawns for this unit < RESPAWN_MAX ?" [label="no: count++"];
  "Re-spawns for this unit < RESPAWN_MAX ?" -> "Cap reached: degrade by role" [label="no"];
  "Cap reached: degrade by role" -> "Role of the dead agent ?";
  "Role of the dead agent ?" -> "Reviewer: fall to 2-of-2; exclude file if all reviewers dead";
  "Role of the dead agent ?" -> "All K adversaries of a file dead: mark it un-red-teamed";
  "Role of the dead agent ?" -> "Reconciler: keep the prior (Wave-0/peer) stance";
  "Role of the dead agent ?" -> "Cross-file: omit consistency; Arbiter: leave finding contested";
  "All K adversaries of a file dead: mark it un-red-teamed" -> "Raise the red_team coverage-gap flag for those files";
  "Use the recovered result" -> "Render with honest run-integrity reporting";
  "Reviewer: fall to 2-of-2; exclude file if all reviewers dead" -> "Render with honest run-integrity reporting";
  "Reconciler: keep the prior (Wave-0/peer) stance" -> "Render with honest run-integrity reporting";
  "Cross-file: omit consistency; Arbiter: leave finding contested" -> "Render with honest run-integrity reporting";
  "Raise the red_team coverage-gap flag for those files" -> "Render with honest run-integrity reporting";
}
```

### Re-spawn (first recourse)

When an agent dies, re-spawn **only that unit/agent** — never the rest of the fleet. Cap at `RESPAWN_MAX` attempts per unit. Use a valid re-spawn result as the original.

**Size-aware re-spawn (adversaries).** `agent()` returns `null` on a terminal death without exposing the error class, so the script cannot branch on "prompt is too long" specifically. Instead, a red-team adversary's **final** re-spawn carries a **degraded payload** — the compact rule index (rule ID + title, no bodies) and an instruction to read only the cited finding locations — while earlier retries stay faithful. A faithful retry recovers a transient stall; the degraded final attempt catches a deterministic overflow, which re-sending the identical prompt cannot. This converts a residual overflow into a *degraded-but-present* adversary rather than a lost one. Reviewers/reconcilers keep their scoped inputs unchanged across retries (per-unit scope already bounds their size).

### Degrade by role (after re-spawn is exhausted)

Only after a unit burns `RESPAWN_MAX` does its role's graceful degradation apply: every loss is either covered (reviewer 2-of-2) or **loudly flagged** (adversary coverage gap).

| Dead role (after re-spawn) | Action |
|---|---|
| Some reviewers of a file | Fewer than 3 stances remain → use the Consensus Edge Cases below (2-of-2, reduced confidence). |
| All reviewers of a file | Exclude that file; report it as unreviewed. |
| One lens adversary of a file | No action — the file is still covered by its other lens adversaries (a file needs ≥ 1 of its K adversaries to survive). |
| **All K** lens adversaries of a file | Mark that file **un-red-teamed** and raise the `red_team` coverage-gap flag for it — never substitute peer stances as if adversarial coverage were complete. |
| A defense reconciler | Keep that reviewer's peer stance; the adversary challenges have no effect on it. |
| The cross-file agent | Omit the consistency section; note it in the report. |
| A single arbiter (should-fix / consider) | Leave the finding contested; do not include it in the body. |
| All 3 arbiters of a contested must-fix | Leave the finding contested (still shown in the contested section). A *partial* vote with no majority keeps it in the body marked `split` — never silently dropped. |

### Adversary-coverage gate

Track which in-scope files were actually red-teamed. A file is covered if **≥ 1** of its K lens adversaries returned. After all re-spawns settle, if **all K** of a file's adversaries failed, the result's `red_team` must carry a prominent **coverage-gap flag** naming that file — never paper over it with peer stances.

## Run Failures

| Scenario | Action |
|---|---|
| Workflow tool unavailable / cannot start | Inform the user the multi-agent review could not start; offer the single-reviewer skill (`phpunit-unit-test-writing`). |
| Run aborts on the fail-hard guard (empty manifest, missing field) | This is the intended guard. Fix the manifest and run again; never re-run on empty input. |
| A single agent errors mid-flight | Not a run failure — see Mid-Run Agent Death (re-spawn that unit, never the whole fleet). |
| The whole run aborts mid-flight | Prefer resuming the interrupted run so completed work and the re-spawn budget are not discarded; re-run from scratch only when resume is unavailable. |

## Consensus Edge Cases

| Scenario | Action |
|---|---|
| File has only 2 valid stances | 2-of-2 voting: both agree → include; disagree → contested. Note reduced confidence. |
| File has only 1 valid stance | Include all findings with the annotation "Single reviewer — no consensus possible." |
