import json
import zipfile

import pytest

from agent_skills_export import build_skill


@pytest.fixture
def skill_dir(tmp_path):
    """Minimal skill directory with SKILL.md containing non-spec fields."""
    skill = tmp_path / "test-skill"
    skill.mkdir()
    (skill / "SKILL.md").write_text(
        "---\n"
        "name: test-skill\n"
        "version: 1.0.0\n"
        "model: sonnet\n"
        "description: A test skill for unit testing.\n"
        "allowed-tools: Read, Grep, Glob\n"
        "---\n"
        "\n"
        "# Test Skill\n"
        "\n"
        "Instructions go here.\n"
    )
    return skill


@pytest.fixture
def plugin_json_dir(skill_dir):
    """Skill directory with a .claude-plugin/plugin.json in its parent."""
    claude_plugin = skill_dir.parent / ".claude-plugin"
    claude_plugin.mkdir()
    (claude_plugin / "plugin.json").write_text(
        json.dumps(
            {
                "name": "test-plugin",
                "version": "2.1.0",
                "description": "A test plugin",
                "author": {"name": "Test Author", "email": "test@example.com"},
                "license": "MIT",
                "keywords": ["test"],
            }
        )
    )
    return skill_dir


@pytest.fixture
def built_skill(plugin_json_dir, tmp_path):
    """Pre-built skill ZIP and output directory. Avoids rebuilding per test."""
    output_dir = tmp_path / "dist"
    zip_path = build_skill(plugin_json_dir, output_dir)
    with zipfile.ZipFile(zip_path) as zf:
        skill_md_content = zf.read("test-skill/SKILL.md").decode()
        zip_names = zf.namelist()
    return {
        "zip_path": zip_path,
        "output_dir": output_dir,
        "skill_md": skill_md_content,
        "zip_names": zip_names,
    }


@pytest.fixture
def base_frontmatter():
    """Minimal spec-valid frontmatter."""
    return {"name": "my-skill", "description": "Does things."}
