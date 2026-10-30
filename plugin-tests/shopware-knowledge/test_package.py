"""Contract tests use synthetic packs, never the moving shared checkout."""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("shopware_knowledge_pack_validator", ROOT / "scripts/shopware-knowledge/validate_skill_pack.py")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)
runner_spec = importlib.util.spec_from_file_location("shopware_knowledge_eval_runner", ROOT / "eval/shopware-knowledge/run.py")
runner = importlib.util.module_from_spec(runner_spec)
runner_spec.loader.exec_module(runner)


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="skill-pack-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.skill = self.root / validator.SKILL
        self.plugin = self.root / validator.PLUGIN
        self.write(self.skill / "SKILL.md", "---\nname: shopware-development\nversion: 0.10.0\ndescription: Review and implement Shopware extensions.\n---\n# Development\n\nRead [backend](references/backend.md) for backend changes.\n")
        self.write(self.skill / ".agent-skills", "")
        self.write(self.skill / "LICENSE", "MIT License\n\nCopyright (c) Example Maintainers\n")
        self.write(self.skill / "references/backend.md", "# Backend\n\nSee [transactions][tx].\n\n[tx]: transactions.md#transactions\n")
        self.write(self.skill / "references/transactions.md", "# Transactions\n\nResolve the owning customer before changing a stored method.\n")
        for runtime in ("claude", "codex"):
            self.json(self.plugin / f".{runtime}-plugin/plugin.json", {
                "name": "shopware-knowledge", "version": "0.10.0",
                "description": "Shopware extension knowledge", "skills": "./skills/",
                "author": {"name": "Example Maintainers"}, "license": "MIT",
            })
        self.json(self.root / ".claude-plugin/marketplace.json", {
            "name": "example-skills", "owner": {"name": "Example Maintainers"},
            "plugins": [{"name": "shopware-knowledge", "source": "./plugins/shopware-knowledge"}],
        })
        self.json(self.root / ".agents/plugins/marketplace.json", {
            "name": "example-skills", "plugins": [{"name": "shopware-knowledge",
            "source": {"source": "local", "path": "./plugins/shopware-knowledge"}}],
        })
        self.index_path = self.plugin / "knowledge-index.json"
        self.json(self.index_path, {"schema_version": 1, "skill": "shopware-development", "topics": [
            {"id": name, "path": f"references/{name}.md", "modes": ["review", "implement"],
             "shopware": ["6.7", "6.6"], "feature_flags": [],
             "sources": ["https://developer.shopware.com/docs/guides/plugins/"]}
            for name in ("backend", "transactions")
        ]})

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def json(self, path, data):
        self.write(path, json.dumps(data))

    def alter_json(self, path, change):
        value = json.loads(path.read_text())
        change(value)
        self.json(path, value)

    def errors(self, export=False):
        return validator.PackValidator(self.root).run(export=export)

    def assert_code(self, code):
        errors = self.errors()
        self.assertTrue(any(e.startswith(code + ":") for e in errors), errors)

    def test_valid_minimal_pack_without_agents_or_mcp(self):
        self.assertEqual([], self.errors())

    def test_upstream_export_and_skills_ref_are_required_and_work(self):
        self.assertEqual([], self.errors(export=True))

    def test_missing_license_notice_is_rejected(self):
        (self.skill / "LICENSE").unlink()
        self.assert_code("license-notice")

    def test_blank_license_notice_is_rejected(self):
        self.write(self.skill / "LICENSE", "\n")
        self.assert_code("license-notice")

    def test_transitive_reference_reachability(self):
        path = self.skill / "references/backend.md"
        self.write(path, "# Backend\n\nBackend instructions.\n")
        self.assert_code("unreachable-reference")

    def test_broken_link(self):
        self.write(self.skill / "references/backend.md", "[Missing](missing.md)\n")
        self.assert_code("link")

    def test_undefined_reference_link(self):
        self.write(self.skill / "references/backend.md", "[Details][unknown]\n")
        self.assert_code("markdown")

    def test_unknown_heading(self):
        self.write(self.skill / "references/backend.md", "[Details](transactions.md#absent)\n")
        self.assert_code("link")

    def test_out_of_bundle_existing_reference(self):
        self.write(self.plugin / "private.md", "# Not shipped\n")
        self.write(self.skill / "references/backend.md", "[Details](../../../private.md)\n")
        self.assert_code("link")

    def test_percent_encoded_escape(self):
        self.write(self.plugin / "private.md", "# Not shipped\n")
        self.write(self.skill / "references/backend.md", "[Details](%2e%2e/%2e%2e/%2e%2e/private.md)\n")
        self.assert_code("link")

    def test_symlink_escape(self):
        outside = self.root / "outside.md"
        self.write(outside, "# Outside\n")
        (self.skill / "references/alias.md").symlink_to(outside)
        self.assert_code("symlink")

    def test_native_version_drift(self):
        path = self.skill / "SKILL.md"
        self.write(path, path.read_text().replace("version: 0.10.0", "version: 0.9.0"))
        self.assert_code("version")

    def test_manifest_version_drift(self):
        self.alter_json(self.plugin / ".codex-plugin/plugin.json", lambda v: v.update(version="0.9.0"))
        self.assert_code("manifest-identity")

    def test_wrong_manifest_skill_shape(self):
        self.alter_json(self.plugin / ".claude-plugin/plugin.json", lambda v: v.update(skills=[{"name": "shopware-development", "path": "SKILL.md"}]))
        self.assert_code("manifest-skills")

    def test_marketplace_source_must_resolve_to_plugin(self):
        self.alter_json(self.root / ".agents/plugins/marketplace.json", lambda v: v["plugins"][0]["source"].update(path="./plugins"))
        self.assert_code("marketplace-path")

    def test_duplicate_json_keys(self):
        self.write(self.index_path, '{"schema_version": 1, "schema_version": 2}')
        self.assert_code("json")

    def test_duplicate_yaml_keys(self):
        path = self.skill / "SKILL.md"
        self.write(path, path.read_text().replace("name: shopware-development", "name: shopware-development\nname: another"))
        self.assert_code("frontmatter")

    def test_description_budget(self):
        path = self.skill / "SKILL.md"
        self.write(path, path.read_text().replace("Review and implement Shopware extensions.", "x" * 1025))
        self.assert_code("description")

    def test_index_omission(self):
        self.alter_json(self.index_path, lambda v: v["topics"].pop())
        self.assert_code("index-omission")

    def test_duplicate_index_ids(self):
        self.alter_json(self.index_path, lambda v: v["topics"][1].update(id="backend"))
        self.assert_code("index-id")

    def test_duplicate_index_paths(self):
        self.alter_json(self.index_path, lambda v: v["topics"][1].update(path="references/backend.md"))
        self.assert_code("index-path")

    def test_index_source_and_applicability_cannot_be_blank(self):
        self.alter_json(self.index_path, lambda v: v["topics"][0].update(sources=[" "], shopware=[], modes=[], feature_flags=[""]))
        self.assert_code("index-sources")
        self.assert_code("index-applicability")

    def test_index_path_must_exist(self):
        self.alter_json(self.index_path, lambda v: v["topics"][0].update(path="references/missing.md"))
        self.assert_code("index-path")

    def test_private_path_and_provenance_are_hygiene_failures(self):
        self.write(self.skill / "references/transactions.md", "# Transactions\n\nSee /Users/example/private/source.php and https://example.slack.com/archives/channel/message.\n")
        self.assert_code("private-path")
        self.assert_code("private-provenance")

    def test_runtime_tool_dependency_is_linted(self):
        self.write(self.skill / "references/transactions.md", "# Transactions\n\nOpen the file with the Read tool.\n")
        self.assert_code("runtime-neutrality")

    def test_mutating_preapproval_is_rejected(self):
        path = self.skill / "SKILL.md"
        self.write(path, path.read_text().replace("version: 0.10.0", "version: 0.10.0\nallowed-tools: [Edit, 'Bash(bin/console cache:clear *)']"))
        self.assert_code("preapproval")

    def test_example_links_are_not_treated_as_runtime_links(self):
        path = self.skill / "references/transactions.md"
        self.write(path, path.read_text() + "\n```markdown\n[Example](missing.md)\n```\n")
        self.assertEqual([], self.errors())

    def test_same_document_heading_link(self):
        path = self.skill / "references/transactions.md"
        self.write(path, path.read_text() + "\n[Top](#transactions)\n")
        self.assertEqual([], self.errors())

    def test_maintainer_task_modes(self):
        self.alter_json(self.index_path, lambda v: v["topics"][0].update(modes=["migrate", "report", "operate", "test"]))
        self.assertEqual([], self.errors())


class RunnerTests(unittest.TestCase):
    def test_all_fixed_fixtures_have_valid_schema_and_targets(self):
        self.assertEqual(14, len(runner.load_cases()))

    def test_materialization_does_not_include_expected_rubric(self):
        case = runner.load_cases()[0]
        with tempfile.TemporaryDirectory() as temp:
            # Keep tests self-cleaning without changing runner's default retention.
            run_dir = Path(temp) / "run"
            run_dir.mkdir()
            with patch.object(runner.tempfile, "mkdtemp", return_value=str(run_dir)):
                _, fixture, _ = runner.materialize(case, "codex")
            actual = {p.relative_to(fixture).as_posix(): p.read_text() for p in fixture.rglob("*") if p.is_file()}
            self.assertEqual(case["files"], actual)
            self.assertFalse((fixture / "cases.json").exists())

    def test_unsafe_fixture_path_rejected(self):
        for name in ("../rubric.json", "/tmp/file", ".agents/settings.json", "src/../../file"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                runner.fixture_path(name)

    def test_default_model_is_not_overridden(self):
        args = runner.command("codex", "codex", Path("/tmp/project"), None, None, [], 2)
        self.assertNotIn("--model", args)
        self.assertIn("--ignore-user-config", args)
        self.assertIn("--ignore-rules", args)
        self.assertIn("read-only", args)

    def test_claude_loads_only_supplied_plugin_and_read_tools(self):
        args = runner.command("claude", "claude", Path("/tmp/project"), Path("/tmp/project/plugin"), None, [], 2)
        self.assertIn("--plugin-dir", args)
        self.assertEqual("", args[args.index("--setting-sources") + 1])
        self.assertIn("--restricted", args)
        self.assertNotIn("--model", args)
        self.assertEqual("Read,Glob,Grep,Skill", args[args.index("--tools") + 1])


if __name__ == "__main__":
    unittest.main()
