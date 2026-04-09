import json

import pytest

from agent_skills_export import find_plugin_json


class TestFindPluginJson:
    @pytest.mark.parametrize("depth", [0, 2], ids=["immediate_parent", "two_levels_up"])
    def test_finds_plugin_json_at_ancestor(self, tmp_path, depth):
        plugin_root = tmp_path / "plugin-root"
        plugin_root.mkdir()
        claude_plugin = plugin_root / ".claude-plugin"
        claude_plugin.mkdir()
        (claude_plugin / "plugin.json").write_text(
            json.dumps(
                {
                    "name": "test-plugin",
                    "version": "1.0.0",
                }
            )
        )
        skill_dir = plugin_root
        for i in range(depth):
            skill_dir = skill_dir / f"level-{i}"
        skill_dir.mkdir(parents=True, exist_ok=True)

        result = find_plugin_json(skill_dir)
        assert result["name"] == "test-plugin"

    def test_raises_when_no_plugin_json_exists(self, tmp_path):
        skill_dir = tmp_path / "orphan"
        skill_dir.mkdir()
        with pytest.raises(FileNotFoundError, match="plugin.json"):
            find_plugin_json(skill_dir)
