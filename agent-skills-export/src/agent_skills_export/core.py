"""Core build logic for Agent Skills export."""

from __future__ import annotations

import json
import shutil
import sys
import zipfile
from pathlib import Path
from typing import Any

import yaml

SPEC_FIELDS = {"name", "description", "license", "compatibility", "metadata"}

EXCLUDED_NAMES = {
    ".agent-skills",
    ".DS_Store",
    "Thumbs.db",
    "__pycache__",
    "__MACOSX",
    ".idea",
    ".vscode",
}

EXCLUDED_EXTENSIONS = {".pyc", ".swp", ".swo"}


def parse_skill_md(content: str) -> tuple[dict[str, Any], str]:
    """Parse SKILL.md into frontmatter dict and body string."""
    if not content.startswith("---"):
        raise ValueError("SKILL.md must start with YAML frontmatter (---)")
    parts = content.split("---", 2)
    if len(parts) < 3:
        raise ValueError("SKILL.md frontmatter not properly closed with ---")
    frontmatter = yaml.safe_load(parts[1])
    if not isinstance(frontmatter, dict):
        raise ValueError("SKILL.md frontmatter must be a YAML mapping")
    body = parts[2]
    return frontmatter, body


def serialize_skill_md(frontmatter: dict[str, Any], body: str) -> str:
    """Serialize frontmatter dict and body back into SKILL.md format."""
    fm_str = yaml.dump(
        frontmatter,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    )
    return f"---\n{fm_str}---{body}"


def find_plugin_json(skill_dir: Path) -> dict[str, Any]:
    """Walk up from skill_dir to find the nearest .claude-plugin/plugin.json."""
    current = skill_dir.resolve()
    while current != current.parent:
        candidate = current / ".claude-plugin" / "plugin.json"
        if candidate.is_file():
            result: dict[str, Any] = json.loads(candidate.read_text())
            return result
        current = current.parent
    raise FileNotFoundError(
        f"No .claude-plugin/plugin.json found in parent directories of {skill_dir}"
    )


def transform_frontmatter(
    frontmatter: dict[str, Any], plugin_data: dict[str, Any]
) -> dict[str, Any]:
    """Strip non-spec fields and enrich with plugin.json data."""
    result = {k: v for k, v in frontmatter.items() if k in SPEC_FIELDS}

    metadata = dict(result.get("metadata") or {})

    if "version" in plugin_data and "version" not in metadata:
        metadata["version"] = plugin_data["version"]

    author = plugin_data.get("author", {})
    if isinstance(author, dict) and "name" in author and "author" not in metadata:
        metadata["author"] = author["name"]

    if metadata:
        result["metadata"] = metadata

    if "license" not in result and "license" in plugin_data:
        result["license"] = plugin_data["license"]

    return result


def should_exclude(rel_path: Path) -> bool:
    """Check if a file or directory should be excluded from the ZIP."""
    for part in rel_path.parts:
        if part in EXCLUDED_NAMES:
            return True
    if rel_path.suffix in EXCLUDED_EXTENSIONS:
        return True
    return rel_path.name.endswith("~")


def build_skill(skill_dir: Path, output_dir: Path) -> Path:
    """Build a spec-compliant ZIP from a skill directory.

    Produces both a ZIP file and an unzipped output directory (for validation).

    Returns the path to the created ZIP file.
    """
    skill_md_path = skill_dir / "SKILL.md"
    if not skill_md_path.is_file():
        raise FileNotFoundError(f"SKILL.md not found in {skill_dir}")

    content = skill_md_path.read_text()
    frontmatter, body = parse_skill_md(content)

    skill_name = frontmatter.get("name")
    if not skill_name:
        raise ValueError("SKILL.md frontmatter missing required 'name' field")

    plugin_data = find_plugin_json(skill_dir)
    transformed = transform_frontmatter(frontmatter, plugin_data)
    new_content = serialize_skill_md(transformed, body)

    output_dir.mkdir(parents=True, exist_ok=True)

    skill_output = output_dir / skill_name
    if skill_output.exists():
        shutil.rmtree(skill_output)
    skill_output.mkdir()
    (skill_output / "SKILL.md").write_text(new_content)

    for file_path in skill_dir.rglob("*"):
        if not file_path.is_file() or file_path.name == "SKILL.md":
            continue
        rel_path = file_path.relative_to(skill_dir)
        if should_exclude(rel_path):
            continue
        dest = skill_output / rel_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(file_path.read_bytes())

    zip_path = output_dir / f"{skill_name}.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file_path in sorted(skill_output.rglob("*")):
            if file_path.is_file():
                arcname = f"{skill_name}/{file_path.relative_to(skill_output)}"
                zf.write(file_path, arcname)

    return zip_path


def discover_exportable_skills(root_dir: Path) -> list[dict[str, str]]:
    """Find all skills with .agent-skills markers under root_dir.

    Returns a list of dicts with 'path' (relative to root_dir) and 'name' (sanitized for artifacts).
    """
    results: list[dict[str, str]] = []

    for marker in sorted(root_dir.rglob(".agent-skills")):
        if not marker.is_file():
            continue
        skill_dir = marker.parent
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.is_file():
            continue

        try:
            content = skill_md.read_text()
            frontmatter, _ = parse_skill_md(content)
            skill_name = frontmatter.get("name", "")
        except (ValueError, OSError):
            skill_name = ""

        if not skill_name:
            skill_name = skill_dir.name

        artifact_name = _sanitize_artifact_name(skill_name)
        rel_path = skill_dir.relative_to(root_dir)

        results.append({"path": str(rel_path), "name": artifact_name})

    return results


def _sanitize_artifact_name(name: str) -> str:
    """Sanitize a skill name for use as a GitHub Actions artifact name."""
    import re

    name = name.lower().replace(" ", "-")
    name = re.sub(r"[^a-z0-9_-]", "", name)
    return name.strip("-")


def validate_skill(skill_output_dir: Path) -> list[str]:
    """Validate a built skill directory using skills-ref.

    Returns a list of validation errors. Empty list means valid.
    Prints a warning if skills-ref is not installed.
    """
    try:
        from skills_ref import validate  # type: ignore[import-untyped]

        result: list[str] = validate(skill_output_dir)
        return result
    except ImportError:
        print("Warning: skills-ref not installed, skipping validation", file=sys.stderr)
        print(
            "Install: pip install 'skills-ref @ git+https://github.com/agentskills/agentskills.git#subdirectory=skills-ref'",
            file=sys.stderr,
        )
        return []
