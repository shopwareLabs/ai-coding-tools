import pytest

from agent_skills_export import transform_frontmatter


class TestStripNonSpecFields:
    @pytest.mark.parametrize("field", ["version", "model", "allowed-tools"])
    def test_removes_field(self, base_frontmatter, field):
        base_frontmatter[field] = "some-value"
        plugin_data = {"version": "1.0.0"}
        result = transform_frontmatter(base_frontmatter, plugin_data)
        assert field not in result

    @pytest.mark.parametrize("field", ["name", "description", "license", "compatibility"])
    def test_preserves_spec_field(self, base_frontmatter, field):
        base_frontmatter[field] = "kept-value"
        result = transform_frontmatter(base_frontmatter, {})
        assert result[field] == "kept-value"


class TestEnrichFromPluginJson:
    def test_adds_version_and_author_to_metadata(self, base_frontmatter):
        plugin_data = {"version": "2.1.0", "author": {"name": "Author"}}
        result = transform_frontmatter(base_frontmatter, plugin_data)
        assert result["metadata"]["version"] == "2.1.0"
        assert result["metadata"]["author"] == "Author"

    def test_adds_license_when_absent(self, base_frontmatter):
        plugin_data = {"license": "MIT"}
        result = transform_frontmatter(base_frontmatter, plugin_data)
        assert result["license"] == "MIT"

    def test_does_not_overwrite_existing_license(self, base_frontmatter):
        base_frontmatter["license"] = "Apache-2.0"
        plugin_data = {"license": "MIT"}
        result = transform_frontmatter(base_frontmatter, plugin_data)
        assert result["license"] == "Apache-2.0"

    def test_does_not_overwrite_existing_metadata_keys(self, base_frontmatter):
        base_frontmatter["metadata"] = {"author": "Skill Author", "custom": "value"}
        plugin_data = {"version": "2.0.0", "author": {"name": "Plugin Author"}}
        result = transform_frontmatter(base_frontmatter, plugin_data)
        assert result["metadata"]["author"] == "Skill Author"
        assert result["metadata"]["custom"] == "value"
        assert result["metadata"]["version"] == "2.0.0"

    def test_skips_metadata_when_plugin_data_empty(self, base_frontmatter):
        result = transform_frontmatter(base_frontmatter, {})
        assert "metadata" not in result

    def test_skips_author_when_missing_from_plugin(self, base_frontmatter):
        plugin_data = {"version": "1.0.0"}
        result = transform_frontmatter(base_frontmatter, plugin_data)
        assert "author" not in result["metadata"]
