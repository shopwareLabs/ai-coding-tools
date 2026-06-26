# Workflow Design — Adaptation Guide

`workflow/team-review.workflow.mjs` is the shipped review workflow: a waved fan-out of fresh agents coordinated through a blackboard, no agent-to-agent messaging — independent review → peer reconciliation → conditional red team → conditional defense → cross-file consistency (with the cross-cutting SUT-coverage map) → verdicts (with integration-to-unit placement flags), with 2-of-3 consensus per unit. It reviews unit, integration, and migration tests over one mixed manifest, routing each file by `test_type`. Launch it with the run manifest as `args`; it self-adapts at runtime on the signals below.

You already know how Claude Code workflows are built. This reference does **not** restate the script step by step — it covers only the inputs the workflow expects and its adaptation surface.

## Pre-Run Collect

The inputs you supply, built before launch and carried in the run manifest. The per-file `fingerprint` and `digest` are produced by the ephemeral pre-run extraction subagents (Phase 1) — one per file, their context discarded once they return the compact entry. This does not defeat the digest: its purpose is downstream, keeping method bodies out of the **reviewer** agents, whose `L > C` track consumes the body-free digest instead of the file.

- **Cross-file fingerprint** — a fixed-size structural signature per file: `setUp` shape, mock strategy (createMock/createStub), assertion style, data-provider style, attribute order. Compute for **every** file. The cross-file agent consumes it.
- **Structural digest** — for each file whose combined lines exceed `C`: class declaration, `#[CoversClass]`, member order, method signatures, attribute lines, property declarations. **No method bodies.** The `L > C` digest-track reviewers consume it.
- **Per-type rule catalogs** — for each test type present, call `build_rule_package` (unit → no arguments; integration → `group=integration, test_type=integration`; migration → `group=migration, test_type=migration`), keep each returned path, and splice it into the run manifest by path (`jq --rawfile`) as `rule_packages.{type}` — never load the catalog into context. When any integration file is present, also build `group=placement, test_type=integration` → `rule_packages.placement` (reference for the placement-flag signal). The workflow selects each agent's scoped `## RULES` block from the file's per-type catalog; do not build per-track packages. Abort if a needed build fails or renders zero rules.

## What you can adapt, and for what purpose

Frozen seed constants in the script. Change a seed in the script to retune the workflow; a launch never changes them per run. `T`/`C` are **test+source combined** line counts.

| Lever | Seed | Adjust to … |
|---|---|---|
| `T` | 450 | raise to keep more files whole (Track A, fewer agents); lower to decompose sooner under context pressure. Lines above which a file decomposes. |
| `C` | 800 | shift where the whole-class track drops to a body-free structural digest. |
| `M` | 8 | set method-shard granularity (max test methods per shard). |
| `U_file` | 18 | cap reviewer agents per single file (all tracks + widening). |
| `K_adv` | 3 | adversaries per file = the lens count (`LENSES`). Each file gets K independent adversaries, one per lens, each reading exactly one file. Retune by changing the lens set, not the number alone. |
| `G` | 300 | cap reviewers per chunk before sequential auto-partition. |
| `F_cap` | 40 | files the cross-file agent ingests before sharding by pattern dimension. |
| `RESPAWN_MAX` | 2 | re-spawn attempts for a dead unit/agent before degrade-and-flag (adversary retries degrade their payload). |
| `BUDGET_FLOOR` | 60000 | token floor checked before each conditional wave / adaptation. |
| Model tiers | sonnet / opus | sonnet for reviewers, reconcilers, the cross-file agent, and the single arbiter; **opus** for adversaries (impressions + red team) and the 3 arbiters on a contested must-fix. |

Arbitration is **uncapped** (cost is not a constraint here): every contested finding is arbitrated, sorted must-fix-first, so position can never drop a must-fix.

The workflow also self-adapts at runtime: it skips the red team on zero findings or a peer concession rate ≥ 0.5; runs at most one extra peer-reconciliation pass on units still contested after Wave 1 (max 2 passes total); routes adversary resurrections into defense; arbitrates **every** contested finding (a contested must-fix gets 3 opus arbiters by majority — confirmed ≥ 2, refuted ≥ 2, else kept as `split`; should-fix/consider keep a single arbiter); and widens a sharply-divided unit by +2 reviewers once. These fire only on their signals — a clean review triggers none.

## Already handled — do not re-adapt

These failure modes are designed out. Do not add compensating logic.

- **Large test+source files overflowing context** — handled by static Track-B decomposition (method-shards + whole-class or `L > C` digest). Do not add a runtime "will it fit" estimate; the track is a fixed line-count decision.
- **A single agent dying mid-run (overflow or transient `529`)** — handled by bounded re-spawn of that unit, then degrade-and-flag. Never re-run the whole fleet.
- **Large changesets exceeding the agent budget** — handled by sequential auto-chunking at `G`, with one global cross-file pass over all chunks. Do not shard the cross-file analysis per chunk.
- **The full rule catalog overflowing context-heavy agents** — handled by per-agent scoped `## RULES` selection. Do not inject the full catalog into every agent.
- **A unit whose three reviewers all find nothing** — handled by the Wave-1 zero-finding skip. Do not spawn reconcilers for an empty unit.
- **An empty or incomplete manifest** — handled by the fail-hard abort. Never run on partial input or return a hollow report.
- **An agent silently inheriting the session model tier** — handled by explicit per-spawn model pinning. Never rely on the default.
