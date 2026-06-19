# Workflow Design

Design the review as a Workflow: a deterministic coordinator over fresh, schema-constrained agents. Agents never message each other. The only shared memory is the script — it routes one wave's outputs into the next wave's prompts (a blackboard, not a mesh). Each agent gets a narrow prompt and returns one schema-validated object.

## Base Wave Shape

The default flow, in order. Several waves are conditional — see Adaptation Points.

1. **Wave 0 — Independent review + impressions (parallel).**
   - Reviewer agents review the manifest files independently (each invokes the reviewing sub-skill). Honor the consensus invariant: every file is reviewed by 3 independent reviewers.
   - Adversary agents form independent impressions of their assigned files (no consensus exposure yet).
   - All Wave 0 agents run concurrently.

2. **Collect & assemble (deterministic).** Group findings per file. For each reviewer, assemble the peer-findings package: co-reviewers' findings on the files that reviewer shares.

3. **Wave 1 — Peer reconciliation (parallel).** Each reviewer reconciles its findings against peers' findings (invokes the reconciling sub-skill in peer mode). Returns a revised binding stance per file.

4. **Preliminary consensus (deterministic).** Merge Wave 1 stances per file into a preliminary consensus (2-of-3 majority). Compute the red-team skip signal.

5. **Wave 2 — Red team (conditional).** Adversary agents challenge the preliminary consensus (invoke the adversarial-reviewing sub-skill) using the consensus package plus their Wave 0 impressions. Return challenges, resurrections, adversary-introduced findings, and endorsements.

6. **Wave 3 — Defense (conditional).** Each reviewer whose files drew challenges reconciles its stance against those challenges (invokes the reconciling sub-skill in adversary mode). Returns a revised stance with an adversary-impact tag on every entry.

7. **Cross-file consistency (dedicated agent).** One agent receives every file's final consensus — plus any cross-file inconsistencies the adversaries surfaced as candidate signals — and hunts pattern divergence across files (setUp strategy, mocking, assertions, data providers, attribute ordering). Returns consistency findings. This is the sole producer of cross-file findings — individual reviewers do not emit them.

8. **Verdicts (deterministic).** Final per-file consensus merge, status determination, adversary-impact assembly, and the returned object.

## Authoring-Time Parameters

Decide these once, before launch, from the resolved manifest and the available budget, and bake them in as constants:

- Reviewer count, adversary count, and how files are packed per agent.
- Model per agent (every agent carries an explicit model; tiers are under Authoring Constraints below).
- Whether the input is small enough to give each reviewer a single file (maximum isolation) or large enough to bundle files per reviewer (cost control).

## Adaptation Points

These are the points where the workflow's shape is allowed to change at runtime. Design the script with each one built in: an agent returns a steering signal as a schema field, the script branches on it, and a concrete cap bounds it. Never leave a cap to runtime discretion.

| # | Steering signal | Branch / loop rule | Hard cap |
|---|---|---|---|
| 1 | N (file count) + budget, known before launch | Choose reviewer count, adversary count, packing, and model tiers | Fixed by the allocation reference; not a runtime loop |
| 2 | Script-computed: preliminary consensus has zero findings, OR peer reconciliation already withdrew a large share of the Wave-0 findings (concession rate ≥ 0.5) | Skip Wave 2 + Wave 3; go straight to verdicts | Single conditional; never both run when the signal says skip |
| 3 | Script-computed: after the Wave-1 merge, shared files still carry non-unanimous (contested or split) findings | Run one additional peer-reconciliation pass, seeded with the updated peer stances | **Max 2 peer passes total**; stop as soon as the merge has no contested findings |
| 4 | Adversary returns resurrections or adversary-introduced findings | Route them into Wave 3 so the owning reviewer can re-adopt or adopt | Bounded by the adversary output; no loop |
| 5 | A finding is contested after merge (reported by only 1 of 3), OR a must-fix was overturned in defense, OR stances split with no majority | Spawn one arbiter agent for that finding; it re-reads the code and settles it | One arbiter per contested finding; no arbiter when consensus is clean; opus for must-fix/critical, sonnet otherwise |
| 6 | A file's reviewers diverge sharply (no majority on most findings, or contested count exceeds agreed count) | Spawn extra reviewers for that file only, then re-merge that file | **At most +2 reviewers per file, once per file**; only while the budget floor holds |

Points 2–4 are the base review loop. Points 5–6 are enhancements — include them, but they fire only on their signals; a clean review never spawns an arbiter or an extra reviewer.

## Authoring Constraints

- **Fail hard.** Throw if the baked-in manifest is empty or any entry is missing its path or scope. Never let the workflow run on empty input and return a hollow report.
- **Inline, not args.** Bake the manifest and counts in as constants. Do not pass them as workflow args.
- **Log the resolved scope first.** The first log line states file count, reviewer count, adversary count, and packing, so the run is auditable at a glance.
- **Explicit model on every agent.** Never omit the model. Default tiers: reviewers, adversaries, and reconcilers run on sonnet; arbiters (point 5) and the cross-file agent run on opus.
- **Read-only review agents.** Spawn reviewers and adversaries through the read-only agent types; they must not write files.
- **Schema-constrain every agent.** Force each agent's output to the field contract defined for its role.
- **Concrete guards only.** Max 2 peer passes; at most +2 reviewers per file; a budget floor checked before any conditional wave. No discretionary caps.
- **Keep it simple.** Prefer parallel fan-out and conditional waves. Use loops or extra waves only for the bounded adaptation points above.

## Returned-Object Shape

Return one object the rendering step can consume directly:

- `summary` — files reviewed, reviewer count, overall status.
- `files[]` — per file: status, category, the reviewers/slots used, `errors` / `warnings` / `informational` (each finding carries consensus level, adversary-impact tag, dissent if majority, and any arbitration verdict), `contested[]`, and a consensus tally.
- `consistency[]` — cross-file divergences from the dedicated cross-file agent.
- `red_team` — skipped flag and skip reason, or the challenge/defense metrics.
- `adaptation` — which adaptation points fired this run (extra peer pass, extra reviewers per file, arbiters spawned) so the run is transparent.
