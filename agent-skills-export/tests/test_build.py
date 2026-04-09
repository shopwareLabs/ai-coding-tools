import subprocess
import sys

from agent_skills_export import build_skill


class TestBuildSkill:
    """Integration tests for the full build pipeline."""

    def test_produces_zip_and_output_directory(self, built_skill):
        assert built_skill["zip_path"].name == "test-skill.zip"
        assert built_skill["zip_path"].exists()
        assert (built_skill["output_dir"] / "test-skill").is_dir()
        assert (built_skill["output_dir"] / "test-skill" / "SKILL.md").is_file()

    def test_strips_non_spec_frontmatter_fields(self, built_skill):
        fm_block = built_skill["skill_md"].split("---")[1]
        assert "\nversion:" not in fm_block
        assert "\nmodel:" not in fm_block
        assert "\nallowed-tools:" not in fm_block

    def test_enriches_from_plugin_json(self, built_skill):
        assert "Test Author" in built_skill["skill_md"]
        assert "2.1.0" in built_skill["skill_md"]
        assert "MIT" in built_skill["skill_md"]

    def test_preserves_body(self, built_skill):
        assert "# Test Skill" in built_skill["skill_md"]
        assert "Instructions go here." in built_skill["skill_md"]

    def test_includes_reference_files(self, plugin_json_dir, tmp_path):
        refs = plugin_json_dir / "references"
        refs.mkdir()
        (refs / "guide.md").write_text("# Guide\n")
        output_dir = tmp_path / "dist"
        zip_path = build_skill(plugin_json_dir, output_dir)
        import zipfile

        with zipfile.ZipFile(zip_path) as zf:
            assert "test-skill/references/guide.md" in zf.namelist()

    def test_excludes_junk_files(self, plugin_json_dir, tmp_path):
        (plugin_json_dir / ".agent-skills").touch()
        (plugin_json_dir / ".DS_Store").write_bytes(b"\x00")
        pycache = plugin_json_dir / "__pycache__"
        pycache.mkdir()
        (pycache / "mod.cpython-312.pyc").write_bytes(b"\x00")

        output_dir = tmp_path / "dist"
        zip_path = build_skill(plugin_json_dir, output_dir)
        import zipfile

        with zipfile.ZipFile(zip_path) as zf:
            names = zf.namelist()
        assert all(n[:11] == "test-skill/" for n in names)
        assert not any(".agent-skills" in n for n in names)
        assert not any(".DS_Store" in n for n in names)
        assert not any("__pycache__" in n for n in names)


class TestCLI:
    def test_succeeds_with_valid_skill(self, plugin_json_dir, tmp_path):
        output_dir = tmp_path / "cli-dist"
        result = subprocess.run(
            [sys.executable, "-m", "agent_skills_export", str(plugin_json_dir), str(output_dir)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        assert (output_dir / "test-skill.zip").exists()

    def test_defaults_output_to_cwd(self, plugin_json_dir, tmp_path):
        result = subprocess.run(
            [sys.executable, "-m", "agent_skills_export", str(plugin_json_dir)],
            capture_output=True,
            text=True,
            cwd=str(tmp_path),
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        assert (tmp_path / "test-skill.zip").exists()

    def test_fails_on_missing_skill_md(self, tmp_path):
        empty_dir = tmp_path / "empty"
        empty_dir.mkdir()
        result = subprocess.run(
            [sys.executable, "-m", "agent_skills_export", str(empty_dir), str(tmp_path / "out")],
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0
