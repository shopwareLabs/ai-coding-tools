export const meta = {
  name: 'phpunit-unit-test-team-review',
  description: 'Team consensus + red-team review of Shopware PHPUnit unit tests. Reads its manifest from args; encodes the wave shape, gate, caps, and adaptation points of the team-reviewing skill references.',
  phases: [
    { title: 'Wave 0: Review + impressions' },
    { title: 'Wave 1: Peer reconciliation' },
    { title: 'Targeted widening' },
    { title: 'Wave 2: Red team' },
    { title: 'Wave 3: Defense' },
    { title: 'Arbitration' },
    { title: 'Cross-file consistency' },
  ],
};

// ===========================================================================
// Manifest (args) — Phase 1/2 output. Fail hard on incomplete input.
//   { files: [ { path, source_path, test_lines, source_lines, method_count,
//                methods: [scoped names | []], test_methods: [all names],
//                fingerprint: "<structural signature>", digest: "<text>"|null } ],
//     rule_packages: { full: "<rendered full unit-review catalog>" },
//     base?: "<base ref, for logging>" }
// The full catalog is the single rule source: the script selects each wave's
// scoped `## RULES` block from it (review_unit / scoped_review / category /
// finding-referenced), byte-identical to build_rule_package's scoped output.
// ===========================================================================
const manifest = args;
if (!manifest || typeof manifest !== 'object') throw new Error('Manifest (args) missing or not an object');
const MANIFEST = manifest.files;
if (!Array.isArray(MANIFEST) || MANIFEST.length === 0) throw new Error('Manifest is empty — abort (fail-hard guard)');
const FULL_CATALOG = manifest.rule_packages && manifest.rule_packages.full;
if (typeof FULL_CATALOG !== 'string' || FULL_CATALOG.trim().length === 0) {
  throw new Error('rule_packages.full missing — the rendered rule catalog is required (build_rule_package + Read in Phase 2)');
}
for (const e of MANIFEST) {
  if (!e || typeof e.path !== 'string' || !e.path.endsWith('Test.php')) throw new Error('Manifest entry missing/invalid path: ' + JSON.stringify(e));
  if (typeof e.source_path !== 'string' || !e.source_path) throw new Error('Manifest entry missing source_path: ' + e.path);
  if (!Number.isFinite(e.test_lines) || !Number.isFinite(e.source_lines)) throw new Error('Manifest entry missing line counts: ' + e.path);
  if (!Array.isArray(e.methods)) throw new Error('Manifest entry missing methods scope: ' + e.path);
  if (!Array.isArray(e.test_methods)) throw new Error('Manifest entry missing test_methods (all method names): ' + e.path);
}

// ===========================================================================
// Constants — frozen seed values (authoritative table: workflow-design.md).
// ===========================================================================
// <<GEOM-CONST-START>>  (geometry seeds the pure helpers read — fixture-shared)
const T = 450;            // combined test+source lines above which a file is decomposed (Track B)
const C = 800;            // combined lines above which whole-class becomes the digest-only escape
const M = 8;              // max test methods per method-shard
const K_adv = 6;          // max files per adversary impression agent
const U_file = 18;        // max reviewer agents per single file
const G = 300;            // max reviewer agents per chunk (auto-partition above this)
const F_cap = 40;         // files the cross-file agent ingests before sharding by pattern dimension
const SLOTS = 3;          // reviewers per unit (consensus invariant: 2-of-3 per track)
// <<GEOM-CONST-END>>
const RESPAWN_MAX = 2;    // re-spawn attempts for a dead unit/agent before degrade-and-flag
const BUDGET_FLOOR = 60000; // token floor checked before any conditional wave
const ARB_CAP = 15;       // max arbiter agents per run

const MODEL_BODY = 'sonnet';
const TYPE_REVIEWER = 'test-writing:test-reviewer';
const TYPE_ADVERSARY = 'test-writing:test-adversary';

function budgetOk() { return !budget.total || budget.remaining() > BUDGET_FLOOR; }

// ===========================================================================
// Output schemas (StructuredOutput contracts per role; agent-guardrails.md).
// ===========================================================================
const FINDING_PROPS = {
  rule_id: { type: 'string' },
  enforce: { type: 'string', enum: ['must-fix', 'should-fix', 'consider'] },
  location: { type: 'string', description: 'real file:line, e.g. FooTest.php:45' },
  summary: { type: 'string' },
  current: { type: 'string' },
  suggested: { type: 'string' },
};
const REVIEWER_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['reviewer', 'category', 'clean', 'findings'],
  properties: {
    reviewer: { type: 'string' },
    category: { type: 'string', description: 'source-class category A(DTO)|B(Service)|C(Flow/Event)|D(DAL)|E(Exception)' },
    clean: { type: 'boolean' },
    findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['rule_id', 'enforce', 'location', 'summary'], properties: FINDING_PROPS } },
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
    findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['rule_id', 'enforce', 'location', 'summary'], properties: FINDING_PROPS } },
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
      new_findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['rule_id', 'enforce', 'location', 'summary'], properties: FINDING_PROPS } },
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
    findings: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['rule_id', 'enforce', 'location', 'summary', 'adversary_impact'], properties: { ...FINDING_PROPS, adversary_impact: { type: 'string', enum: ['defended', 'unchanged'] } } } },
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

// <<PURE-HELPERS-START>>  (no agent/log/phase/budget refs — fixture-testable)
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
// Wave-2 red-team package: rules applicable to any of the given categories.
function categoryRules(catalog, categories) {
  const want = new Set(categories.filter(Boolean));
  if (want.size === 0) return joinRules(catalog.order.map((id) => catalog.byId.get(id)));
  const out = [];
  for (const id of catalog.order) {
    const r = catalog.byId.get(id);
    if (r.categories.length === 0 || r.categories.some((c) => want.has(c))) out.push(r);
  }
  return joinRules(out);
}

// ---------------------------------------------------------------------------
// Decomposition: per-file track + units (reviewer-allocation.md).
// ---------------------------------------------------------------------------
function combinedLines(file) { return (file.test_lines || 0) + (file.source_lines || 0); }
function trackOf(file) {
  const L = combinedLines(file);
  if (L <= T) return { track: 'A', wholeClass: 'n/a' };
  if (L <= C) return { track: 'B', wholeClass: 'fused' };
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
function effectiveShards(scopedMethods) {
  const shardCap = Math.floor((U_file - 3) / 3); // 5 at seed constants
  const Meff = Math.max(M, Math.ceil(scopedMethods / shardCap));
  return { Meff };
}
function buildUnits(file, catalog) {
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
function projForFile(file, catalog) { return buildUnits(file, catalog).length * SLOTS; }

// Greedy sequential chunk partition by per-file reviewer projection (<= G each).
function chunkFiles(files, catalog) {
  const chunks = [];
  let cur = [], curN = 0;
  for (const f of files) {
    const p = projForFile(f, catalog);
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
      rule_id: g.rule_id, title: shortTitle(rep.summary), enforce, location: rep.location,
      summary: rep.summary || '', current: rep.current || '', suggested: rep.suggested || '',
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
      rule_id: k.rule_id, title: k.title || shortTitle(k.summary), enforce: k.enforce, location: k.location,
      consensus: k.consensus || 'majority', adversary_impact: k.adversary_impact || 'unchanged',
      arbitration: k.arbitration || null, current: k.current || '', suggested: k.suggested || '',
      summary: k.summary || '', dissent: k.dissent || null,
    };
    if (k.enforce === 'must-fix') errors.push(entry);
    else if (k.enforce === 'should-fix') warnings.push(entry);
    else informational.push(entry);
  }
  for (const inf of (extraInformational || [])) informational.push(inf);
  const status = errors.length ? 'ISSUES_FOUND' : ((warnings.length || informational.length) ? 'NEEDS_ATTENTION' : 'PASS');
  return { errors, warnings, informational, status };
}
// <<PURE-HELPERS-END>>

// ===========================================================================
// Prompt builders (text sourced from agent-guardrails.md / red-team-context.md).
// ===========================================================================
const GUARD = [
  'You are a READ-ONLY reviewer in a multi-agent consensus review of Shopware PHPUnit unit tests.',
  'UNIVERSAL GUARDRAILS:',
  '- Read-only. Do NOT modify files, apply fixes, or run PHPStan/PHPUnit/ECS.',
  '- The ## RULES block at the end of this prompt is COMPLETE and scoped to your task — it holds every rule you must evaluate, and there is nothing more to fetch. Apply its detection algorithms against the code. You MUST Read/Grep the test file and its source class. You must NEVER read, open, search, or locate any rule file by any means: no Read/Grep/Glob of a rules directory or rendered package, no cat/grep/ugrep/find/bfs via Bash, no get_rules and no build_rule_package call. Reaching for a rule file is a defect, never a fallback.',
  '- Calibrated honesty. Report a finding ONLY when a rule detection algorithm fires on real code you read. If the unit is clean under your lens, say so plainly. Do not manufacture findings to look thorough; do not wave real ones through to look agreeable.',
  '- Cite real evidence: every finding names a real file:line you read and the rule clause it triggers. Never fabricate rule IDs, locations, or code.',
  '- Respect scope: judge only the methods named in your scope and their #[DataProvider] providers; when the scope says full class, review the whole class.',
  '- Emit exactly ONE short visible line (a finding tally) alongside your structured output. No other prose.',
].join('\n');

function reviewerPrompt(unit, file, label) {
  const isDigest = unit.type === 'digest';
  const lensLine = unit.type === 'method'
    ? 'You are reviewing ONLY the listed methods and their data providers (review_unit=method). Ignore cross-method and class-structure concerns — another track owns those.'
    : unit.type === 'wholeclass'
      ? 'You are reviewing class-structure + cross-method (class-bodies) concerns over the FULL class. Per-single-method-body findings belong to the method track; focus on structure, ordering, redundancy across methods, data-provider consolidation, duplicated arrange.'
      : isDigest
        ? 'You are reviewing the class-structure DIGEST only (Digest Mode). The class-bodies rules are NOT evaluated for this file (it exceeds the cross-body limit C). If the digest shows the class is too large to review whole, note "split this test class".'
        : 'You are reviewing the FULL class against ALL rule groups (Track A).';
  return [
    GUARD,
    '',
    `## ROLE: Wave 0 independent reviewer "${label}" for unit [${unit.ukey}].`,
    `Test file: ${file.path}`,
    `Source class (#[CoversClass]): ${file.source_path}`,
    `review_unit: ${unit.reviewUnits ? unit.reviewUnits.join(', ') : 'none (all rule groups)'}`,
    `Method scope: ${unit.methodScope}`,
    '',
    'STEP 1 — Invoke the Skill tool with skill="test-writing:phpunit-unit-test-reviewing".',
    isDigest
      ? 'Provide to the sub-skill: the source class path, review_unit=class-structure, and digest="<the digest text below>". Review the DIGEST text in this prompt — do NOT Read the test file (reading the bodies defeats the escape). rules = the verbatim ## RULES text below (Inline-Rules Mode; the sub-skill must NOT call get_rules).'
      : 'Provide to the sub-skill: the test file path, the source class path, review_unit as above, the method scope as above, and rules = the verbatim ## RULES text below (Inline-Rules Mode; the sub-skill must NOT call get_rules).',
    lensLine,
    isDigest ? '\nSTRUCTURAL DIGEST (review this; do not Read the test file):\n```\n' + (file.digest || '') + '\n```' : '',
    '',
    'STEP 2 — Return your findings strictly as the output schema. Set clean=true with findings=[] if nothing fires.',
    '',
    '## RULES',
    unit.rules,
  ].join('\n');
}

function adversaryImpressionPrompt(files, label) {
  return [
    'You are a READ-ONLY adversary forming INDEPENDENT impressions of Shopware PHPUnit unit tests.',
    '- Read-only. Do NOT modify files or run any tool beyond reading code. For IMPRESSIONS you do NOT use rules, get_rules, or any rule file — form intuitive concerns.',
    '',
    `## ROLE: Wave 0 adversary "${label}" forming impressions (no consensus exposure yet, no rule catalog).`,
    'For each assigned file, Read the test file and its source class, then apply these heuristic lenses:',
    '- Absence detection: behavior NOT tested that should be (uncovered branch, error path, boundary).',
    '- Consequence weighting: which gaps would cause the most production damage.',
    '- Dependency fan-out: shared assumptions/mocks that could mask a real bug.',
    '- Pattern anomalies: mocking/assertion/style inconsistencies.',
    '- The "would I be surprised if this passed while behavior broke?" test.',
    'Do NOT invoke any skill or get_rules. Return concerns per file as the schema (file_path, area, severity).',
    '',
    'Assigned files (test → source):',
    ...files.map((f) => `- ${f.path}  →  ${f.source_path}`),
  ].join('\n');
}

function reconcilePrompt(unit, file, label, own, peers, subsetRules) {
  return [
    GUARD,
    '',
    `## ROLE: Wave 1 PEER reconciler "${label}" for unit [${unit.ukey}] of ${file.path}.`,
    'STEP 1 — Invoke the Skill tool with skill="test-writing:phpunit-unit-test-reconciling" in PEER mode.',
    'Weigh your own Wave-0 findings against your peers\' findings on this same unit. Maintain a finding only if its detection algorithm truly fires; withdraw it (with a reason) if a peer\'s argument or the code shows it does not. Adopt a peer finding you now agree with.',
    'The ## RULES block holds only the rules your and your peers\' findings cite. Look up any contested rule by ID there; do NOT call get_rules.',
    '',
    `YOUR Wave-0 findings:\n${JSON.stringify(own, null, 1)}`,
    '',
    `PEERS' Wave-0 findings on this unit:\n${JSON.stringify(peers, null, 1)}`,
    '',
    'STEP 2 — Return your revised binding stance (findings + withdrawn) as the schema.',
    '',
    '## RULES',
    subsetRules,
  ].join('\n');
}

function redTeamPrompt(pkgs, impressions, label, catRules) {
  return [
    GUARD,
    '',
    `## ROLE: Wave 2 RED TEAM adversary "${label}". Challenge the preliminary consensus.`,
    'STEP 1 — Invoke the Skill tool with skill="test-writing:phpunit-unit-test-adversarial-reviewing".',
    'Use the consensus package + your Wave-0 impressions. Challenge weak findings, resurrect prematurely-withdrawn findings with code evidence, introduce findings the panel missed (each with a real detection-algorithm citation), and endorse the ones that are solid. The ## RULES block is the category-scoped catalog for your files; select rules from it by ID — do NOT call get_rules.',
    '',
    `Consensus package (per file: consensus_findings, withdrawn_findings, reconciliation_record):\n${JSON.stringify(pkgs, null, 1)}`,
    '',
    `Your Wave-0 impressions:\n${JSON.stringify(impressions, null, 1)}`,
    '',
    'STEP 2 — Return challenges/resurrections/new_findings/endorsements/cross_file_inconsistencies per file as the schema.',
    '',
    '## RULES',
    catRules,
  ].join('\n');
}

function defensePrompt(file, label, consensus, challenges, subsetRules) {
  return [
    GUARD,
    '',
    `## ROLE: Wave 3 DEFENSE reconciler "${label}" for ${file.path}.`,
    'STEP 1 — Invoke the Skill tool with skill="test-writing:phpunit-unit-test-reconciling" in ADVERSARY mode.',
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
    '- Read-only. You may Read files to confirm a divergence, but do NOT call get_rules or open any rule file.',
    '',
    `## ROLE: Cross-file consistency agent${axis ? ` (pattern axis: ${axis})` : ''}. Detect pattern DIVERGENCE across the test suite from the fingerprints below.`,
    'Compare these structural axes across files: setUp strategy, mock strategy (createMock vs createStub), assertion style (static:: vs $this->), data-provider usage, and attribute usage/ordering. Report only divergences where a clear majority follows one pattern and a minority diverges. Consistency findings are warnings. If the suite is uniform, return consistency=[].',
    '',
    `Per-file fingerprints:\n${JSON.stringify(fingerprints, null, 1)}`,
    '',
    `Adversary-surfaced candidate cross-file signals:\n${JSON.stringify(advSignals, null, 1)}`,
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
// ===========================================================================
async function spawn(promptText, opts) {
  for (let attempt = 0; attempt <= RESPAWN_MAX; attempt++) {
    const res = await agent(promptText, {
      label: attempt ? `${opts.label}#retry${attempt}` : opts.label,
      phase: opts.phase, model: opts.model, agentType: opts.agentType, schema: opts.schema,
    });
    if (res) return res;
    if (attempt < RESPAWN_MAX) log(`Re-spawn ${opts.label}: attempt ${attempt + 1}/${RESPAWN_MAX} (agent died)`);
  }
  log(`Re-spawn exhausted for ${opts.label} — degrading by role`);
  return null;
}

// ===========================================================================
// Build the plan + announce scope.
// ===========================================================================
const CATALOG = parseCatalog(FULL_CATALOG);
if (CATALOG.byId.size === 0) throw new Error('Parsed 0 rules from rule_packages.full — rendered catalog format unrecognized');

// Fail-hard: an L > C file must carry a pre-extracted digest.
for (const f of MANIFEST) {
  if (trackOf(f).wholeClass === 'digest-escape' && (!f.digest || !String(f.digest).trim())) {
    throw new Error(`File exceeds C=${C} lines but no structural digest provided in manifest: ${f.path}`);
  }
}

const FILES = MANIFEST.map((f) => ({ ...f, ...trackOf(f), units: buildUnits(f, CATALOG) }));
const TOTAL_UNITS = FILES.reduce((s, f) => s + f.units.length, 0);
const TOTAL_PROJ = FILES.reduce((s, f) => s + f.units.length * SLOTS, 0);
const CHUNKS = chunkFiles(FILES, CATALOG);

log(`Scope: ${FILES.length} files | ${TOTAL_UNITS} units | ${TOTAL_PROJ} Wave-0 reviewers (3/unit) | ${CHUNKS.length} chunk(s) (G=${G}) | T=${T} C=${C} M=${M} | tiers: body=sonnet, arbiter=opus(must-fix)/sonnet${manifest.base ? ` | base=${manifest.base}` : ''}`);
FILES.forEach((f) => log(`  Track ${f.track} ${f.path}: L=${combinedLines(f)} -> ${f.units.length} unit(s) [${f.wholeClass}]`));

// Run-wide accumulators.
const adaptation = { extra_peer_pass_reviewers: 0, extra_reviewers_by_file: {}, arbiters: 0, arbiters_confirmed: 0, arbiters_refuted: 0, skipped_reconcile_units: 0 };
const allFileResults = [];
const allFingerprints = [];
const allAdvSignals = [];
const redTeamMetrics = { ran: false, challenges_made: 0, challenges_defended: 0, challenges_overturned: 0, resurrections: 0, new_findings_introduced: 0, new_findings_adopted: 0, skip_reasons: [] };
const coverageGapFiles = [];

// ===========================================================================
// Per-chunk pipeline: Waves 0-3 + arbitration + per-file verdicts.
// Cross-file is deferred and run once globally after all chunks.
// ===========================================================================
for (let ci = 0; ci < CHUNKS.length; ci++) {
  const chunkFilesList = CHUNKS[ci];
  const chunkUnits = chunkFilesList.flatMap((f) => f.units.map((u) => ({ ...u, file: f })));
  if (CHUNKS.length > 1) log(`Chunk ${ci + 1}/${CHUNKS.length}: ${chunkFilesList.length} files, ${chunkUnits.length} units`);

  // ---- WAVE 0 — reviewers (3/unit) + adversary impressions ----
  phase('Wave 0: Review + impressions');
  const advGroups = [];
  for (let i = 0; i < chunkFilesList.length; i += K_adv) advGroups.push(chunkFilesList.slice(i, i + K_adv));

  const reviewerTasks = [];
  chunkUnits.forEach((unit) => { for (let n = 1; n <= SLOTS; n++) reviewerTasks.push({ unit, n, label: `reviewer-${n}` }); });

  const [wave0Reviews, wave0Impr] = await Promise.all([
    parallel(reviewerTasks.map((t) => () =>
      spawn(reviewerPrompt(t.unit, t.unit.file, t.label), {
        label: `rev:${t.unit.ukey}:${t.label}`, phase: 'Wave 0: Review + impressions', model: MODEL_BODY,
        agentType: TYPE_REVIEWER, schema: REVIEWER_SCHEMA,
      }).then((r) => (r ? { ukey: t.unit.ukey, fileId: t.unit.fileId, n: t.n, reviewer: t.label, ...r } : null)))),
    parallel(advGroups.map((grp, gi) => () =>
      spawn(adversaryImpressionPrompt(grp, `adversary-${gi}`), {
        label: `adv-impr:c${ci}:${gi}`, phase: 'Wave 0: Review + impressions', model: MODEL_BODY,
        agentType: TYPE_ADVERSARY, schema: ADV_IMPRESSION_SCHEMA,
      }).then((r) => (r ? { gi, files: grp.map((f) => f.path), ...r } : null)))),
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
    const subsetRules = rulesByIds(CATALOG, unitIds);
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
    // ---- WAVE 2 — red team (per adversary group; category-scoped rules) ----
    phase('Wave 2: Red team');
    const consByPath = new Map(consensus.map((c) => [c.path, c]));
    const imprByPath = new Map();
    for (const im of wave0Impr.filter(Boolean)) for (const fr of (im.files || [])) imprByPath.set(fr.file_path, fr.concerns || []);

    const redTeam = (await parallel(advGroups.map((grp, gi) => () => {
      const cats = [...new Set(grp.map((f) => categoryByPath.get(f.path)).filter((c) => c && c !== '?'))];
      const catRules = categoryRules(CATALOG, cats);
      const pkgs = grp.map((f) => {
        const c = consByPath.get(f.path);
        return { file_path: f.path, category: categoryByPath.get(f.path), consensus_findings: c ? c.kept.map((k) => ({ rule_id: k.rule_id, enforce: k.enforce, consensus: k.consensus, location: k.location, summary: k.summary })) : [], withdrawn_findings: (c ? c.contested : []).map((x) => ({ rule_id: x.rule_id, location: x.location, summary: x.summary })) };
      });
      const impressions = grp.map((f) => ({ file_path: f.path, concerns: imprByPath.get(f.path) || [] }));
      return spawn(redTeamPrompt(pkgs, impressions, `adversary-${gi}`, catRules), {
        label: `redteam:c${ci}:${gi}`, phase: 'Wave 2: Red team', model: MODEL_BODY,
        agentType: TYPE_ADVERSARY, schema: REDTEAM_SCHEMA,
      });
    }))).filter(Boolean);

    // Adversary coverage: which files were actually red-teamed (after re-spawn).
    const redTeamedPaths = new Set();
    for (let gi = 0; gi < advGroups.length; gi++) { if (redTeam.some((rt) => rt && (rt.adversary === `adversary-${gi}`))) for (const f of advGroups[gi]) redTeamedPaths.add(f.path); }
    // Fallback: map by returned file paths too.
    for (const rt of redTeam) for (const fr of (rt.files || [])) redTeamedPaths.add(fr.path);
    for (const f of chunkFilesList) if (!redTeamedPaths.has(f.path)) coverageGapFiles.push(f.path);

    for (const rt of redTeam) for (const fr of (rt.files || [])) {
      allAdvSignals.push(...(fr.cross_file_inconsistencies || []).map((x) => ({ ...x, file: fr.path })));
      redTeamMetrics.challenges_made += (fr.challenges_to_consensus || []).length;
      redTeamMetrics.new_findings_introduced += (fr.new_findings || []).length;
      const hasWork = (fr.challenges_to_consensus || []).length || (fr.resurrections || []).length || (fr.new_findings || []).length;
      if (hasWork) {
        if (!challengesByPath.has(fr.path)) challengesByPath.set(fr.path, []);
        challengesByPath.get(fr.path).push(fr);
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
      const subsetRules = rulesByIds(CATALOG, ids);
      for (let n = 1; n <= SLOTS; n++) defenseTasks.push({ path, file: chunkFilesList.find((f) => f.path === path), label: `reviewer-${n}`, consensus: c ? { kept: c.kept, contested: c.contested } : { kept: [], contested: [] }, challenges: frs, subsetRules });
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

  // ---- Adaptation point 5 — arbitration (contested + overturned must-fix) ----
  phase('Arbitration');
  const arbiterTasks = [];
  for (const c of consensus) for (const ct of c.contested) {
    arbiterTasks.push({ finding: ct, path: c.path, file: chunkFilesList.find((f) => f.path === c.path), model: normEnforce(ct.enforce) === 'must-fix' ? 'opus' : 'sonnet' });
  }
  if (arbiterTasks.length > 0 && budgetOk()) {
    const todo = arbiterTasks.slice(0, ARB_CAP);
    if (arbiterTasks.length > ARB_CAP) log(`Adaptation 5: ${arbiterTasks.length} contested findings; capping arbitration at ${ARB_CAP}`);
    log(`Adaptation 5: arbitrating ${todo.length} contested finding(s)`);
    adaptation.arbiters += todo.length;
    const rawArb = await parallel(todo.map((t) => () => {
      const ruleText = rulesByIds(CATALOG, new Set([t.finding.rule_id]));
      return spawn(arbiterPrompt(t.finding, t.file, ruleText), {
        label: `arbiter:${t.file.path}:${t.finding.rule_id}`, phase: 'Arbitration', model: t.model,
        agentType: TYPE_REVIEWER, schema: ARBITER_SCHEMA,
      }).then((v) => (v ? { _t: t, ...v } : null));
    }));
    for (const a of rawArb.filter(Boolean)) {
      const t = a._t, target = consensus.find((x) => x.path === t.path);
      if (!target) continue;
      const idx = target.contested.findIndex((f) => f.rule_id === t.finding.rule_id && f.location === t.finding.location);
      const verdict = (a.verdict || '').toLowerCase();
      if (verdict === 'confirmed') {
        adaptation.arbiters_confirmed++;
        const f = idx >= 0 ? target.contested.splice(idx, 1)[0] : { ...t.finding };
        f.enforce = a.corrected_enforce ? normEnforce(a.corrected_enforce) : normEnforce(f.enforce);
        f.consensus = 'majority';
        f.adversary_impact = f.adversary_impact || 'unchanged';
        f.arbitration = { verdict: 'confirmed', reasoning: a.reasoning };
        target.kept.push(f);
      } else if (verdict === 'refuted') { adaptation.arbiters_refuted++; if (idx >= 0) target.contested[idx].arbitration = { verdict: 'refuted', reasoning: a.reasoning }; }
      else if (idx >= 0) target.contested[idx].arbitration = { verdict: 'uncertain', reasoning: a.reasoning };
    }
  }

  // ---- Per-file verdicts for this chunk ----
  for (const f of chunkFilesList) {
    const c = consensus.find((x) => x.path === f.path);
    const extraInfo = (f.wholeClass === 'digest-escape')
      ? [{ rule_id: 'TEAM-SPLIT', title: 'Split this test class', enforce: 'consider', location: `${f.path}:1`, consensus: 'unanimous', adversary_impact: 'unchanged', arbitration: null, current: '', suggested: '', summary: `${f.path} (${combinedLines(f)} combined lines) exceeds the cross-body review limit C=${C}; the class-bodies (cross-method) rules were not evaluated. Split this test class.`, dissent: null }]
      : [];
    const b = bucketFile(c, extraInfo);
    const reviewerLabels = ['reviewer-1', 'reviewer-2', 'reviewer-3'];
    if (adaptation.extra_reviewers_by_file[f.path]) reviewerLabels.push('reviewer-4', 'reviewer-5');
    allFileResults.push({
      path: f.path, status: b.status, category: categoryByPath.get(f.path) || '?',
      track: f.track, units: f.units.length, reviewers: reviewerLabels,
      errors: b.errors, warnings: b.warnings, informational: b.informational,
      contested: c.contested.map((ct) => ({ rule_id: ct.rule_id, title: ct.title, enforce: ct.enforce, location: ct.location, reported_by: ct.reported_by || [], reason: ct.summary || '', outcome: ct.outcome || '', arbitration: ct.arbitration || null })),
      consensus: { unanimous: c.kept.filter((k) => k.consensus === 'unanimous').length, majority: c.kept.filter((k) => k.consensus !== 'unanimous').length, contested: c.contested.length },
      wholeClass: f.wholeClass,
    });
    allFingerprints.push({ path: f.path, track: f.track, fingerprint: f.fingerprint || '' });
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
// Verdicts — assemble the single result the rendering step consumes.
// ===========================================================================
const anyErrors = allFileResults.some((f) => f.errors.length > 0);
const anyWarn = allFileResults.some((f) => f.warnings.length > 0 || f.informational.length > 0) || consistency.length > 0;
const overall = anyErrors ? 'ISSUES_FOUND' : (anyWarn ? 'NEEDS_ATTENTION' : 'PASS');

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
log(`Verdict: ${overall} | ${allFileResults.filter((f) => f.status !== 'PASS').length}/${FILES.length} files with issues | ${consistency.length} cross-file findings | ${adaptation.arbiters} arbiter(s)`);

return {
  summary: {
    files_reviewed: FILES.length,
    reviewers: totalReviewers,
    overall_status: overall,
    files_with_issues: allFileResults.filter((f) => f.status !== 'PASS').length,
  },
  files: allFileResults.map((f) => ({
    path: f.path, status: f.status, category: f.category, reviewers: f.reviewers,
    errors: f.errors, warnings: f.warnings, informational: f.informational,
    contested: f.contested, consensus: f.consensus,
  })),
  consistency,
  decomposition,
  red_team,
  adaptation,
};
