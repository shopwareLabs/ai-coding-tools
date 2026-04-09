"""CLI entry point for agent-skills-export."""

from __future__ import annotations

import json
from pathlib import Path

import typer

from .core import build_skill, discover_exportable_skills, validate_skill

# Main app for build-agent-skill (default command: build)
app = typer.Typer(add_completion=False)


@app.command()
def main(
    skill_dir: Path = typer.Argument(  # noqa: B008
        help="Path to the skill directory containing SKILL.md",
    ),
    output_dir: Path = typer.Argument(  # noqa: B008
        default=None,
        help="Output directory for the ZIP [default: current directory]",
    ),
) -> None:
    """Build an Agent Skills-compliant ZIP from a Claude Code skill."""
    if output_dir is None:
        output_dir = Path.cwd()

    if not skill_dir.is_dir():
        typer.echo(f"Error: not a directory: {skill_dir}", err=True)
        raise typer.Exit(code=1)

    try:
        zip_path = build_skill(skill_dir, output_dir)
    except (FileNotFoundError, ValueError) as e:
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(code=1) from e

    skill_name = zip_path.stem
    skill_output = output_dir / skill_name

    errors = validate_skill(skill_output)
    if errors:
        typer.echo(f"Validation failed for {skill_name}:", err=True)
        for error in errors:
            typer.echo(f"  - {error}", err=True)
        raise typer.Exit(code=1)

    typer.echo(f"Built: {zip_path}")


# Separate app for list-agent-skills
list_app = typer.Typer(add_completion=False)


@list_app.command()
def list_skills(
    root_dir: Path = typer.Argument(  # noqa: B008
        default=None,
        help="Root directory to search [default: current directory]",
    ),
) -> None:
    """List exportable skills as JSON for GitHub Actions matrix.

    Finds all skills with .agent-skills markers and outputs JSON array
    with 'path' and 'name' fields for each skill.
    """
    if root_dir is None:
        root_dir = Path.cwd()

    if not root_dir.is_dir():
        typer.echo(f"Error: not a directory: {root_dir}", err=True)
        raise typer.Exit(code=1)

    skills = discover_exportable_skills(root_dir)
    typer.echo(json.dumps(skills))
