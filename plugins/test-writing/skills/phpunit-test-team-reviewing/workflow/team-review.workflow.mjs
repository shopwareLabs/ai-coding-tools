export const meta = {
  name: 'phpunit-test-team-review',
  description: 'Team consensus review of Shopware PHPUnit unit, integration, and migration tests over one mixed manifest. Mode-switched stages driven by the skill: review (waves 0-1 + consensus per shard), adversarial (red team + defense + arbitration over a persisted consensus), signals (cross-file consistency + adoption over the whole changeset). Reads its manifest from args; routes per file by test_type; encodes the wave shape, gates, caps, and adaptation points of the team-reviewing skill references.',
  phases: [
    { title: 'Wave 0: Review + impressions' },
    { title: 'Wave 1: Peer reconciliation' },
    { title: 'Targeted widening' },
    { title: 'Wave 2: Red team' },
    { title: 'Wave 3: Defense' },
    { title: 'Arbitration' },
    { title: 'Cross-file consistency' },
    { title: 'Adoption signal' },
  ],
};

// Prompts and schemas live in THIS file, not the references: the per-role
// StructuredOutput schemas (REVIEWER_SCHEMA, ADV_IMPRESSION_SCHEMA, RECONCILE_SCHEMA,
// REDTEAM_SCHEMA, DEFENSE_SCHEMA, CROSSFILE_SCHEMA, ARBITER_SCHEMA) are defined below,
// and the prompt builders (GUARD + reviewerPrompt / adversaryImpressionPrompt /
// reconcilePrompt / redTeamPrompt / defensePrompt / crossFilePrompt / arbiterPrompt)
// follow them. The references describe only the adaptation surface — change a contract here.

// ===========================================================================
// Manifest (args) — Phase 1/2 output. Fail hard on incomplete input.
//   { files: [ { path, test_type: "unit"|"integration"|"migration",
//                source_path, source_paths: [all #[CoversClass] sources],
//                test_lines, source_lines, method_count,
//                methods: [scoped names | []], changed_methods: [diff-touched names | omit], test_methods: [all names],
//                fingerprint: "<structural signature>", digest: "<text>"|null,
//                baseline: "pass"|"fail"|"unavailable" (omit = unavailable) } ],
//     rule_packages: { unit?, integration?, migration?: "<rendered catalog>" },
//     base?: "<base ref, for logging>",
//     mode?: "review" | "adversarial" | "signals" (default review),
//     consensus?: [ per-file adversarial_input payloads from review-mode results ]  (mode=adversarial only),
//     adv_signals?: [ candidate cross-file signals from an adversarial run ]        (mode=signals, optional) }
// test_type is the PRIMARY routing axis (classified by path in Phase 1). Each
// test type has its own rendered catalog; the script slices each wave's scoped
// `## RULES` subset from the file's per-type catalog in-process — the workflow
// runtime sandboxes the script, so it cannot call build_rule_package or any MCP
// tool once running. mode=signals needs no catalogs at all.
// ===========================================================================
const TEST_TYPES = ['unit', 'integration', 'migration'];
// The caller supplies each file's pre-review test state; no stage of this run executes
// tests, so an unsupplied value stays 'unavailable' rather than being inferred.
const BASELINES = ['pass', 'fail', 'unavailable'];
const manifest = args;
if (!manifest || typeof manifest !== 'object') throw new Error('Manifest (args) missing or not an object');
const DRY_RUN = manifest.dry_run === true;   // projection-only: no agents spawn, catalogs not required
// Execution mode — one committed script, three sequential stages driven by the skill:
//   review      waves 0-1 + widening + consensus; emits per-file verdicts + adversarial_input payloads
//   adversarial red team + defense + arbitration over the persisted consensus payloads
//   signals     cross-file consistency + adoption signal (manifest-only inputs, no catalogs)
// Absent defaults to review (the skill always sets it); an unknown value is a defect, never coerced.
const MODES = ['review', 'adversarial', 'signals'];
const MODE = manifest.mode == null ? 'review' : manifest.mode;
if (!MODES.includes(MODE)) throw new Error(`Unknown mode ${JSON.stringify(manifest.mode)} — expected review | adversarial | signals`);
const MANIFEST = manifest.files;
if (!Array.isArray(MANIFEST) || MANIFEST.length === 0) throw new Error('Manifest is empty — abort (fail-hard guard)');

// ---------------------------------------------------------------------------
// Downstream string-keyed joins (coverage map, adoption signal) key on path strings, so a
// SUT spelled absolute in one manifest entry and relative in another would split into two
// identities and silently drop the coverage overlap. Every path lives under src/ or tests/
// (the classification + SUT-resolution contract), so anchoring to that root is deterministic
// and collapses both spellings of one file. A path under neither root is a genuine defect,
// not a spelling variant — rejected rather than canonicalized.
// ---------------------------------------------------------------------------
function normPath(p) {
  const s = String(p == null ? '' : p).replace(/\\/g, '/').replace(/\/{2,}/g, '/').replace(/^\.\//, '').replace(/\/+$/, '').trim();
  const m = s.match(/.*\/((?:src|tests)\/.*)$/) || s.match(/^((?:src|tests)\/.*)$/);
  return m ? m[1] : s;
}
function isAbsPath(p) { return typeof p === 'string' && (p.startsWith('/') || /^[A-Za-z]:[\\/]/.test(p)); }

for (const e of MANIFEST) {
  if (!e || typeof e.path !== 'string' || !e.path.endsWith('Test.php')) throw new Error('Manifest entry missing/invalid path: ' + JSON.stringify(e));
  if (!TEST_TYPES.includes(e.test_type)) throw new Error(`Manifest entry missing/invalid test_type (unit|integration|migration): ${e.path} (got ${JSON.stringify(e.test_type)})`);
  if (typeof e.source_path !== 'string' || !e.source_path) throw new Error('Manifest entry missing source_path: ' + e.path);
  if (e.source_paths != null && !Array.isArray(e.source_paths)) throw new Error('Manifest entry source_paths must be an array when present: ' + e.path);
  if (!Number.isFinite(e.test_lines) || !Number.isFinite(e.source_lines)) throw new Error('Manifest entry missing line counts: ' + e.path);
  if (!Array.isArray(e.methods)) throw new Error('Manifest entry missing methods scope: ' + e.path);
  if (!Array.isArray(e.test_methods)) throw new Error('Manifest entry missing test_methods (all method names): ' + e.path);
  if (e.changed_methods != null && !Array.isArray(e.changed_methods)) throw new Error('Manifest entry changed_methods must be an array when present: ' + e.path);
  if (e.baseline != null && !BASELINES.includes(e.baseline)) throw new Error(`Manifest entry baseline must be one of ${BASELINES.join('|')} when present: ${e.path} (got ${JSON.stringify(e.baseline)})`);
  // A path under neither src/ nor tests/ can't be canonicalized and would silently split a
  // SUT across the joins (input-resolution.md Per-File Extraction requires repo-relative).
  if (isAbsPath(normPath(e.path))) throw new Error(`Manifest entry path does not resolve under tests/ and cannot be made repo-relative: ${e.path}`);
  if (isAbsPath(normPath(e.source_path))) throw new Error(`Manifest entry source_path does not resolve under src/ and cannot be made repo-relative: ${e.source_path} (${e.path})`);
  if (Array.isArray(e.source_paths) && e.source_paths.some((s) => isAbsPath(normPath(s)))) throw new Error(`Manifest entry has a source_paths entry that does not resolve under src/ and cannot be made repo-relative: ${e.path}`);
}
const TYPES_PRESENT = [...new Set(MANIFEST.map((e) => e.test_type))];
const RULE_PACKAGES = manifest.rule_packages;
// A review or adversarial run requires a non-empty rendered catalog per test type
// present; a dry-run projection spawns no agents and a signals run uses no rules.
if (!DRY_RUN && MODE !== 'signals') {
  if (!RULE_PACKAGES || typeof RULE_PACKAGES !== 'object') {
    throw new Error('rule_packages missing — a rendered catalog per test type is required (build_rule_package + Read in Phase 3)');
  }
  for (const t of TYPES_PRESENT) {
    const c = RULE_PACKAGES[t];
    if (typeof c !== 'string' || c.trim().length === 0) {
      throw new Error(`rule_packages.${t} missing — files of test_type=${t} are present but their rendered catalog was not supplied`);
    }
  }
}

// mode=adversarial input: one persisted consensus payload per file (each file's
// adversarial_input from the review-mode results, assembled by the skill). Fail hard on
// gaps — red-teaming a file without its consensus payload would silently challenge nothing.
let CONSENSUS_BY_PATH = null;
if (!DRY_RUN && MODE === 'adversarial') {
  if (!Array.isArray(manifest.consensus) || manifest.consensus.length === 0) {
    throw new Error('mode=adversarial requires manifest.consensus — the per-file adversarial_input payloads from the review-mode results');
  }
  CONSENSUS_BY_PATH = new Map();
  for (const c of manifest.consensus) {
    if (!c || typeof c.path !== 'string' || !Array.isArray(c.kept) || !Array.isArray(c.contested)) {
      throw new Error('manifest.consensus entry missing path/kept/contested: ' + JSON.stringify(c && c.path));
    }
    // Every stage of this run keys on finding_id. A payload from a review run that
    // predates it would fold withdrawals, adoptions, and arbitration against nothing.
    for (const k of [...c.kept, ...c.contested]) requireFindingId(k, `manifest.consensus payload for ${c.path} — re-run the review stage to stamp identity`);
    // A resurrection resolves its original out of withdrawn_originals; a payload that lists
    // withdrawals without them predates the store, so every re-adoption of one would abort
    // the defense fold mid-run. Fail at the boundary instead, naming the fix.
    if (Array.isArray(c.withdrawn_findings) && c.withdrawn_findings.length > 0 && !Array.isArray(c.withdrawn_originals)) {
      throw new Error(`manifest.consensus payload for ${c.path} carries withdrawn_findings without withdrawn_originals — re-run the review stage so a resurrection can resolve its original`);
    }
    CONSENSUS_BY_PATH.set(normPath(c.path), c);
  }
  for (const e of MANIFEST) {
    if (!CONSENSUS_BY_PATH.has(normPath(e.path))) throw new Error(`mode=adversarial: no consensus payload for ${e.path}`);
  }
}

// ===========================================================================
// Fixed seeds (not preset knobs — see workflow-design.md to retune).
// ===========================================================================
const T = 450;            // combined test+source lines above which a file decomposes (Track B) — a reviewability threshold, fixed across presets
const U_file = 18;        // max reviewer agents per single file
const G = 300;            // max reviewer agents per chunk (auto-partition above this)
const F_cap = 40;         // files the cross-file agent ingests before sharding by pattern dimension
const SLOTS = 3;          // reviewers per unit — the 2-of-3 majority consensus invariant; NEVER a preset knob
const RESPAWN_MAX = 1;    // re-spawn attempts for a dead agent — ONE retry; storms suppress retries entirely
const BUDGET_FLOOR = 60000; // token floor checked before any conditional wave
const AGENT_BUDGET = 900; // pre-flight ceiling per run: headroom under the engine's 1000-agent lifetime cap (cached replays count toward that cap, so a run projecting past it can never finish, even resumed)
const WAVE_NULL_MIN = 8;  // wave size below which the null-rate circuit breaker never trips
const WAVE_NULL_RATE = 0.3; // terminal-null share of a wave that trips the circuit breaker
const STORM_NULLS = 8;    // consecutive terminal nulls that suppress further retries (usage-limit storm)

// ===========================================================================
// Tuning presets — the cost/quality operating point, selected by name in the
// manifest (manifest.preset), fail-soft to 'standard' when absent or unknown.
//   C       whole-class fused → digest-escape line threshold (no agent-count effect; coverage/token only)
//   M       max test methods per shard (higher = fewer Track-B shards = fewer agents)
//   lenses  adversary lens count = adversaries/file in each of Wave 0 and Wave 2 (the agent-count lever)
//   arbMax  HARD cap on arbitrated contested findings per run (must-fix first; the trimmed
//           tail stays contested and visible — uncapped arbitration is what blew a
//           433-projection run past the 1000-agent engine cap)
//   arbFile HARD cap on arbitrated contested findings per file (must-fix first)
// ===========================================================================
const PRESETS = {
  deep:     { C: 1200, M: 6,  lenses: 3, arbMax: 36, arbFile: 6 },
  standard: { C: 1000, M: 8,  lenses: 3, arbMax: 24, arbFile: 4 },
  lean:     { C: 800,  M: 14, lenses: 1, arbMax: 6,  arbFile: 3 },
};
const PRESET_NAME = (manifest.preset && PRESETS[manifest.preset]) ? manifest.preset : 'standard';
const PRESET = PRESETS[PRESET_NAME];
const C = PRESET.C;
const M = PRESET.M;
const ARB_MAX = PRESET.arbMax;
const ARB_FILE = PRESET.arbFile;

// Model combos — body tier does rule-checking / reconciliation / cross-file / single
// (should-fix) arbiter; adversary tier does impressions, red team, and the must-fix
// arbiter panel. Selected by name (manifest.models), fail-soft to 'sonnet-opus'.
const MODEL_PRESETS = {
  'sonnet-opus':  { body: 'sonnet', adversary: 'opus' },
  'haiku-opus':   { body: 'haiku',  adversary: 'opus' },
  'haiku-sonnet': { body: 'haiku',  adversary: 'sonnet' },
};
const MODELS_NAME = (manifest.models && MODEL_PRESETS[manifest.models]) ? manifest.models : 'sonnet-opus';
const MODEL_BODY = MODEL_PRESETS[MODELS_NAME].body;
const MODEL_ADVERSARY = MODEL_PRESETS[MODELS_NAME].adversary;
const TYPE_REVIEWER = 'test-writing:test-reviewer';
const TYPE_ADVERSARY = 'test-writing:test-adversary';

function budgetOk() { return !budget.total || budget.remaining() > BUDGET_FLOOR; }

// ===========================================================================
// Adversary lenses — the K independent per-file adversaries (impressions + red team).
// K is the lens count, not an arbitrary number: three orthogonal ways a test
// fails its purpose (does it run for real / assert enough / exist at all). The axes
// are test-agnostic; the red team carries the full catalog for the file's test_type
// as its ## RULES block, so each lens draws the cited rules from that block rather
// than a hardcoded per-type ID list. Each lens reads exactly ONE file in each wave,
// so read accumulation is bounded by a single file and the multi-file accumulation
// that overflowed cannot occur. No convention lens — convention is the reviewer
// wave's strength (see red-team-context.md).
// ===========================================================================
const ALL_LENSES = [
  {
    id: 'L1', name: 'tautology hunter',
    impression: 'TAUTOLOGY LENS (does it run for real?): hunt for tests that would still pass if the SUT were broken — over-mocking the SUT or its real collaborators, asserting on stubbed return values, call-count coupling, guard-clause leakage in arrange. Of each assertion ask: does it verify the behaviour, or only the double you set up?',
    redteam: 'Your lens is the TAUTOLOGY HUNTER (does it run for real?): challenge or introduce findings where a test would pass even if the SUT were broken — over-mocking, asserting on stubs/doubles, call-count over-coupling, guard-clause isolation. Cite the rules in your ## RULES block that fit this axis.',
  },
  {
    id: 'L2', name: 'weak-assertion hunter',
    impression: 'WEAK-ASSERTION LENS (does it assert enough?): do the assertions pin the real contract, or only that "something happened"? Are edge cases and error paths asserted with specific expectations (message, code, concrete value, persisted state) rather than type-only or existence-only checks?',
    redteam: 'Your lens is the WEAK-ASSERTION HUNTER (does it assert enough?): challenge or introduce findings where assertions are too weak to pin the contract, or edge and error cases are unasserted. Cite the rules in your ## RULES block that fit this axis.',
  },
  {
    id: 'L3', name: 'missed-coverage / completeness hunter',
    impression: 'MISSED-COVERAGE LENS (is it there at all?): read the SUT public surface, enumerate its behaviours, branches, and error paths, and find the ones with NO test at all. What would you add that the panel did not think to write?',
    redteam: 'Your lens is the MISSED-COVERAGE / COMPLETENESS HUNTER (is it there at all?): read the SUT public surface, enumerate its behaviours/branches/error paths, and INTRODUCE findings for those with no test — the "introduce what the panel missed" posture. Cite the rules in your ## RULES block that fit this axis (you may opportunistically flag a glaring convention issue, but completeness is your axis).',
  },
];
// Active lenses = the preset's lens count, taken in priority order. L1 (tautology) is
// first deliberately: a test that passes even when the SUT is broken is the worst defect,
// so it is the single lens a lean preset keeps. deep/standard keep all three.
const LENSES = ALL_LENSES.slice(0, PRESET.lenses);
const K_adv = LENSES.length;   // adversaries per file = active lens count

// ===========================================================================
// Output schemas — one StructuredOutput contract per role (owned here).
// ===========================================================================
const FINDING_PROPS = {
  rule_id: { type: 'string' },
  enforce: { type: 'string', enum: ['must-fix', 'should-fix', 'consider'] },
  location: { type: 'string', description: 'real file:line, e.g. FooTest.php:45 (line is a hint — method is the stable locator)' },
  method: { type: 'string', description: 'the test method the finding is in, e.g. testFoo; "class-level" for whole-class/structural findings' },
  summary: { type: 'string' },
  current: { type: 'string' },
  suggested: { type: 'string' },
  implies_src_change: { type: 'boolean', description: 'true ONLY when the fix cannot be made in the test alone — it requires changing production (src/) code; default false' },
  // Deletion accounting. A finding that removes test code says what it removes, so the
  // after-state guard can ask assert_surviving_tests what the class still contains and no
  // assertion is dropped without a named survivor. `covered_by_test` deliberately avoids the
  // name `covered_by`, which the result shape already uses for the SUT-coverage map.
  deleted_methods: { type: 'array', items: { type: 'string' }, description: 'test methods this remediation removes ENTIRELY, by bare name (e.g. testFoo); empty when it removes none' },
  removed_assertions: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['assertion', 'covered_by_test'], properties: {
    assertion: { type: 'string', description: 'the assertion the remediation removes, quoted from the code' },
    covered_by_test: { type: 'string', description: 'the surviving test method that still covers this assertion, or the literal "none — coverage lost"' },
  } }, description: 'per assertion this remediation removes, the surviving test that covers it; empty when it removes none' },
};
// Reviewers never emit an identity (the workflow derives it at ingest), but every later
// role is handed findings that already carry one and must quote it back, so the schemas
// those roles answer with declare it. `finding_id` leads the property list: an agent that
// writes it first cannot drift onto a finding it did not mean by the time it reaches the
// body fields.
const FINDING_PROPS_REF = {
  finding_id: { type: 'string', description: 'the finding_id of the finding this entry refers to, quoted verbatim from the payload above; absent only on a finding introduced here for the first time' },
  ...FINDING_PROPS,
};
const REVIEWER_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['reviewer', 'category', 'clean', 'findings'],
  properties: {
    reviewer: { type: 'string' },
    category: { type: 'string', description: 'unit source-class category A(DTO)|B(Service)|C(Flow/Event)|D(DAL)|E(Exception); "n/a" for integration/migration tests' },
    clean: { type: 'boolean' },
    findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['rule_id', 'enforce', 'location', 'method', 'summary'], properties: FINDING_PROPS } },
  },
};
const ADV_IMPRESSION_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['adversary', 'files'],
  properties: {
    adversary: { type: 'string' },
    files: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['file_path', 'concerns'], properties: {
      file_path: { type: 'string' },
      concerns: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['area', 'severity'], properties: { area: { type: 'string' }, severity: { type: 'string', enum: ['high', 'medium', 'low'] } } } },
    } } },
  },
};
const RECONCILE_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['reviewer', 'findings', 'withdrawn'],
  properties: {
    reviewer: { type: 'string' },
    findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['finding_id', 'rule_id', 'enforce', 'location', 'method', 'summary'], properties: FINDING_PROPS_REF } },
    withdrawn: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['finding_id', 'rule_id', 'reason'], properties: { finding_id: { type: 'string', description: 'the finding_id of the withdrawn finding, quoted verbatim' }, rule_id: { type: 'string' }, reason: { type: 'string' } } } },
  },
};
const REDTEAM_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['adversary', 'files'],
  properties: {
    adversary: { type: 'string' },
    files: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['path'], properties: {
      path: { type: 'string' },
      challenges_to_consensus: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['finding_id', 'rule_id'], properties: { finding_id: { type: 'string', description: 'the finding_id of the consensus finding under challenge, quoted verbatim' }, rule_id: { type: 'string' }, consensus_was: { type: 'string' }, challenge: { type: 'string' }, verdict_sought: { type: 'string' } } } },
      // A resurrection is the first link of the chain that ends in a defender's re_adopted
      // entry; without the withdrawn finding's id here the defender has none to quote.
      // `rule_id` is required alongside it (and on challenges, below) because the defense
      // wave builds each file's disputed-rule package out of the rule_ids its resurrections,
      // challenges and new findings cite — an entry that omits it silently drops the very
      // rule the defenders must judge it under. It is embedded in `finding_id`, so requiring
      // it costs the adversary nothing and keeps schema and fold aligned.
      resurrections: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['finding_id', 'rule_id'], properties: { finding_id: { type: 'string', description: 'the finding_id of the withdrawn finding being resurrected, quoted verbatim' }, rule_id: { type: 'string', description: 'the rule_id of that finding, quoted verbatim from the id — the defenders are shown this rule' }, withdrawn_reason: { type: 'string' }, resurrection_argument: { type: 'string' }, code_evidence: { type: 'string' } } } },
      new_findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['rule_id', 'enforce', 'location', 'method', 'summary'], properties: FINDING_PROPS } },
      endorsements: { type: 'array', items: { type: 'object', additionalProperties: false, properties: { rule_id: { type: 'string' }, reason: { type: 'string' } } } },
      cross_file_inconsistencies: { type: 'array', items: { type: 'object', additionalProperties: false, properties: { rule_id: { type: 'string' }, this_file_status: { type: 'string' }, other_file: { type: 'string' }, other_file_status: { type: 'string' }, inconsistency: { type: 'string' } } } },
    } } },
  },
};
const DEFENSE_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['reviewer', 'path', 'findings', 'withdrawn', 're_adopted', 'adopted_new'],
  properties: {
    reviewer: { type: 'string' }, path: { type: 'string' },
    findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['finding_id', 'rule_id', 'enforce', 'location', 'method', 'summary', 'adversary_impact'], properties: { ...FINDING_PROPS_REF, adversary_impact: { type: 'string', enum: ['defended', 'unchanged'] } } } },
    // re_adopted/adopted_new both feed the promotion fold, which resolves `finding_id` against
    // the record that already carries it (the consensus entry or the persisted withdrawn
    // original for a re-adoption, the red team's own `new_findings` entry for an adoption)
    // and takes IDENTITY — finding_id, rule_id — from it alone. Required here is therefore
    // only what the fold cannot proceed without: `finding_id` (the back-reference), `enforce`
    // (the defender's severity judgment), and `suggested` (the remediation, merged into
    // suggested_variants alongside the original's own). location/method/summary/current stay
    // allowed but optional, and they are read: when this entry's `suggested` wins the merge,
    // its own descriptive fields accompany it so `current` and `suggested` describe one
    // change, and each field it omits falls back to the resolved original's.
    re_adopted: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['finding_id', 'enforce', 'suggested'], properties: { ...FINDING_PROPS_REF, adversary_impact: { type: 'string' } } } },
    withdrawn: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['finding_id'], properties: { finding_id: { type: 'string', description: 'the finding_id of the withdrawn finding, quoted verbatim' }, rule_id: { type: 'string' }, reason: { type: 'string' }, location: { type: 'string' }, enforce: { type: 'string' }, adversary_impact: { type: 'string' } } } },
    adopted_new: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['finding_id', 'enforce', 'suggested'], properties: { ...FINDING_PROPS_REF, adversary_impact: { type: 'string' } } } },
  },
};
const CROSSFILE_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['consistency'],
  properties: { consistency: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['pattern_id', 'title', 'description', 'recommendation'], properties: {
    pattern_id: { type: 'string' }, title: { type: 'string' }, description: { type: 'string' },
    pattern_a: { type: 'object', additionalProperties: true }, pattern_b: { type: 'object', additionalProperties: true },
    recommendation: { type: 'string' }, reason: { type: 'string' },
  } } } },
};
const ARBITER_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['rule_id', 'file', 'verdict', 'reasoning'],
  properties: {
    rule_id: { type: 'string' }, file: { type: 'string' },
    verdict: { type: 'string', enum: ['confirmed', 'refuted', 'uncertain'] },
    corrected_enforce: { type: 'string', enum: ['must-fix', 'should-fix', 'consider'] },
    reasoning: { type: 'string' },
  },
};
const ADOPTION_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['adoption_opportunities'],
  properties: {
    adoption_opportunities: { type: 'array', items: { type: 'object', additionalProperties: false,
      required: ['new_abstraction', 'introduced_by', 'candidates'],
      properties: {
        new_abstraction: { type: 'string', description: 'the reusable test abstraction the changeset added (Stub*/Fake* class, builder, shared fixture) — path or class name' },
        introduced_by: { type: 'string', description: 'the reviewed changeset file that introduces/defines it' },
        candidates: { type: 'array', items: { type: 'object', additionalProperties: false,
          required: ['path', 'method', 'rule_ref', 'note'],
          properties: {
            path: { type: 'string', description: 'a changeset peer file (must be one of the reviewed files)' },
            method: { type: 'string' },
            rule_ref: { type: 'string', description: 'UNIT-003 | DESIGN-009 | DESIGN-004 etc.' },
            note: { type: 'string' },
          } } },
      } } },
  },
};

// ---------------------------------------------------------------------------
// Rule-catalog parsing + per-wave selection.
// The rendered catalog is "# <ID> — <Title>\n<meta>\n<meta>\n\n<body>" blocks
// joined by "\n\n---\n\n". Split on the rule HEADING (not bare "---": a rule
// body can contain a horizontal rule), so a finding-referenced subset never
// gets half a rule. Each rule's metadata (review unit / categories / scoped
// review / enforce) is parsed from its header lines for in-script scoping.
// ---------------------------------------------------------------------------
function parseCatalog(full) {
  const lines = full.split('\n');
  const headRe = /^#\s+([A-Z]+-\d+)\s+—\s+/;
  const blocks = [];
  let cur = null;
  for (const line of lines) {
    const m = line.match(headRe);
    if (m) {
      if (cur) blocks.push(cur);
      cur = { id: m[1], lines: [line] };
    } else if (cur) {
      cur.lines.push(line);
    }
  }
  if (cur) blocks.push(cur);
  const byId = new Map();
  const order = [];
  for (const b of blocks) {
    // Drop a trailing drop-separator ("---") that belongs between rules.
    let text = b.lines.join('\n').replace(/\n+\s*---\s*$/, '').replace(/\s+$/, '');
    const reviewUnit = (text.match(/Review unit:\s*([a-z-]+)/) || [])[1] || '';
    const categories = ((text.match(/Categories:\s*([^|\n]+)/) || [])[1] || '').split(',').map((s) => s.trim()).filter(Boolean);
    const scopedReview = (text.match(/Scoped review:\s*([a-z]+)/) || [])[1] || '';
    const enforce = (text.match(/Enforce:\s*([a-z-]+)/) || [])[1] || '';
    byId.set(b.id, { id: b.id, text, reviewUnit, categories, scopedReview, enforce });
    order.push(b.id);
  }
  return { byId, order };
}
function joinRules(entries) { return entries.map((e) => e.text).join('\n\n---\n\n'); }
function rulesByIds(catalog, ids) {
  const seen = new Set();
  const out = [];
  for (const id of catalog.order) {
    if (ids.has(id) && catalog.byId.has(id) && !seen.has(id)) { seen.add(id); out.push(catalog.byId.get(id)); }
  }
  return joinRules(out);
}
// Wave-0 reviewer package: review_unit membership (null = all) + scoped_review.
function trackRules(catalog, reviewUnits, scoped) {
  const out = [];
  for (const id of catalog.order) {
    const r = catalog.byId.get(id);
    if (reviewUnits && !reviewUnits.includes(r.reviewUnit)) continue;
    if (scoped && r.scopedReview === 'exclude') continue;
    out.push(r);
  }
  return joinRules(out);
}
// Wave-2 red-team package: the full catalog. Category-scoping the adversary catalog is a
// dead lever (it barely shrinks the catalog); the per-file scope, not the rule subset, is
// what bounds adversary size.
function allRules(catalog) { return joinRules(catalog.order.map((id) => catalog.byId.get(id))); }
// Degraded re-spawn payload: rule headers (ID + title) only, no bodies — a compact index
// for an adversary whose full-catalog prompt overflowed.
function compactCatalog(catalog) { return catalog.order.map((id) => catalog.byId.get(id).text.split('\n')[0]).join('\n'); }

// ---------------------------------------------------------------------------
// Decomposition: per-file track + units (reviewer-allocation.md).
// ---------------------------------------------------------------------------
function combinedLines(file) { return (file.test_lines || 0) + (file.source_lines || 0); }
// Narrow diff: a scoped run touching few methods relative to the class. Drives the
// whole-class→digest downgrade and the adversary read-scope note — the fixed per-file
// overhead must scale down when the diff did not touch most of the file.
function narrowOf(file) {
  const scoped = (file.methods || []).length > 0;
  return scoped && file.methods.length <= Math.max(3, Math.ceil((file.test_methods.length || 1) / 4));
}
function trackOf(file, c = C) {
  const L = combinedLines(file);
  if (L <= T) return { track: 'A', wholeClass: 'n/a' };
  if (L <= c) return { track: 'B', wholeClass: 'fused' };
  return { track: 'B', wholeClass: 'digest-escape' };
}
function shardMethods(methods, max) {
  const n = methods.length;
  if (n === 0) return [[]];
  const count = Math.ceil(n / max);
  const size = Math.ceil(n / count);
  const out = [];
  for (let i = 0; i < n; i += size) out.push(methods.slice(i, i + size));
  return out;
}
// Coarsen shards so total reviewers stay <= U_file (reviewer-allocation.md formula).
function effectiveShards(scopedMethods, m = M) {
  const shardCap = Math.floor((U_file - 3) / 3); // 5 at seed constants
  const Meff = Math.max(m, Math.ceil(scopedMethods / shardCap));
  return { Meff };
}
function buildUnits(file) {
  const catalog = catalogFor(file);
  const dec = trackOf(file);
  const scoped = (file.methods || []).length > 0;
  if (dec.track === 'A') {
    return [{
      ukey: file.path, fileId: file.path, type: 'trackA', track: 'A',
      reviewUnits: null, scopedReview: scoped,
      methodScope: scoped ? file.methods.join(', ') : 'full class',
      rules: trackRules(catalog, null, scoped),
    }];
  }
  const inScope = scoped ? file.methods : file.test_methods;
  const { Meff } = effectiveShards(inScope.length);
  const shards = shardMethods(inScope, Meff);
  const units = [];
  shards.forEach((m, i) => {
    units.push({
      ukey: `${file.path}#m${i}`, fileId: file.path, type: 'method', track: 'B',
      reviewUnits: ['method'], scopedReview: scoped,
      methodScope: m.length ? m.join(', ') : 'all test methods',
      rules: trackRules(catalog, ['method'], scoped),
    });
  });
  // Diff-scoped narrowing: on a narrow diff the fused whole-class pass does not pay for
  // itself — downgrade to the digest track when a digest is available (extraction computes
  // one above the fixed 800-line floor; below it the fused unit stays).
  const narrowDigest = narrowOf(file) && typeof file.digest === 'string' && file.digest.trim().length > 0;
  if (dec.wholeClass === 'fused' && !narrowDigest) {
    units.push({
      ukey: `${file.path}#wc`, fileId: file.path, type: 'wholeclass', track: 'B',
      reviewUnits: ['class-structure', 'class-bodies'], scopedReview: false,
      methodScope: scoped ? `full class (findings filtered to: ${file.methods.join(', ')})` : 'full class (cross-method + structure)',
      rules: trackRules(catalog, ['class-structure', 'class-bodies'], false),
    });
  } else {
    // L > C (digest-escape) or narrow diff with a digest: class-structure digest only
    // (no body read); class-bodies skipped.
    units.push({
      ukey: `${file.path}#digest`, fileId: file.path, type: 'digest', track: 'B',
      reviewUnits: ['class-structure'], scopedReview: false,
      methodScope: 'class-structure digest (no bodies)',
      rules: trackRules(catalog, ['class-structure'], false),
    });
  }
  return units;
}
function projForFile(file) { return buildUnits(file).length * SLOTS; }
// Catalog-free unit COUNT for a hypothetical preset (c, m) — the dry-run projection.
// Mirrors buildUnits' unit shape (Track A = 1; Track B = method-shards + 1 whole-class/
// digest) without attaching rules. Keep in lockstep with buildUnits: same trackOf,
// effectiveShards, and shardMethods, so the count matches the real run exactly.
function projectUnits(file, c, m) {
  if (trackOf(file, c).track === 'A') return 1;
  const inScope = (file.methods || []).length > 0 ? file.methods : file.test_methods;
  const { Meff } = effectiveShards(inScope.length, m);
  return shardMethods(inScope, Meff).length + 1;
}

// Greedy sequential chunk partition by per-file reviewer projection (<= G each).
function chunkFiles(files) {
  const chunks = [];
  let cur = [], curN = 0;
  for (const f of files) {
    const p = projForFile(f);
    if (cur.length && curN + p > G) { chunks.push(cur); cur = []; curN = 0; }
    cur.push(f); curN += p;
  }
  if (cur.length) chunks.push(cur);
  return chunks;
}

// ---------------------------------------------------------------------------
// Finding clustering + consensus merge (per unit, then per file).
// ---------------------------------------------------------------------------
// Normalize an LLM-emitted method name to a bare identifier before matching the diff-parsed changed
// set — an exact-string mismatch (testFoo() vs testFoo) would silently invert branch_touched.
function methodId(m) { return String(m || '').replace(/\s*\(.*$/, '').trim(); }

// ---------------------------------------------------------------------------
// Finding identity — a finding IS the defect it describes, never the line it sits on:
// `${rule_id}|${method}|${fingerprint of current}`. Line numbers take no part in it, in
// either direction: two reviewers reporting one defect at :43 and :47 must not split into
// two findings, and two different defects under one rule in one method must not merge into
// one and borrow each other's votes. The fingerprint runs over whitespace-normalized text,
// so re-indentation between two stances is not a new defect; `summary` stands in where a
// stance quoted no `current`.
// ---------------------------------------------------------------------------
function normText(s) { return String(s == null ? '' : s).replace(/\s+/g, ' ').trim(); }
// FNV-1a, 32-bit. Self-contained and stable across processes, which the stage boundary
// needs: the adversarial stage re-reads ids a review run wrote to disk, in another run.
function stableHash(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
  return h.toString(16).padStart(8, '0');
}
function deriveFindingId(f, ctx) {
  if (!f || typeof f !== 'object') throw new Error(`Finding is not an object — ${ctx}: ${JSON.stringify(f)}`);
  const ruleId = String(f.rule_id == null ? '' : f.rule_id).trim();
  if (!ruleId) throw new Error(`Finding carries no rule_id, so no identity can be derived — ${ctx}: ${JSON.stringify(f)}`);
  const basis = normText(f.current) || normText(f.summary);
  if (!basis) throw new Error(`Finding ${ruleId} carries neither current nor summary, so no identity can be derived — ${ctx}`);
  return `${ruleId}|${methodId(f.method) || 'class-level'}|${stableHash(basis)}`;
}
// Stamp identity where agent output enters the run. A quoted id wins over a derived one:
// it is this workflow's own id handed to the agent and quoted back, so a stance that
// restated the finding's text in its own words stays the same finding.
function ingestFinding(f, ctx) {
  const quoted = (f && typeof f.finding_id === 'string') ? f.finding_id.trim() : '';
  f.finding_id = quoted || deriveFindingId(f, ctx);
  return f;
}
function ingestFindings(list, ctx) { for (const f of (list || [])) ingestFinding(f, ctx); return list; }
// A back-reference (a withdrawal, a challenge, a resurrection) carries no code to derive
// from — its id is the only thing tying it to a finding, so a missing one is a broken
// contract, never an entry to skip past.
function requireFindingId(e, ctx) {
  const id = (e && typeof e.finding_id === 'string') ? e.finding_id.trim() : '';
  if (!id) throw new Error(`Missing finding_id — ${ctx}: ${JSON.stringify(e)}`);
  return id;
}
function assertFindingIds(list, ctx) { for (const e of (list || [])) requireFindingId(e, ctx); return list; }
function normEnforce(e) {
  const x = String(e || '').toLowerCase();
  if (x.includes('must') || x.includes('critical') || x.includes('error')) return 'must-fix';
  if (x.includes('should') || x.includes('warn')) return 'should-fix';
  return 'consider';
}
function sevRank(e) { const n = normEnforce(e); return n === 'must-fix' ? 3 : (n === 'should-fix' ? 2 : 1); }
function shortTitle(s) { const t = String(s || '').split(/[.\n]/)[0].trim(); return t.length > 90 ? t.slice(0, 90) + '...' : (t || 'finding'); }
function majorityEnforce(items) {
  const tally = {};
  for (const it of items) { const n = normEnforce(it.enforce); tally[n] = (tally[n] || 0) + 1; }
  let best = 'should-fix', bestN = -1;
  for (const k of Object.keys(tally)) if (tally[k] > bestN || (tally[k] === bestN && sevRank(k) > sevRank(best))) { best = k; bestN = tally[k]; }
  return best;
}
const IMPACT_RANK = { introduced: 4, resurrected: 3, defended: 2, overturned: 2, unchanged: 1 };
function pickImpact(items) {
  let best = 'unchanged';
  for (const it of items) { const im = it.adversary_impact || 'unchanged'; if ((IMPACT_RANK[im] || 0) > (IMPACT_RANK[best] || 0)) best = im; }
  return best;
}
// ---------------------------------------------------------------------------
// Remediation preservation — a merged finding carries EVERY distinct remediation its
// stances proposed, longest first (the most complete one leads), duplicates collapsed
// under whitespace normalization. `owner` is the record behind the leading variant:
// title/summary/current/method/location all come from it, so `current` and `suggested`
// describe one change rather than two stances' halves. Both the raw stance shape
// (`suggested`/`location`) and the merged shape (`suggested_variants`/`locations`) feed
// in, so one merge serves the per-unit merge and the file-level union.
// ---------------------------------------------------------------------------
function variantsOf(r) {
  if (Array.isArray(r.suggested_variants)) return r.suggested_variants;
  return (r.suggested == null || String(r.suggested) === '') ? [] : [String(r.suggested)];
}
function locationsOf(r) {
  if (Array.isArray(r.locations)) return r.locations;
  return r.location ? [String(r.location)] : [];
}
// ---------------------------------------------------------------------------
// Deletion accounting rides through every merge the way `suggested_variants` does — a
// stance that named a deletion the winning variant's owner did not name still named it,
// and the after-state guard needs the union across the file's kept findings, not one
// stance's share of it. `deleted_methods` unions (a set of method names); the
// `{assertion, covered_by_test}` pairs of `removed_assertions` concatenate in first-seen
// order with exact duplicates collapsed under whitespace normalization, the same
// normalization `mergeRemediations` collapses remediations under. Method names run
// through `methodId` first: an LLM writing `testFoo()` and one writing `testFoo` name one
// method, and an unnormalized pair would both survive the union and reach the guard as an
// unmatched entry that accuses a finding of deleting a method that does not exist.
// ---------------------------------------------------------------------------
function mergeDeletionAccounting(records) {
  const methods = [];
  const assertions = [];
  const seenAssertion = new Set();
  for (const r of records) {
    for (const m of (Array.isArray(r.deleted_methods) ? r.deleted_methods : [])) {
      const id = methodId(m);
      if (id && !methods.includes(id)) methods.push(id);
    }
    for (const a of (Array.isArray(r.removed_assertions) ? r.removed_assertions : [])) {
      if (!a || typeof a !== 'object') continue;
      const assertion = String(a.assertion == null ? '' : a.assertion);
      const coveredBy = String(a.covered_by_test == null ? '' : a.covered_by_test);
      const key = `${normText(assertion)}|${normText(coveredBy)}`;
      if (key === '|' || seenAssertion.has(key)) continue;
      seenAssertion.add(key);
      assertions.push({ assertion, covered_by_test: coveredBy });
    }
  }
  return { deleted_methods: methods, removed_assertions: assertions };
}
function mergeRemediations(records) {
  const byNorm = new Map();
  for (const r of records) for (const s of variantsOf(r)) {
    const n = normText(s);
    if (n !== '' && !byNorm.has(n)) byNorm.set(n, { text: String(s), owner: r });
  }
  const ordered = [...byNorm.values()].sort((a, b) => b.text.length - a.text.length);
  const locations = [];
  for (const r of records) for (const loc of locationsOf(r)) if (loc && !locations.includes(loc)) locations.push(loc);
  // Where no stance proposed a remediation, nothing distinguishes the records, so the
  // first one carries the descriptive fields.
  return { owner: ordered.length ? ordered[0].owner : records[0], suggested_variants: ordered.map((o) => o.text), locations };
}
// The descriptive fields of a merged record come from the owner, so `current` and
// `suggested` describe one change. A record can own the leading remediation without
// carrying its own descriptive fields — a defender's `re_adopted`/`adopted_new` entry is
// schema-required to carry only finding_id/enforce/suggested — and such an owner cannot
// claim that invariant for a field it never supplied: each absent field falls back to the
// record the merge pairs it with (the resolved original, or the other side of a union)
// rather than being dropped.
// Absent means the property is missing or undefined, never an empty string. `current: ""`
// is the contract-valid state of a finding that quoted no code — the one the identity
// fingerprint falls back to `summary` for — and `method: ""` is the class-level locator
// `methodId` already reads it as. Treating either as absent would pair the owner's
// remediation with a different record's code, which is the invariant this helper exists for.
function fieldOf(owner, fb, key, whenAbsent) {
  if (owner[key] !== undefined) return owner[key];
  if (fb[key] !== undefined) return fb[key];
  return whenAbsent;
}
function descriptiveFrom(owner, fallback) {
  const fb = fallback || {};
  const summary = fieldOf(owner, fb, 'summary', '');
  return {
    // Derived from whichever summary won above, never taken from `fb`: the title always
    // describes the summary actually rendered.
    title: owner.title || shortTitle(summary),
    location: fieldOf(owner, fb, 'location', undefined),
    method: fieldOf(owner, fb, 'method', 'class-level'),
    summary,
    current: fieldOf(owner, fb, 'current', ''),
  };
}
// The merged core of one finding_id's stances: identity, the descriptive fields of the
// leading remediation's owner, every distinct remediation and location, the deletion
// accounting unioned across stances, the majority enforce level, and the src-change flag
// OR'd across stances (any reviewer escalates — an attention flag, not a consensus vote).
function coreRecord(findingId, ruleId, items) {
  const { owner, suggested_variants, locations } = mergeRemediations(items);
  return {
    finding_id: findingId, rule_id: ruleId,
    ...descriptiveFrom(owner, null), locations,
    ...mergeDeletionAccounting(items),
    enforce: majorityEnforce(items),
    suggested: suggested_variants[0] || '', suggested_variants,
    implies_src_change: items.some((it) => it.implies_src_change === true),
  };
}
// Merge ONE unit's stances ([{reviewer, findings}]) into {kept, contested}.
function mergeUnit(stances) {
  const alive = stances.filter(Boolean);
  const aliveCount = alive.length || SLOTS;
  const majority = Math.floor(aliveCount / 2) + 1;
  const labels = alive.map((s) => s.reviewer);
  const groups = new Map();
  alive.forEach((st) => {
    for (const f of (st.findings || [])) {
      const k = requireFindingId(f, `unit consensus merge (reviewer ${st.reviewer}, rule ${f.rule_id})`);
      if (!groups.has(k)) groups.set(k, { finding_id: k, rule_id: f.rule_id, items: [], reviewers: new Set() });
      const g = groups.get(k);
      g.items.push(f);
      g.reviewers.add(st.reviewer);
    }
  });
  const kept = [], contested = [];
  for (const g of groups.values()) {
    const votes = g.reviewers.size;
    const rec = {
      ...coreRecord(g.finding_id, g.rule_id, g.items),
      adversary_impact: pickImpact(g.items), arbitration: null, votes,
    };
    if (votes >= majority && votes >= 2) {
      rec.consensus = votes === aliveCount ? 'unanimous' : 'majority';
      if (rec.consensus === 'majority') {
        const omit = labels.filter((l) => !g.reviewers.has(l));
        rec.dissent = omit.length ? { reviewer: omit[0], reason: 'did not report this finding' } : null;
      } else { rec.dissent = null; }
      kept.push(rec);
    } else {
      rec.consensus = 'contested';
      rec.reported_by = [...g.reviewers];
      rec.outcome = `minority (${votes} of ${aliveCount}) — excluded from body`;
      contested.push(rec);
    }
  }
  return { kept, contested, aliveCount, reviewers: labels };
}
// Two units can reach the same finding (a class-level defect the whole-class pass and a
// method shard both see). Consensus strength stays that of the stronger unit; the
// remediation, and the descriptive fields that must agree with it, come from the leading
// variant across both — neither unit's remediation is dropped for being the loser.
// `base` donates every field except the merged remediation ones — so the file-level union
// keeps consensus strength from the stronger unit, and a defense-stage promotion keeps the
// fresh disposition (adversary_impact, consensus) rather than a stale one. `locations`
// ordering is independent of `base`: it is always first-seen (ingest order), never
// reshuffled by which record wins votes or supplies `suggested` — pass `locFirst`/
// `locSecond` when that ingest order differs from (base, other); it defaults to (base,
// other) for call sites where base already IS first-seen. A descriptive field the owner
// does not carry falls back to the other record rather than being dropped.
function unionRecords(base, other, locFirst = base, locSecond = other) {
  const { owner, suggested_variants } = mergeRemediations([base, other]);
  const locations = [];
  for (const r of [locFirst, locSecond]) for (const loc of locationsOf(r)) if (loc && !locations.includes(loc)) locations.push(loc);
  return {
    ...base,
    ...descriptiveFrom(owner, owner === base ? other : base), locations,
    // Deletion accounting reads the same first-seen pair `locations` does, for the same
    // reason: it is ingest order, never a function of which record won the disposition.
    ...mergeDeletionAccounting([locFirst, locSecond]),
    suggested: suggested_variants[0] || '', suggested_variants,
  };
}
// A promotion's finding_id may already be a live record — the id can already sit in `kept`
// (a defender re-cites a still-kept finding) or in `contested` (a withdrawal moved it there
// earlier in this same fold). Either way it is one finding, never a duplicate: merge its
// remediation into the surviving record, splicing the id out of `contested` when that is
// where it lived (a promotion to kept removes the same id from contested; an id already in
// kept never duplicates). `candidate` donates every non-remediation field — consensus and
// adversary_impact reflect the wave that just happened, not the stale pre-existing record —
// while `locations` still lists the pre-existing record's locations before the candidate's,
// first-seen order.
function reconcilePromotion(c, id, candidate) {
  const keptIdx = c.kept.findIndex((k) => k.finding_id === id);
  if (keptIdx >= 0) { c.kept[keptIdx] = unionRecords(candidate, c.kept[keptIdx], c.kept[keptIdx], candidate); return; }
  const contestedIdx = c.contested.findIndex((k) => k.finding_id === id);
  if (contestedIdx >= 0) {
    const existing = c.contested.splice(contestedIdx, 1)[0];
    c.kept.push(unionRecords(candidate, existing, existing, candidate));
    return;
  }
  c.kept.push(candidate);
}
// Union a file's per-unit merges into file-level {kept, contested}, deduped by finding_id.
// ONE accumulator per finding_id, fed in encounter order — unit by unit, and within a unit
// its kept records then its contested ones (a unit places one finding_id in exactly one of
// the two, so that inner order interleaves nothing). Aggregating the buckets separately and
// folding them together afterwards would group each id's locations by bucket instead: a
// finding seen contested, then kept, then contested again would read its two contested
// locations adjacently, which is not the order any reviewer met them in.
// Disposition is unchanged — consensus in ANY unit wins, so the first kept record takes over
// as `base` and donates votes, consensus strength and dissent; among kept records the higher
// vote count wins (a tie keeps the incumbent), among contested ones the incumbent stays. Only
// the merged remediation fields move: the losing unit's stances describe the SAME finding, so
// their remediations and locations union into the winner rather than being dropped with it.
function mergeFile(unitMerges) {
  const acc = new Map();
  for (const um of unitMerges) {
    for (const [bucket, records] of [['kept', um.kept], ['contested', um.contested]]) {
      for (const r of records) {
        const key = requireFindingId(r, `file-level union of ${bucket} findings`);
        const prev = acc.get(key);
        if (!prev) { acc.set(key, { bucket, record: r }); continue; }
        const incomingWins = prev.bucket === bucket
          ? (bucket === 'kept' && r.votes > prev.record.votes)
          : bucket === 'kept';
        acc.set(key, {
          bucket: (prev.bucket === 'kept' || bucket === 'kept') ? 'kept' : 'contested',
          // `locFirst`/`locSecond` stay (accumulated, incoming) in both branches: location
          // order is encounter order and never follows which record wins the disposition.
          record: incomingWins ? unionRecords(r, prev.record, prev.record, r) : unionRecords(prev.record, r),
        });
      }
    }
  }
  const kept = [], contested = [];
  for (const e of acc.values()) (e.bucket === 'kept' ? kept : contested).push(e.record);
  return { kept, contested };
}
function bucketFile(consensus, extraInformational) {
  const errors = [], warnings = [], informational = [];
  for (const k of consensus.kept) {
    const entry = {
      finding_id: requireFindingId(k, 'report entry'),
      rule_id: k.rule_id, title: k.title || shortTitle(k.summary), enforce: k.enforce, location: k.location, locations: locationsOf(k), method: k.method || 'class-level',
      consensus: k.consensus || 'majority', adversary_impact: k.adversary_impact || 'unchanged',
      arbitration: k.arbitration || null, current: k.current || '', suggested: k.suggested || '', suggested_variants: variantsOf(k),
      summary: k.summary || '', dissent: k.dissent || null, implies_src_change: k.implies_src_change === true,
      // What applying this finding removes — the union the after-state guard passes to
      // assert_surviving_tests, and the per-assertion survivor list a reader checks.
      ...mergeDeletionAccounting([k]),
    };
    if (k.enforce === 'must-fix') errors.push(entry);
    else if (k.enforce === 'should-fix') warnings.push(entry);
    else informational.push(entry);
  }
  for (const inf of (extraInformational || [])) informational.push(inf);
  const status = errors.length ? 'ISSUES_FOUND' : ((warnings.length || informational.length) ? 'NEEDS_ATTENTION' : 'PASS');
  return { errors, warnings, informational, status };
}

// ===========================================================================
// Prompt builders — per-role prompt text (owned here).
// ===========================================================================
const GUARD = [
  'You are a READ-ONLY reviewer in a multi-agent consensus review of Shopware PHPUnit tests (unit, integration, or migration).',
  'UNIVERSAL GUARDRAILS:',
  '- Read-only. Do NOT modify files, apply fixes, or run PHPStan/PHPUnit/ECS.',
  '- The ## RULES block at the end of this prompt is COMPLETE and scoped to your task — it holds every rule you must evaluate, and there is nothing more to fetch. Apply its detection algorithms against the code. You MUST Read/Grep the test file and its source class. You must NEVER read, open, search, or locate any rule file by any means: no Read/Grep/Glob of a rules directory or rendered package, no cat/grep/ugrep/find/bfs via Bash, no get_rules and no build_rule_package call. Reaching for a rule file is a defect, never a fallback.',
  '- Calibrated honesty. Report a finding ONLY when a rule detection algorithm fires on real code you read. If the unit is clean under your lens, say so plainly. Do not manufacture findings to look thorough; do not wave real ones through to look agreeable.',
  '- Cite real evidence: every finding names a real file:line you read and the rule clause it triggers. Never fabricate rule IDs, locations, or code.',
  '- Every finding names its `method` — the test method it occurs in (e.g. testFoo), or "class-level" for whole-class/structural concerns — and sets `implies_src_change` true ONLY when the fix cannot be made in the test alone (it requires changing production src/ code); default false.',
  '- A finding whose fix REMOVES test code accounts for what it removes: `deleted_methods` lists by bare name (testFoo, never testFoo()) every test method the fix deletes outright, and `removed_assertions` carries one {assertion, covered_by_test} per assertion the fix drops, where covered_by_test names the surviving test that still covers it or is the literal "none — coverage lost". Both default to []. Naming a deletion you cannot pair with a survivor is the honest answer, never a reason to omit the field.',
  '- Respect scope: judge only the methods named in your scope and their #[DataProvider] providers; when the scope says full class, review the whole class.',
  '- Emit exactly ONE short visible line (a finding tally) alongside your structured output. No other prose.',
].join('\n');

// Per-type reviewing sub-skill; reconciling + adversarial are shared and type-neutral.
function reviewSkillFor(testType) { return `test-writing:phpunit-${testType}-test-reviewing`; }
const RECONCILE_SKILL = 'test-writing:phpunit-test-reconciling';
const ADVERSARIAL_SKILL = 'test-writing:phpunit-test-adversarial-reviewing';
function sourcesOf(file) { return (Array.isArray(file.source_paths) && file.source_paths.length) ? file.source_paths.join(', ') : file.source_path; }

function reviewerPrompt(unit, file, label) {
  const isDigest = unit.type === 'digest';
  const lensLine = unit.type === 'method'
    ? 'You are reviewing ONLY the listed methods and their data providers (review_unit=method). Ignore cross-method and class-structure concerns — another track owns those.'
    : unit.type === 'wholeclass'
      ? 'You are reviewing class-structure + cross-method (class-bodies) concerns over the FULL class. Per-single-method-body findings belong to the method track; focus on structure, ordering, redundancy across methods, data-provider consolidation, duplicated arrange.'
      : isDigest
        ? 'You are reviewing the class-structure DIGEST only (Digest Mode). The class-bodies rules are NOT evaluated for this file (it exceeds the cross-body limit C). If the digest shows the class is too large to review whole, note "split this test class".'
        : 'You are reviewing the FULL class against ALL rule groups (Track A).';
  const catLine = file.test_type === 'unit'
    ? 'Set category to the detected unit source-class category A–E.'
    : 'Set category to "n/a" (only unit tests carry an A–E category).';
  return [
    GUARD,
    '',
    `## ROLE: Wave 0 independent reviewer "${label}" for unit [${unit.ukey}].`,
    `Test type: ${file.test_type}`,
    `Test file: ${file.path}`,
    `Source class(es) (#[CoversClass]): ${sourcesOf(file)}`,
    `review_unit: ${unit.reviewUnits ? unit.reviewUnits.join(', ') : 'none (all rule groups)'}`,
    `Method scope: ${unit.methodScope}`,
    '',
    `STEP 1 — Invoke the Skill tool with skill="${reviewSkillFor(file.test_type)}".`,
    isDigest
      ? 'Provide to the sub-skill: the source class path, review_unit=class-structure, and digest="<the digest text below>". Review the DIGEST text in this prompt — do NOT Read the test file (reading the bodies defeats the escape). rules = the verbatim ## RULES text below (Inline-Rules Mode; the sub-skill must NOT call get_rules).'
      : 'Provide to the sub-skill: the test file path, the source class path(s), review_unit as above, the method scope as above, and rules = the verbatim ## RULES text below (Inline-Rules Mode; the sub-skill must NOT call get_rules).',
    lensLine,
    isDigest ? '\nSTRUCTURAL DIGEST (review this; do not Read the test file):\n```\n' + (file.digest || '') + '\n```' : '',
    '',
    `STEP 2 — Return your findings strictly as the output schema. ${catLine} If the sub-skill produces an informational placement hint (e.g. the INTEGRATION-008 unit-shape smoke check), include it in findings with enforce="consider" and its rule_id, so it reaches the consensus merge — the schema has no separate informational channel. Set clean=true with findings=[] if nothing fires.`,
    '',
    '## RULES',
    unit.rules,
  ].join('\n');
}

function adversaryImpressionPrompt(file, lens, label) {
  return [
    `You are a READ-ONLY adversary forming an INDEPENDENT impression of ONE Shopware PHPUnit ${file.test_type} test.`,
    '- Read-only. Do NOT modify files or run any tool beyond reading code. For IMPRESSIONS you do NOT use rules, get_rules, or any rule file — form intuitive concerns.',
    '',
    `## ROLE: Wave 0 adversary "${label}" — ${lens.name} — forming an impression (no consensus exposure yet, no rule catalog).`,
    'Read the test file and its source class(es), then apply your lens:',
    lens.impression,
    'Plus the universal adversary instinct: "would I be surprised if this test passed while the behaviour broke?"',
    'Do NOT invoke any skill or get_rules. Return concerns for this ONE file as the schema (files array with a single entry: file_path, concerns[].area, concerns[].severity).',
    '',
    'Assigned file (test → source):',
    `- ${file.path}  →  ${sourcesOf(file)}`,
    ...(narrowOf(file) ? ['', `Diff scope: the changeset touched only ${file.methods.join(', ')}. Focus your reading on these methods, their data providers, and the class structure; do not exhaustively review untouched methods.`] : []),
  ].join('\n');
}

function reconcilePrompt(unit, file, label, own, peers, subsetRules) {
  return [
    GUARD,
    '',
    `## ROLE: Wave 1 PEER reconciler "${label}" for unit [${unit.ukey}] of ${file.path}.`,
    `STEP 1 — Invoke the Skill tool with skill="${RECONCILE_SKILL}" in PEER mode.`,
    'Weigh your own current findings against your peers\' findings on this same unit. Maintain a finding only if its detection algorithm truly fires; withdraw it (with a reason) if a peer\'s argument or the code shows it does not. Adopt a peer finding you now agree with.',
    'Every finding below carries a `finding_id`. Quote it verbatim on each finding you maintain, adopt, or withdraw — it is how the merge knows which finding you mean. Never invent, alter, or omit one.',
    'The ## RULES block holds only the rules your and your peers\' findings cite. Look up any contested rule by ID there; do NOT call get_rules.',
    '',
    `YOUR current findings:\n${JSON.stringify(own, null, 1)}`,
    '',
    `PEERS' current findings on this unit:\n${JSON.stringify(peers, null, 1)}`,
    '',
    'STEP 2 — Return your revised binding stance (findings + withdrawn) as the schema.',
    '',
    '## RULES',
    subsetRules,
  ].join('\n');
}

function redTeamPrompt(pkg, impression, lens, label, rulesText, degraded) {
  return [
    GUARD,
    '',
    `## ROLE: Wave 2 RED TEAM adversary "${label}" — ${lens.name}. Challenge the preliminary consensus on ONE file.`,
    `STEP 1 — Invoke the Skill tool with skill="${ADVERSARIAL_SKILL}".`,
    lens.redteam,
    degraded
      ? 'DEGRADED RE-SPAWN: a prior attempt overflowed the context window. Read ONLY the cited finding locations (not the whole file), and the ## RULES block below is a COMPACT index (rule ID + title per line, no bodies) — apply the rules you know by ID; do NOT fetch rule bodies.'
      : 'Use the consensus package + your Wave-0 impression. Challenge weak findings, resurrect prematurely-withdrawn findings with code evidence, introduce findings the panel missed (each with a real detection-algorithm citation), and endorse the ones that are solid. The ## RULES block is the full catalog; select rules from it by ID — do NOT call get_rules.',
    'Every consensus and withdrawn finding in the package carries a `finding_id`. Quote it verbatim on each challenge and each resurrection — never invent or alter one. A finding you introduce is new and carries no `finding_id`.',
    '',
    `Consensus package (consensus_findings, withdrawn_findings, reconciliation_record):\n${JSON.stringify(pkg, null, 1)}`,
    '',
    `Your Wave-0 impression (this lens):\n${JSON.stringify(impression, null, 1)}`,
    '',
    'STEP 2 — Return challenges/resurrections/new_findings/endorsements/cross_file_inconsistencies for this ONE file as the schema (files array with a single entry).',
    '',
    '## RULES',
    rulesText,
  ].join('\n');
}

function defensePrompt(file, label, consensus, challenges, subsetRules) {
  return [
    GUARD,
    '',
    `## ROLE: Wave 3 DEFENSE reconciler "${label}" for ${file.path}.`,
    `STEP 1 — Invoke the Skill tool with skill="${RECONCILE_SKILL}" in ADVERSARY mode.`,
    'Defend each consensus finding the adversary challenged (keep it only if the detection algorithm still holds), withdraw any the challenge overturned, re-adopt any resurrected finding the evidence supports, and adopt any adversary-introduced finding the majority should accept. Tag every entry with an adversary_impact. The ## RULES block holds only the rules under dispute; look up by ID — do NOT call get_rules.',
    'Every finding, challenge, and resurrection in the payloads below carries a `finding_id`. Quote it verbatim on each withdrawal, re-adoption, maintained finding, and adopted adversary finding — never invent or alter one.',
    '',
    `Current consensus findings for this file:\n${JSON.stringify(consensus, null, 1)}`,
    '',
    `Adversary challenges/resurrections/new_findings for this file:\n${JSON.stringify(challenges, null, 1)}`,
    '',
    'STEP 2 — Return revised stance as the schema.',
    '',
    '## RULES',
    subsetRules,
  ].join('\n');
}

function crossFilePrompt(fingerprints, advSignals, axis) {
  return [
    'You are the cross-file consistency agent and the SOLE producer of cross-file findings.',
    '- Read-only. You may Read or Grep files to confirm a divergence or check a repo-wide distribution, but do NOT call get_rules or open any rule file.',
    '',
    `## ROLE: Cross-file consistency agent${axis ? ` (pattern axis: ${axis})` : ''}. Detect pattern DIVERGENCE across the reviewed test suite from the fingerprints below.`,
    'The suite may mix test_type=unit, integration, and migration (each fingerprint carries its test_type and the source_paths it covers). Compare these structural axes across files: setUp strategy, mock strategy (createMock vs createStub), assertion style (static::assert* is the convention), data-provider usage, ID management (IdsCollection vs raw Uuid::randomHex), and attribute usage/ordering. Assertion style (static::assert*) and expectation style ($this->expect*) are INDEPENDENT families — $this->expect*() is the correct PHPUnit convention; never report it as drift toward static::.',
    'Pay attention to CROSS-TYPE drift: a convention that diverges across the unit/integration boundary (ID management, fixture conventions) is a high-value consistency finding. Report a divergence only where a clear majority follows one pattern and a minority diverges. GROUND every "the convention is X" claim: the reviewed files are a SAMPLE, not the repository — before asserting a pattern is the project norm, verify it with a repo-wide check (Grep for both patterns and compare counts) or frame the finding as sample-local ("within these N reviewed files"). Do not assert a repo-wide norm the sample cannot establish, and never recommend aligning the majority onto a minority pattern. Consistency findings are warnings. If the suite is uniform, return consistency=[].',
    '',
    `Per-file fingerprints (path, test_type, track, source_paths, fingerprint):\n${JSON.stringify(fingerprints, null, 1)}`,
    '',
    `Adversary-surfaced candidate cross-file signals:\n${JSON.stringify(advSignals, null, 1)}`,
  ].join('\n');
}

function adoptionPrompt(changesetFiles) {
  return [
    'You are the changeset adoption-opportunity agent. The changeset under review introduced new test code; surface where a NEW reusable test abstraction it added could simplify an UNTOUCHED peer test in the SAME changeset.',
    '- Read-only. You may Read or Grep the reviewed files (and a Stub/Fake/builder they reference) to confirm an opportunity. Do NOT call get_rules or open any rule file.',
    '',
    '## ROLE: Adoption signal (informational, never a must-fix). Scope is STRICTLY the changeset files listed below — never the wider repository.',
    'A reusable test abstraction is a Stub*/Fake* class, a builder, or a shared fixture the changeset adds. For each one a changeset file introduces or newly references, find peer methods IN THE LISTED FILES whose current shape it would simplify:',
    '- an inline createMock(...) chain a new Stub* would replace (UNIT-003),',
    '- duplicated inline arrange a new builder/fixture would collapse (DESIGN-009),',
    '- near-duplicate construction a shared fixture would unify (DESIGN-004 / DESIGN-009).',
    'Prefer abstractions that appear in DIFF-TOUCHED regions (the listed changed_methods / new code) — a pre-existing helper a reviewed file merely uses is NOT a changeset-introduced opportunity, do not surface it. If nothing qualifies, return adoption_opportunities=[]. This is informational only: it never raises status and is never a must-fix on code the developer did not touch.',
    '',
    `Changeset files (path, test_type, source_paths, fingerprint, changed_methods = diff-touched):\n${JSON.stringify(changesetFiles, null, 1)}`,
  ].join('\n');
}

function arbiterPrompt(finding, file, ruleText) {
  return [
    GUARD,
    '',
    `## ROLE: Arbiter. Settle ONE contested finding on the evidence alone for ${file.path}.`,
    'Re-read the cited test code and its source class. The ## RULES block holds ONLY the single contested rule — find it by ID and apply its detection algorithm. Decide confirmed | refuted | uncertain, and give corrected_enforce if the level should change. Do NOT call get_rules or open any rule file.',
    '',
    `Contested finding:\n${JSON.stringify(finding, null, 1)}`,
    '',
    '## RULES',
    ruleText,
  ].join('\n');
}

// ===========================================================================
// Re-spawn wrapper (error-handling.md): ONE retry for a dead agent, re-pinning
// model + agentType + schema (never inherit). agent() returns null on a terminal
// death without exposing the error class, so the single retry sends the DEGRADED
// payload when opts.degrade is given (finding-localized reads + compact catalog) —
// a transient stall recovers on it, and a deterministic overflow gets the payload
// that can fit, turning a residual overflow into a degraded-but-present agent.
// STORM SUPPRESSION: a usage-limit storm kills every agent instantly; each retry
// then burns an agent-cap slot at zero value (measured: 852 dead retries in one
// run). After STORM_NULLS consecutive terminal nulls, retries are skipped — the
// wave-level circuit breaker halts the run at the next wave boundary.
// ===========================================================================
// Each agent() call (every retry included) is one on-disk transcript, so counting them is
// the true fan-out — surfaced because the reviewer-only figure understated it ~3-5x.
let agentsSpawned = 0;
let stormNulls = 0;   // consecutive terminal nulls across the run — the storm signal
const HALT = { halted: false, at: null, nulls: 0, of: 0 };
async function spawn(promptText, opts) {
  for (let attempt = 0; attempt <= RESPAWN_MAX; attempt++) {
    if (HALT.halted) return null;                              // breaker tripped: drain without spawning
    if (attempt > 0 && stormNulls >= STORM_NULLS) return null; // storm: a retry is a guaranteed dead agent
    const prompt = attempt === RESPAWN_MAX && opts.degrade ? opts.degrade() : promptText;
    agentsSpawned++;
    const res = await agent(prompt, {
      label: attempt ? `${opts.label}#retry${attempt}` : opts.label,
      phase: opts.phase, model: opts.model, agentType: opts.agentType, schema: opts.schema,
    });
    if (res) { stormNulls = 0; return res; }
    stormNulls++;
    if (attempt < RESPAWN_MAX) log(`Re-spawn ${opts.label}: attempt ${attempt + 1}/${RESPAWN_MAX} (agent died${opts.degrade && attempt + 1 === RESPAWN_MAX ? ', degrading payload' : ''})`);
  }
  log(`Re-spawn exhausted for ${opts.label} — degrading by role`);
  return null;
}

// ===========================================================================
// Wave-level circuit breaker: when a wave loses >= WAVE_NULL_RATE of its agents to
// terminal deaths (usage-limit storm, provider outage), continuing would (a) build
// consensus from degraded peer sets and journal downstream results keyed to those
// degraded prompts — poisoning every later resume with a cache-key-drift cascade —
// and (b) burn the remaining pipeline into the agent cap at zero value. Trip ->
// stop cleanly at the wave boundary; the run returns a structured PARTIAL result
// (never a silent success). The campaign driver relaunches the stage cleanly.
// ===========================================================================
function waveCheck(name, results) {
  const of = results.length;
  const nulls = results.filter((r) => r == null).length;
  if (!HALT.halted && of >= WAVE_NULL_MIN && nulls / of >= WAVE_NULL_RATE) {
    HALT.halted = true; HALT.at = name; HALT.nulls = nulls; HALT.of = of;
    log(`CIRCUIT BREAKER: ${name} lost ${nulls}/${of} agents to terminal deaths — halting at the wave boundary with a partial result`);
  }
  return results;
}
function partialResult(extra) {
  return {
    mode: MODE, partial: true,
    halted_at: { wave: HALT.at, dead_agents: HALT.nulls, wave_size: HALT.of },
    note: 'halted by the wave-level circuit breaker before consuming a degraded wave; results cover only work completed before the halt. Relaunch this stage cleanly — do not resume into a storm-poisoned journal (error-handling.md).',
    agents_spawned: agentsSpawned,
    ...extra,
  };
}

// ===========================================================================
// Build the plan + announce scope.
// ===========================================================================
// Dry-run projection — per-preset agent-count estimate, NO agents spawned. Returns
// before any catalog parsing (catalogs aren't needed). Waves 1/2/3 and arbitration/
// widening are runtime-conditional, so max_structural_agents is an upper bound.
if (DRY_RUN) {
  const projections = {};
  for (const [name, p] of Object.entries(PRESETS)) {
    const units = MANIFEST.reduce((s, f) => s + projectUnits(f, p.C, p.M), 0);
    const reviewersPerWave = units * SLOTS;
    const advPerWave = MANIFEST.length * p.lenses;
    projections[name] = {
      units,
      reviewers_per_wave: reviewersPerWave,           // Waves 0, 1 (review / reconcile)
      adversaries_per_wave: advPerWave,               // Wave-0 impressions (mode=review) / red team (mode=adversarial)
      wave0_agents: reviewersPerWave + advPerWave,    // always runs
      review_agents_bound: reviewersPerWave * 3 + advPerWave,                    // mode=review upper bound (waves 0-1 + 2nd pass + widening + impressions)
      adversarial_agents_bound: advPerWave + MANIFEST.length * SLOTS + p.arbMax * 3, // mode=adversarial upper bound (red team + defense + capped arbitration ×3 votes)
      max_structural_agents: reviewersPerWave * 3 + advPerWave * 2 + 1, // whole-pipeline upper bound across modes
      chunks: Math.max(1, Math.ceil(reviewersPerWave / G)),
      lenses: p.lenses,
      arbMax: p.arbMax,
      // Per-file shard weights for the skill's campaign partition (reviewer-allocation.md
      // §Shard Budget): weight = the file's share of review_agents_bound.
      per_file: MANIFEST.map((f) => { const u = projectUnits(f, p.C, p.M); return { path: f.path, units: u, weight: u * SLOTS * 3 + p.lenses }; }),
    };
  }
  log(`Dry run — projection only, no review agents spawned. files=${MANIFEST.length}`);
  return { dry_run: true, files: MANIFEST.length, slots: SLOTS, model_combos: Object.keys(MODEL_PRESETS), projections };
}

// One parsed catalog per test type — each type carries a different ruleset, so
// every wave selects a file's rules through `catalogFor`. mode=signals uses no rules.
const CATALOGS = new Map();
if (MODE !== 'signals') {
  for (const t of TYPES_PRESENT) {
    const c = parseCatalog(RULE_PACKAGES[t]);
    if (c.byId.size === 0) throw new Error(`Parsed 0 rules from rule_packages.${t} — rendered catalog format unrecognized`);
    CATALOGS.set(t, c);
  }
}
function catalogFor(file) { return CATALOGS.get(file.test_type); }

// Per-type red-team catalogs (the full catalog for each type; no category-scoping)
// + headers-only compact index for a degraded re-spawn. Red team runs in mode=adversarial.
const RED_TEAM_RULES = new Map();
const RED_TEAM_RULES_COMPACT = new Map();
if (MODE === 'adversarial') {
  for (const [t, c] of CATALOGS) { RED_TEAM_RULES.set(t, allRules(c)); RED_TEAM_RULES_COMPACT.set(t, compactCatalog(c)); }
}

// Fail-hard: an L > C file must carry a pre-extracted digest (review decomposes by digest).
if (MODE === 'review') {
  for (const f of MANIFEST) {
    if (trackOf(f).wholeClass === 'digest-escape' && (!f.digest || !String(f.digest).trim())) {
      throw new Error(`File exceeds C=${C} lines but no structural digest provided in manifest: ${f.path}`);
    }
  }
}

// One canonicalization point keeps every downstream join on a single identity and the
// report on clean repo-relative paths; re-normalizing at each join would be error-prone.
// Units are a review-mode concern: adversarial works per file, signals per fingerprint.
const FILES = MANIFEST.map((f) => {
  const nf = {
    ...f,
    path: normPath(f.path),
    source_path: normPath(f.source_path),
    baseline: f.baseline == null ? 'unavailable' : f.baseline,
    ...((Array.isArray(f.source_paths) && f.source_paths.length) ? { source_paths: f.source_paths.map(normPath) } : {}),
  };
  const base = { ...nf, ...trackOf(nf) };
  return MODE === 'review' ? { ...base, units: buildUnits(nf) } : base;
});
const TOTAL_UNITS = MODE === 'review' ? FILES.reduce((s, f) => s + f.units.length, 0) : 0;
const TOTAL_PROJ = TOTAL_UNITS * SLOTS;
const CHUNKS = MODE === 'review' ? chunkFiles(FILES) : [FILES];
const filesByType = {};
for (const f of FILES) filesByType[f.test_type] = (filesByType[f.test_type] || 0) + 1;
const typeCounts = TEST_TYPES.filter((t) => filesByType[t]).map((t) => `${t}×${filesByType[t]}`).join(', ');

if (MODE === 'review') {
  log(`Scope (mode=review): ${FILES.length} files (${typeCounts}) | ${TOTAL_UNITS} units | ${TOTAL_PROJ} Wave-0 reviewers (${SLOTS}/unit) | ${K_adv} impression adversar${K_adv === 1 ? 'y' : 'ies'}/file (lenses ${LENSES.map((l) => l.id).join('/')}) | ${CHUNKS.length} chunk(s) (G=${G}) | preset=${PRESET_NAME} T=${T} C=${C} M=${M} | models=${MODELS_NAME} (body=${MODEL_BODY}, adversary=${MODEL_ADVERSARY})${manifest.base ? ` | base=${manifest.base}` : ''}`);
  FILES.forEach((f) => log(`  ${f.test_type} Track ${f.track} ${f.path}: L=${combinedLines(f)} -> ${f.units.length} unit(s) [${f.wholeClass}]`));
} else if (MODE === 'adversarial') {
  log(`Scope (mode=adversarial): ${FILES.length} files (${typeCounts}) | ${K_adv} red-team adversar${K_adv === 1 ? 'y' : 'ies'}/file (lenses ${LENSES.map((l) => l.id).join('/')}) | arbMax=${ARB_MAX} arbFile=${ARB_FILE} | preset=${PRESET_NAME} | models=${MODELS_NAME} (body=${MODEL_BODY}, adversary=${MODEL_ADVERSARY}, arbiter=${MODEL_ADVERSARY}(must-fix×3)/${MODEL_BODY})${manifest.base ? ` | base=${manifest.base}` : ''}`);
} else {
  log(`Scope (mode=signals): ${FILES.length} files (${typeCounts}) | cross-file consistency${FILES.some((f) => Array.isArray(f.changed_methods)) ? ' + adoption signal' : ''} | F_cap=${F_cap}${manifest.base ? ` | base=${manifest.base}` : ''}`);
}

// Shared helpers across modes.
function outputTokensNow() {
  // budget.spent() is this turn's OUTPUT tokens, NOT the cache-inclusive billable total —
  // labelled honestly. Surfaced because the reviewer-only count understated real fan-out.
  return (typeof budget !== 'undefined' && budget && typeof budget.spent === 'function') ? budget.spent() : null;
}
// branch_touched: diff runs only — is the finding's method in the literal changed set? null on a
// non-diff run or a class-level finding (no method to scope).
function tagBranchFor(f) {
  const changedSet = Array.isArray(f.changed_methods) ? new Set(f.changed_methods.map(methodId)) : null;
  return (e) => { const mid = methodId(e.method); e.branch_touched = (changedSet && mid && mid !== 'class-level') ? changedSet.has(mid) : null; };
}
function contestedView(c, f) {
  const changedSet = Array.isArray(f.changed_methods) ? new Set(f.changed_methods.map(methodId)) : null;
  return c.contested.map((ct) => { const mid = methodId(ct.method); return ({ finding_id: requireFindingId(ct, 'contested entry'), rule_id: ct.rule_id, title: ct.title, enforce: ct.enforce, location: ct.location, locations: locationsOf(ct), method: ct.method || 'class-level', branch_touched: (changedSet && mid && mid !== 'class-level') ? changedSet.has(mid) : null, reported_by: ct.reported_by || [], reason: ct.summary || '', outcome: ct.outcome || '', current: ct.current || '', suggested_variants: variantsOf(ct), ...mergeDeletionAccounting([ct]), arbitration: ct.arbitration || null,
    // Same sourcing as the kept-record path (bucketFile): these already ride on `ct` from
    // mergeUnit/coreRecord — a contested record is the same `rec` shape as a kept one, only
    // routed to the other bucket — so the template can render Consensus/Provenance/Source
    // change for contested findings on the same terms as kept ones.
    consensus: ct.consensus || 'contested', adversary_impact: ct.adversary_impact || 'unchanged', implies_src_change: ct.implies_src_change === true }); });
}
// Escalation signal: findings whose fix needs a production (src/) change, not test-only.
// Informational — never raises status.
function srcChangeOf(fileResults) {
  return fileResults.flatMap((f) =>
    [...f.errors, ...f.warnings, ...f.informational, ...f.contested].filter((e) => e.implies_src_change)
      // contested entries carry the defect text as `reason`, not `summary` (contestedView) — fall back to it
      // so a contested finding's escalation row reads the same as a kept one's.
      .map((e) => ({ path: f.path, rule_id: e.rule_id, method: e.method, location: e.location, summary: e.summary ?? e.reason })));
}
function overallOf(fileResults) {
  const anyErrors = fileResults.some((f) => f.errors.length > 0);
  const anyWarn = fileResults.some((f) => f.warnings.length > 0 || f.informational.length > 0);
  return anyErrors ? 'ISSUES_FOUND' : (anyWarn ? 'NEEDS_ATTENTION' : 'PASS');
}

// Run-wide accumulators.
const adaptation = { extra_peer_pass_reviewers: 0, extra_reviewers_by_file: {}, arbiters: 0, arbiters_confirmed: 0, arbiters_refuted: 0, arbiters_split: 0, skipped_reconcile_units: 0 };
const allFileResults = [];

// ===========================================================================
// mode=review — Waves 0-1 + widening + consensus, per chunk. Red team, defense,
// arbitration, cross-file, and adoption run as their own later stages; this run
// ends at per-file consensus verdicts + the persisted adversarial_input payloads.
// ===========================================================================
if (MODE === 'review') {
// Pre-flight cap assert: refuse to start a run that cannot finish. Cached replays count
// toward the engine's 1000-agent lifetime cap, so an oversized run cannot be rescued by
// resuming — it must be sharded before launch (skill Phase 2 shard plan).
const reviewBound = TOTAL_PROJ * 3 + FILES.length * K_adv;
if (reviewBound > AGENT_BUDGET) {
  throw new Error(`mode=review projects up to ${reviewBound} agents > per-run budget ${AGENT_BUDGET} — shard the manifest (skill Phase 2 shard plan) instead of launching one oversized run`);
}

const consensusMetrics = { wave0_keys: 0, withdrawn: 0, kept_total: 0, contested_total: 0 };

for (let ci = 0; ci < CHUNKS.length && !HALT.halted; ci++) {
  const chunkFilesList = CHUNKS[ci];
  const chunkUnits = chunkFilesList.flatMap((f) => f.units.map((u) => ({ ...u, file: f })));
  if (CHUNKS.length > 1) log(`Chunk ${ci + 1}/${CHUNKS.length}: ${chunkFilesList.length} files, ${chunkUnits.length} units`);

  // ---- WAVE 0 — reviewers (3/unit) + adversary impressions (K lenses per file) ----
  phase('Wave 0: Review + impressions');
  // Per-file × per-lens adversary tasks: each adversary reads exactly ONE file (bounds the
  // read accumulation that overflowed), and each file gets K independent lens samples.
  const advTasks = chunkFilesList.flatMap((f) => LENSES.map((lens) => ({ file: f, lens })));

  const reviewerTasks = [];
  chunkUnits.forEach((unit) => { for (let n = 1; n <= SLOTS; n++) reviewerTasks.push({ unit, n, label: `reviewer-${n}` }); });

  const [wave0Reviews, wave0Impr] = await Promise.all([
    parallel(reviewerTasks.map((t) => () =>
      spawn(reviewerPrompt(t.unit, t.unit.file, t.label), {
        label: `rev:${t.unit.ukey}:${t.label}`, phase: 'Wave 0: Review + impressions', model: MODEL_BODY,
        agentType: TYPE_REVIEWER, schema: REVIEWER_SCHEMA,
      }).then((r) => (r ? { ukey: t.unit.ukey, fileId: t.unit.fileId, n: t.n, reviewer: t.label, ...r } : null)))),
    parallel(advTasks.map((t) => () =>
      spawn(adversaryImpressionPrompt(t.file, t.lens, `adversary-${t.lens.id}`), {
        label: `adv-impr:c${ci}:${t.file.path}:${t.lens.id}`, phase: 'Wave 0: Review + impressions', model: MODEL_ADVERSARY,
        agentType: TYPE_ADVERSARY, schema: ADV_IMPRESSION_SCHEMA,
      }).then((r) => (r ? { path: t.file.path, lens: t.lens.id, ...r } : null)))),
  ]);
  waveCheck('Wave 0: Review + impressions', [...wave0Reviews, ...wave0Impr]);
  if (HALT.halted) break;

  const reviewsByUnit = new Map();
  for (const r of wave0Reviews.filter(Boolean)) {
    ingestFindings(r.findings, `Wave-0 review of ${r.ukey} by ${r.reviewer}`);
    if (!reviewsByUnit.has(r.ukey)) reviewsByUnit.set(r.ukey, []);
    reviewsByUnit.get(r.ukey).push(r);
  }
  // Category per file (majority of the file's reviewers' reported category).
  const categoryByPath = new Map();
  for (const f of chunkFilesList) {
    const cats = {};
    for (const u of f.units) for (const r of (reviewsByUnit.get(u.ukey) || [])) if (r.category) cats[r.category] = (cats[r.category] || 0) + 1;
    let best = '?', bestN = -1;
    for (const k of Object.keys(cats)) if (cats[k] > bestN) { best = k; bestN = cats[k]; }
    categoryByPath.set(f.path, best);
  }

  // ---- WAVE 1 — peer reconciliation (gated: skip a unit if all 3 stances empty) ----
  phase('Wave 1: Peer reconciliation');
  const reconcileTasks = [];
  for (const unit of chunkUnits) {
    const stances = reviewsByUnit.get(unit.ukey) || [];
    const anyFindings = stances.some((s) => (s.findings || []).length > 0);
    if (!anyFindings) { adaptation.skipped_reconcile_units++; continue; }
    const unitIds = new Set();
    for (const s of stances) for (const f of (s.findings || [])) unitIds.add(f.rule_id);
    const subsetRules = rulesByIds(catalogFor(unit.file), unitIds);
    for (let n = 1; n <= SLOTS; n++) {
      const own = (stances.find((s) => s.n === n) || { findings: [] }).findings || [];
      const peers = stances.filter((s) => s.n !== n).flatMap((s) => s.findings || []);
      reconcileTasks.push({ unit, n, label: `reviewer-${n}`, own, peers, subsetRules });
    }
  }
  log(`Wave 1: ${adaptation.skipped_reconcile_units} unit(s) skipped (all-empty Wave-0) cumulative; ${reconcileTasks.length} reconcilers this chunk`);

  const wave1Raw = await parallel(reconcileTasks.map((t) => () =>
    spawn(reconcilePrompt(t.unit, t.unit.file, t.label, t.own, t.peers, t.subsetRules), {
      label: `recon:${t.unit.ukey}:${t.label}`, phase: 'Wave 1: Peer reconciliation', model: MODEL_BODY,
      agentType: TYPE_REVIEWER, schema: RECONCILE_SCHEMA,
    }).then((r) => (r ? { ukey: t.unit.ukey, n: t.n, reviewer: t.label, ...r } : null))));
  waveCheck('Wave 1: Peer reconciliation', wave1Raw);
  if (HALT.halted) break;
  const wave1 = wave1Raw.filter(Boolean);
  for (const w of wave1) {
    ingestFindings(w.findings, `Wave-1 stance on ${w.ukey} by ${w.reviewer}`);
    assertFindingIds(w.withdrawn, `Wave-1 withdrawal on ${w.ukey} by ${w.reviewer}`);
  }

  // Reconciliation record per unit (each reviewer's maintained findings + withdrawn-with-reasons),
  // for the red-team context package persisted per file. Captured from Wave 1, the primary peer
  // reconciliation; the second pass below (Adaptation 3) appends its own entries to this same map
  // once it runs, so a finding first withdrawn there folds into fileReconContext exactly like one
  // withdrawn in Wave 1 — RECONCILE_SCHEMA is the same schema for both passes.
  const reconByUnit = new Map();
  for (const w of wave1) {
    if (!reconByUnit.has(w.ukey)) reconByUnit.set(w.ukey, []);
    reconByUnit.get(w.ukey).push({ reviewer: w.reviewer, maintained: w.findings || [], withdrawn: w.withdrawn || [] });
  }
  // Assemble a file's red-team context: per-reviewer reconciliation_record (aggregated across the
  // file's units) + withdrawn_findings with who first reported each in Wave 0 and the withdrawal reason.
  // A finding every reviewer withdrew survives in neither kept nor contested, so the adversarial
  // stage would have nothing to resolve when a resurrection of it is re-adopted. The
  // identity-complete original is therefore persisted beside the withdrawal, keyed by finding_id
  // within this file's scope and merged across every stance that carried the finding before it
  // was withdrawn — the Wave-0 stances that first reported it AND the reconciler stances that
  // maintained it afterwards — so a re-adoption restores the finding the id names, with every
  // remediation proposed for it, instead of aborting the fold or restoring a stale one.
  const fileReconContext = (f) => {
    const record = [], withdrawnById = new Map(), withdrawnOriginals = new Map(), multiUnit = f.units.length > 1;
    for (const unit of f.units) {
      const reporters = new Map();   // finding_id -> Wave-0 reviewers who reported it
      const wave0ById = new Map();   // finding_id -> the Wave-0 stances that reported it
      for (const r of (reviewsByUnit.get(unit.ukey) || [])) for (const fn of (r.findings || [])) {
        const id = requireFindingId(fn, `Wave-0 reporter index for ${unit.ukey}`);
        if (!reporters.has(id)) reporters.set(id, new Set());
        reporters.get(id).add(r.reviewer);
        if (!wave0ById.has(id)) wave0ById.set(id, []);
        wave0ById.get(id).push(fn);
      }
      // finding_id -> the reconciler stances that maintained it. A reconciler restates the
      // finding in its own payload, which may carry a remediation Wave 0 never proposed; that
      // payload is the only copy of it once a later pass withdraws the finding outright.
      const reconById = new Map();
      for (const rec of (reconByUnit.get(unit.ukey) || [])) for (const m of (rec.maintained || [])) {
        const id = requireFindingId(m, `reconciler payload index for ${unit.ukey}`);
        if (!reconById.has(id)) reconById.set(id, []);
        reconById.get(id).push(m);
      }
      for (const rec of (reconByUnit.get(unit.ukey) || [])) {
        record.push({
          reviewer: rec.reviewer,
          ...(multiUnit ? { unit: unit.ukey } : {}),
          maintained: (rec.maintained || []).map((m) => ({ finding_id: m.finding_id, rule_id: m.rule_id, location: m.location })),
          withdrawn: (rec.withdrawn || []).map((w) => ({ finding_id: w.finding_id, rule_id: w.rule_id, reason: w.reason })),
        });
        for (const w of (rec.withdrawn || [])) {
          const id = requireFindingId(w, `withdrawal in the red-team package for ${f.path}`);
          if (!withdrawnById.has(id)) withdrawnById.set(id, { finding_id: id, rule_id: w.rule_id, originally_reported_by: [...(reporters.get(id) || [])], reason: w.reason });
          // The original is the finding's most-merged state at this fold, never its Wave-0
          // state alone: a reconciler that maintained the finding with a remediation of its
          // own proposed that remediation before the withdrawal, and once a later peer pass
          // withdraws the finding outright it survives nowhere else. Wave-0 stances lead
          // (first-seen order), the reconciler payloads for the same id follow.
          // The store is file-scoped and both indexes are per unit, so two units that both
          // withdrew this id each hold their own contributors for it. Merge rather than keep
          // the first: the second unit's remediations and locations belong to the same
          // finding, and a resurrection restoring only one unit's would lose the other's.
          // (Re-merging within one unit — one store per withdrawing reviewer over the same
          // stance objects — is idempotent: the variants and locations dedupe to what is
          // already there.)
          const contributors = [...(wave0ById.get(id) || []), ...(reconById.get(id) || [])];
          if (contributors.length) {
            const fresh = coreRecord(id, contributors[0].rule_id, contributors);
            const prev = withdrawnOriginals.get(id);
            withdrawnOriginals.set(id, prev ? unionRecords(prev, fresh) : fresh);
          }
        }
      }
    }
    return { withdrawn_findings: [...withdrawnById.values()], withdrawn_originals: [...withdrawnOriginals.values()], reconciliation_record: record };
  };

  // Binding stances per unit: Wave-1 stance if reconciled, else carry Wave-0 forward.
  const bindingByUnit = new Map();
  for (const unit of chunkUnits) {
    const recon = wave1.filter((w) => w.ukey === unit.ukey);
    if (recon.length > 0) bindingByUnit.set(unit.ukey, recon.map((w) => ({ reviewer: w.reviewer, findings: w.findings || [] })));
    else bindingByUnit.set(unit.ukey, (reviewsByUnit.get(unit.ukey) || []).map((s) => ({ reviewer: s.reviewer, findings: s.findings || [] })));
  }

  const unitMergeOf = (u) => mergeUnit(bindingByUnit.get(u.ukey) || []);
  const fileConsensus = () => chunkFilesList.map((f) => ({ path: f.path, ...mergeFile(f.units.map(unitMergeOf)) }));
  let consensus = fileConsensus();

  // ---- Adaptation point 3 — one extra peer-reconciliation pass on still-contested units ----
  // Max 2 passes total: a unit still carrying contested (non-unanimous) findings after the
  // Wave-1 merge reconciles once more, seeded with the updated Wave-1 stances. Settled units
  // (no contested findings) are left untouched, and there is no third pass.
  if (budgetOk()) {
    const pass2Tasks = [];
    for (const unit of chunkUnits) {
      const stances = bindingByUnit.get(unit.ukey) || [];
      if (stances.length < 2 || mergeUnit(stances).contested.length === 0) continue;
      const unitIds = new Set();
      for (const s of stances) for (const f of (s.findings || [])) unitIds.add(f.rule_id);
      const subsetRules = rulesByIds(catalogFor(unit.file), unitIds);
      stances.forEach((self) => {
        const peers = stances.filter((s) => s !== self).flatMap((s) => s.findings || []);
        pass2Tasks.push({ unit, reviewer: self.reviewer, own: self.findings || [], peers, subsetRules });
      });
    }
    if (pass2Tasks.length > 0) {
      const pass2Ukeys = new Set(pass2Tasks.map((t) => t.unit.ukey));
      log(`Adaptation 3: ${pass2Ukeys.size} unit(s) still contested after Wave 1 — second peer pass (${pass2Tasks.length} reconcilers)`);
      const wave1bRaw = await parallel(pass2Tasks.map((t) => () =>
        spawn(reconcilePrompt(t.unit, t.unit.file, t.reviewer, t.own, t.peers, t.subsetRules), {
          label: `recon2:${t.unit.ukey}:${t.reviewer}`, phase: 'Wave 1: Peer reconciliation', model: MODEL_BODY,
          agentType: TYPE_REVIEWER, schema: RECONCILE_SCHEMA,
        }).then((r) => (r ? { ukey: t.unit.ukey, ...r, reviewer: t.reviewer } : null))));
      waveCheck('Wave 1: Peer reconciliation (2nd pass)', wave1bRaw);
      if (HALT.halted) break;
      const wave1b = wave1bRaw.filter(Boolean);
      for (const w of wave1b) {
        ingestFindings(w.findings, `Wave-1 second-pass stance on ${w.ukey} by ${w.reviewer}`);
        assertFindingIds(w.withdrawn, `Wave-1 second-pass withdrawal on ${w.ukey} by ${w.reviewer}`);
      }
      // fileReconContext runs after this block (once, over the whole chunk) and folds every entry
      // reconByUnit holds for a unit — appending here means a finding first withdrawn in this
      // second pass (nobody withdrew it in Wave 1) reaches withdrawn_findings/withdrawn_originals
      // the same way a Wave-1 withdrawal already does, instead of vanishing from both kept/contested
      // and the withdrawal store.
      for (const w of wave1b) {
        if (!reconByUnit.has(w.ukey)) reconByUnit.set(w.ukey, []);
        reconByUnit.get(w.ukey).push({ reviewer: w.reviewer, maintained: w.findings || [], withdrawn: w.withdrawn || [] });
      }
      adaptation.extra_peer_pass_reviewers += wave1b.length;   // count survivors, mirroring Adaptation 6
      for (const ukey of pass2Ukeys) {
        const recon = wave1b.filter((w) => w.ukey === ukey);
        if (recon.length > 0) bindingByUnit.set(ukey, recon.map((w) => ({ reviewer: w.reviewer, findings: w.findings || [] })));
      }
      consensus = fileConsensus();
    }
  }

  // Concession rate — accumulated run-wide and exported for the campaign's adversarial gate.
  const wave0Keys = new Set();
  for (const r of wave0Reviews.filter(Boolean)) for (const fnd of (r.findings || [])) wave0Keys.add(r.ukey + '|' + requireFindingId(fnd, `Wave-0 concession key set for ${r.ukey}`));
  const bindingKeys = new Set();
  for (const [ukey, stances] of bindingByUnit) for (const st of stances) for (const fnd of (st.findings || [])) bindingKeys.add(ukey + '|' + requireFindingId(fnd, `binding concession key set for ${ukey}`));
  let withdrawnCount = 0;
  for (const k of wave0Keys) if (!bindingKeys.has(k)) withdrawnCount++;
  const concessionRate = wave0Keys.size === 0 ? 0 : withdrawnCount / wave0Keys.size;
  consensusMetrics.wave0_keys += wave0Keys.size;
  consensusMetrics.withdrawn += withdrawnCount;

  // ---- Adaptation point 6 — targeted widening on sharply-divergent units ----
  phase('Targeted widening');
  const widenTasks = [];
  for (const unit of chunkUnits) {
    const um = unitMergeOf(unit);
    const fileReviewerTotal = unit.file.units.length * SLOTS;
    if (um.contested.length > 0 && um.contested.length >= um.kept.length && budgetOk() && fileReviewerTotal + 2 <= U_file) {
      for (let n = SLOTS + 1; n <= SLOTS + 2; n++) widenTasks.push({ unit, n, label: `reviewer-${n}` });
    }
  }
  if (widenTasks.length > 0) {
    const widenedUkeys = new Set(widenTasks.map((t) => t.unit.ukey));
    log(`Adaptation 6: widening ${widenedUkeys.size} divergent unit(s) with +2 reviewers each`);
    const widenRaw = await parallel(widenTasks.map((t) => () =>
      spawn(reviewerPrompt(t.unit, t.unit.file, t.label), {
        label: `widen:${t.unit.ukey}:${t.label}`, phase: 'Targeted widening', model: MODEL_BODY,
        agentType: TYPE_REVIEWER, schema: REVIEWER_SCHEMA,
      }).then((r) => (r ? { ukey: t.unit.ukey, reviewer: t.label, ...r } : null))));
    waveCheck('Targeted widening', widenRaw);
    if (HALT.halted) break;
    const widen = widenRaw.filter(Boolean);
    for (const w of widen) {
      ingestFindings(w.findings, `widening review of ${w.ukey} by ${w.reviewer}`);
      const arr = bindingByUnit.get(w.ukey) || [];
      arr.push({ reviewer: w.reviewer, findings: w.findings || [] });
      bindingByUnit.set(w.ukey, arr);
      const path = chunkUnits.find((u) => u.ukey === w.ukey).fileId;
      adaptation.extra_reviewers_by_file[path] = (adaptation.extra_reviewers_by_file[path] || 0) + 1;
    }
    consensus = fileConsensus();
  }

  const totalKept = consensus.reduce((a, c) => a + c.kept.length, 0);
  log(`Chunk ${ci + 1}: ${totalKept} kept | concession ${(concessionRate * 100).toFixed(0)}% | red team deferred to mode=adversarial (campaign gate)`);
  for (const c of consensus) for (const k of c.kept) if (!k.adversary_impact) k.adversary_impact = 'unchanged';

  // ---- Per-file consensus verdicts + persisted adversarial_input for this chunk ----
  // Arbitration is an adversarial-stage concern (mode=adversarial) — contested findings
  // leave this run unarbitrated, carried in the adversarial_input payload.
  for (const f of chunkFilesList) {
    const c = consensus.find((x) => x.path === f.path);
    const extraInfo = (f.wholeClass === 'digest-escape')
      ? [ingestFinding({ rule_id: 'TEAM-SPLIT', title: 'Split this test class', enforce: 'consider', location: `${f.path}:1`, locations: [`${f.path}:1`], method: 'class-level', consensus: 'unanimous', adversary_impact: 'unchanged', arbitration: null, current: '', suggested: '', suggested_variants: [], deleted_methods: [], removed_assertions: [], summary: `${f.path} (${combinedLines(f)} combined lines) exceeds the cross-body review limit C=${C}; the class-bodies (cross-method) rules were not evaluated. Split this test class.`, dissent: null, implies_src_change: false }, `split-class informational entry for ${f.path}`)]
      : [];
    const b = bucketFile(c, extraInfo);
    const tagBranch = tagBranchFor(f);
    b.errors.forEach(tagBranch); b.warnings.forEach(tagBranch); b.informational.forEach(tagBranch);
    consensusMetrics.kept_total += c.kept.length;
    consensusMetrics.contested_total += c.contested.length;
    const reviewerLabels = ['reviewer-1', 'reviewer-2', 'reviewer-3'];
    if (adaptation.extra_reviewers_by_file[f.path]) reviewerLabels.push('reviewer-4', 'reviewer-5');
    const rc = fileReconContext(f);
    const impressions = wave0Impr.filter(Boolean).filter((im) => im.path === f.path)
      .map((im) => ({ lens: im.lens, concerns: (im.files || []).flatMap((fr) => fr.concerns || []) }));
    allFileResults.push({
      path: f.path, test_type: f.test_type, baseline: f.baseline, status: b.status, category: categoryByPath.get(f.path) || '?',
      track: f.track, units: f.units.length, reviewers: reviewerLabels,
      errors: b.errors, warnings: b.warnings, informational: b.informational,
      contested: contestedView(c, f),
      consensus: { unanimous: c.kept.filter((k) => k.consensus === 'unanimous').length, majority: c.kept.filter((k) => k.consensus !== 'unanimous').length, contested: c.contested.length },
      wholeClass: f.wholeClass,
      // The persisted handoff to mode=adversarial: everything red team, defense, and
      // arbitration need, so the adversarial stage runs from disk with no dependency
      // on this run's journal (a boundary the cache-key-drift cascade cannot cross).
      adversarial_input: {
        path: f.path, category: categoryByPath.get(f.path) || '?',
        kept: c.kept, contested: c.contested,
        informational_extras: extraInfo,
        withdrawn_findings: rc.withdrawn_findings, withdrawn_originals: rc.withdrawn_originals, reconciliation_record: rc.reconciliation_record,
        impressions,
      },
    });
  }
}

if (HALT.halted) {
  const done = new Set(allFileResults.map((f) => f.path));
  return partialResult({ files: allFileResults, unprocessed_files: FILES.filter((f) => !done.has(f.path)).map((f) => f.path) });
}

const totalReviewers = TOTAL_PROJ + Object.values(adaptation.extra_reviewers_by_file).reduce((a, b) => a + b, 0);
const implies_src_change = srcChangeOf(allFileResults);
const decomposition = FILES.map((f) => ({
  path: f.path, track: f.track,
  method_shards: f.track === 'B' ? f.units.filter((u) => u.type === 'method').length : 0,
  whole_class: f.track === 'B' ? f.wholeClass : 'n/a',
  split_skip: f.wholeClass === 'digest-escape' ? `${combinedLines(f)} combined lines > C=${C}; class-bodies rules not evaluated` : null,
}));
const overall = overallOf(allFileResults);
const concession_rate = consensusMetrics.wave0_keys === 0 ? 0 : consensusMetrics.withdrawn / consensusMetrics.wave0_keys;
// The red-team skip signal, exported for the campaign's adversarial gate instead of
// being consumed inline (workflow-design.md).
const skipRecommended = consensusMetrics.kept_total === 0 || concession_rate >= 0.5;
const skipReason = consensusMetrics.kept_total === 0
  ? 'zero consensus findings — nothing to challenge'
  : (concession_rate >= 0.5 ? `peer reconciliation already conceded ${(concession_rate * 100).toFixed(0)}% of Wave-0 findings (>= 50%)` : null);
const outputTokens = outputTokensNow();
log(`Consensus verdict (mode=review): ${overall} | ${allFileResults.filter((f) => f.status !== 'PASS').length}/${FILES.length} files with issues | ${consensusMetrics.kept_total} kept | ${consensusMetrics.contested_total} contested | concession ${(concession_rate * 100).toFixed(0)}% | adversarial gate: ${skipRecommended ? `skip recommended — ${skipReason}` : 'run'} | ${implies_src_change.length} src-change escalation(s) | ${agentsSpawned} agents spawned | ${outputTokens == null ? 'n/a' : Math.round(outputTokens / 1000) + 'k'} output tokens`);
return {
  mode: 'review',
  summary: {
    files_reviewed: FILES.length,
    files_reviewed_by_type: filesByType,
    reviewers: totalReviewers,
    agents_spawned: agentsSpawned,
    output_tokens: outputTokens,
    // Consensus-stage status: the adversarial stage may still adjust per-file statuses;
    // the campaign's merged report is the final word (report-format.md).
    overall_status: overall,
    files_with_issues: allFileResults.filter((f) => f.status !== 'PASS').length,
    implies_src_change_count: implies_src_change.length,
    kept_findings: consensusMetrics.kept_total,
    contested_findings: consensusMetrics.contested_total,
    concession_rate,
    adversarial_gate: { skip_recommended: skipRecommended, reason: skipReason },
  },
  files: allFileResults,
  implies_src_change,
  decomposition,
  adaptation,
};
}

// ===========================================================================
// mode=adversarial — red team + defense + arbitration over the persisted consensus
// payloads. The sole consumer of consensus; launched by the campaign after its
// adversarial gate. Emits FINAL per-file verdicts that supersede the consensus-stage
// ones in the merged report.
// ===========================================================================
if (MODE === 'adversarial') {
const advBound = FILES.length * K_adv + FILES.length * SLOTS + ARB_MAX * 3;
if (advBound > AGENT_BUDGET) {
  throw new Error(`mode=adversarial projects up to ${advBound} agents > per-run budget ${AGENT_BUDGET} — split the adversarial stage or lower the lens count/arbitration caps`);
}
const payloadOf = (path) => CONSENSUS_BY_PATH.get(path);
const consensus = FILES.map((f) => {
  const p = payloadOf(f.path);
  return { path: f.path, kept: (p.kept || []).map((k) => ({ ...k })), contested: (p.contested || []).map((k) => ({ ...k })) };
});
const consByPath = new Map(consensus.map((c) => [c.path, c]));
// Per file, the identity-complete originals of the findings peer reconciliation withdrew —
// the only place a resurrected-then-re-adopted finding's identity still exists, since it
// sits in neither kept nor contested. Keyed within the file, never across: one finding_id
// can name different defects in two files.
const withdrawnOriginalsByPath = new Map();
for (const f of FILES) {
  const m = new Map();
  for (const w of (payloadOf(f.path).withdrawn_originals || [])) m.set(requireFindingId(w, `withdrawn original in the consensus payload for ${f.path}`), w);
  withdrawnOriginalsByPath.set(f.path, m);
}
const redTeamMetrics = { challenges_made: 0, challenges_defended: 0, challenges_overturned: 0, resurrections: 0, new_findings_introduced: 0, new_findings_adopted: 0 };
const coverageGapFiles = [];
const allAdvSignals = [];

// ---- WAVE 2 — red team (per file × K lenses; full catalog) ----
phase('Wave 2: Red team');
const advTasks = FILES.flatMap((f) => LENSES.map((lens) => ({ file: f, lens })));
// Each (file, lens) is one independent adversary reading exactly that one file.
const redTeamRaw = await parallel(advTasks.map((t) => () => {
  const f = t.file, c = consByPath.get(f.path), pl = payloadOf(f.path);
  const pkg = {
    file_path: f.path, category: pl.category || '?',
    consensus_findings: c.kept.map((k) => ({ finding_id: k.finding_id, rule_id: k.rule_id, enforce: k.enforce, consensus: k.consensus, location: k.location, summary: k.summary })),
    withdrawn_findings: pl.withdrawn_findings || [], reconciliation_record: pl.reconciliation_record || [],
    ...(narrowOf(f) ? { diff_scope: `the changeset touched only ${f.methods.join(', ')} — focus your reading on these methods and the class structure; do not exhaustively review untouched methods` } : {}),
  };
  const impression = { file_path: f.path, concerns: (pl.impressions || []).filter((im) => im.lens === t.lens.id).flatMap((im) => im.concerns || []) };
  const redTeamRules = RED_TEAM_RULES.get(f.test_type);
  const redTeamRulesCompact = RED_TEAM_RULES_COMPACT.get(f.test_type);
  return spawn(redTeamPrompt(pkg, impression, t.lens, `adversary-${t.lens.id}`, redTeamRules, false), {
    label: `redteam:${f.path}:${t.lens.id}`, phase: 'Wave 2: Red team', model: MODEL_ADVERSARY,
    agentType: TYPE_ADVERSARY, schema: REDTEAM_SCHEMA,
    degrade: () => redTeamPrompt(pkg, impression, t.lens, `adversary-${t.lens.id}`, redTeamRulesCompact, true),
  }).then((r) => ({ path: f.path, lens: t.lens.id, result: r }));
}));
waveCheck('Wave 2: Red team', redTeamRaw.map((e) => e.result));
if (HALT.halted) return partialResult({ files: [] });

// Per-file coverage: a file is covered iff >= 1 of its K adversaries returned a result;
// coverage_gap is set only if ALL K of a file's adversaries failed (never report an
// incomplete adversarial pass as complete — the [!CAUTION] flag stays loud).
const okByFile = new Map();
for (const e of redTeamRaw) if (e.result) okByFile.set(e.path, (okByFile.get(e.path) || 0) + 1);
for (const f of FILES) if (!okByFile.get(f.path)) coverageGapFiles.push(f.path);

// Union every surviving lens adversary's challenges per file into the defense wave.
const challengesByPath = new Map();
// A defender's `adopted_new` entry has no owning record of its own — it is the identity
// source for its finding_id, carrying method/location/summary/current already stamped by
// REDTEAM_SCHEMA (method is required there), unlike the defender's own payload which does not.
// Scoped per file (`fr.path`, the path under which the defenders of that file are shown the
// finding), because finding_id embeds no path: the same id raised on two files names two
// different defects and must never cross-resolve. Within one file, two lens adversaries
// raising the same id are one finding — unioned through mergeRemediations so the later
// adversary's remediation is not dropped for arriving second.
const newFindingsByPath = new Map();
for (const e of redTeamRaw) {
  if (!e.result) continue;
  for (const fr of (e.result.files || [])) {
    assertFindingIds(fr.challenges_to_consensus, `red-team challenge on ${fr.path} (lens ${e.lens})`);
    assertFindingIds(fr.resurrections, `red-team resurrection on ${fr.path} (lens ${e.lens})`);
    // Stamped in place, so the defender that adopts one quotes back the id this run
    // issued rather than minting a second identity for the same defect.
    ingestFindings(fr.new_findings, `red-team new finding on ${fr.path} (lens ${e.lens})`);
    if (!newFindingsByPath.has(fr.path)) newFindingsByPath.set(fr.path, new Map());
    const newFindingsHere = newFindingsByPath.get(fr.path);
    for (const nf of (fr.new_findings || [])) {
      const nid = requireFindingId(nf, `red-team new finding on ${fr.path} (lens ${e.lens})`);
      const prev = newFindingsHere.get(nid);
      newFindingsHere.set(nid, prev ? unionRecords(prev, nf) : nf);
    }
    allAdvSignals.push(...(fr.cross_file_inconsistencies || []).map((x) => ({ ...x, file: fr.path })));
    redTeamMetrics.challenges_made += (fr.challenges_to_consensus || []).length;
    redTeamMetrics.new_findings_introduced += (fr.new_findings || []).length;
    const hasWork = (fr.challenges_to_consensus || []).length || (fr.resurrections || []).length || (fr.new_findings || []).length;
    if (hasWork) {
      if (!challengesByPath.has(fr.path)) challengesByPath.set(fr.path, []);
      challengesByPath.get(fr.path).push(fr);
    }
  }
}

// ---- WAVE 3 — defense (3 reconcilers per challenged file) ----
phase('Wave 3: Defense');
const defenseTasks = [];
for (const [path, frs] of challengesByPath) {
  const dfile = FILES.find((f) => f.path === path);
  if (!dfile) { log(`Wave 3: adversary cited unknown path ${path} — challenge dropped (not in manifest)`); continue; }
  const c = consByPath.get(path);
  const ids = new Set();
  for (const k of (c ? c.kept : [])) ids.add(k.rule_id);
  for (const fr of frs) {
    for (const x of (fr.challenges_to_consensus || [])) ids.add(x.rule_id);
    for (const x of (fr.resurrections || [])) ids.add(x.rule_id);
    for (const x of (fr.new_findings || [])) ids.add(x.rule_id);
  }
  const subsetRules = rulesByIds(catalogFor(dfile), ids);
  for (let n = 1; n <= SLOTS; n++) defenseTasks.push({ path, file: dfile, label: `reviewer-${n}`, consensus: c ? { kept: c.kept, contested: c.contested } : { kept: [], contested: [] }, challenges: frs, subsetRules });
}
let defense = [];
if (defenseTasks.length > 0) {
  log(`Wave 3: defending ${new Set(defenseTasks.map((t) => t.path)).size} challenged file(s) with ${SLOTS} reconcilers each`);
  const defenseRaw = await parallel(defenseTasks.map((t) => () =>
    spawn(defensePrompt(t.file, t.label, t.consensus, t.challenges, t.subsetRules), {
      label: `defense:${t.file.path}:${t.label}`, phase: 'Wave 3: Defense', model: MODEL_BODY,
      agentType: TYPE_REVIEWER, schema: DEFENSE_SCHEMA,
    })));
  waveCheck('Wave 3: Defense', defenseRaw);
  if (HALT.halted) return partialResult({ files: [] });
  defense = defenseRaw.filter(Boolean);
  for (const d of defense) {
    ingestFindings(d.findings, `defense stance on ${d.path}`);
    ingestFindings(d.re_adopted, `defense re-adoption on ${d.path}`);
    ingestFindings(d.adopted_new, `defense adoption of an adversary finding on ${d.path}`);
    assertFindingIds(d.withdrawn, `defense withdrawal on ${d.path}`);
  }
} else { log('Wave 3: no files drew actionable challenges — defense skipped'); }

// A defense-stage promotion's identity comes from the record its finding_id already names,
// never from the defender's payload. Every record a legitimate back-reference can name is a
// consultation source here, all four scoped to this one file: the consensus entry (kept or
// contested) for a re-adoption of a surviving finding, the review stage's persisted
// withdrawn original for a re-adoption of one peer reconciliation removed from both sets,
// and the red team's own new_findings entry (identity-complete — REDTEAM_SCHEMA requires
// `method` there) for an adoption. A quoted id resolving to none of them is a broken
// back-reference, not a new finding to invent identity for.
function resolveOriginal(c, id, newFindings, withdrawnOriginals, ctx) {
  const k = c.kept.find((x) => x.finding_id === id);
  if (k) return k;
  const ct = c.contested.find((x) => x.finding_id === id);
  if (ct) return ct;
  const w = withdrawnOriginals.get(id);
  if (w) return w;
  const nf = newFindings.get(id);
  if (nf) return nf;
  throw new Error(`Promoted finding quotes finding_id ${id} that resolves to no known record — ${ctx}`);
}
// Fold defense into consensus (majority of 3 defenders per file).
const overturnedMustFix = [];
const byPath = new Map();
for (const d of defense) { if (!byPath.has(d.path)) byPath.set(d.path, []); byPath.get(d.path).push(d); }
for (const c of consensus) {
  const defs = byPath.get(c.path);
  if (!defs) { c.kept.forEach((k) => { if (!k.adversary_impact) k.adversary_impact = 'unchanged'; }); continue; }
  const withdrawVotes = new Map(), adoptVotes = new Map(), readoptVotes = new Map();
  // A vote is one defender, per finding: a defender that lists the same finding twice is
  // still one voice, and two of three defenders is the majority that moves a finding. Every
  // defender's record is kept (not just the first) so a promoted adoption/re-adoption can
  // union their remediations and locations instead of discarding all but the first voter's.
  // `voices` holds every entry in the order the defenders were folded, repeats included, so
  // a defender's second entry merges where it was seen rather than behind the last
  // defender's first — that ordering is what `locations` reads. `items` holds only the
  // vote-casting entry per defender: a repeat from a defender that already voted for this id
  // casts no second vote and is deliberately absent from the enforce tally.
  const castVote = (map, id, rec, seen) => {
    let e = map.get(id);
    if (!e) { e = { n: 0, items: [], voices: [] }; map.set(id, e); }
    e.voices.push(rec);
    if (seen.has(id)) return;
    seen.add(id);
    e.n++;
    e.items.push(rec);
  };
  for (const d of defs) {
    const seenW = new Set(), seenA = new Set(), seenR = new Set();
    for (const w of (d.withdrawn || [])) castVote(withdrawVotes, requireFindingId(w, `defense withdrawal on ${c.path}`), w, seenW);
    for (const a of (d.adopted_new || [])) castVote(adoptVotes, requireFindingId(a, `defense adoption on ${c.path}`), a, seenA);
    for (const r of (d.re_adopted || [])) castVote(readoptVotes, requireFindingId(r, `defense re-adoption on ${c.path}`), r, seenR);
    // `findings` is a defender's maintained stance on an existing kept/contested record —
    // its `adversary_impact` is `defended`/`unchanged`, never `introduced`, so it casts no
    // vote and moves nothing between kept and contested. Its remediation still merges in,
    // through the same mergeRemediations/unionRecords machinery as every other stage, so a
    // defender that proposes a different fix while maintaining a finding does not lose it.
    // `rec` donates `...base` in unionRecords below, so votes/consensus/arbitration/outcome/
    // dissent/adversary_impact pass through untouched; only the remediation-tracking fields
    // (title/location/method/summary/current/suggested/suggested_variants/locations) follow
    // the merge's winning variant, exactly as they do at every other merge site.
    for (const f of (d.findings || [])) {
      const fid = requireFindingId(f, `defense maintained finding on ${c.path}`);
      const rec = c.kept.find((k) => k.finding_id === fid) || c.contested.find((k) => k.finding_id === fid);
      if (!rec) throw new Error(`Defense-maintained finding quotes finding_id ${fid} that resolves to no known record — defense maintained finding on ${c.path}`);
      Object.assign(rec, unionRecords(rec, f, rec, f), { implies_src_change: rec.implies_src_change === true || f.implies_src_change === true });
    }
  }
  c.kept = c.kept.filter((k) => {
    if (((withdrawVotes.get(requireFindingId(k, `defense fold on ${c.path}`)) || {}).n || 0) >= 2) {
      k.adversary_impact = 'overturned';
      if (normEnforce(k.enforce) === 'must-fix') overturnedMustFix.push({ ...k });
      c.contested.push({ ...k, consensus: 'contested', reported_by: ['overturned in defense'], outcome: 'must-fix overturned by adversary defense' });
      return false;
    }
    k.adversary_impact = k.adversary_impact || 'defended';
    return true;
  });
  // Identity (finding_id, rule_id) is the resolved original's and only the original's: a
  // defender that omits `method` must not silently downgrade a method-level finding to
  // class-level. The descriptive fields follow the remediation instead, exactly as every
  // other merge site does — they come from the record that supplied `suggested_variants[0]`,
  // so `current` and `suggested` describe one change even when that record is a defender's
  // payload. Where such an owner carries no value of its own for a field (the schema
  // requires only finding_id/enforce/suggested of it), that field falls back to the
  // original's rather than being dropped. reconcilePromotion then resolves the id against
  // the current kept/contested sets so the same finding_id never duplicates across them.
  const newFindings = newFindingsByPath.get(c.path) || new Map();
  const withdrawnOriginals = withdrawnOriginalsByPath.get(c.path) || new Map();
  const promote = (id, v, ctx, impact) => {
    const orig = resolveOriginal(c, id, newFindings, withdrawnOriginals, ctx);
    // Every defender entry for this id — the voting ones and the repeats that cast no
    // second vote — contributes its remediation, location and src-change flag, merged in
    // the order the entries were seen (`v.voices`) rather than all votes ahead of all
    // repeats, which would reorder one defender's second location behind another's first.
    // Only `v.items` sets the enforce level, so a defender listing the finding twice does
    // not weigh twice in the severity tally.
    const voices = v.voices;
    const { owner, suggested_variants, locations } = mergeRemediations([orig, ...voices]);
    reconcilePromotion(c, id, {
      finding_id: id, rule_id: orig.rule_id,
      ...descriptiveFrom(owner, orig), locations,
      // Same rule as everywhere else: the deletion accounting is the union across the
      // original and every defender entry, not the winning variant owner's alone.
      ...mergeDeletionAccounting([orig, ...voices]),
      enforce: normEnforce(majorityEnforce(v.items)), suggested: suggested_variants[0] || '', suggested_variants,
      consensus: 'majority', adversary_impact: impact,
      implies_src_change: orig.implies_src_change === true || voices.some((it) => it.implies_src_change === true),
    });
  };
  for (const [id, v] of adoptVotes) if (v.n >= 2) {
    promote(id, v, `adoption on ${c.path}`, 'introduced');
    redTeamMetrics.new_findings_adopted++;
  }
  for (const [id, v] of readoptVotes) if (v.n >= 2) {
    promote(id, v, `re-adoption on ${c.path}`, 'resurrected');
    redTeamMetrics.resurrections++;
  }
}
redTeamMetrics.challenges_overturned += overturnedMustFix.length;
for (const c of consensus) for (const k of c.kept) if (k.adversary_impact === 'defended') redTeamMetrics.challenges_defended++;
for (const c of consensus) for (const k of c.kept) if (!k.adversary_impact) k.adversary_impact = 'unchanged';

// ---- Arbitration (HARD-capped per file and per run) ----
// Every contested finding is a candidate; must-fix sort first at both cap levels, and
// every trimmed finding stays in `contested` and surfaces unchanged in the report. Both
// caps are HARD — the measured alternative was uncapped arbitration driving a
// 433-projection run into the 1000-agent engine cap. An arbitrated contested MUST-FIX
// gets 3 adversary-tier arbiters with a majority verdict (>=2 confirm -> kept, >=2
// refute -> excluded, no majority -> KEPT marked `split` so a possibly-real must-fix is
// never silently dropped). should-fix / consider keep a single body-tier arbiter.
phase('Arbitration');
const arbiterTasks = [];
for (const c of consensus) for (const ct of c.contested) {
  const mustFix = normEnforce(ct.enforce) === 'must-fix';
  arbiterTasks.push({ finding: ct, path: c.path, file: FILES.find((f) => f.path === c.path), mustFix, votes: mustFix ? 3 : 1, model: mustFix ? MODEL_ADVERSARY : MODEL_BODY });
}
const byFileTasks = new Map();
for (const t of arbiterTasks) { if (!byFileTasks.has(t.path)) byFileTasks.set(t.path, []); byFileTasks.get(t.path).push(t); }
const perFileCapped = [];
for (const [, ts] of byFileTasks) { ts.sort((a, b) => sevRank(b.finding.enforce) - sevRank(a.finding.enforce)); perFileCapped.push(...ts.slice(0, ARB_FILE)); }
perFileCapped.sort((a, b) => sevRank(b.finding.enforce) - sevRank(a.finding.enforce));
const arbActive = perFileCapped.slice(0, ARB_MAX);
if (arbActive.length > 0 && budgetOk()) {
  const totalArbiters = arbActive.reduce((s, t) => s + t.votes, 0);
  const capNote = arbActive.length < arbiterTasks.length ? ` (capped from ${arbiterTasks.length} by arbFile=${ARB_FILE}/arbMax=${ARB_MAX}; tail left contested)` : '';
  log(`Arbitration: ${arbActive.length} contested finding(s)${capNote} (${totalArbiters} arbiter agent(s); must-fix x3 ${MODEL_ADVERSARY})`);
  adaptation.arbiters += arbActive.length;
  // Spawn every arbiter vote concurrently; group the verdicts back by task index.
  const votesRaw = await parallel(arbActive.flatMap((t, ti) => {
    const ruleText = rulesByIds(catalogFor(t.file), new Set([t.finding.rule_id]));
    return Array.from({ length: t.votes }, (_, vi) => () =>
      spawn(arbiterPrompt(t.finding, t.file, ruleText), {
        label: `arbiter:${t.file.path}:${t.finding.rule_id}${t.votes > 1 ? `#${vi + 1}` : ''}`, phase: 'Arbitration', model: t.model,
        agentType: TYPE_REVIEWER, schema: ARBITER_SCHEMA,
      }).then((v) => ({ ti, v })));
  }));
  waveCheck('Arbitration', votesRaw.map((r) => r.v));
  if (HALT.halted) return partialResult({ files: [] });
  const votesByTask = new Map();
  for (const r of votesRaw) { if (!votesByTask.has(r.ti)) votesByTask.set(r.ti, []); if (r.v) votesByTask.get(r.ti).push(r.v); }

  arbActive.forEach((t, ti) => {
    const target = consensus.find((x) => x.path === t.path);
    if (!target) return;
    const idx = target.contested.findIndex((f) => f.finding_id === requireFindingId(t.finding, `arbitration target on ${t.path}`));
    const votes = votesByTask.get(ti) || [];
    const confirm = votes.filter((v) => (v.verdict || '').toLowerCase() === 'confirmed');
    const refute = votes.filter((v) => (v.verdict || '').toLowerCase() === 'refuted');
    const tally = `${confirm.length} confirmed / ${refute.length} refuted of ${t.votes}`;
    const promote = (verdict, ce, reasoning) => {
      const f = idx >= 0 ? target.contested.splice(idx, 1)[0] : { ...t.finding };
      f.enforce = ce ? normEnforce(ce) : normEnforce(f.enforce);
      f.consensus = 'majority';
      f.adversary_impact = f.adversary_impact || 'unchanged';
      f.arbitration = { verdict, reasoning };
      target.kept.push(f);
    };
    if (t.votes === 1) {
      // should-fix / consider — single arbiter, unchanged dispositions.
      const v = votes[0];
      if (!v) return;   // arbiter died -> leave contested (error-handling.md)
      const verdict = (v.verdict || '').toLowerCase();
      if (verdict === 'confirmed') { adaptation.arbiters_confirmed++; promote('confirmed', v.corrected_enforce, v.reasoning); }
      else if (verdict === 'refuted') { adaptation.arbiters_refuted++; if (idx >= 0) target.contested[idx].arbitration = { verdict: 'refuted', reasoning: v.reasoning }; }
      else if (idx >= 0) target.contested[idx].arbitration = { verdict: 'uncertain', reasoning: v.reasoning };
      return;
    }
    // contested MUST-FIX — 3 adversary-tier arbiters, majority verdict.
    const reasoning = votes.map((v) => v.reasoning).filter(Boolean).join(' | ');
    if (confirm.length >= 2) {
      adaptation.arbiters_confirmed++;
      promote('confirmed', majorityEnforce(confirm.map((v) => ({ enforce: v.corrected_enforce || t.finding.enforce }))), `arbiter majority confirmed (${tally})${reasoning ? `: ${reasoning}` : ''}`);
    } else if (refute.length >= 2) {
      adaptation.arbiters_refuted++;
      if (idx >= 0) target.contested[idx].arbitration = { verdict: 'refuted', reasoning: `arbiter majority refuted (${tally})${reasoning ? `: ${reasoning}` : ''}` };
    } else if (votes.length === 0) {
      // all arbiters died -> leave contested (error-handling.md); still visible in the contested section.
    } else {
      // no majority either way -> KEEP the possibly-real must-fix, flagged for human judgment.
      adaptation.arbiters_split++;
      promote('split', null, `no arbiter majority — needs human judgment (${tally})${reasoning ? `: ${reasoning}` : ''}`);
    }
  });
}

// ---- FINAL per-file verdicts (supersede the consensus-stage statuses at merge) ----
for (const f of FILES) {
  const c = consByPath.get(f.path);
  const pl = payloadOf(f.path);
  const b = bucketFile(c, pl.informational_extras || []);
  const tagBranch = tagBranchFor(f);
  b.errors.forEach(tagBranch); b.warnings.forEach(tagBranch); b.informational.forEach(tagBranch);
  allFileResults.push({
    path: f.path, test_type: f.test_type, baseline: f.baseline, status: b.status, category: pl.category || '?',
    errors: b.errors, warnings: b.warnings, informational: b.informational,
    contested: contestedView(c, f),
    consensus: { unanimous: c.kept.filter((k) => k.consensus === 'unanimous').length, majority: c.kept.filter((k) => k.consensus !== 'unanimous').length, contested: c.contested.length },
  });
}
const advOverall = overallOf(allFileResults);
const advSrcChange = srcChangeOf(allFileResults);
const uniqueCoverageGap = [...new Set(coverageGapFiles)];
const red_team = {
  skipped: false, skip_reason: null,
  challenges_made: redTeamMetrics.challenges_made,
  challenges_defended: redTeamMetrics.challenges_defended,
  challenges_overturned: redTeamMetrics.challenges_overturned,
  resurrections: redTeamMetrics.resurrections,
  new_findings_introduced: redTeamMetrics.new_findings_introduced,
  new_findings_adopted: redTeamMetrics.new_findings_adopted,
  change_rate: 0,
  coverage_gap: uniqueCoverageGap.length ? { files: uniqueCoverageGap, note: 'in-scope files left un-red-teamed after re-spawn — adversary coverage is incomplete' } : null,
};
const advOutputTokens = outputTokensNow();
log(`Adversarial verdict (mode=adversarial): ${advOverall} | ${allFileResults.filter((f) => f.status !== 'PASS').length}/${FILES.length} files with issues | ${redTeamMetrics.challenges_made} challenge(s), ${redTeamMetrics.challenges_overturned} overturned, ${redTeamMetrics.new_findings_adopted} new finding(s) adopted | ${adaptation.arbiters} arbiter(s) | ${advSrcChange.length} src-change escalation(s) | ${agentsSpawned} agents spawned | ${advOutputTokens == null ? 'n/a' : Math.round(advOutputTokens / 1000) + 'k'} output tokens`);
return {
  mode: 'adversarial',
  summary: {
    files_reviewed: FILES.length,
    files_reviewed_by_type: filesByType,
    agents_spawned: agentsSpawned,
    output_tokens: advOutputTokens,
    overall_status: advOverall,
    files_with_issues: allFileResults.filter((f) => f.status !== 'PASS').length,
    implies_src_change_count: advSrcChange.length,
  },
  files: allFileResults,
  red_team,
  // Candidate cross-file signals surfaced by the red team — optional hints for a signals
  // run sequenced after this stage; informational passthrough otherwise.
  cross_file_signals: allAdvSignals,
  implies_src_change: advSrcChange,
  adaptation,
};
}

// ===========================================================================
// mode=signals — whole-changeset signals with manifest-only inputs: the cross-file
// consistency agent and the changeset adoption signal. No dependency on any review
// result, so the campaign launches it concurrently with the first review shard.
// The SUT-coverage map and placement flags are deterministic joins the skill
// computes at merge time — no agents, so they do not live here.
// ===========================================================================
phase('Cross-file consistency');
const allFingerprints = FILES.map((f) => ({ path: f.path, test_type: f.test_type, track: f.track, source_paths: (Array.isArray(f.source_paths) && f.source_paths.length) ? f.source_paths : [f.source_path], fingerprint: f.fingerprint || '' }));
// Candidate signals from an adversarial run, when the campaign sequences signals after it;
// empty on the default concurrent schedule — the agent works from fingerprints alone.
const advSignals = Array.isArray(manifest.adv_signals) ? manifest.adv_signals : [];
let consistency = [];
if (allFingerprints.length <= F_cap) {
  const cf = await spawn(crossFilePrompt(allFingerprints, advSignals, null), {
    label: 'cross-file', phase: 'Cross-file consistency', model: MODEL_BODY, agentType: TYPE_REVIEWER, schema: CROSSFILE_SCHEMA,
  });
  consistency = (cf && cf.consistency) || [];
} else {
  const axes = ['setUp strategy', 'mock strategy', 'assertion style', 'data-provider usage', 'attribute ordering'];
  const shards = await parallel(axes.map((ax) => () => spawn(crossFilePrompt(allFingerprints, advSignals, ax), {
    label: `cross-file:${ax}`, phase: 'Cross-file consistency', model: MODEL_BODY, agentType: TYPE_REVIEWER, schema: CROSSFILE_SCHEMA,
  })));
  for (const s of shards.filter(Boolean)) consistency.push(...((s && s.consistency) || []));
  log(`Cross-file sharded by ${axes.length} pattern axes (>${F_cap} files)`);
}
consistency = consistency.map((c) => ({ ...c, source: 'cross-file consistency agent' }));

// ===========================================================================
// A reusable abstraction the changeset introduced can make untouched peer tests improvable
// with no dependency edge to follow — the rationale for this "expand" signal. Kept
// informational and bounded to the changeset's own files: sweeping the wider repo would
// dredge pre-existing issues the change didn't create. A non-diff run has no changeset
// boundary, so there is nothing to expand against.
// ===========================================================================
phase('Adoption signal');
let adoption_opportunities = [];
const IS_DIFF_RUN = FILES.some((f) => Array.isArray(f.changed_methods));
if (IS_DIFF_RUN) {
  const changesetFiles = FILES.map((f) => ({
    path: f.path, test_type: f.test_type,
    source_paths: (Array.isArray(f.source_paths) && f.source_paths.length) ? f.source_paths : [f.source_path],
    fingerprint: f.fingerprint || '',
    changed_methods: Array.isArray(f.changed_methods) ? f.changed_methods : [],
  }));
  const ad = await spawn(adoptionPrompt(changesetFiles), {
    label: 'adoption', phase: 'Adoption signal', model: MODEL_BODY, agentType: TYPE_REVIEWER, schema: ADOPTION_SCHEMA,
  });
  // The agent is told to stay in the changeset but may stray; enforce the boundary in code
  // so a candidate outside the reviewed set can't leak into the signal (IA6).
  const inScope = new Set(FILES.map((f) => f.path));
  adoption_opportunities = ((ad && ad.adoption_opportunities) || [])
    .map((o) => ({
      new_abstraction: o.new_abstraction,
      introduced_by: normPath(o.introduced_by),
      candidates: (o.candidates || []).map((c) => ({ ...c, path: normPath(c.path) })).filter((c) => inScope.has(c.path)),
    }))
    .filter((o) => o.candidates.length > 0);
  if (adoption_opportunities.length) log(`Adoption signal: ${adoption_opportunities.length} changeset abstraction(s) peers could adopt (informational, never raises status)`);
} else {
  log('Adoption signal: skipped (non-diff run — no changeset boundary to bound the expand signal)');
}

const outputTokens = outputTokensNow();
log(`Signals verdict (mode=signals): ${consistency.length} cross-file finding(s) | ${adoption_opportunities.length} adoption signal(s) | ${agentsSpawned} agents spawned | ${outputTokens == null ? 'n/a' : Math.round(outputTokens / 1000) + 'k'} output tokens`);
return {
  mode: 'signals',
  summary: {
    files_reviewed: FILES.length,
    files_reviewed_by_type: filesByType,
    agents_spawned: agentsSpawned,
    output_tokens: outputTokens,
    consistency_findings: consistency.length,
    adoption_count: adoption_opportunities.length,
  },
  consistency,
  adoption_opportunities,
};
