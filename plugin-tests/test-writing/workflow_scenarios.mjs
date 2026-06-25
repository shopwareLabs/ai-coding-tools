// Behaviour scenarios for the team-review Workflow script, driven through workflow_harness.mjs.
// Run one scenario: `node workflow_scenarios.mjs <name>`. Prints "PASS <name>" on success;
// an AssertionError (non-zero exit) on failure. The bats wrapper runs one @test per scenario.
//
// Each scenario asserts its PRECONDITION first (e.g. the red team actually ran, or N findings
// were arbitrated) before the outcome — otherwise a skipped wave would let the outcome assertion
// pass for the wrong reason.

import assert from 'node:assert/strict';
import {
  runWorkflow, parseLabel, manifest, testFile, finding, defaultResponder,
} from './workflow_harness.mjs';

const FILE_A = 'tests/unit/FileATest.php';
const FILE_BIG = 'tests/unit/FileBigTest.php';
const FILE_CLEAN = 'tests/unit/FileCleanTest.php';

// A reviewer/reconciler stance that reports the same finding from all reviewers of a unit
// (-> unanimous kept), so totalKept > 0 and the red team is not skipped.
function keptReviewer(p, keptFinding) {
  if (p.kind === 'rev') return { reviewer: p.reviewer, category: 'B', clean: false, findings: [keptFinding] };
  if (p.kind === 'recon' || p.kind === 'recon2') return { reviewer: p.reviewer, findings: [keptFinding], withdrawn: [] };
  return null;
}

// ---------------------------------------------------------------------------
const scenarios = {
  // Wrap/syntax guard + result shape: the AsyncFunction wrap must execute the real script
  // and return the documented top-level result keys.
  async smoke() {
    const { result } = await runWorkflow(manifest([testFile('Solo')]), defaultResponder);
    for (const k of ['summary', 'files', 'consistency', 'decomposition', 'red_team', 'adaptation']) {
      assert.ok(k in result, `result missing top-level key: ${k}`);
    }
    assert.equal(result.summary.files_reviewed, 1);
    assert.equal(typeof result.summary.overall_status, 'string');
    assert.ok('arbiters_split' in result.adaptation, 'adaptation must expose arbiters_split');
  },

  // §5.1 — per-file scope (one file per adversary); all-K-fail -> coverage_gap for that file
  // only; 1-of-3 fail -> NO gap. Precondition: the red team ran.
  async coverage() {
    const kept = finding('CONV-001', 'must-fix', 'FileATest.php:10');
    const responder = (prompt, opts) => {
      const p = parseLabel(opts.label);
      if (p.fileId === FILE_A && (p.kind === 'rev' || p.kind === 'recon' || p.kind === 'recon2')) return keptReviewer(p, kept);
      if (p.kind === 'redteam') {
        if (p.path === FILE_BIG) return null;                 // all 3 lenses die -> gap
        if (p.path === FILE_A && p.lens === 'L1') return null; // 1 of 3 dies -> still covered
      }
      return defaultResponder(prompt, opts);
    };
    const { result, spawns } = await runWorkflow(
      manifest([testFile('FileA'), testFile('FileBig', { test_lines: 500, source_lines: 200, test_methods: ['t1', 't2'] })]),
      responder,
    );

    // Precondition: red team actually ran (else coverage accounting never executes).
    assert.equal(result.red_team.skipped, false, 'precondition: red team must run');

    // all-K-fail file is the sole coverage gap; the 1-of-3 file is covered.
    const gap = result.red_team.coverage_gap;
    assert.ok(gap, 'coverage_gap must be set when a file lost all K adversaries');
    assert.deepEqual(gap.files, [FILE_BIG]);
    assert.ok(!gap.files.includes(FILE_A), 'a file that kept >=1 adversary must NOT be a gap');

    // Per-file scope: every adversary prompt references exactly its own file, never the other.
    const advs = spawns.filter((s) => s.label.startsWith('redteam:') || s.label.startsWith('adv-impr:'));
    assert.ok(advs.length > 0);
    for (const s of advs) {
      const p = parseLabel(s.label);
      assert.ok(s.prompt.includes(p.path), `${s.label} must reference its own file`);
      for (const other of [FILE_A, FILE_BIG].filter((x) => x !== p.path)) {
        assert.ok(!s.prompt.includes(other), `${s.label} leaked another file: ${other}`);
      }
    }
  },

  // §3.4 — size-aware re-spawn: the full-payload attempt "overflows" (null), the degraded
  // retry succeeds, and the file is covered via that degraded-but-present adversary (not lost).
  // Also proves the degraded prompt / compact catalog build without throwing.
  async ['degrade-recover']() {
    const kept = finding('CONV-001', 'must-fix', 'FileATest.php:10');
    const responder = (prompt, opts) => {
      const p = parseLabel(opts.label);
      if (p.fileId === FILE_A && (p.kind === 'rev' || p.kind === 'recon' || p.kind === 'recon2')) return keptReviewer(p, kept);
      if (p.kind === 'redteam') {
        // Full-payload attempt dies; only the degraded re-spawn (compact catalog) returns.
        if (!prompt.includes('DEGRADED RE-SPAWN')) return null;
        return { adversary: `adversary-${p.lens}`, files: [{ path: p.path, challenges_to_consensus: [], resurrections: [], new_findings: [], endorsements: [], cross_file_inconsistencies: [] }] };
      }
      return defaultResponder(prompt, opts);
    };
    const { result, spawns } = await runWorkflow(manifest([testFile('FileA')]), responder);

    assert.equal(result.red_team.skipped, false, 'precondition: red team must run');
    // Recovered via the degraded retry -> no coverage gap.
    assert.equal(result.red_team.coverage_gap, null, 'degraded retry must keep the file covered');
    // The degraded payload was actually issued and is the compact-catalog variant.
    const degraded = spawns.filter((s) => s.label.startsWith('redteam:') && s.prompt.includes('DEGRADED RE-SPAWN'));
    assert.ok(degraded.length >= 1, 'a degraded red-team re-spawn must have been issued');
    assert.ok(degraded[0].prompt.includes('COMPACT index'), 'degraded payload must carry the compact catalog');
  },

  // §5.2 (part 1) — K=3 distinct-lens adversaries spawn per file in BOTH waves.
  async lenses() {
    const kept = finding('CONV-001', 'must-fix', 'FileATest.php:10');
    const responder = (prompt, opts) => {
      const p = parseLabel(opts.label);
      if (p.fileId === FILE_A && (p.kind === 'rev' || p.kind === 'recon' || p.kind === 'recon2')) return keptReviewer(p, kept);
      return defaultResponder(prompt, opts);
    };
    const { result, spawns } = await runWorkflow(manifest([testFile('FileA')]), responder);
    assert.equal(result.red_team.skipped, false, 'precondition: both adversary waves must run');

    const imprPostures = ['TAUTOLOGY LENS', 'WEAK-ASSERTION LENS', 'MISSED-COVERAGE LENS'];
    const redPostures = ['TAUTOLOGY HUNTER', 'WEAK-ASSERTION HUNTER', 'MISSED-COVERAGE / COMPLETENESS HUNTER'];

    for (const [prefix, postures] of [['adv-impr:', imprPostures], ['redteam:', redPostures]]) {
      const ss = spawns.filter((s) => s.label.startsWith(prefix));
      assert.equal(ss.length, 3, `${prefix} must spawn exactly K=3 per file`);
      assert.deepEqual(ss.map((s) => parseLabel(s.label).lens).sort(), ['L1', 'L2', 'L3']);
      for (const posture of postures) {
        assert.equal(ss.filter((s) => s.prompt.includes(posture)).length, 1, `exactly one ${prefix} carries "${posture}"`);
      }
      for (const s of ss) {
        const hits = postures.filter((t) => s.prompt.includes(t));
        assert.equal(hits.length, 1, `${s.label} must carry exactly one lens posture`);
      }
    }
  },

  // §5.2 (part 2) — the lens adversaries' introductions are unioned (and deduped) into defense.
  async ['defense-union']() {
    const kept = finding('CONV-001', 'must-fix', 'FileATest.php:5');
    const introA = finding('UNIT-005', 'should-fix', 'FileATest.php:10'); // L1 and L2 both introduce
    const introB = finding('CONV-009', 'should-fix', 'FileATest.php:20'); // L3 introduces
    const responder = (prompt, opts) => {
      const p = parseLabel(opts.label);
      if (p.fileId === FILE_A && (p.kind === 'rev' || p.kind === 'recon' || p.kind === 'recon2')) return keptReviewer(p, kept);
      if (p.kind === 'redteam') {
        const intro = p.lens === 'L3' ? introB : introA; // L1,L2 -> introA (duplicate); L3 -> introB
        return { adversary: `adversary-${p.lens}`, files: [{ path: p.path, challenges_to_consensus: [], resurrections: [], new_findings: [intro], endorsements: [], cross_file_inconsistencies: [] }] };
      }
      if (p.kind === 'defense') {
        return { reviewer: p.reviewer, path: p.path, findings: [kept], withdrawn: [], re_adopted: [], adopted_new: [introA, introB] };
      }
      return defaultResponder(prompt, opts);
    };
    const { result, spawns } = await runWorkflow(manifest([testFile('FileA')]), responder);
    assert.equal(result.red_team.skipped, false, 'precondition: red team must run');

    // Union reached the defense wave: every defender prompt carries both lenses' introductions.
    const defenders = spawns.filter((s) => s.label.startsWith('defense:'));
    assert.ok(defenders.length >= 1, 'defense must run on the challenged file');
    for (const s of defenders) {
      assert.ok(s.prompt.includes('UNIT-005'), 'defense prompt missing L1/L2 introduction');
      assert.ok(s.prompt.includes('CONV-009'), 'defense prompt missing L3 introduction');
    }

    // Dedup: UNIT-005 was introduced by two lenses but is adopted into the body exactly once.
    const fileA = result.files.find((f) => f.path === FILE_A);
    const warnIds = fileA.warnings.map((w) => w.rule_id);
    assert.equal(warnIds.filter((x) => x === 'UNIT-005').length, 1, 'duplicate introduction must dedup to one finding');
    assert.ok(warnIds.includes('CONV-009'));
    assert.equal(fileA.warnings.find((w) => w.rule_id === 'UNIT-005').adversary_impact, 'introduced');
  },

  // §5.3 — uncapped + must-fix-first: >15 contested incl. a must-fix at iteration position 20
  // is arbitrated, not dropped by position.
  async ['arb-uncap']() {
    const findings = [];
    for (let i = 0; i < 19; i++) findings.push(finding('UNIT-005', 'should-fix', `FileATest.php:${10 + i * 10}`));
    findings.push(finding('DESIGN-003', 'must-fix', 'FileATest.php:300')); // the 20th, a must-fix
    const responder = (prompt, opts) => {
      const p = parseLabel(opts.label);
      // Only reviewer-1 reports the findings -> every one is contested (1-of-3).
      if (p.fileId === FILE_A && p.reviewer === 'reviewer-1') {
        if (p.kind === 'rev') return { reviewer: p.reviewer, category: 'B', clean: false, findings };
        if (p.kind === 'recon' || p.kind === 'recon2') return { reviewer: p.reviewer, findings, withdrawn: [] };
      }
      if (p.kind === 'arbiter') {
        if (p.rule === 'DESIGN-003') return { rule_id: p.rule, file: p.path, verdict: 'confirmed', reasoning: 'real' };
        return { rule_id: p.rule, file: p.path, verdict: 'refuted', reasoning: 'not real' };
      }
      return defaultResponder(prompt, opts);
    };
    const { result, spawns } = await runWorkflow(manifest([testFile('FileA')]), responder);

    // Precondition: every one of the 20 contested findings was arbitrated (uncapped).
    assert.equal(result.adaptation.arbiters, 20, 'all contested findings must be arbitrated (no ARB_CAP)');

    // The must-fix at position 20 got 3 opus arbiters and was promoted into the body.
    const mfArb = spawns.filter((s) => s.label.startsWith('arbiter:') && parseLabel(s.label).rule === 'DESIGN-003');
    assert.ok(mfArb.length >= 3, 'contested must-fix must get 3 arbiters');
    const fileA = result.files.find((f) => f.path === FILE_A);
    assert.ok(fileA.errors.some((e) => e.rule_id === 'DESIGN-003'), 'must-fix arbitrated into the body, not dropped by position');
  },

  // §5.4 — 3-vote must-fix arbitration: 2 confirm -> kept.
  async ['arb-2confirm']() { await arbMustFix(['confirmed', 'confirmed', 'refuted'], (fileA, result) => {
    assert.equal(result.adaptation.arbiters_confirmed, 1);
    assert.ok(fileA.errors.some((e) => e.rule_id === 'DESIGN-003'), '2-of-3 confirm must keep the finding');
    assert.ok(!fileA.contested.some((c) => c.rule_id === 'DESIGN-003'), 'confirmed finding must leave contested');
  }); },

  // §5.4 — 2 refute -> excluded.
  async ['arb-2refute']() { await arbMustFix(['refuted', 'refuted', 'confirmed'], (fileA, result) => {
    assert.equal(result.adaptation.arbiters_refuted, 1);
    assert.ok(!fileA.errors.some((e) => e.rule_id === 'DESIGN-003'), '2-of-3 refute must exclude the finding');
    const c = fileA.contested.find((x) => x.rule_id === 'DESIGN-003');
    assert.ok(c && c.arbitration && c.arbitration.verdict === 'refuted', 'excluded finding stays contested, marked refuted');
  }); },

  // §5.4 — 1/1/1 split (no majority) -> kept-as-split (a possibly-real must-fix is never dropped).
  async ['arb-split']() { await arbMustFix(['confirmed', 'refuted', 'uncertain'], (fileA, result) => {
    assert.equal(result.adaptation.arbiters_split, 1);
    const e = fileA.errors.find((x) => x.rule_id === 'DESIGN-003');
    assert.ok(e, 'split must-fix must be KEPT in the body');
    assert.equal(e.arbitration.verdict, 'split', 'kept split finding is marked split');
  }); },

  // §5.5 — preserve the quality floor: 3 reviewers/unit, Wave-1 gate, contested bucketing,
  // cross-file agent, three-tier severity.
  async preserve() {
    const kept = finding('CONV-001', 'must-fix', 'FileATest.php:10');
    const contested = finding('UNIT-005', 'should-fix', 'FileATest.php:30');
    const responder = (prompt, opts) => {
      const p = parseLabel(opts.label);
      if (p.fileId === FILE_A) {
        const own = p.reviewer === 'reviewer-1' ? [kept, contested] : [kept];
        if (p.kind === 'rev') return { reviewer: p.reviewer, category: 'B', clean: false, findings: own };
        if (p.kind === 'recon' || p.kind === 'recon2') return { reviewer: p.reviewer, findings: own, withdrawn: [] };
      }
      return defaultResponder(prompt, opts); // FileClean -> clean everywhere
    };
    const { result, spawns } = await runWorkflow(
      manifest([testFile('FileA'), testFile('FileClean')]), responder,
    );

    // 3 independent reviewers on FileA's (single Track-A) unit.
    const aRevs = spawns.filter((s) => s.label.startsWith('rev:') && parseLabel(s.label).fileId === FILE_A);
    assert.equal(aRevs.length, 3, 'floor: 3 reviewers per unit');

    // Wave-1 gate: the all-empty FileClean unit is NOT reconciled; FileA is.
    const cleanRecon = spawns.filter((s) => (s.label.startsWith('recon:') || s.label.startsWith('recon2:')) && parseLabel(s.label).fileId === FILE_CLEAN);
    assert.equal(cleanRecon.length, 0, 'floor: Wave-1 gate skips all-empty units');
    const aRecon = spawns.filter((s) => s.label.startsWith('recon:') && parseLabel(s.label).fileId === FILE_A);
    assert.ok(aRecon.length >= 1, 'floor: non-empty unit is reconciled');

    // Sole cross-file consistency agent runs once.
    const cf = spawns.filter((s) => s.label === 'cross-file' || s.label.startsWith('cross-file:'));
    assert.equal(cf.length, 1, 'floor: one cross-file consistency agent');

    // Three-tier severity + contested bucketing.
    const fileA = result.files.find((f) => f.path === FILE_A);
    assert.ok(Array.isArray(fileA.errors) && Array.isArray(fileA.warnings) && Array.isArray(fileA.informational));
    assert.ok(fileA.errors.some((e) => e.rule_id === 'CONV-001'), 'unanimous must-fix in errors');
    assert.ok(fileA.contested.some((c) => c.rule_id === 'UNIT-005'), 'floor: 1-of-3 finding bucketed contested');
    assert.equal(typeof fileA.consensus.unanimous, 'number');
  },
};

// Shared driver for the three §5.4 must-fix arbitration cases.
async function arbMustFix(verdicts, check) {
  const mf = finding('DESIGN-003', 'must-fix', 'FileATest.php:50');
  const responder = (prompt, opts) => {
    const p = parseLabel(opts.label);
    if (p.fileId === FILE_A && p.reviewer === 'reviewer-1') {
      if (p.kind === 'rev') return { reviewer: p.reviewer, category: 'B', clean: false, findings: [mf] };
      if (p.kind === 'recon' || p.kind === 'recon2') return { reviewer: p.reviewer, findings: [mf], withdrawn: [] };
    }
    if (p.kind === 'arbiter') {
      return { rule_id: p.rule, file: p.path, verdict: verdicts[(p.vote || 1) - 1], reasoning: `vote ${p.vote}` };
    }
    return defaultResponder(prompt, opts);
  };
  const { result } = await runWorkflow(manifest([testFile('FileA')]), responder);
  assert.equal(result.adaptation.arbiters, 1, 'precondition: exactly one contested must-fix arbitrated');
  const fileA = result.files.find((f) => f.path === FILE_A);
  check(fileA, result);
}

// ---------------------------------------------------------------------------
const name = process.argv[2];
const fn = scenarios[name];
if (!fn) {
  process.stderr.write(`Unknown scenario: ${name}\nAvailable: ${Object.keys(scenarios).join(', ')}\n`);
  process.exit(2);
}
fn().then(() => {
  process.stdout.write(`PASS ${name}\n`);
}).catch((err) => {
  process.stderr.write(`FAIL ${name}: ${err && err.stack ? err.stack : err}\n`);
  process.exit(1);
});
