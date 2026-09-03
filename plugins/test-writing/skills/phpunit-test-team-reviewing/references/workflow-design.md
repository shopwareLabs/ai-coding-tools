# Workflow Design — Adaptation Guide

`workflow/team-review.workflow.mjs` is the shipped review workflow: a waved fan-out of fresh agents coordinated through a blackboard, no agent-to-agent messaging, with 2-of-3 consensus per unit. It reviews unit, integration, and migration tests over one mixed manifest, routing each file by `test_type`, and is **mode-switched** — the skill drives it as a campaign of sequential launches, each with a manifest `mode`:

| mode | runs | consumes | emits |
|---|---|---|---|
| `review` (default) | Wave 0 (reviewers + adversary impressions) → Wave 1 peer reconciliation (max 2 passes) → targeted widening → consensus | manifest + per-type catalogs | per-file consensus verdicts + a per-file `adversarial_input` payload (kept/contested, reconciliation record, impressions) + the exported adversarial-gate signal |
| `adversarial` | Wave 2 red team → Wave 3 defense → arbitration | manifest + catalogs + `consensus` (the persisted `adversarial_input` payloads) | final per-file verdicts + red-team metrics + candidate cross-file signals |
| `signals` | cross-file consistency + changeset adoption signal | manifest only (no catalogs) | `consistency` + `adoption_opportunities` |

One shard of files = one `review` launch; `signals` runs once over the whole changeset (it depends on nothing and may run concurrently with the first shard); `adversarial` runs once over all shards' persisted consensus, behind the campaign's gate. The SUT-coverage map and placement flags are deterministic joins the skill computes at merge time — they involve no agents and do not live in the script. Every mode asserts its own agent projection against `AGENT_BUDGET` before spawning anything: cached replays count toward the engine's 1000-agent lifetime cap, so an oversized run can never be rescued by resuming — it must be sharded before launch.

You already know how Claude Code workflows are built. This reference does **not** restate the script step by step — it covers only the inputs the workflow expects and its adaptation surface.

## Pre-Run Collect

The inputs you supply, built before launch and carried in the run manifest. The per-file `fingerprint` and `digest` are produced by the ephemeral pre-run extraction subagents (Phase 1) — one per file, their context discarded once they return the compact entry. This does not defeat the digest: its purpose is downstream, keeping method bodies out of the **reviewer** agents, whose `L > C` track consumes the body-free digest instead of the file.

- **Cross-file fingerprint** — a fixed-size structural signature per file: `setUp` shape, mock strategy (createMock/createStub), assertion style, data-provider style, attribute order. Compute for **every** file. The cross-file agent consumes it.
- **Structural digest** — for each file whose combined lines exceed **800** (the digest floor — the lowest preset `C`, so every preset's `L > C` digest-track files have a digest regardless of which preset the run selects): class declaration, `#[CoversClass]`, member order, method signatures, attribute lines, property declarations. **No method bodies.** The `L > C` digest-track reviewers consume it. If a preset is ever added with `C` below 800, lower this floor to match.
- **Per-type rule catalogs** — for each test type present, call `build_rule_package` with `test_type` alone and no `group` (unit → no arguments at all, which defaults to `test_type=unit`; integration → `test_type=integration`; migration → `test_type=migration`) to get that type's *composed* catalog — its own group plus every convention/design/isolation/provider rule declaring the type. Passing `group` alongside `test_type` narrows to that single group instead (e.g. `group=placement, test_type=integration`, used only by the integration-to-unit migrating skill) and must not be used here. Keep each returned path, and splice it into the run manifest by path (`jq --rawfile`) as `rule_packages.{type}` — never load the catalog into context. Required for `review` and `adversarial` runs; a `signals` run uses no catalogs. The workflow selects each agent's scoped `## RULES` block from the file's per-type catalog; do not build per-track packages. Abort if a needed build fails or renders zero rules.

## What you can adapt, and for what purpose

Two kinds of knob: **per-run presets** carried in the manifest (`preset`, `models`) that a launch selects without editing the script, and **fixed seeds** that only a script edit changes. `T` is a **test+source combined** line count.

**Per-run presets** (manifest `preset` / `models`; fail-soft to `standard` / `sonnet-opus`; defined in the script's `PRESETS` / `MODEL_PRESETS`):

| preset | C | M | lenses (= K_adv) | arbMax | arbFile |
|---|---|---|---|---|---|
| `deep` | 1200 | 6 | 3 | 36 | 6 |
| `standard` (default) | 1000 | 8 | 3 | 24 | 4 |
| `lean` | 800 | 14 | 1 | 6 | 3 |

- `C` — fused → body-free digest threshold (coverage/token only; **no agent-count effect** — the whole-class unit is `SLOTS` reviewers either way).
- `M` — max methods per shard (higher → fewer Track-B shards → fewer agents).
- `lenses` (= `K_adv`) — adversaries per file in each of Wave 0 and Wave 2; the **primary agent-count lever**. Lenses are taken in priority order, L1 (tautology) first. Change the lens set, not the count alone.
- `arbMax` / `arbFile` — **hard** caps on arbitrated contested findings per run and per file. Candidates sort must-fix-first at both levels, so the caps trim the lowest-severity tail first; every trimmed finding stays in `contested` and surfaces unchanged. The caps are hard because the measured alternative was uncapped arbitration driving a 433-projection run into the 1000-agent engine cap.

Model combos set the body and adversary tiers: `sonnet-opus` (default), `haiku-opus`, `haiku-sonnet`. Body = reviewers / reconcilers / cross-file / should-fix arbiter; adversary = impressions / red team / must-fix arbiter panel. Lower body tiers cut cost but reduce rule-application precision.

**Fixed seeds** (script edit only):

| Lever | Seed | Adjust to … |
|---|---|---|
| `T` | 450 | raise to keep more files whole (Track A, fewer agents); lower to decompose sooner. Combined lines above which a file decomposes. Fixed across presets. |
| `U_file` | 18 | cap reviewer agents per single file (all tracks + widening). |
| `G` | 300 | cap reviewers per chunk before sequential auto-partition (an in-run safety net — the campaign's shard plan is the primary partition). |
| `F_cap` | 40 | files the cross-file agent ingests before sharding by pattern dimension. |
| `SLOTS` | 3 | reviewers per unit — the 2-of-3 consensus invariant. Not a preset knob; changing it changes consensus semantics. |
| `MIN_LIVE_STANCES` | 2 | live stances a unit's merge requires before it will compute at all; below it the merge throws and the shard fails. Raise to demand a full panel; never lower to 1 or 0, which is the fail-open it replaced. |
| `RESPAWN_MAX` | 1 | re-spawn attempts for a dead agent — one retry, which carries the degraded payload when one is defined. |
| `BUDGET_FLOOR` | 60000 | token floor checked before each conditional wave / adaptation. |
| `AGENT_BUDGET` | 900 | per-run pre-flight ceiling (headroom under the engine's 1000-agent lifetime cap, which cached replays also consume). |
| `WAVE_NULL_MIN` / `WAVE_NULL_RATE` | 8 / 0.3 | circuit breaker: a wave of ≥ 8 agents losing ≥ 30% to terminal deaths halts the run at the wave boundary with a partial result. |
| `STORM_NULLS` | 8 | consecutive terminal nulls that suppress further retries (usage-limit storm — each storm retry is a guaranteed dead agent that still burns a cap slot). |

The workflow also self-adapts at runtime: a `review` run makes at most one extra peer-reconciliation pass on units still contested after Wave 1 (max 2 passes total) and widens a sharply-divided unit by +2 reviewers once; an `adversarial` run routes adversary resurrections into defense and arbitrates contested findings up to the caps (a contested must-fix gets 3 adversary-tier arbiters by majority — confirmed ≥ 2, refuted ≥ 2, else kept as `split`; should-fix/consider keep a single arbiter). The red-team **skip signal** (zero kept findings, or peer concession rate ≥ 0.5) is computed by the `review` run and exported in its summary as `adversarial_gate` — the campaign consumes it at the gate instead of the script skipping inline. These fire only on their signals — a clean review triggers none.

## Already handled — do not re-adapt

These failure modes are designed out. Do not add compensating logic.

- **Large test+source files overflowing context** — handled by static Track-B decomposition (method-shards + whole-class or `L > C` digest), plus the narrow-diff downgrade (a scoped run touching ≤ max(3, ¼) of a fused file's methods reviews the digest instead of the full bodies, when a digest exists). Do not add a runtime "will it fit" estimate; the track is a fixed line-count decision.
- **A single agent dying mid-run (overflow or transient `529`)** — handled by one bounded re-spawn of that unit, then degrade-and-flag. Never re-run the whole fleet.
- **Large changesets exceeding the agent budget** — handled by the campaign's shard plan (skill Phase 2) plus each run's `AGENT_BUDGET` pre-flight assert; `G`-chunking remains as an in-run safety net. Do not launch one oversized run and plan to resume it — replays consume the same cap.
- **Usage-limit storms** — handled by retry suppression (`STORM_NULLS`) and the wave-level circuit breaker, which halts at the wave boundary with a partial result instead of journaling consensus built from degraded peer sets. Do not add retry loops around a storm.
- **Cross-shard blindness of the cross-file analysis** — handled by the `signals` mode running once over the whole changeset. Do not run cross-file per shard.
- **The full rule catalog overflowing context-heavy agents** — handled by per-agent scoped `## RULES` selection. Do not inject the full catalog into every agent.
- **A unit whose three reviewers all find nothing** — handled by the Wave-1 zero-finding skip. Do not spawn reconcilers for an empty unit.
- **A unit whose reviewers died** — handled by a hard floor in the merge: fewer than **2** live stances throws, naming the unit and the stance count, and the shard fails. Do not add a fallback denominator or a degraded merge. The circuit breaker cannot cover this (it never trips below `WAVE_NULL_MIN` agents, and a one-file Track-A wave is six), and the failure it prevents is silent: zero stances produced an empty consensus that rendered as a clean `PASS`.
- **A reviewing sub-skill whose deletion after-state guard refused** — handled by `status`/`reason` on the reviewer schema: the stance is excluded from consensus, its findings are not ingested, the file becomes `FAILED` carrying every refusal verbatim, and the payload carries them into the adversarial stage so its final verdict cannot upgrade the file. Do not solve this by telling the sub-skill to skip its guard when the campaign runs one — the sub-skill guard covers that reviewer's own findings and the campaign guard covers the union, and both are meaningful. Do not default a missing `reason`; a refusal nobody can read is not a report.
- **A reconciliation pass that came back partial** — handled at the point the binding stances are replaced: a pass replaces them only when it produced at least `MIN_LIVE_STANCES` of them, otherwise the richer prior binding stands and the partial pass is logged and discarded. Do not make the replacement unconditional; that is what made *zero* surviving reconcilers keep working while *one* replaced a complete Wave-0 set with a single stance the merge then refused, aborting the run.
- **Reviewers who quoted different extents of the same code** — handled by finding identity being `rule_id|method` and nothing else, so their stances pool votes on one record (consensus-and-verdicts.md §Finding identity). Do not add a fingerprint or a similarity threshold to separate them again; both reintroduce the fragmentation that made every phrasing its own contested single-vote group.
- **A guardrail contradicting the mode it is rendered above** — handled by `guard(readsSource)`: the digest reviewer and its reconciler get the "do not open the file" instruction, everyone else the "you must read the file" one. Do not restore a single universal read directive; digest mode exists so an oversized class is never opened.
- **Informational findings escalating a file's status** — handled in `bucketFile` and `overallOf`: only must-fix and should-fix move status. Do not re-escalate on `informational` anywhere downstream; INTEGRATION-008's placement hint and the workflow's own "split this test class" entry are defined as status-neutral, and escalating them made one clean integration test disagree with `phpunit-integration-test-reviewing` about its own verdict.
- **An empty or incomplete manifest** — handled by the fail-hard abort (including `mode=adversarial` without its `consensus` payloads). Never run on partial input or return a hollow report.
- **An agent silently inheriting the session model tier** — handled by explicit per-spawn model pinning. Never rely on the default.
