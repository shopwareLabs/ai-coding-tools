// Fixture unit test for the PURE helpers of the committed team-review Workflow
// script. The Workflow body uses runtime globals (agent/parallel/phase/log) and
// a top-level `return`, so it cannot be imported directly. Instead this test
// extracts the two sentinel-delimited self-contained blocks (geometry constants
// + pure helpers) from the real source and evaluates THEM in isolation — so it
// exercises the shipped helper code, not a copy that could drift.
//
// Run:  node plugin-tests/test-writing/team-review-workflow-helpers.test.mjs
//
// Not wired into the bats suite on purpose: the CI "Bash Tests" job ships only
// jq/shellcheck/bats and no node. The rule-SELECTION predicate this script also
// covers is independently guarded against the real renderer by
// plugin-tests/test-writing/selection_equivalence.bats.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const WF = join(here, '..', '..', 'plugins', 'test-writing', 'skills', 'phpunit-unit-test-team-reviewing', 'workflow', 'team-review.workflow.mjs');
const src = readFileSync(WF, 'utf8');

function slice(start, end) {
  const a = src.indexOf(start);
  const b = src.indexOf(end);
  if (a < 0 || b < 0) throw new Error(`sentinel not found: ${start} / ${end}`);
  // Begin after the start marker's own line (it may carry a trailing comment).
  const from = src.indexOf('\n', a + start.length) + 1;
  return src.slice(from, b);
}
const geom = slice('// <<GEOM-CONST-START>>', '// <<GEOM-CONST-END>>');
const pure = slice('// <<PURE-HELPERS-START>>', '// <<PURE-HELPERS-END>>');
const exported = ['parseCatalog', 'rulesByIds', 'trackRules', 'categoryRules', 'trackOf', 'combinedLines', 'shardMethods', 'effectiveShards', 'buildUnits', 'mergeUnit', 'mergeFile', 'bucketFile', 'normEnforce', 'findKey'];
// eslint-disable-next-line no-new-func
const H = new Function(`${geom}\n${pure}\nreturn { ${exported.join(', ')} };`)();

let pass = 0, fail = 0;
function check(name, cond) {
  if (cond) { pass++; } else { fail++; console.error(`FAIL: ${name}`); }
}
function eq(name, got, want) { check(`${name} (got ${JSON.stringify(got)}, want ${JSON.stringify(want)})`, JSON.stringify(got) === JSON.stringify(want)); }

// --- Synthetic rendered catalog (renderer format: "# ID — Title" + 2 meta lines
//     + body, joined by "\n\n---\n\n"). CONV-001's body contains a standalone
//     "---" horizontal rule to prove the parser splits on HEADINGS, not on "---".
const CATALOG_TEXT = [
  '# CONV-001 — Attribute order',
  'Group: convention | Enforce: must-fix',
  'Test types: unit | Categories: A,B,C,D,E | Scope: phpunit | Review unit: class-structure | Scoped review: exclude',
  '',
  'Intro to CONV-001.',
  '',
  '---',
  '',
  'End of CONV-001 body after a horizontal rule.',
  '',
  '---',
  '',
  '# DESIGN-001 — No conditionals',
  'Group: design | Enforce: must-fix',
  'Test types: unit | Categories: A,B,C,D,E | Scope: general | Review unit: method | Scoped review: include',
  '',
  'Body of DESIGN-001.',
  '',
  '---',
  '',
  '# UNIT-003 — Over-mocking',
  'Group: unit | Enforce: must-fix',
  'Test types: unit | Categories: B,D | Scope: shopware | Review unit: class-bodies | Scoped review: include',
  '',
  'Body of UNIT-003.',
].join('\n');
const CAT = H.parseCatalog(CATALOG_TEXT);

// parseCatalog: 3 rules, correct order, no over-split on the inner "---".
eq('parseCatalog: rule count', CAT.byId.size, 3);
eq('parseCatalog: order', CAT.order, ['CONV-001', 'DESIGN-001', 'UNIT-003']);
const conv = CAT.byId.get('CONV-001');
check('parseCatalog: CONV-001 keeps text before its inner ---', conv.text.includes('Intro to CONV-001.'));
check('parseCatalog: CONV-001 keeps text after its inner ---', conv.text.includes('End of CONV-001 body'));
check('parseCatalog: CONV-001 does not retain trailing separator', !/---\s*$/.test(conv.text));
eq('parseCatalog: CONV-001 reviewUnit', conv.reviewUnit, 'class-structure');
eq('parseCatalog: CONV-001 scopedReview', conv.scopedReview, 'exclude');
eq('parseCatalog: UNIT-003 categories', CAT.byId.get('UNIT-003').categories, ['B', 'D']);
eq('parseCatalog: DESIGN-001 reviewUnit', CAT.byId.get('DESIGN-001').reviewUnit, 'method');

// rulesByIds: only the requested rule, no neighbors.
const sub = H.rulesByIds(CAT, new Set(['DESIGN-001']));
check('rulesByIds: contains requested', sub.includes('# DESIGN-001'));
check('rulesByIds: excludes others', !sub.includes('# CONV-001') && !sub.includes('# UNIT-003'));

// trackRules: review_unit membership + scoped_review exclusion.
const methodPkg = H.trackRules(CAT, ['method'], false);
check('trackRules method: only method rule', methodPkg.includes('# DESIGN-001') && !methodPkg.includes('# CONV-001') && !methodPkg.includes('# UNIT-003'));
const scopedAll = H.trackRules(CAT, null, true);
check('trackRules scoped=true: drops scoped-review=exclude (CONV-001)', !scopedAll.includes('# CONV-001'));
check('trackRules scoped=true: keeps include rules', scopedAll.includes('# DESIGN-001') && scopedAll.includes('# UNIT-003'));

// categoryRules: rules applicable to category A (CONV/DESIGN are A-E; UNIT-003 is B,D only).
const catA = H.categoryRules(CAT, ['A']);
check('categoryRules A: includes A-E rules', catA.includes('# CONV-001') && catA.includes('# DESIGN-001'));
check('categoryRules A: excludes B,D-only rule', !catA.includes('# UNIT-003'));

// trackOf: A / B-fused / B-digest from combined line counts.
eq('trackOf: A (L<=T)', H.trackOf({ test_lines: 100, source_lines: 50 }), { track: 'A', wholeClass: 'n/a' });
eq('trackOf: B fused (T<L<=C)', H.trackOf({ test_lines: 300, source_lines: 200 }), { track: 'B', wholeClass: 'fused' });
eq('trackOf: B digest (L>C)', H.trackOf({ test_lines: 600, source_lines: 400 }), { track: 'B', wholeClass: 'digest-escape' });

// shardMethods: even split, empty, and single-shard cases.
eq('shardMethods: 10 methods / M=8 → 2x5', H.shardMethods(['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'], 8).map((s) => s.length), [5, 5]);
eq('shardMethods: empty → one empty shard', H.shardMethods([], 8), [[]]);
eq('shardMethods: 3 methods → single shard', H.shardMethods(['a', 'b', 'c'], 8), [['a', 'b', 'c']]);

// buildUnits: Track A = 1 unit; Track B fused = method shards + whole-class; digest = shards + digest.
const uA = H.buildUnits({ path: 'A/T.php', source_path: 'A/S.php', test_lines: 100, source_lines: 50, methods: ['testA'], test_methods: ['testA', 'testB'] }, CAT);
eq('buildUnits: Track A → 1 unit', uA.length, 1);
eq('buildUnits: Track A type', uA[0].type, 'trackA');
check('buildUnits: Track A scoped', uA[0].scopedReview === true);
const uBf = H.buildUnits({ path: 'B/T.php', source_path: 'B/S.php', test_lines: 300, source_lines: 200, methods: [], test_methods: ['m1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7', 'm8', 'm9', 'm10'] }, CAT);
eq('buildUnits: Track B fused unit types', uBf.map((u) => u.type), ['method', 'method', 'wholeclass']);
const uBd = H.buildUnits({ path: 'D/T.php', source_path: 'D/S.php', test_lines: 600, source_lines: 400, methods: [], test_methods: ['m1', 'm2', 'm3', 'm4', 'm5'] }, CAT);
eq('buildUnits: Track B digest unit types', uBd.map((u) => u.type), ['method', 'digest']);

// mergeUnit: unanimous (3/3, longest suggested wins, majority enforce), contested (1/3).
const mu = H.mergeUnit([
  { reviewer: 'reviewer-1', findings: [{ rule_id: 'CONV-001', enforce: 'must-fix', location: 'F.php:45', summary: 'a', suggested: 'fix-long-aaa' }, { rule_id: 'DESIGN-001', enforce: 'must-fix', location: 'F.php:10', summary: 'd' }] },
  { reviewer: 'reviewer-2', findings: [{ rule_id: 'CONV-001', enforce: 'should-fix', location: 'F.php:46', summary: 'a2', suggested: 'fix-short' }] },
  { reviewer: 'reviewer-3', findings: [{ rule_id: 'CONV-001', enforce: 'must-fix', location: 'F.php:45', summary: 'a3' }] },
]);
eq('mergeUnit: kept count', mu.kept.length, 1);
eq('mergeUnit: kept rule', mu.kept[0].rule_id, 'CONV-001');
eq('mergeUnit: unanimous consensus', mu.kept[0].consensus, 'unanimous');
eq('mergeUnit: majority enforce = must-fix', mu.kept[0].enforce, 'must-fix');
eq('mergeUnit: most complete suggested wins', mu.kept[0].suggested, 'fix-long-aaa');
eq('mergeUnit: contested count', mu.contested.length, 1);
eq('mergeUnit: contested rule', mu.contested[0].rule_id, 'DESIGN-001');

// mergeUnit: 2-of-3 majority attaches a dissent from the omitting reviewer.
const mu2 = H.mergeUnit([
  { reviewer: 'reviewer-1', findings: [{ rule_id: 'UNIT-003', enforce: 'must-fix', location: 'F.php:20', summary: 'm' }] },
  { reviewer: 'reviewer-2', findings: [{ rule_id: 'UNIT-003', enforce: 'must-fix', location: 'F.php:21', summary: 'm2' }] },
  { reviewer: 'reviewer-3', findings: [] },
]);
eq('mergeUnit: majority consensus', mu2.kept[0].consensus, 'majority');
eq('mergeUnit: dissent names omitting reviewer', mu2.kept[0].dissent.reviewer, 'reviewer-3');

// mergeFile: a finding kept in any unit is removed from the file-level contested set.
const mf = H.mergeFile([
  { kept: [{ rule_id: 'CONV-001', location: 'F.php:45', votes: 3, consensus: 'unanimous' }], contested: [] },
  { kept: [], contested: [{ rule_id: 'CONV-001', location: 'F.php:45', votes: 1 }, { rule_id: 'X-001', location: 'F.php:99', votes: 1 }] },
]);
eq('mergeFile: kept deduped', mf.kept.map((k) => k.rule_id), ['CONV-001']);
eq('mergeFile: consensus removes from contested', mf.contested.map((c) => c.rule_id), ['X-001']);

// bucketFile: error/warning/informational split + extra informational (split skip) + status.
const bf = H.bucketFile({ kept: [
  { rule_id: 'CONV-001', enforce: 'must-fix', location: 'F.php:45', summary: 'a', consensus: 'unanimous', adversary_impact: 'unchanged' },
  { rule_id: 'DESIGN-005', enforce: 'should-fix', location: 'F.php:78', summary: 'w', consensus: 'majority' },
  { rule_id: 'UNIT-008', enforce: 'consider', location: 'F.php:90', summary: 'i' },
], contested: [] }, [{ rule_id: 'TEAM-SPLIT', enforce: 'consider', summary: 'split', informationalOnly: true }]);
eq('bucketFile: errors', bf.errors.length, 1);
eq('bucketFile: warnings', bf.warnings.length, 1);
eq('bucketFile: informational (UNIT-008 + split)', bf.informational.length, 2);
eq('bucketFile: status', bf.status, 'ISSUES_FOUND');

// bucketFile: clean kept → PASS.
eq('bucketFile: empty → PASS', H.bucketFile({ kept: [], contested: [] }, []).status, 'PASS');

console.log(`team-review workflow helpers: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
