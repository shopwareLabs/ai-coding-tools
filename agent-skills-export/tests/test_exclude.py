from pathlib import PurePosixPath

import pytest

from agent_skills_export import should_exclude


@pytest.mark.parametrize(
    "path",
    [
        ".agent-skills",
        ".DS_Store",
        "references/.DS_Store",
        "Thumbs.db",
        "__pycache__/mod.cpython-312.pyc",
        "__MACOSX/file",
        ".idea/workspace.xml",
        ".vscode/settings.json",
        "file.swp",
        "file.swo",
        "file.md~",
        "script.pyc",
    ],
    ids=lambda p: p.replace("/", "_").replace(".", ""),
)
def test_excludes_junk_files(path):
    assert should_exclude(PurePosixPath(path))


@pytest.mark.parametrize(
    "path",
    [
        "SKILL.md",
        "references/guide.md",
        "scripts/extract.py",
        "assets/template.json",
    ],
)
def test_allows_regular_files(path):
    assert not should_exclude(PurePosixPath(path))
