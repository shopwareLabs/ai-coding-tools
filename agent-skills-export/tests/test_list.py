"""Tests for skill discovery and list command."""

import json
import subprocess
import sys

import pytest

from agent_skills_export import discover_exportable_skills
from agent_skills_export.core import _sanitize_artifact_name


class TestSanitizeArtifactName:
    @pytest.mark.parametrize(
        ("input_name", "expected"),
        [
            ("my-skill", "my-skill"),
            ("My Skill", "my-skill"),
            ("MY_SKILL", "my_skill"),
            ("skill@v1.0", "skillv10"),
            ("  spaces  ", "spaces"),
            ("CamelCase", "camelcase"),
            ("special!@#chars", "specialchars"),
            ("123-numeric", "123-numeric"),
        ],
    )
    def test_sanitizes_name_for_artifact(self, input_name, expected):
        assert _sanitize_artifact_name(input_name) == expected


class TestDiscoverExportableSkills:
    def test_finds_skill_with_marker(self, tmp_path):
        skill_dir = tmp_path / "plugins" / "test" / "skills" / "my-skill"
        skill_dir.mkdir(parents=True)
        (skill_dir / ".agent-skills").touch()
        (skill_dir / "SKILL.md").write_text(
            "---\nname: my-skill\ndescription: A skill.\n---\n\nBody.\n"
        )

        results = discover_exportable_skills(tmp_path)

        assert len(results) == 1
        assert results[0]["path"] == "plugins/test/skills/my-skill"
        assert results[0]["name"] == "my-skill"

    def test_uses_directory_name_when_no_frontmatter_name(self, tmp_path):
        skill_dir = tmp_path / "skills" / "fallback-skill"
        skill_dir.mkdir(parents=True)
        (skill_dir / ".agent-skills").touch()
        (skill_dir / "SKILL.md").write_text("---\ndescription: No name.\n---\n\nBody.\n")

        results = discover_exportable_skills(tmp_path)

        assert len(results) == 1
        assert results[0]["name"] == "fallback-skill"

    def test_skips_marker_without_skill_md(self, tmp_path):
        skill_dir = tmp_path / "orphan"
        skill_dir.mkdir()
        (skill_dir / ".agent-skills").touch()

        results = discover_exportable_skills(tmp_path)

        assert results == []

    def test_finds_multiple_skills_sorted_by_path(self, tmp_path):
        for name in ["zebra", "alpha", "beta"]:
            skill_dir = tmp_path / "plugins" / name
            skill_dir.mkdir(parents=True)
            (skill_dir / ".agent-skills").touch()
            (skill_dir / "SKILL.md").write_text(f"---\nname: {name}\ndescription: Skill.\n---\n")

        results = discover_exportable_skills(tmp_path)

        assert len(results) == 3
        assert [r["name"] for r in results] == ["alpha", "beta", "zebra"]

    def test_returns_empty_list_when_no_markers(self, tmp_path):
        (tmp_path / "plugins").mkdir()
        (tmp_path / "plugins" / "no-marker").mkdir()

        results = discover_exportable_skills(tmp_path)

        assert results == []

    def test_sanitizes_skill_name_for_artifact(self, tmp_path):
        skill_dir = tmp_path / "skills" / "my-skill"
        skill_dir.mkdir(parents=True)
        (skill_dir / ".agent-skills").touch()
        (skill_dir / "SKILL.md").write_text(
            "---\nname: My Fancy Skill!\ndescription: Fancy.\n---\n"
        )

        results = discover_exportable_skills(tmp_path)

        assert results[0]["name"] == "my-fancy-skill"


class TestListCLI:
    def test_outputs_json_array(self, tmp_path):
        skill_dir = tmp_path / "plugins" / "test-skill"
        skill_dir.mkdir(parents=True)
        (skill_dir / ".agent-skills").touch()
        (skill_dir / "SKILL.md").write_text("---\nname: test-skill\ndescription: Test.\n---\n")

        result = subprocess.run(
            [sys.executable, "-m", "agent_skills_export.cli_list", str(tmp_path)],
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0, f"stderr: {result.stderr}"
        data = json.loads(result.stdout)
        assert isinstance(data, list)
        assert len(data) == 1
        assert data[0]["name"] == "test-skill"

    def test_defaults_to_cwd(self, tmp_path):
        skill_dir = tmp_path / "skills" / "cwd-skill"
        skill_dir.mkdir(parents=True)
        (skill_dir / ".agent-skills").touch()
        (skill_dir / "SKILL.md").write_text("---\nname: cwd-skill\ndescription: Test.\n---\n")

        result = subprocess.run(
            [sys.executable, "-m", "agent_skills_export.cli_list"],
            capture_output=True,
            text=True,
            cwd=str(tmp_path),
        )

        assert result.returncode == 0, f"stderr: {result.stderr}"
        data = json.loads(result.stdout)
        assert len(data) == 1

    def test_outputs_empty_array_when_no_skills(self, tmp_path):
        result = subprocess.run(
            [sys.executable, "-m", "agent_skills_export.cli_list", str(tmp_path)],
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        assert json.loads(result.stdout) == []

    def test_fails_on_nonexistent_directory(self, tmp_path):
        result = subprocess.run(
            [sys.executable, "-m", "agent_skills_export.cli_list", str(tmp_path / "nonexistent")],
            capture_output=True,
            text=True,
        )

        assert result.returncode != 0
        assert "not a directory" in result.stderr
