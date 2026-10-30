# Shopware Knowledge Maintenance

> Scope and installation are described in the [plugin README](README.md).
> Runtime instructions live only in the skill directory below.

## Ownership

- `skills/shopware-development/`: runtime-neutral, self-contained instructions and examples. Keep platform invocation and installation outside it.
- `knowledge-index.json`: stable topic IDs, applicability, feature flags, and evidence. Regenerate with `python3 scripts/shopware-knowledge/build_knowledge_index.py` from the repository root.
- `eval/shopware-knowledge/`: fixed defect cases, valid controls, a dry-run-first CLI runner, and pinned validation requirements. A static assertion is not a model behavior test.
- `plugin-tests/shopware-knowledge/`: isolated synthetic package tests; no source-repository history or preservation ledger is required.
- Record evidence-backed corrections and executed checks in the [plugin changelog](CHANGELOG.md), alongside the relevant test or fixture change.

Preserve business invariants. Before changing a rule, record the failure it addresses, matching source evidence, and regression case. Do not add private project details, feedback provenance, personal paths, or unsupported universal thresholds.

## Checks

From the repository root:

```bash
python3 -m pip install -r eval/shopware-knowledge/requirements.txt
python3 scripts/shopware-knowledge/build_knowledge_index.py --check
python3 scripts/shopware-knowledge/validate_skill_pack.py
python3 -m unittest discover -s plugin-tests/shopware-knowledge -p 'test_*.py'
python3 eval/shopware-knowledge/run.py check
.github/scripts/validate-versions.sh
.github/scripts/validate-issue-templates.sh
git diff --check
```

Use one Python environment for the commands above and the required upstream `build-agent-skill` and `skills-ref` executables; missing dependencies fail. The package validator builds and validates a temporary portable export. It does not test model behavior. CI runs these focused checks in the `shopware-knowledge` workflow without modifying the host exporter or its tests.

When a local core checkout contains the pinned tag objects, run `python3 scripts/shopware-knowledge/verify_core_anchors.py --core /path/to/shopware-core`. This verifies the bundled source URLs with `git cat-file` at their exact refs; it does not fetch missing objects and fails on unavailable refs or paths. It is an additional source-evidence check, not a runtime behavior test.

The CLI runner never changes user auth/settings or environment variables. `check`, `materialize`, and `run` without `--execute` do not call a model. For an authorized real run, use `python3 eval/shopware-knowledge/run.py run --case c13 --runtime codex --skill plugins/shopware-knowledge/skills/shopware-development --execute`. Pass `--model` only to override the CLI default. Claude uses `--runtime claude` and a temporary plugin wrapper. Compare independent skill snapshots with `--arm A` and `--arm B`; do not include expected rubrics in model prompts. A human or independent semantic reviewer scores source-backed reasoning, fixes, false positives and clean controls, not exact wording or keywords. Authentication, native discovery and runtime integration remain separate evidence gates.

## Review Cadence

Once per month and before a release, review supported Shopware patch notes and stable source changes, relevant PHPStan rules, installed Symfony/PHP compatibility, and reported skill failures. Record inspected versions, decisions, and executed tests in the changelog/validation report. The cadence is a maintenance commitment, not a background automation.

Ship `0.10.0` only after review. Keep Claude/Codex manifests, skill version, and plugin changelog synchronized using the host version-bump script. Do not publish a tag as part of the preparation branch.
