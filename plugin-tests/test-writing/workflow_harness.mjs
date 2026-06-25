// Test harness for the committed team-review Workflow script.
//
// The workflow script (`team-review.workflow.mjs`) cannot be imported directly: it
// has a top-level `return` and an `export const meta` that Claude Code's Workflow
// runtime evaluates with the orchestration globals injected. `node --check` cannot
// parse it for the same reason. So this harness reproduces a minimal version of that
// wrapping — strip the `export` from the meta declaration (which also legalizes the
// top-level `return` inside a function body), then evaluate the body inside an
// AsyncFunction with stub globals. This makes the real workflow logic runnable and
// observable: every agent() spawn is recorded, and the workflow's `result` is returned.
//
// The stub `agent` delegates to a per-scenario `responder(prompt, opts)`; scenarios
// drive deterministic agent outputs to exercise coverage accounting, the lens fan-out,
// and arbitration without spawning real agents.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HARNESS_DIR = dirname(fileURLToPath(import.meta.url));
export const WORKFLOW_PATH = join(
  HARNESS_DIR, '..', '..',
  'plugins', 'test-writing', 'skills', 'phpunit-unit-test-team-reviewing',
  'workflow', 'team-review.workflow.mjs',
);

const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

// Strip the ESM `export` keyword from the meta declaration so the script body can run
// inside an AsyncFunction. Throws (fail loud) if the expected header is gone — a future
// rename must update this harness rather than silently wrapping a no-op.
export function loadWorkflowSource() {
  const raw = readFileSync(WORKFLOW_PATH, 'utf8');
  const transformed = raw.replace(/^export\s+const\s+meta\s*=/m, 'const meta =');
  if (transformed === raw) {
    throw new Error('Harness transform found no `export const meta` to strip — the workflow header changed; update workflow_harness.mjs.');
  }
  return transformed;
}

// Run the workflow with stub globals. Returns { result, spawns, logs, phases }.
//   manifest  — the value the workflow reads as `args`
//   responder — async (prompt, opts) => structured result | null (null/undefined = agent died)
//   options   — { budget } optional budget stub
export async function runWorkflow(manifest, responder, options = {}) {
  const source = loadWorkflowSource();
  const spawns = [];
  const logs = [];
  const phases = [];

  const agent = async (prompt, opts) => {
    const rec = { prompt, opts, label: opts.label };
    spawns.push(rec);
    const res = await responder(prompt, opts);
    rec.returned = res === undefined ? null : res;
    return rec.returned;
  };
  // Mirror the documented parallel() semantics: a thunk that throws resolves to null.
  const parallel = async (thunks) =>
    Promise.all(thunks.map((t) => Promise.resolve().then(() => t()).catch(() => null)));
  const pipeline = async (items, ...stages) =>
    Promise.all(items.map(async (item, i) => {
      let v = item;
      for (const stage of stages) {
        try { v = await stage(v, item, i); } catch { return null; }
      }
      return v;
    }));
  const log = (m) => { logs.push(String(m)); };
  const phase = (p) => { phases.push(String(p)); };
  const budget = options.budget || { total: null, spent: () => 0, remaining: () => Infinity };

  const fn = new AsyncFunction('agent', 'parallel', 'pipeline', 'log', 'phase', 'args', 'budget', source);
  const result = await fn(agent, parallel, pipeline, log, phase, manifest, budget);
  return { result, spawns, logs, phases };
}

// ---------------------------------------------------------------------------
// Label parsing — the workflow encodes the agent's role + identity in opts.label.
// ---------------------------------------------------------------------------
export function parseLabel(label) {
  const base = label.replace(/#retry\d+$/, '');
  const parts = base.split(':');
  const kind = parts[0];
  const out = { kind, base, label };
  if (kind === 'rev' || kind === 'recon' || kind === 'recon2' || kind === 'widen') {
    out.ukey = parts[1];
    out.fileId = parts[1].split('#')[0];
    out.reviewer = parts[2];
  } else if (kind === 'adv-impr' || kind === 'redteam') {
    out.path = parts[2];
    out.lens = parts[3];
  } else if (kind === 'defense') {
    out.path = parts[1];
    out.reviewer = parts[2];
  } else if (kind === 'arbiter') {
    out.path = parts[1];
    const rv = parts[2] || '';
    out.rule = rv.split('#')[0];
    out.vote = rv.includes('#') ? parseInt(rv.split('#')[1], 10) : 1;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Synthetic rule catalog (parses through parseCatalog -> >=1 rule, never throws).
// ---------------------------------------------------------------------------
function ruleBlock(id, title, reviewUnit, enforce) {
  return `# ${id} — ${title}\nReview unit: ${reviewUnit} | Categories: A, B | Scoped review: include | Enforce: ${enforce}\n\nDetection Algorithm: synthetic rule body for ${id}.`;
}
export const CATALOG_TEXT = [
  ruleBlock('CONV-001', 'Attribute order', 'class-structure', 'must-fix'),
  ruleBlock('DESIGN-003', 'Data provider missing', 'method', 'must-fix'),
  ruleBlock('UNIT-005', 'createStub would suffice', 'method', 'should-fix'),
  ruleBlock('CONV-009', 'Weak exception assertion', 'method', 'should-fix'),
  ruleBlock('DESIGN-010', 'Guard clause isolation', 'class-bodies', 'consider'),
].join('\n\n---\n\n');

// ---------------------------------------------------------------------------
// Manifest builders.
// ---------------------------------------------------------------------------
export function testFile(name, opts = {}) {
  const {
    test_lines = 100, source_lines = 100, methods = [],
    test_methods = ['testDoesA'], digest = null,
  } = opts;
  const path = `tests/unit/${name}Test.php`;
  return {
    path,
    source_path: `src/${name}.php`,
    test_lines, source_lines,
    method_count: test_methods.length,
    methods, test_methods,
    fingerprint: `fp-${name}`,
    digest,
  };
}
export function manifest(files) {
  return { files, rule_packages: { full: CATALOG_TEXT }, base: 'test-base' };
}

// ---------------------------------------------------------------------------
// Default responder — well-formed empty results for every role, derived from the
// label. Scenarios wrap this with overrides keyed on parseLabel().
// ---------------------------------------------------------------------------
export function defaultResponder(prompt, opts) {
  const p = parseLabel(opts.label);
  switch (p.kind) {
    case 'rev':
    case 'widen':
      return { reviewer: p.reviewer, category: 'B', clean: true, findings: [] };
    case 'recon':
    case 'recon2':
      return { reviewer: p.reviewer, findings: [], withdrawn: [] };
    case 'adv-impr':
      return { adversary: `adversary-${p.lens}`, files: [{ file_path: p.path, concerns: [] }] };
    case 'redteam':
      return { adversary: `adversary-${p.lens}`, files: [{ path: p.path, challenges_to_consensus: [], resurrections: [], new_findings: [], endorsements: [], cross_file_inconsistencies: [] }] };
    case 'defense':
      return { reviewer: p.reviewer, path: p.path, findings: [], withdrawn: [], re_adopted: [], adopted_new: [] };
    case 'arbiter':
      return { rule_id: p.rule, file: p.path, verdict: 'uncertain', reasoning: 'default uncertain' };
    default:
      if (opts.label === 'cross-file' || opts.label.startsWith('cross-file:')) return { consistency: [] };
      return null;
  }
}

// Build a finding object as a reviewer would emit it.
export function finding(rule_id, enforce, location, summary = 'synthetic finding') {
  return { rule_id, enforce, location, summary, current: '// current', suggested: '// suggested' };
}
