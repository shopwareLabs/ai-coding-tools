#!/usr/bin/env python3
"""Materialize blind source fixtures; optionally invoke a CLI after --execute.

Never sets HOME, CODEX_HOME or other environment variables, changes user settings,
copies credentials, calls a model during check/materialize, or scores prose.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path, PurePosixPath

CASES = Path(__file__).with_name("cases.json")
NAME = "shopware-development"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def fixture_path(name):
    path = PurePosixPath(name)
    require(isinstance(name, str) and name and not path.is_absolute() and ".." not in path.parts and "\\" not in name, f"unsafe fixture path: {name}")
    require(not any(part.startswith(".") for part in path.parts), f"hidden/config path forbidden in source fixture: {name}")
    return path


def load_cases(path=CASES):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    require(data.get("schema_version") == 1, "unsupported fixture schema")
    cases = data.get("cases")
    require(isinstance(cases, list) and 1 <= len(cases) <= 14, "requires 1..14 cases")
    ids = set()
    for case in cases:
        ident = case.get("id")
        require(isinstance(ident, str) and re.fullmatch(r"[a-z0-9-]+", ident) and ident not in ids, "invalid/duplicate case ID")
        ids.add(ident)
        require(isinstance(case.get("prompt"), str) and case["prompt"].strip(), f"{ident}: prompt required")
        files = case.get("files")
        require(isinstance(files, dict) and "composer.json" in files, f"{ident}: source files and root composer.json required")
        for name, content in files.items():
            fixture_path(name)
            require(isinstance(content, str) and content.strip(), f"{ident}: blank/nontext file {name}")
            if name.endswith("composer.json"):
                manifest = json.loads(content)
                require(manifest.get("require", {}).get("shopware/core") in {"6.7.15.1", "6.6.10.30"}, f"{ident}: exact core target required in {name}")
            require(not re.search(r"/Users/|/private/tmp/|slack\.com/|-----BEGIN .*PRIVATE KEY", content), f"{ident}: private content in fixture")
        expected = case.get("expected")
        require(isinstance(expected, dict) and isinstance(expected.get("findings"), list), f"{ident}: expected rubric required")
        for finding in expected["findings"]:
            require(all(finding.get(key) for key in ("behavior", "evidence", "minimal_fix", "verification")), f"{ident}: incomplete finding rubric")
            require(all(file in files for file in finding["evidence"]), f"{ident}: unknown evidence file")
            require(finding.get("severity") in {"P0", "P1", "P2", "P3"}, f"{ident}: severity required only on proven finding")
        if not expected["findings"]:
            require(bool(expected.get("required_behavior")), f"{ident}: clean control needs an affirmative rubric")
    return cases


def hashes(root):
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob("*")) if p.is_file()}


def materialize(case, runtime, skill=None):
    run_dir = Path(tempfile.mkdtemp(prefix="shopware-eval-")).resolve()
    fixture = run_dir / "project"
    fixture.mkdir()
    for name, content in case["files"].items():
        path = fixture / str(fixture_path(name))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    plugin = None
    if skill is not None:
        skill = Path(skill).resolve()
        require((skill / "SKILL.md").is_file(), "--skill must contain SKILL.md")
        require(not any(p.is_symlink() for p in skill.rglob("*")), "skill copy must not include symlinks")
        if runtime == "codex":
            destination = fixture / ".agents/skills" / NAME
        else:
            plugin = fixture / "subject-plugin"
            destination = plugin / "skills" / NAME
            (plugin / ".claude-plugin").mkdir(parents=True)
            (plugin / ".claude-plugin/plugin.json").write_text(json.dumps({
                "name": "shopware-knowledge", "version": "0.10.0",
                "description": "Isolated evaluation wrapper for the selected skill snapshot",
            }), encoding="utf-8")
        shutil.copytree(skill, destination, ignore=shutil.ignore_patterns("__pycache__", ".DS_Store", ".git"))
    return run_dir, fixture, plugin


def global_skills(extra=()):
    """Disable duplicate local skills per invocation, without editing config."""
    roots = [Path.home() / ".agents/skills", Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "skills", Path("/etc/codex/skills")]
    paths = {Path(p).expanduser().resolve() for p in extra}
    for root in roots:
        if root.is_dir():
            paths.update(p.resolve() for p in root.rglob("SKILL.md") if p.parent.name == NAME)
    return sorted(str(p / "SKILL.md" if p.is_dir() else p) for p in paths)


def command(runtime, executable, fixture, plugin, model, disabled, budget):
    if runtime == "codex":
        config = "skills.config=[" + ",".join("{path=" + json.dumps(path) + ",enabled=false}" for path in disabled) + "]"
        args = [executable, "-a", "never", "--config", config, "exec", "--cd", str(fixture),
                "--sandbox", "read-only", "--skip-git-repo-check", "--ephemeral", "--json",
                "--ignore-user-config", "--ignore-rules",
                "--output-last-message", str(fixture.parent / "answer.txt")]
        if model:
            args.extend(["--model", model])
        return args + ["-"]
    args = [executable, "--print", "--output-format", "json",
            "--no-session-persistence", "--setting-sources", "", "--restricted",
            "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
            "--permission-mode", "dontAsk", "--tools", "Read,Glob,Grep,Skill",
            "--allowed-tools", "Read,Glob,Grep,Skill", "--max-budget-usd", str(budget)]
    if model:
        args.extend(["--model", model])
    if plugin:
        args.extend(["--plugin-dir", str(plugin)])
    return args


def cli_info(runtime, executable):
    result = {}
    for label, args in (("version", ["--version"]), ("help", ["--help"]), ("exec_help", ["exec", "--help"] if runtime == "codex" else ["--help"])):
        proc = subprocess.run([executable, *args], text=True, capture_output=True, timeout=30)
        require(proc.returncode == 0, f"CLI {label} failed: {proc.stderr}")
        result[label] = proc.stdout + proc.stderr
    required = ["--sandbox", "--ephemeral", "--output-last-message", "--ignore-user-config", "--ignore-rules"] if runtime == "codex" else ["--plugin-dir", "--setting-sources", "--restricted", "--strict-mcp-config"]
    require(all(flag in result["exec_help"] for flag in required), "CLI flags differ from inspected help; update runner before model use")
    return result


def run_case(case, args):
    run_dir, fixture, plugin = materialize(case, args.runtime, args.skill)
    model = args.model
    disabled = global_skills(args.disable_skill) if args.runtime == "codex" else []
    executable = args.cli or args.runtime
    argv = command(args.runtime, executable, fixture, plugin, model, disabled, args.budget_usd)
    prompt = case["prompt"]
    if args.skill and args.invocation == "explicit":
        invocation = "$shopware-development" if args.runtime == "codex" else "/shopware-knowledge:shopware-development"
        prompt = invocation + "\n\n" + prompt
    prompt += "\n\nRead the source files under the current project directory. Remain read-only. Do not read outside this project or use external services. If exact core source is absent, identify that verification boundary rather than claiming it was inspected."
    (run_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
    before = hashes(fixture)
    record = {"case": case["id"], "arm": args.arm, "runtime": args.runtime, "model": model,
              "invocation": args.invocation, "command": argv, "disabled_skills": disabled,
              "fixture_sha256": before, "executed": False, "semantic_score": None}
    print(f"{case['id']}: {run_dir}", flush=True)
    print(shlex.join(argv), flush=True)
    if args.command == "run" and args.execute:
        record["cli"] = cli_info(args.runtime, executable)
        start = time.monotonic()
        try:
            # Inherit the process environment unchanged, including authentication.
            with (run_dir / "stdout.log").open("w") as stdout, (run_dir / "stderr.log").open("w") as stderr:
                proc = subprocess.run(argv, cwd=fixture, input=prompt, text=True, stdout=stdout, stderr=stderr, timeout=args.timeout)
            record.update(executed=True, returncode=proc.returncode)
        except subprocess.TimeoutExpired:
            record.update(executed=True, timed_out=True, returncode=124)
        record["elapsed_seconds"] = round(time.monotonic() - start, 3)
        record["fixture_unchanged"] = hashes(fixture) == before
    (run_dir / "run.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    # No expected rubric is written into the CLI-visible project or its prompt.
    return record.get("returncode", 0) if record.get("fixture_unchanged", True) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check", "list", "materialize", "run"])
    parser.add_argument("--case", action="append", default=[], help="repeat for several fixed cases")
    parser.add_argument("--all", action="store_true", help="explicitly select all 14 cases")
    parser.add_argument("--runtime", choices=["codex", "claude"], default="codex")
    parser.add_argument("--skill", type=Path, help="selected skill snapshot; omit for no-skill control")
    parser.add_argument("--arm", default="unlabelled", help="A/B label stored only outside the fixture")
    parser.add_argument("--invocation", choices=["explicit", "auto"], default="explicit")
    parser.add_argument("--disable-skill", action="append", default=[], help="extra Codex skill path to disable per invocation")
    parser.add_argument("--cli", help="CLI executable path, if not on PATH")
    parser.add_argument("--model", help="optional model override; omitted uses unchanged CLI default")
    parser.add_argument("--budget-usd", type=float, default=2.0, help="Claude per-case API budget cap")
    parser.add_argument("--timeout", type=int, default=600, help="per-case subprocess timeout in seconds")
    parser.add_argument("--execute", action="store_true", help="permit actual model calls; otherwise dry-run only")
    args = parser.parse_args()
    try:
        cases = load_cases()
        if args.command == "check":
            print(f"PASS: {len(cases)} fixture schemas, composer targets and separate rubrics; no model calls")
            return 0
        if args.command == "list":
            print("\n".join(c["id"] for c in cases))
            return 0
        require(args.all or args.case, "select --case ID or --all")
        require(not (set(args.case) - {c["id"] for c in cases}), "unknown case ID")
        require(not args.execute or args.command == "run", "--execute is only accepted with run")
        require(args.timeout > 0 and args.budget_usd > 0, "timeout and budget must be positive")
        selected = cases if args.all else [c for c in cases if c["id"] in args.case]
        failed = False
        for case in selected:
            failed = bool(run_case(case, args)) or failed
        return int(failed)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
