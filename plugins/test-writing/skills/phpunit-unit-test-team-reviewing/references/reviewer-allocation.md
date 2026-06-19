# Reviewer & Adversary Allocation

## Consensus Invariant

Every file is reviewed by **3 independent reviewers**, and findings are decided by **2-of-3 majority**. This holds regardless of how files are packed into agents. It is the one fixed rule; packing below only changes how the 3-per-file reviews are distributed across agents.

Each wave spawns fresh agents — there is no persistent reviewer identity across waves. Carry a stable `reviewer-{n}` label in prompts and outputs only so a file's three stances can be matched across waves for the merge.

## Reviewer Packing

Let N = number of files. Total reviews = 3N. Distribute them by N:

| N | Packing | Reviewer agents |
|---|---|---|
| 1 | All 3 reviewers on the one file | 3 |
| 2–6 | **Per-file fan-out** — 3 distinct reviewer agents per file, one file each | 3N |
| ≥ 7 | **Bundled** — R = min(15, N) reviewer agents; assign each file to 3 distinct reviewers by round-robin (file `i` → reviewers `[i, i+1, i+2] mod R`); each reviewer carries ≈ `ceil(3N / R)` files | min(15, N) |

Per-file fan-out is the default because each agent then carries one file — maximum context isolation and no assignment arithmetic. Bundle only when N is large enough that per-file fan-out would spawn too many agents for the budget. When budget is ample, prefer raising the fan-out (fewer files per reviewer) over bundling.

Round-robin (the bundled case) gives every file exactly 3 distinct reviewers when R ≥ 3, and chains overlap between adjacent files.

## Adversary Packing

Adversaries stress-test the consensus; they are fewer than reviewers and need not cover every file (the dedicated cross-file consistency agent covers holistic patterns).

| N | Adversaries | Files per adversary |
|---|---|---|
| 1–3 | 1 | all |
| 4–11 | 2 | contiguous partition |
| ≥ 12 | 3 | contiguous partition |

Partition files contiguously: adversary 0 gets the first block, adversary 1 the next, and so on. Every file gets exactly one adversary.

## Targeted Widening (adaptation point 6)

When a file's three reviewers diverge sharply (no majority on most findings, or more contested findings than agreed ones), spawn up to **2 additional reviewers for that file only**, once per file, while the budget floor holds. Re-merge that file with the enlarged reviewer set. This raises confidence on genuinely contested files without inflating the cost of clean ones.
