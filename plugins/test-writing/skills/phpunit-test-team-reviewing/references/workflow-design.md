# Workflow Design — Adaptation Guide

`workflow/team-review.workflow.mjs` is the shipped review workflow: a waved fan-out of fresh agents coordinated through a blackboard, no agent-to-agent messaging — independent review → peer reconciliation → conditional red team → conditional defense → cross-file consistency (with the cross-cutting SUT-coverage map) → verdicts (with integration-to-unit placement flags), with 2-of-3 consensus per unit. It reviews unit, integration, and migration tests over one mixed manifest, routing each file by `test_type`. Launch it with the run manifest as `args`; it self-adapts at runtime on the signals below.

You already know how Claude Code workflows are built. This reference does **not** restate the script step by step — it covers only the inputs the workflow expects and its adaptation surface.

## Pre-Run Collect

The inputs you supply, built before launch and carried in the run manifest. The per-file `fingerprint` and `digest` are produced by the ephemeral pre-run extraction subagents (Phase 1) — one per file, their context discarded once they return the compact entry. This does not defeat the digest: its purpose is downstream, keeping method bodies out of the **reviewer** agents, whose `L > C` track consumes the body-free digest instead of the file.

- **Cross-file fingerprint** — a fixed-size structural signature per file: `setUp` shape, mock strategy (createMock/createStub), assertion style, data-provider style, attribute order. Compute for **every** file. The cross-file agent consumes it.
- **Structural digest** — for each file whose combined lines exceed **800** (the digest floor — the lowest preset `C`, so every preset's `L > C` digest-track files have a digest regardless of which preset the run selects): class declaration, `#[CoversClass]`, member order, method signatures, attribute lines, property declarations. **No method bodies.** The `L > C` digest-track reviewers consume it. If a preset is ever added with `C` below 800, lower this floor to match.
- **Per-type rule catalogs** — for each test type present, call `build_rule_package` (unit → no arguments; integration → `group=integration, test_type=integration`; migration → `group=migration, test_type=migration`), keep each returned path, and splice it into the run manifest by path (`jq --rawfile`) as `rule_packages.{type}` — never load the catalog into context. When any integration file is present, also build `group=placement, test_type=integration` → `rule_packages.placement` (reference for the placement-flag signal). The workflow selects each agent's scoped `## RULES` block from the file's per-type catalog; do not build per-track packages. Abort if a needed build fails or renders zero rules.

## What you can adapt, and for what purpose

Two kinds of knob: **per-run presets** carried in the manifest (`preset`, `models`) that a launch selects without editing the script, and **fixed seeds** that only a script edit changes. `T` is a **test+source combined** line count.

**Per-run presets** (manifest `preset` / `models`; fail-soft to `standard` / `sonnet-opus`; defined in the script's `PRESETS` / `MODEL_PRESETS`):

| preset | C | M | lenses (= K_adv) | arbMax |
|---|---|---|---|---|
| `deep` | 1200 | 6 | 3 | uncapped |
| `standard` (default) | 1000 | 8 | 3 | uncapped |
| `lean` | 800 | 14 | 1 | 6 |

- `C` — fused → body-free digest threshold (coverage/token only; **no agent-count effect** — the whole-class unit is `SLOTS` reviewers either way).
- `M` — max methods per shard (higher → fewer Track-B shards → fewer agents).
- `lenses` (= `K_adv`) — adversaries per file in each of Wave 0 and Wave 2; the **primary agent-count lever**. Lenses are taken in priority order, L1 (tautology) first. Change the lens set, not the count alone.
- `arbMax` — cap on total arbitrated contested findings; must-fix are always arbitrated regardless (the cap trims only the lower-severity tail, which stays contested).

Model combos set the body and adversary tiers: `sonnet-opus` (default), `haiku-opus`, `haiku-sonnet`. Body = reviewers / reconcilers / cross-file / should-fix arbiter; adversary = impressions / red team / must-fix arbiter panel. Lower body tiers cut cost but reduce rule-application precision.

**Fixed seeds** (script edit only):

| Lever | Seed | Adjust to … |
|---|---|---|
| `T` | 450 | raise to keep more files whole (Track A, fewer agents); lower to decompose sooner. Combined lines above which a file decomposes. Fixed across presets. |
| `U_file` | 18 | cap reviewer agents per single file (all tracks + widening). |
| `G` | 300 | cap reviewers per chunk before sequential auto-partition. |
| `F_cap` | 40 | files the cross-file agent ingests before sharding by pattern dimension. |
| `SLOTS` | 3 | reviewers per unit — the 2-of-3 consensus invariant. Not a preset knob; changing it changes consensus semantics. |
| `RESPAWN_MAX` | 2 | re-spawn attempts for a dead unit/agent before degrade-and-flag (adversary retries degrade their payload). |
| `BUDGET_FLOOR` | 60000 | token floor checked before each conditional wave / adaptation. |

Arbitration is **uncapped** on `deep`/`standard` and capped at `arbMax` on `lean`; must-fix findings are always arbitrated, sorted must-fix-first, so the cap can never drop a must-fix.

The workflow also self-adapts at runtime: it skips the red team on zero findings or a peer concession rate ≥ 0.5; runs at most one extra peer-reconciliation pass on units still contested after Wave 1 (max 2 passes total); routes adversary resurrections into defense; arbitrates contested findings up to the preset's `arbMax` (a contested must-fix gets 3 adversary-tier arbiters by majority — confirmed ≥ 2, refuted ≥ 2, else kept as `split`; should-fix/consider keep a single arbiter; must-fix are always arbitrated regardless of the cap); and widens a sharply-divided unit by +2 reviewers once. These fire only on their signals — a clean review triggers none.

## Already handled — do not re-adapt

These failure modes are designed out. Do not add compensating logic.

- **Large test+source files overflowing context** — handled by static Track-B decomposition (method-shards + whole-class or `L > C` digest). Do not add a runtime "will it fit" estimate; the track is a fixed line-count decision.
- **A single agent dying mid-run (overflow or transient `529`)** — handled by bounded re-spawn of that unit, then degrade-and-flag. Never re-run the whole fleet.
- **Large changesets exceeding the agent budget** — handled by sequential auto-chunking at `G`, with one global cross-file pass over all chunks. Do not shard the cross-file analysis per chunk.
- **The full rule catalog overflowing context-heavy agents** — handled by per-agent scoped `## RULES` selection. Do not inject the full catalog into every agent.
- **A unit whose three reviewers all find nothing** — handled by the Wave-1 zero-finding skip. Do not spawn reconcilers for an empty unit.
- **An empty or incomplete manifest** — handled by the fail-hard abort. Never run on partial input or return a hollow report.
- **An agent silently inheriting the session model tier** — handled by explicit per-spawn model pinning. Never rely on the default.
