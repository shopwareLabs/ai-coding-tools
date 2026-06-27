export const meta = {
  name: 'phpunit-test-team-review',
  description: 'Team consensus + red-team review of Shopware PHPUnit unit, integration, and migration tests over one mixed manifest. Reads its manifest from args; routes per file by test_type; encodes the wave shape, gate, caps, cross-cutting coverage map, placement flags, changeset adoption signal, and adaptation points of the team-reviewing skill references.',
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
//                fingerprint: "<structural signature>", digest: "<text>"|null } ],
//     rule_packages: { unit?, integration?, migration?: "<rendered catalog>",
//                      placement?: "<rendered placement reasoning catalog>" },
//     base?: "<base ref, for logging>" }
// test_type is the PRIMARY routing axis (classified by path in Phase 1). Each
// test type has its own rendered catalog; the script slices each wave's scoped
// `## RULES` subset from the file's per-type catalog in-process — the workflow
// runtime sandboxes the script, so it cannot call build_rule_package or any MCP
// tool once running. `placement` is an optional side catalog used only for the
// placement-flag signal; never required.
// ===========================================================================
const TEST_TYPES = ['unit', 'integration', 'migration'];
const manifest = args;
if (!manifest || typeof manifest !== 'object') throw new Error('Manifest (args) missing or not an object');
const DRY_RUN = manifest.dry_run === true;   // projection-only: no agents spawn, catalogs not required
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
  // A path under neither src/ nor tests/ can't be canonicalized and would silently split a
  // SUT across the joins (input-resolution.md Per-File Extraction requires repo-relative).
  if (isAbsPath(normPath(e.path))) throw new Error(`Manifest entry path does not resolve under tests/ and cannot be made repo-relative: ${e.path}`);
  if (isAbsPath(normPath(e.source_path))) throw new Error(`Manifest entry source_path does not resolve under src/ and cannot be made repo-relative: ${e.source_path} (${e.path})`);
  if (Array.isArray(e.source_paths) && e.source_paths.some((s) => isAbsPath(normPath(s)))) throw new Error(`Manifest entry has a source_paths entry that does not resolve under src/ and cannot be made repo-relative: ${e.path}`);
}
const TYPES_PRESENT = [...new Set(MANIFEST.map((e) => e.test_type))];
const RULE_PACKAGES = manifest.rule_packages;
// A real run requires a non-empty rendered catalog per test type present; a dry-run
// projection spawns no agents and needs none.
if (!DRY_RUN) {
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

// ===========================================================================
// Fixed seeds (not preset knobs — see workflow-design.md to retune).
// ===========================================================================
const T = 450;            // combined test+source lines above which a file decomposes (Track B) — a reviewability threshold, fixed across presets
const U_file = 18;        // max reviewer agents per single file
const G = 300;            // max reviewer agents per chunk (auto-partition above this)
const F_cap = 40;         // files the cross-file agent ingests before sharding by pattern dimension
const SLOTS = 3;          // reviewers per unit — the 2-of-3 majority consensus invariant; NEVER a preset knob
const RESPAWN_MAX = 2;    // re-spawn attempts for a dead unit/agent before degrade-and-flag
const BUDGET_FLOOR = 60000; // token floor checked before any conditional wave

// ===========================================================================
// Tuning presets — the cost/quality operating point, selected by name in the
// manifest (manifest.preset), fail-soft to 'standard' when absent or unknown.
//   C       whole-class fused → digest-escape line threshold (no agent-count effect; coverage/token only)
//   M       max test methods per shard (higher = fewer Track-B shards = fewer agents)
//   lenses  adversary lens count = adversaries/file in each of Wave 0 and Wave 2 (the agent-count lever)
//   arbMax  cap on total arbitrated contested findings (null = uncapped); must-fix are ALWAYS arbitrated
// ===========================================================================
const PRESETS = {
  deep:     { C: 1200, M: 6,  lenses: 3, arbMax: null },
  standard: { C: 1000, M: 8,  lenses: 3, arbMax: null },
  lean:     { C: 800,  M: 14, lenses: 1, arbMax: 6 },
};
const PRESET_NAME = (manifest.preset && PRESETS[manifest.preset]) ? manifest.preset : 'standard';
const PRESET = PRESETS[PRESET_NAME];
const C = PRESET.C;
const M = PRESET.M;
const ARB_MAX = PRESET.arbMax;

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
    findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['rule_id', 'enforce', 'location', 'method', 'summary'], properties: FINDING_PROPS } },
    withdrawn: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['rule_id', 'reason'], properties: { rule_id: { type: 'string' }, reason: { type: 'string' } } } },
  },
};
const REDTEAM_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['adversary', 'files'],
  properties: {
    adversary: { type: 'string' },
    files: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['path'], properties: {
      path: { type: 'string' },
      challenges_to_consensus: { type: 'array', items: { type: 'object', additionalProperties: false, properties: { rule_id: { type: 'string' }, consensus_was: { type: 'string' }, challenge: { type: 'string' }, verdict_sought: { type: 'string' } } } },
      resurrections: { type: 'array', items: { type: 'object', additionalProperties: false, properties: { rule_id: { type: 'string' }, withdrawn_reason: { type: 'string' }, resurrection_argument: { type: 'string' }, code_evidence: { type: 'string' } } } },
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
    findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['rule_id', 'enforce', 'location', 'method', 'summary', 'adversary_impact'], properties: { ...FINDING_PROPS, adversary_impact: { type: 'string', enum: ['defended', 'unchanged'] } } } },
    re_adopted: { type: 'array', items: { type: 'object', additionalProperties: false, properties: { ...FINDING_PROPS, adversary_impact: { type: 'string' } } } },
    withdrawn: { type: 'array', items: { type: 'object', additionalProperties: false, properties: { rule_id: { type: 'string' }, reason: { type: 'string' }, location: { type: 'string' }, enforce: { type: 'string' }, adversary_impact: { type: 'string' } } } },
    adopted_new: { type: 'array', items: { type: 'object', additionalProperties: false, properties: { ...FINDING_PROPS, adversary_impact: { type: 'string' } } } },
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
  if (dec.wholeClass === 'fused') {
    units.push({
      ukey: `${file.path}#wc`, fileId: file.path, type: 'wholeclass', track: 'B',
      reviewUnits: ['class-structure', 'class-bodies'], scopedReview: false,
      methodScope: scoped ? `full class (findings filtered to: ${file.methods.join(', ')})` : 'full class (cross-method + structure)',
      rules: trackRules(catalog, ['class-structure', 'class-bodies'], false),
    });
  } else {
    // L > C: class-structure digest only (no body read); class-bodies skipped.
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
function lineOf(loc) { const m = String(loc || '').match(/(\d+)/g); return m ? parseInt(m[m.length - 1], 10) : 0; }
function findKey(f) { return `${f.rule_id}@${Math.round(lineOf(f.location) / 5)}`; }
// Normalize an LLM-emitted method name to a bare identifier before matching the diff-parsed changed
// set — an exact-string mismatch (testFoo() vs testFoo) would silently invert branch_touched.
function methodId(m) { return String(m || '').replace(/\s*\(.*$/, '').trim(); }
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
function bestSuggested(items) {
  // Most complete remediation: the longest `suggested` among concordant stances.
  return items.reduce((a, b) => ((b.suggested || '').length > (a.suggested || '').length ? b : a));
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
      const k = findKey(f);
      if (!groups.has(k)) groups.set(k, { rule_id: f.rule_id, items: [], reviewers: new Set() });
      const g = groups.get(k);
      g.items.push(f);
      g.reviewers.add(st.reviewer);
    }
  });
  const kept = [], contested = [];
  for (const g of groups.values()) {
    const votes = g.reviewers.size;
    const rep = bestSuggested(g.items);
    const enforce = majorityEnforce(g.items);
    const rec = {
      rule_id: g.rule_id, title: shortTitle(rep.summary), enforce, location: rep.location, method: rep.method || 'class-level',
      summary: rep.summary || '', current: rep.current || '', suggested: rep.suggested || '',
      adversary_impact: pickImpact(g.items), arbitration: null, votes,
      implies_src_change: g.items.some((it) => it.implies_src_change === true), // OR by design: any reviewer escalates (attention flag, not a consensus vote)
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
// Union a file's per-unit merges into file-level {kept, contested}, deduped by key.
function mergeFile(unitMerges) {
  const kdedup = new Map();
  for (const um of unitMerges) for (const k of um.kept) {
    const key = findKey(k);
    if (!kdedup.has(key) || k.votes > kdedup.get(key).votes) kdedup.set(key, k);
  }
  const cdedup = new Map();
  for (const um of unitMerges) for (const c of um.contested) {
    const key = findKey(c);
    if (!cdedup.has(key)) cdedup.set(key, c);
  }
  for (const key of kdedup.keys()) cdedup.delete(key); // consensus in any unit wins
  return { kept: [...kdedup.values()], contested: [...cdedup.values()] };
}
function bucketFile(consensus, extraInformational) {
  const errors = [], warnings = [], informational = [];
  for (const k of consensus.kept) {
    const entry = {
      rule_id: k.rule_id, title: k.title || shortTitle(k.summary), enforce: k.enforce, location: k.location, method: k.method || 'class-level',
      consensus: k.consensus || 'majority', adversary_impact: k.adversary_impact || 'unchanged',
      arbitration: k.arbitration || null, current: k.current || '', suggested: k.suggested || '',
      summary: k.summary || '', dissent: k.dissent || null, implies_src_change: k.implies_src_change === true,
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
  ].join('\n');
}

function reconcilePrompt(unit, file, label, own, peers, subsetRules) {
  return [
    GUARD,
    '',
    `## ROLE: Wave 1 PEER reconciler "${label}" for unit [${unit.ukey}] of ${file.path}.`,
    `STEP 1 — Invoke the Skill tool with skill="${RECONCILE_SKILL}" in PEER mode.`,
    'Weigh your own current findings against your peers\' findings on this same unit. Maintain a finding only if its detection algorithm truly fires; withdraw it (with a reason) if a peer\'s argument or the code shows it does not. Adopt a peer finding you now agree with.',
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
// Re-spawn wrapper (error-handling.md): retry a dead agent up to RESPAWN_MAX,
// re-pinning model + agentType + schema on every attempt (never inherit).
// Size-aware re-spawn: agent() returns null on a terminal death without exposing
// the error class, so we cannot branch on "prompt is too long" specifically.
// When opts.degrade is given, only the FINAL re-spawn sends the DEGRADED payload
// (finding-localized reads + compact catalog); earlier retries stay faithful. A
// transient stall thus recovers on a faithful retry, while a deterministic overflow
// — which a faithful retry cannot fix — is caught by the degraded last attempt,
// turning a residual overflow into a degraded-but-present adversary, not a lost one.
// ===========================================================================
// Each agent() call (every retry included) is one on-disk transcript, so counting them is
// the true fan-out — surfaced because the reviewer-only figure understated it ~3-5x.
let agentsSpawned = 0;
async function spawn(promptText, opts) {
  for (let attempt = 0; attempt <= RESPAWN_MAX; attempt++) {
    const prompt = attempt === RESPAWN_MAX && opts.degrade ? opts.degrade() : promptText;
    agentsSpawned++;
    const res = await agent(prompt, {
      label: attempt ? `${opts.label}#retry${attempt}` : opts.label,
      phase: opts.phase, model: opts.model, agentType: opts.agentType, schema: opts.schema,
    });
    if (res) return res;
    if (attempt < RESPAWN_MAX) log(`Re-spawn ${opts.label}: attempt ${attempt + 1}/${RESPAWN_MAX} (agent died${opts.degrade && attempt + 1 === RESPAWN_MAX ? ', degrading payload' : ''})`);
  }
  log(`Re-spawn exhausted for ${opts.label} — degrading by role`);
  return null;
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
      reviewers_per_wave: reviewersPerWave,           // Waves 0, 1, 3 (review / reconcile / defense)
      adversaries_per_wave: advPerWave,               // Waves 0, 2 (impressions / red team)
      wave0_agents: reviewersPerWave + advPerWave,    // always runs
      max_structural_agents: reviewersPerWave * 3 + advPerWave * 2 + 1, // + cross-file; conditional waves included as upper bound
      chunks: Math.max(1, Math.ceil(reviewersPerWave / G)),
      lenses: p.lenses,
      arbMax: p.arbMax,
    };
  }
  log(`Dry run — projection only, no review agents spawned. files=${MANIFEST.length}`);
  return { dry_run: true, files: MANIFEST.length, slots: SLOTS, model_combos: Object.keys(MODEL_PRESETS), projections };
}

// One parsed catalog per test type — each type carries a different ruleset, so
// every wave selects a file's rules through `catalogFor`.
const CATALOGS = new Map();
for (const t of TYPES_PRESENT) {
  const c = parseCatalog(RULE_PACKAGES[t]);
  if (c.byId.size === 0) throw new Error(`Parsed 0 rules from rule_packages.${t} — rendered catalog format unrecognized`);
  CATALOGS.set(t, c);
}
function catalogFor(file) { return CATALOGS.get(file.test_type); }
// Placement is an optional side catalog: reference only, never required.
const PLACEMENT_CATALOG = (typeof RULE_PACKAGES.placement === 'string' && RULE_PACKAGES.placement.trim())
  ? parseCatalog(RULE_PACKAGES.placement) : null;

// Per-type red-team catalogs (the full catalog for each type; no category-scoping)
// + headers-only compact index for a degraded re-spawn.
const RED_TEAM_RULES = new Map();
const RED_TEAM_RULES_COMPACT = new Map();
for (const [t, c] of CATALOGS) { RED_TEAM_RULES.set(t, allRules(c)); RED_TEAM_RULES_COMPACT.set(t, compactCatalog(c)); }

// Fail-hard: an L > C file must carry a pre-extracted digest.
for (const f of MANIFEST) {
  if (trackOf(f).wholeClass === 'digest-escape' && (!f.digest || !String(f.digest).trim())) {
    throw new Error(`File exceeds C=${C} lines but no structural digest provided in manifest: ${f.path}`);
  }
}

// One canonicalization point keeps every downstream join on a single identity and the
// report on clean repo-relative paths; re-normalizing at each join would be error-prone.
const FILES = MANIFEST.map((f) => {
  const nf = {
    ...f,
    path: normPath(f.path),
    source_path: normPath(f.source_path),
    ...((Array.isArray(f.source_paths) && f.source_paths.length) ? { source_paths: f.source_paths.map(normPath) } : {}),
  };
  return { ...nf, ...trackOf(nf), units: buildUnits(nf) };
});
const TOTAL_UNITS = FILES.reduce((s, f) => s + f.units.length, 0);
const TOTAL_PROJ = FILES.reduce((s, f) => s + f.units.length * SLOTS, 0);
const CHUNKS = chunkFiles(FILES);
const filesByType = {};
for (const f of FILES) filesByType[f.test_type] = (filesByType[f.test_type] || 0) + 1;
const typeCounts = TEST_TYPES.filter((t) => filesByType[t]).map((t) => `${t}×${filesByType[t]}`).join(', ');

log(`Scope: ${FILES.length} files (${typeCounts}) | ${TOTAL_UNITS} units | ${TOTAL_PROJ} Wave-0 reviewers (${SLOTS}/unit) | ${K_adv} adversaries/file (lenses ${LENSES.map((l) => l.id).join('/')}) | ${CHUNKS.length} chunk(s) (G=${G}) | preset=${PRESET_NAME} T=${T} C=${C} M=${M} arbMax=${ARB_MAX == null ? '∞' : ARB_MAX} | models=${MODELS_NAME} (body=${MODEL_BODY}, adversary=${MODEL_ADVERSARY}, arbiter=${MODEL_ADVERSARY}(must-fix×3)/${MODEL_BODY})${manifest.base ? ` | base=${manifest.base}` : ''}`);
FILES.forEach((f) => log(`  ${f.test_type} Track ${f.track} ${f.path}: L=${combinedLines(f)} -> ${f.units.length} unit(s) [${f.wholeClass}]`));

// Run-wide accumulators.
const adaptation = { extra_peer_pass_reviewers: 0, extra_reviewers_by_file: {}, arbiters: 0, arbiters_confirmed: 0, arbiters_refuted: 0, arbiters_split: 0, skipped_reconcile_units: 0 };
const allFileResults = [];
const allFingerprints = [];
const allAdvSignals = [];
const redTeamMetrics = { ran: false, challenges_made: 0, challenges_defended: 0, challenges_overturned: 0, resurrections: 0, new_findings_introduced: 0, new_findings_adopted: 0, skip_reasons: [] };
const coverageGapFiles = [];
// Detect-and-flag signal (a), keyed by integration-test path: present when the
// file's consensus reached the INTEGRATION-008 unit-shape smoke check.
const assertionShapeFlags = new Map();

// ===========================================================================
// Per-chunk pipeline: Waves 0-3 + arbitration + per-file verdicts.
// Cross-file is deferred and run once globally after all chunks.
// ===========================================================================
for (let ci = 0; ci < CHUNKS.length; ci++) {
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

  const reviewsByUnit = new Map();
  for (const r of wave0Reviews.filter(Boolean)) {
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

  const wave1 = (await parallel(reconcileTasks.map((t) => () =>
    spawn(reconcilePrompt(t.unit, t.unit.file, t.label, t.own, t.peers, t.subsetRules), {
      label: `recon:${t.unit.ukey}:${t.label}`, phase: 'Wave 1: Peer reconciliation', model: MODEL_BODY,
      agentType: TYPE_REVIEWER, schema: RECONCILE_SCHEMA,
    }).then((r) => (r ? { ukey: t.unit.ukey, n: t.n, reviewer: t.label, ...r } : null))))).filter(Boolean);

  // Reconciliation record per unit (each reviewer's maintained findings + withdrawn-with-reasons),
  // for the Wave-2 red-team context package. Captured from Wave 1, the primary peer reconciliation.
  const reconByUnit = new Map();
  for (const w of wave1) {
    if (!reconByUnit.has(w.ukey)) reconByUnit.set(w.ukey, []);
    reconByUnit.get(w.ukey).push({ reviewer: w.reviewer, maintained: w.findings || [], withdrawn: w.withdrawn || [] });
  }
  // Assemble a file's red-team context: per-reviewer reconciliation_record (aggregated across the
  // file's units) + withdrawn_findings with who first reported each in Wave 0 and the withdrawal reason.
  const fileReconContext = (f) => {
    const record = [], withdrawnByRule = new Map(), multiUnit = f.units.length > 1;
    for (const unit of f.units) {
      const reporters = new Map();   // rule_id -> Wave-0 reviewers who reported it
      for (const r of (reviewsByUnit.get(unit.ukey) || [])) for (const fn of (r.findings || [])) {
        if (!reporters.has(fn.rule_id)) reporters.set(fn.rule_id, new Set());
        reporters.get(fn.rule_id).add(r.reviewer);
      }
      for (const rec of (reconByUnit.get(unit.ukey) || [])) {
        record.push({
          reviewer: rec.reviewer,
          ...(multiUnit ? { unit: unit.ukey } : {}),
          maintained: (rec.maintained || []).map((m) => ({ rule_id: m.rule_id, location: m.location })),
          withdrawn: (rec.withdrawn || []).map((w) => ({ rule_id: w.rule_id, reason: w.reason })),
        });
        for (const w of (rec.withdrawn || [])) {
          if (!withdrawnByRule.has(w.rule_id)) withdrawnByRule.set(w.rule_id, { rule_id: w.rule_id, originally_reported_by: [...(reporters.get(w.rule_id) || [])], reason: w.reason });
        }
      }
    }
    return { withdrawn_findings: [...withdrawnByRule.values()], reconciliation_record: record };
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
      const wave1b = (await parallel(pass2Tasks.map((t) => () =>
        spawn(reconcilePrompt(t.unit, t.unit.file, t.reviewer, t.own, t.peers, t.subsetRules), {
          label: `recon2:${t.unit.ukey}:${t.reviewer}`, phase: 'Wave 1: Peer reconciliation', model: MODEL_BODY,
          agentType: TYPE_REVIEWER, schema: RECONCILE_SCHEMA,
        }).then((r) => (r ? { ukey: t.unit.ukey, ...r, reviewer: t.reviewer } : null))))).filter(Boolean);
      adaptation.extra_peer_pass_reviewers += wave1b.length;   // count survivors, mirroring Adaptation 6
      for (const ukey of pass2Ukeys) {
        const recon = wave1b.filter((w) => w.ukey === ukey);
        if (recon.length > 0) bindingByUnit.set(ukey, recon.map((w) => ({ reviewer: w.reviewer, findings: w.findings || [] })));
      }
      consensus = fileConsensus();
    }
  }

  // Concession rate for the red-team skip signal.
  const wave0Keys = new Set();
  for (const r of wave0Reviews.filter(Boolean)) for (const fnd of (r.findings || [])) wave0Keys.add(r.ukey + '|' + findKey(fnd));
  const bindingKeys = new Set();
  for (const [ukey, stances] of bindingByUnit) for (const st of stances) for (const fnd of (st.findings || [])) bindingKeys.add(ukey + '|' + findKey(fnd));
  let withdrawnCount = 0;
  for (const k of wave0Keys) if (!bindingKeys.has(k)) withdrawnCount++;
  const concessionRate = wave0Keys.size === 0 ? 0 : withdrawnCount / wave0Keys.size;

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
    const widen = (await parallel(widenTasks.map((t) => () =>
      spawn(reviewerPrompt(t.unit, t.unit.file, t.label), {
        label: `widen:${t.unit.ukey}:${t.label}`, phase: 'Targeted widening', model: MODEL_BODY,
        agentType: TYPE_REVIEWER, schema: REVIEWER_SCHEMA,
      }).then((r) => (r ? { ukey: t.unit.ukey, reviewer: t.label, ...r } : null))))).filter(Boolean);
    for (const w of widen) {
      const arr = bindingByUnit.get(w.ukey) || [];
      arr.push({ reviewer: w.reviewer, findings: w.findings || [] });
      bindingByUnit.set(w.ukey, arr);
      const path = chunkUnits.find((u) => u.ukey === w.ukey).fileId;
      adaptation.extra_reviewers_by_file[path] = (adaptation.extra_reviewers_by_file[path] || 0) + 1;
    }
    consensus = fileConsensus();
  }

  // ---- Adaptation point 2 — red-team skip signal ----
  const totalKept = consensus.reduce((a, c) => a + c.kept.length, 0);
  const redTeamSkip = totalKept === 0 || concessionRate >= 0.5 || !budgetOk();
  const skipReason = totalKept === 0
    ? 'zero consensus findings — nothing to challenge'
    : (concessionRate >= 0.5 ? `peer reconciliation already conceded ${(concessionRate * 100).toFixed(0)}% of Wave-0 findings (>= 50%)`
      : (!budgetOk() ? 'budget floor reached before red team' : ''));
  log(`Chunk ${ci + 1}: ${totalKept} kept | concession ${(concessionRate * 100).toFixed(0)}% | red team ${redTeamSkip ? 'SKIPPED: ' + skipReason : 'RUNS'}`);

  const challengesByPath = new Map();
  if (redTeamSkip) {
    if (skipReason) redTeamMetrics.skip_reasons.push(skipReason);
  } else {
    redTeamMetrics.ran = true;
    // ---- WAVE 2 — red team (per file × K lenses; full catalog) ----
    phase('Wave 2: Red team');
    const consByPath = new Map(consensus.map((c) => [c.path, c]));
    const imprByFileLens = new Map();
    for (const im of wave0Impr.filter(Boolean)) {
      const concerns = (im.files || []).flatMap((fr) => fr.concerns || []);
      imprByFileLens.set(`${im.path}::${im.lens}`, concerns);
    }

    // Each (file, lens) is one independent adversary reading exactly that one file.
    const redTeamRaw = await parallel(advTasks.map((t) => () => {
      const f = t.file, c = consByPath.get(f.path), rc = fileReconContext(f);
      const pkg = { file_path: f.path, category: categoryByPath.get(f.path), consensus_findings: c ? c.kept.map((k) => ({ rule_id: k.rule_id, enforce: k.enforce, consensus: k.consensus, location: k.location, summary: k.summary })) : [], withdrawn_findings: rc.withdrawn_findings, reconciliation_record: rc.reconciliation_record };
      const impression = { file_path: f.path, concerns: imprByFileLens.get(`${f.path}::${t.lens.id}`) || [] };
      const redTeamRules = RED_TEAM_RULES.get(f.test_type);
      const redTeamRulesCompact = RED_TEAM_RULES_COMPACT.get(f.test_type);
      return spawn(redTeamPrompt(pkg, impression, t.lens, `adversary-${t.lens.id}`, redTeamRules, false), {
        label: `redteam:c${ci}:${f.path}:${t.lens.id}`, phase: 'Wave 2: Red team', model: MODEL_ADVERSARY,
        agentType: TYPE_ADVERSARY, schema: REDTEAM_SCHEMA,
        degrade: () => redTeamPrompt(pkg, impression, t.lens, `adversary-${t.lens.id}`, redTeamRulesCompact, true),
      }).then((r) => ({ path: f.path, lens: t.lens.id, result: r }));
    }));

    // Per-file coverage: a file is covered iff >= 1 of its K adversaries returned a result;
    // coverage_gap is set only if ALL K of a file's adversaries failed (never report an
    // incomplete adversarial pass as complete — the [!CAUTION] flag stays loud).
    const okByFile = new Map();
    for (const e of redTeamRaw) if (e.result) okByFile.set(e.path, (okByFile.get(e.path) || 0) + 1);
    for (const f of chunkFilesList) if (!okByFile.get(f.path)) coverageGapFiles.push(f.path);

    // Union every surviving lens adversary's challenges per file into the defense wave.
    for (const e of redTeamRaw) {
      if (!e.result) continue;
      for (const fr of (e.result.files || [])) {
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
      const c = consByPath.get(path);
      const ids = new Set();
      for (const k of (c ? c.kept : [])) ids.add(k.rule_id);
      for (const fr of frs) {
        for (const x of (fr.challenges_to_consensus || [])) ids.add(x.rule_id);
        for (const x of (fr.resurrections || [])) ids.add(x.rule_id);
        for (const x of (fr.new_findings || [])) ids.add(x.rule_id);
      }
      const dfile = chunkFilesList.find((f) => f.path === path);
      const subsetRules = rulesByIds(catalogFor(dfile), ids);
      for (let n = 1; n <= SLOTS; n++) defenseTasks.push({ path, file: dfile, label: `reviewer-${n}`, consensus: c ? { kept: c.kept, contested: c.contested } : { kept: [], contested: [] }, challenges: frs, subsetRules });
    }
    let defense = [];
    if (defenseTasks.length > 0) {
      log(`Wave 3: defending ${challengesByPath.size} challenged file(s) with 3 reconcilers each`);
      defense = (await parallel(defenseTasks.map((t) => () =>
        spawn(defensePrompt(t.file, t.label, t.consensus, t.challenges, t.subsetRules), {
          label: `defense:${t.file.path}:${t.label}`, phase: 'Wave 3: Defense', model: MODEL_BODY,
          agentType: TYPE_REVIEWER, schema: DEFENSE_SCHEMA,
        }).then((r) => (r ? r : null))))).filter(Boolean);
    } else { log('Wave 3: no files drew actionable challenges — defense skipped'); }

    // Fold defense into consensus (majority of 3 defenders per file).
    const overturnedMustFix = [];
    const byPath = new Map();
    for (const d of defense) { if (!byPath.has(d.path)) byPath.set(d.path, []); byPath.get(d.path).push(d); }
    for (const c of consensus) {
      const defs = byPath.get(c.path);
      if (!defs) { c.kept.forEach((k) => { if (!k.adversary_impact) k.adversary_impact = 'unchanged'; }); continue; }
      const withdrawVotes = new Map(), adoptVotes = new Map(), readoptVotes = new Map();
      for (const d of defs) {
        for (const w of (d.withdrawn || [])) withdrawVotes.set(w.rule_id, (withdrawVotes.get(w.rule_id) || 0) + 1);
        for (const a of (d.adopted_new || [])) { const k = findKey(a); adoptVotes.set(k, { n: ((adoptVotes.get(k) || {}).n || 0) + 1, f: a }); }
        for (const r of (d.re_adopted || [])) { const k = findKey(r); readoptVotes.set(k, { n: ((readoptVotes.get(k) || {}).n || 0) + 1, f: r }); }
      }
      c.kept = c.kept.filter((k) => {
        if ((withdrawVotes.get(k.rule_id) || 0) >= 2) {
          k.adversary_impact = 'overturned';
          if (normEnforce(k.enforce) === 'must-fix') overturnedMustFix.push({ ...k });
          c.contested.push({ ...k, consensus: 'contested', reported_by: ['overturned in defense'], outcome: 'must-fix overturned by adversary defense' });
          return false;
        }
        k.adversary_impact = k.adversary_impact || 'defended';
        return true;
      });
      for (const [, v] of adoptVotes) if (v.n >= 2) { c.kept.push({ ...v.f, enforce: normEnforce(v.f.enforce), title: shortTitle(v.f.summary), consensus: 'majority', adversary_impact: 'introduced' }); redTeamMetrics.new_findings_adopted++; }
      for (const [, v] of readoptVotes) if (v.n >= 2) { c.kept.push({ ...v.f, enforce: normEnforce(v.f.enforce), title: shortTitle(v.f.summary), consensus: 'majority', adversary_impact: 'resurrected' }); redTeamMetrics.resurrections++; }
    }
    redTeamMetrics.challenges_overturned += overturnedMustFix.length;
    for (const c of consensus) for (const k of c.kept) if (k.adversary_impact === 'defended') redTeamMetrics.challenges_defended++;
    consensus._overturnedMustFix = overturnedMustFix;
  }
  for (const c of consensus) for (const k of c.kept) if (!k.adversary_impact) k.adversary_impact = 'unchanged';

  // ---- Adaptation point 5 — arbitration (must-fix-first; ARB_MAX caps the tail) ----
  // Every contested finding is arbitrated up to the preset's ARB_MAX. Tasks are sorted
  // must-fix-first, and must-fix are ALWAYS arbitrated regardless of the cap — the cap only
  // trims the lower-severity tail, and trimmed findings stay in `contested` and surface
  // unchanged. ARB_MAX === null means uncapped (deep/standard). A contested MUST-FIX gets 3
  // adversary-tier arbiters with a majority verdict (>=2 confirm -> kept, >=2 refute ->
  // excluded, no majority -> KEPT marked `split` so a possibly-real must-fix is never
  // silently dropped). should-fix / consider keep a single body-tier arbiter (lower stakes).
  phase('Arbitration');
  const arbiterTasks = [];
  for (const c of consensus) for (const ct of c.contested) {
    const mustFix = normEnforce(ct.enforce) === 'must-fix';
    arbiterTasks.push({ finding: ct, path: c.path, file: chunkFilesList.find((f) => f.path === c.path), mustFix, votes: mustFix ? 3 : 1, model: mustFix ? MODEL_ADVERSARY : MODEL_BODY });
  }
  arbiterTasks.sort((a, b) => sevRank(b.finding.enforce) - sevRank(a.finding.enforce));
  // Apply ARB_MAX: keep every must-fix task, fill the remaining budget with the highest-
  // severity rest. Dropped tasks are never spawned and remain contested in the report.
  const arbActive = ARB_MAX == null ? arbiterTasks : (() => {
    const mf = arbiterTasks.filter((t) => t.mustFix);
    const rest = arbiterTasks.filter((t) => !t.mustFix);
    return [...mf, ...rest.slice(0, Math.max(0, ARB_MAX - mf.length))];
  })();
  if (arbActive.length > 0 && budgetOk()) {
    const totalArbiters = arbActive.reduce((s, t) => s + t.votes, 0);
    const capNote = arbActive.length < arbiterTasks.length ? ` (capped from ${arbiterTasks.length} by arbMax=${ARB_MAX}; tail left contested)` : '';
    log(`Adaptation 5: arbitrating ${arbActive.length} contested finding(s)${capNote} (${totalArbiters} arbiter agent(s); must-fix x3 ${MODEL_ADVERSARY})`);
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
    const votesByTask = new Map();
    for (const r of votesRaw) { if (!votesByTask.has(r.ti)) votesByTask.set(r.ti, []); if (r.v) votesByTask.get(r.ti).push(r.v); }

    arbActive.forEach((t, ti) => {
      const target = consensus.find((x) => x.path === t.path);
      if (!target) return;
      const idx = target.contested.findIndex((f) => f.rule_id === t.finding.rule_id && f.location === t.finding.location);
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

  // ---- Per-file verdicts for this chunk ----
  for (const f of chunkFilesList) {
    const c = consensus.find((x) => x.path === f.path);
    const extraInfo = (f.wholeClass === 'digest-escape')
      ? [{ rule_id: 'TEAM-SPLIT', title: 'Split this test class', enforce: 'consider', location: `${f.path}:1`, method: 'class-level', consensus: 'unanimous', adversary_impact: 'unchanged', arbitration: null, current: '', suggested: '', summary: `${f.path} (${combinedLines(f)} combined lines) exceeds the cross-body review limit C=${C}; the class-bodies (cross-method) rules were not evaluated. Split this test class.`, dissent: null, implies_src_change: false }]
      : [];
    const b = bucketFile(c, extraInfo);
    // branch_touched: diff runs only — is the finding's method in the literal changed set? null on a
    // non-diff run or a class-level finding (no method to scope).
    const changedSet = Array.isArray(f.changed_methods) ? new Set(f.changed_methods.map(methodId)) : null;
    const tagBranch = (e) => { const mid = methodId(e.method); e.branch_touched = (changedSet && mid && mid !== 'class-level') ? changedSet.has(mid) : null; };
    b.errors.forEach(tagBranch); b.warnings.forEach(tagBranch); b.informational.forEach(tagBranch);
    // Signal (a): record the file when INTEGRATION-008 reached consensus, so it
    // is flagged below even though informational findings never raise status.
    if (f.test_type === 'integration') {
      const i8 = b.informational.find((x) => x.rule_id === 'INTEGRATION-008');
      if (i8) assertionShapeFlags.set(f.path, i8.summary || i8.title || 'consensus: every assertion is unit-shape (INTEGRATION-008)');
    }
    const reviewerLabels = ['reviewer-1', 'reviewer-2', 'reviewer-3'];
    if (adaptation.extra_reviewers_by_file[f.path]) reviewerLabels.push('reviewer-4', 'reviewer-5');
    allFileResults.push({
      path: f.path, test_type: f.test_type, status: b.status, category: categoryByPath.get(f.path) || '?',
      track: f.track, units: f.units.length, reviewers: reviewerLabels,
      errors: b.errors, warnings: b.warnings, informational: b.informational,
      contested: c.contested.map((ct) => { const mid = methodId(ct.method); return ({ rule_id: ct.rule_id, title: ct.title, enforce: ct.enforce, location: ct.location, method: ct.method || 'class-level', branch_touched: (changedSet && mid && mid !== 'class-level') ? changedSet.has(mid) : null, reported_by: ct.reported_by || [], reason: ct.summary || '', outcome: ct.outcome || '', arbitration: ct.arbitration || null }); }),
      consensus: { unanimous: c.kept.filter((k) => k.consensus === 'unanimous').length, majority: c.kept.filter((k) => k.consensus !== 'unanimous').length, contested: c.contested.length },
      wholeClass: f.wholeClass,
    });
    allFingerprints.push({ path: f.path, test_type: f.test_type, track: f.track, source_paths: (Array.isArray(f.source_paths) && f.source_paths.length) ? f.source_paths : [f.source_path], fingerprint: f.fingerprint || '' });
  }
}

// ===========================================================================
// Cross-file consistency — once globally, after all chunks (F_cap sharding).
// ===========================================================================
phase('Cross-file consistency');
let consistency = [];
if (allFingerprints.length <= F_cap) {
  const cf = await spawn(crossFilePrompt(allFingerprints, allAdvSignals, null), {
    label: 'cross-file', phase: 'Cross-file consistency', model: MODEL_BODY, agentType: TYPE_REVIEWER, schema: CROSSFILE_SCHEMA,
  });
  consistency = (cf && cf.consistency) || [];
} else {
  const axes = ['setUp strategy', 'mock strategy', 'assertion style', 'data-provider usage', 'attribute ordering'];
  const shards = await parallel(axes.map((ax) => () => spawn(crossFilePrompt(allFingerprints, allAdvSignals, ax), {
    label: `cross-file:${ax}`, phase: 'Cross-file consistency', model: MODEL_BODY, agentType: TYPE_REVIEWER, schema: CROSSFILE_SCHEMA,
  })));
  for (const s of shards.filter(Boolean)) consistency.push(...((s && s.consistency) || []));
  log(`Cross-file sharded by ${axes.length} pattern axes (>${F_cap} files)`);
}
consistency = consistency.map((c) => ({ ...c, source: 'cross-file consistency agent' }));

// ===========================================================================
// Cross-cutting SUT-coverage map — built in-script (not by an agent) so the
// placement flags below get an exact redundancy signal. Reports a SUT only when
// more than one test file covers it. Keys are canonical so one SUT's absolute and relative
// spellings group — without it this map emitted a false-empty coverage_overlap.
// ===========================================================================
const sutToTests = new Map();
for (const f of FILES) {
  const srcs = (Array.isArray(f.source_paths) && f.source_paths.length) ? f.source_paths : [f.source_path];
  for (const sut of srcs) {
    const sutKey = normPath(sut);
    if (!sutToTests.has(sutKey)) sutToTests.set(sutKey, new Map());
    sutToTests.get(sutKey).set(normPath(f.path), f.test_type);   // dedup covering tests per SUT by path
  }
}
const coverage_overlap = [];
for (const [sut, tests] of sutToTests) {
  if (tests.size < 2) continue;
  const covered_by = [...tests].map(([path, test_type]) => ({ path, test_type }));
  const types = new Set(covered_by.map((t) => t.test_type));
  const note = (types.has('unit') && types.has('integration'))
    ? 'integration test redundant with existing unit coverage of this SUT'
    : 'multiple tests cover the same SUT';
  coverage_overlap.push({ sut, covered_by, note });
}

// ===========================================================================
// Integration-to-unit placement flags — detect-and-flag only, never raises
// status, and each points at the standalone migrator because the team review
// never mutates files. A flag fires on an INTEGRATION-008 unit-shape consensus
// (a) and/or redundancy with existing unit coverage (b). The placement catalog,
// when supplied, only contributes its rule IDs as a reference pointer.
// ===========================================================================
const placementRefIds = PLACEMENT_CATALOG ? PLACEMENT_CATALOG.order.join(', ') : null;
const redundantIntegration = new Map();   // integration path -> overlapping unit test paths
for (const ov of coverage_overlap) {
  const unitTests = ov.covered_by.filter((t) => t.test_type === 'unit').map((t) => t.path);
  if (!unitTests.length) continue;
  for (const t of ov.covered_by) {
    if (t.test_type !== 'integration') continue;
    if (!redundantIntegration.has(t.path)) redundantIntegration.set(t.path, new Set());
    for (const u of unitTests) redundantIntegration.get(t.path).add(u);
  }
}
const placement_flags = [];
for (const path of new Set([...assertionShapeFlags.keys(), ...redundantIntegration.keys()])) {
  const a = assertionShapeFlags.has(path);
  const b = redundantIntegration.has(path);
  const reason = a && b ? 'both' : (a ? 'assertions_unit_shape' : 'redundant_with_unit');
  const evidence = [];
  if (a) evidence.push(`assertion-shape consensus: ${assertionShapeFlags.get(path)}`);
  if (b) evidence.push(`already covered by unit test(s): ${[...redundantIntegration.get(path)].join(', ')}`);
  if (placementRefIds) evidence.push(`placement reasoning to audit in the migrator: ${placementRefIds}`);
  placement_flags.push({ path, reason, evidence: evidence.join('; '), pointer: 'phpunit-integration-to-unit-migrating' });
}
if (placement_flags.length) log(`Placement flags: ${placement_flags.length} integration test(s) flagged for placement review (informational, never raises status)`);
if (coverage_overlap.length) log(`Coverage map: ${coverage_overlap.length} SUT(s) covered by more than one test`);

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

// ===========================================================================
// Verdicts — assemble the single result the rendering step consumes.
// ===========================================================================
const anyErrors = allFileResults.some((f) => f.errors.length > 0);
const anyWarn = allFileResults.some((f) => f.warnings.length > 0 || f.informational.length > 0) || consistency.length > 0;
const overall = anyErrors ? 'ISSUES_FOUND' : (anyWarn ? 'NEEDS_ATTENTION' : 'PASS');

// Escalation signal: findings whose fix needs a production (src/) change, not test-only. Informational — never raises status.
const implies_src_change = allFileResults.flatMap((f) =>
  [...f.errors, ...f.warnings, ...f.informational].filter((e) => e.implies_src_change)
    .map((e) => ({ path: f.path, rule_id: e.rule_id, method: e.method, location: e.location, summary: e.summary })));

const decomposition = FILES.map((f) => ({
  path: f.path, track: f.track,
  method_shards: f.track === 'B' ? f.units.filter((u) => u.type === 'method').length : 0,
  whole_class: f.track === 'B' ? f.wholeClass : 'n/a',
  split_skip: f.wholeClass === 'digest-escape' ? `${combinedLines(f)} combined lines > C=${C}; class-bodies rules not evaluated` : null,
}));

const uniqueCoverageGap = [...new Set(coverageGapFiles)];
const red_team = redTeamMetrics.ran
  ? {
    skipped: false, skip_reason: null,
    challenges_made: redTeamMetrics.challenges_made,
    challenges_defended: redTeamMetrics.challenges_defended,
    challenges_overturned: redTeamMetrics.challenges_overturned,
    resurrections: redTeamMetrics.resurrections,
    new_findings_introduced: redTeamMetrics.new_findings_introduced,
    new_findings_adopted: redTeamMetrics.new_findings_adopted,
    change_rate: 0,
    coverage_gap: uniqueCoverageGap.length ? { files: uniqueCoverageGap, note: 'in-scope files left un-red-teamed after re-spawn — adversary coverage is incomplete' } : null,
  }
  : { skipped: true, skip_reason: redTeamMetrics.skip_reasons.join('; ') || 'red team not run', challenges_made: 0, challenges_defended: 0, challenges_overturned: 0, resurrections: 0, new_findings_introduced: 0, new_findings_adopted: 0, change_rate: 0, coverage_gap: null };

const totalReviewers = TOTAL_PROJ + Object.values(adaptation.extra_reviewers_by_file).reduce((a, b) => a + b, 0);
// budget.spent() is this turn's OUTPUT tokens, NOT the cache-inclusive billable total —
// labelled honestly. Surfaced because the reviewer-only count understated real fan-out by
// an order of magnitude.
const outputTokens = (typeof budget !== 'undefined' && budget && typeof budget.spent === 'function') ? budget.spent() : null;
log(`Verdict: ${overall} | ${allFileResults.filter((f) => f.status !== 'PASS').length}/${FILES.length} files with issues | ${consistency.length} cross-file findings | ${coverage_overlap.length} coverage overlap(s) | ${placement_flags.length} placement flag(s) | ${adoption_opportunities.length} adoption signal(s) | ${implies_src_change.length} src-change escalation(s) | ${adaptation.arbiters} arbiter(s) | ${agentsSpawned} agents spawned | ${outputTokens == null ? 'n/a' : Math.round(outputTokens / 1000) + 'k'} output tokens`);

return {
  summary: {
    files_reviewed: FILES.length,
    files_reviewed_by_type: filesByType,
    reviewers: totalReviewers,
    agents_spawned: agentsSpawned,
    output_tokens: outputTokens,
    overall_status: overall,
    files_with_issues: allFileResults.filter((f) => f.status !== 'PASS').length,
    implies_src_change_count: implies_src_change.length,
  },
  files: allFileResults.map((f) => ({
    path: f.path, test_type: f.test_type, status: f.status, category: f.category, reviewers: f.reviewers,
    errors: f.errors, warnings: f.warnings, informational: f.informational,
    contested: f.contested, consensus: f.consensus,
  })),
  consistency,
  coverage_overlap,
  placement_flags,
  adoption_opportunities,
  implies_src_change,
  decomposition,
  red_team,
  adaptation,
};
