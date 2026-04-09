import pytest

from agent_skills_export import parse_skill_md, serialize_skill_md

SIMPLE_SKILL = (
    "---\n"
    "name: my-skill\n"
    "description: Does things.\n"
    "metadata:\n"
    "  custom-key: custom-value\n"
    "---\n"
    "\n"
    "# My Skill\n"
    "\n"
    "Body content.\n"
)


class TestParseSkillMd:
    def test_splits_frontmatter_and_body(self):
        frontmatter, body = parse_skill_md(SIMPLE_SKILL)
        assert frontmatter["name"] == "my-skill"
        assert frontmatter["description"] == "Does things."
        assert frontmatter["metadata"]["custom-key"] == "custom-value"
        assert "# My Skill" in body
        assert "Body content." in body

    def test_handles_folded_yaml_values(self):
        content = "---\nname: x\ndescription: >-\n  First line\n  second line.\n---\n\nBody.\n"
        frontmatter, _ = parse_skill_md(content)
        assert frontmatter["description"] == "First line second line."

    @pytest.mark.parametrize(
        ("content", "error_match"),
        [
            ("# No frontmatter\n", "must start with"),
            ("---\nname: x\n", "not properly closed"),
        ],
        ids=["missing_delimiter", "unclosed_delimiter"],
    )
    def test_rejects_invalid_frontmatter(self, content, error_match):
        with pytest.raises(ValueError, match=error_match):
            parse_skill_md(content)


class TestSerializeSkillMd:
    def test_produces_valid_frontmatter_document(self):
        frontmatter = {"name": "my-skill", "description": "Does things."}
        body = "\n# Content\n"
        result = serialize_skill_md(frontmatter, body)
        assert result.startswith("---\n")
        assert "name: my-skill\n" in result
        assert result.endswith(body)

    def test_roundtrips_through_parse(self):
        frontmatter, body = parse_skill_md(SIMPLE_SKILL)
        result = serialize_skill_md(frontmatter, body)
        re_parsed, re_body = parse_skill_md(result)
        assert re_parsed == frontmatter
        assert re_body == body
