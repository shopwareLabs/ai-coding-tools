#!/usr/bin/env python3
"""Validate the native pack and its upstream-built portable artifact.

These are structural checks and conservative hygiene lints, not behavioral proof.
No model, network request, Git mutation, or repository write is performed.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from urllib.parse import unquote, urlsplit

try:
    import yaml
    from skills_ref import validate as validate_portable
except ImportError as exc:
    raise SystemExit(f"Required validation dependency missing: {exc}. Install eval/shopware-knowledge/requirements.txt")

PLUGIN = Path("plugins/shopware-knowledge")
SKILL = PLUGIN / "skills/shopware-development"
VERSION = "0.10.0"
NAME = "shopware-development"
DESCRIPTION_BUDGET = 1024
MODES = {"plan", "planning", "implement", "implementation", "refactor", "debug", "review", "audit", "research", "migrate", "report", "operate", "test"}


class Invalid(ValueError):
    pass


class UniqueLoader(yaml.SafeLoader):
    """Reject duplicate keys instead of silently accepting the final value."""


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise Invalid(f"duplicate key: {key}")
        result[key] = value
    return result


def yaml_mapping(loader, node):
    return unique_pairs(loader.construct_pairs(node, deep=True))


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, yaml_mapping)


def frontmatter(text):
    match = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)", text, re.S)
    if not match:
        raise Invalid("missing or unclosed YAML frontmatter")
    value = yaml.load(match[1], Loader=UniqueLoader)
    if not isinstance(value, dict):
        raise Invalid("frontmatter must be a mapping")
    return value, text[match.end():]


def nonblank(value):
    return isinstance(value, str) and bool(value.strip())


def string_list(value, empty=False):
    return isinstance(value, list) and (empty or bool(value)) and all(nonblank(v) for v in value)


def prose(text):
    """Exclude code examples from instruction and Markdown-link analysis."""
    lines = []
    fence = None
    for line in text.splitlines():
        marker = re.match(r"^\s{0,3}(`{3,}|~{3,})", line)
        if marker:
            if fence is None:
                fence = marker[1]
            elif marker[1][0] == fence[0] and len(marker[1]) >= len(fence):
                fence = None
            continue
        if fence is None:
            lines.append(line)
    return "\n".join(lines)


def destinations(text):
    """Read inline and full/collapsed reference links, including balanced URLs.

    This intentionally is not a complete CommonMark parser. Code examples and
    inline code are ignored; backticked references/*.md paths are handled below.
    """
    text = re.sub(r"`+[^`\n]*`+", "", prose(text))
    definitions = {}
    for match in re.finditer(r"^\s{0,3}\[([^\]]+)\]:\s*(<[^>]+>|\S+)", text, re.M):
        definitions[match[1].strip().casefold()] = match[2].strip("<>")
    text = re.sub(r"^\s{0,3}\[[^\]]+\]:[^\n]*", "", text, flags=re.M)
    for match in re.finditer(r"!?\[([^\]\n]*)\](\(|\[)", text):
        pos = match.end()
        if match[2] == "[":
            end = text.find("]", pos)
            if end < 0:
                raise Invalid("unclosed reference link")
            label = (text[pos:end] or match[1]).strip().casefold()
            if label not in definitions:
                raise Invalid(f"undefined reference link: {label}")
            yield definitions[label]
            continue
        if pos < len(text) and text[pos] == "<":
            end = text.find(">", pos)
            if end < 0:
                raise Invalid("unclosed angle link")
            yield text[pos + 1:end]
            continue
        start, depth = pos, 0
        while pos < len(text):
            char = text[pos]
            if char == "\\":
                pos += 2
                continue
            if char == "(":
                depth += 1
            elif char == ")":
                if depth == 0:
                    break
                depth -= 1
            elif char.isspace() and depth == 0:
                break
            pos += 1
        if pos == len(text):
            raise Invalid("unclosed inline link")
        yield re.sub(r"\\([()])", r"\1", text[start:pos])
    # Bare reference paths are meaningful routing edges too, not behavior tests.
    yield from re.findall(r"`((?:\./|\.\./)*references/[\w./-]+\.md)`", prose(text))


def anchors(text):
    found, counts = set(), {}
    for line in prose(text).splitlines():
        match = re.match(r"^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$", line)
        if not match:
            continue
        title = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", match[1])
        title = re.sub(r"<[^>]+>", "", title).casefold()
        slug = re.sub(r"[^\w\- ]", "", title).replace(" ", "-")
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        found.add(f"{slug}-{count}" if count else slug)
    found.update(re.findall(r'''(?:id|name)=["']([^"']+)["']''', text))
    return found


class PackValidator:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.skill = (self.root / SKILL).resolve()
        self.plugin = (self.root / PLUGIN).resolve()
        self.errors = []

    def error(self, code, path, detail):
        try:
            path = Path(path).relative_to(self.root)
        except ValueError:
            pass
        self.errors.append(f"{code}: {path}: {detail}")

    def json(self, path):
        try:
            value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs)
            if not isinstance(value, dict):
                raise Invalid("must be a JSON object")
            return value
        except (OSError, ValueError) as exc:
            self.error("json", path, str(exc))
            return {}

    def local(self, base, value, boundary):
        if not nonblank(value) or "\\" in value:
            raise Invalid("expected a nonempty POSIX relative path")
        parsed = urlsplit(value)
        if parsed.scheme or parsed.netloc or parsed.path.startswith(("/", "~")):
            raise Invalid("expected a relative bundled path")
        candidate = base / unquote(parsed.path)
        target = candidate.resolve()
        if not target.is_relative_to(boundary):
            raise Invalid(f"path escapes bundle: {value}")
        if not target.exists():
            raise Invalid(f"missing target: {value}")
        # A case-insensitive developer filesystem must not hide Linux CI errors.
        current = boundary
        for part in candidate.absolute().relative_to(boundary).parts:
            if part in (".", ".."):
                current = (current / part).resolve()
                continue
            if part not in {p.name for p in current.iterdir()}:
                raise Invalid(f"path case mismatch: {value}")
            current /= part
        return target

    def metadata(self, skill, native):
        path = skill / "SKILL.md"
        try:
            data, body = frontmatter(path.read_text(encoding="utf-8"))
        except (OSError, ValueError, yaml.YAMLError) as exc:
            self.error("frontmatter", path, str(exc))
            return
        if data.get("name") != NAME:
            self.error("skill-name", path, f"expected {NAME}")
        description = data.get("description")
        if not nonblank(description) or len(description) > DESCRIPTION_BUDGET:
            self.error("description", path, f"requires 1..{DESCRIPTION_BUDGET} characters")
        if not body.strip():
            self.error("skill-body", path, "empty instructions")
        metadata = data.get("metadata", {})
        if not isinstance(metadata, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in metadata.items()):
            self.error("metadata", path, "metadata must map strings to strings")
            metadata = {}
        if native and data.get("version") != VERSION:
            self.error("version", path, f"native top-level version must be {VERSION}")
        if (not native and ("version" in data or metadata.get("version") != VERSION)) or ("version" in metadata and metadata["version"] != VERSION):
            self.error("version", path, "portable metadata.version or native metadata drift")
        # These are preapproval declarations, not a semantic reading of prose.
        grants = data.get("allowed-tools", [])
        if isinstance(grants, str):
            grants = grants.split()
        if not isinstance(grants, list) or any(g not in {"Read", "Glob", "Grep"} for g in grants):
            self.error("preapproval", path, "only Read/Glob/Grep grants are accepted; shell grants require manual review")
        if native:
            allowed = {"name", "description", "version", "license", "compatibility", "metadata", "allowed-tools", "argument-hint", "when_to_use"}
            if set(data) - allowed:
                self.error("frontmatter-fields", path, f"unsupported fields: {sorted(set(data) - allowed)}")

    def runtime(self, skill):
        skill = skill.resolve()
        paths = sorted(skill.rglob("*"))
        graph, texts = {}, {}
        for path in paths:
            if path.is_symlink():
                self.error("symlink", path, "runtime bundle must contain regular files/directories")
            if path.suffix.lower() != ".md" or not path.is_file():
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except (OSError, UnicodeError) as exc:
                self.error("runtime-text", path, str(exc))
                continue
            texts[path.resolve()] = text
            graph[path.resolve()] = set()
            # Hygiene lints deliberately do not assert behavior or match an answer.
            if re.search(r"(?:/Users/|/home/[^/\s]+/|/private/(?:tmp|var)/|[A-Za-z]:\\Users\\|file://|~/(?:Documents|Desktop)/)", text):
                self.error("private-path", path, "host/private path in runtime Markdown")
            if re.search(r"(?:slack\.com/(?:archives|messages)|slack://|slack\s+(?:thread|feedback|message|export|discussion)|feedback\s+(?:from|by)\s+@)", text, re.I):
                self.error("private-provenance", path, "private conversation provenance in runtime Markdown")
            instruction = prose(text)
            if re.search(r"(?:with|using|via) the (?:Read|Glob|Grep|Task) tool|\bmcp__[\w_]+|\b(?:use|invoke|call)\s+(?:the\s+)?(?:TodoWrite|TaskCreate|AskUserQuestion)\b", instruction, re.I):
                self.error("runtime-neutrality", path, "runtime-specific tool instruction; use capability-neutral wording")
        for path, text in texts.items():
            try:
                body = frontmatter(text)[1] if path == skill / "SKILL.md" else text
                links = list(destinations(body))
            except (Invalid, yaml.YAMLError) as exc:
                self.error("markdown", path, str(exc))
                continue
            for link in links:
                parsed = urlsplit(link)
                if parsed.scheme in {"http", "https", "mailto", "tel"}:
                    continue
                try:
                    target = self.local(path.parent, link if parsed.path else path.name, skill)
                    if target in graph:
                        graph[path].add(target)
                    if parsed.fragment and target.suffix.lower() == ".md" and unquote(parsed.fragment) not in anchors(texts.get(target, "")):
                        raise Invalid(f"unknown heading fragment: {link}")
                except (Invalid, OSError, ValueError) as exc:
                    self.error("link", path, str(exc))
        reached, todo = set(), [skill / "SKILL.md"]
        while todo:
            path = todo.pop()
            if path not in reached:
                reached.add(path)
                todo.extend(graph.get(path, ()))
        for path in graph:
            if path.is_relative_to(skill / "references") and path not in reached:
                self.error("unreachable-reference", path, "no route from SKILL.md")

    def manifests(self):
        for runtime in ("claude", "codex"):
            path = self.plugin / f".{runtime}-plugin/plugin.json"
            data = self.json(path)
            if data.get("name") != "shopware-knowledge" or data.get("version") != VERSION:
                self.error("manifest-identity", path, f"expected shopware-knowledge {VERSION}")
            if not nonblank(data.get("description")):
                self.error("manifest-shape", path, "description required")
            if "author" in data and (not isinstance(data["author"], dict) or not nonblank(data["author"].get("name"))):
                self.error("manifest-shape", path, "author must be an object with name")
            for key in ("mcpServers", "hooks", "agents", "commands"):
                if data.get(key):
                    self.error("manifest-surface", path, f"knowledge-only pack must not enable {key}")
            if "skills" in data:
                values = data["skills"] if isinstance(data["skills"], list) else [data["skills"]]
                if not values:
                    self.error("manifest-skills", path, "skills must not disable discovery")
                for value in values:
                    try:
                        target = self.local(self.plugin, value, self.plugin)
                        if target not in {self.skill, self.skill.parent}:
                            raise Invalid("skills must resolve to the canonical skill or skills directory")
                    except (Invalid, TypeError, ValueError, OSError) as exc:
                        self.error("manifest-skills", path, str(exc))
            interface = data.get("interface")
            if interface is not None and (not isinstance(interface, dict) or not all(nonblank(interface.get(k)) for k in ("displayName", "shortDescription"))):
                self.error("manifest-interface", path, "interface needs displayName and shortDescription")
        for runtime, rel in (("claude", ".claude-plugin/marketplace.json"), ("codex", ".agents/plugins/marketplace.json")):
            path = self.root / rel
            data = self.json(path)
            entries = data.get("plugins")
            if not nonblank(data.get("name")) or not isinstance(entries, list):
                self.error("marketplace-shape", path, "name and plugins array required")
                continue
            if runtime == "claude" and (not isinstance(data.get("owner"), dict) or not nonblank(data["owner"].get("name"))):
                self.error("marketplace-shape", path, "Claude marketplace owner.name required")
            names = [e.get("name") for e in entries if isinstance(e, dict)]
            if len(names) != len(entries) or not all(nonblank(n) for n in names) or len(set(names)) != len(names):
                self.error("marketplace-shape", path, "entries need unique nonempty names")
            matches = [e for e in entries if isinstance(e, dict) and e.get("name") == "shopware-knowledge"]
            if len(matches) != 1:
                self.error("marketplace-entry", path, "exactly one shopware-knowledge entry required")
            for entry in matches:
                source = entry.get("source")
                if runtime == "codex":
                    source = source.get("path") if isinstance(source, dict) and source.get("source") == "local" else None
                try:
                    if self.local(self.root, source, self.root) != self.plugin:
                        raise Invalid("marketplace source is not the canonical plugin root")
                except (Invalid, TypeError, ValueError, OSError) as exc:
                    self.error("marketplace-path", path, str(exc))
                if "version" in entry and entry["version"] != VERSION:
                    self.error("version", path, "marketplace plugin version drift")
        if (self.root / ".claude-plugin/plugin.json").exists():
            self.error("legacy-manifest", self.root / ".claude-plugin/plugin.json", "remove obsolete root plugin manifest")

    def knowledge_index(self):
        path = self.plugin / "knowledge-index.json"
        data = self.json(path)
        topics = data.get("topics")
        if type(data.get("schema_version")) is not int or data.get("schema_version") != 1 or data.get("skill") != NAME or not isinstance(topics, list) or not topics:
            self.error("index-shape", path, "requires schema_version:1, skill and nonempty topics")
            return
        ids, covered = set(), set()
        for topic in topics:
            if not isinstance(topic, dict):
                self.error("index-topic", path, "topic must be an object")
                continue
            ident = topic.get("id")
            if not nonblank(ident) or ident in ids:
                self.error("index-id", path, f"blank/duplicate topic id: {ident}")
            if nonblank(ident):
                ids.add(ident)
            if not string_list(topic.get("modes")) or set(topic["modes"]) - MODES:
                self.error("index-applicability", path, f"{ident}: nonempty supported modes required")
            versions = topic.get("shopware")
            versions = [versions] if isinstance(versions, str) else versions
            if not string_list(versions) or not all(re.search(r"\b6\.[67](?:\b|\.)", v) for v in versions):
                self.error("index-applicability", path, f"{ident}: explicit Shopware 6.6/6.7 applicability required")
            if not string_list(topic.get("feature_flags"), empty=True):
                self.error("index-applicability", path, f"{ident}: feature_flags must be a string array (empty is allowed)")
            if not string_list(topic.get("sources")):
                self.error("index-sources", path, f"{ident}: nonblank source locators required")
            try:
                value = topic.get("path")
                base = self.plugin if isinstance(value, str) and value.startswith(("skills/", "./skills/")) else self.skill
                target = self.local(base, value, self.skill)
                if not target.is_file() or not target.is_relative_to(self.skill / "references"):
                    raise Invalid("topic must point to a bundled reference file")
                if target in covered:
                    raise Invalid("duplicate topic path")
                covered.add(target)
            except (Invalid, TypeError, ValueError, OSError) as exc:
                self.error("index-path", path, f"{ident}: {exc}")
        for ref in (self.skill / "references").rglob("*"):
            if ref.is_file() and ref.resolve() not in covered:
                self.error("index-omission", path, f"reference not covered: {ref.relative_to(self.skill)}")

    def export(self):
        # Invoke the installed upstream CLI, not a locally reimplemented exporter.
        bin_dir = Path(sys.executable).parent
        builder, checker = bin_dir / "build-agent-skill", bin_dir / "skills-ref"
        for executable in (builder, checker):
            if not executable.is_file():
                self.error("dependency", executable, "required CLI missing from Python environment")
        if self.errors:
            return
        with tempfile.TemporaryDirectory(prefix="shopware-export-") as tmp:
            output = Path(tmp)
            for command in ([str(builder), str(self.skill), str(output)], [str(checker), "validate", str(output / NAME)]):
                result = subprocess.run(command, text=True, capture_output=True, timeout=120)
                if result.returncode:
                    self.error("export-command", self.skill, f"{command[0]} exited {result.returncode}: {result.stdout}{result.stderr}")
                    return
            exported = output / NAME
            self.metadata(exported, native=False)
            self.runtime(exported)
            for error in validate_portable(exported):
                self.error("skills-ref", exported, error)
            _, source_body = frontmatter((self.skill / "SKILL.md").read_text())
            _, export_body = frontmatter((exported / "SKILL.md").read_text())
            if source_body != export_body:
                self.error("export-body", exported, "instruction body changed during export")
            expected = {p.relative_to(self.skill).as_posix(): p.read_bytes() for p in self.skill.rglob("*") if p.is_file() and p.name not in {"SKILL.md", ".agent-skills"}}
            actual = {p.relative_to(exported).as_posix(): p.read_bytes() for p in exported.rglob("*") if p.is_file() and p.name != "SKILL.md"}
            if expected != actual:
                self.error("export-files", exported, "reference/assets file set or bytes changed")
            archive_path = output / f"{NAME}.zip"
            with zipfile.ZipFile(archive_path) as archive:
                members = archive.namelist()
                files = {f"{NAME}/{p.relative_to(exported).as_posix()}": p.read_bytes() for p in exported.rglob("*") if p.is_file()}
                if len(set(members)) != len(members) or set(members) != set(files) or any(archive.read(k) != v for k, v in files.items()):
                    self.error("export-zip", archive_path, "ZIP differs from validated portable directory")

    def run(self, export=True):
        if not self.skill.is_dir():
            self.error("skill-path", self.skill, "canonical skill directory missing")
        if not (self.skill / ".agent-skills").is_file():
            self.error("export-marker", self.skill, ".agent-skills marker required beside SKILL.md")
        notice = self.skill / "LICENSE"
        if not notice.is_file() or notice.is_symlink() or not notice.read_text(encoding="utf-8").strip():
            self.error("license-notice", notice, "bundle the license notice inside the installed skill")
        self.metadata(self.skill, native=True)
        self.runtime(self.skill)
        self.manifests()
        self.knowledge_index()
        if export and not self.errors:
            try:
                self.export()
            except (OSError, ValueError, subprocess.TimeoutExpired, zipfile.BadZipFile) as exc:
                self.error("export", self.skill, str(exc))
        return self.errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--structural-only", action="store_true", help="diagnostic only; omits export (not a release gate)")
    args = parser.parse_args()
    errors = PackValidator(args.root).run(export=not args.structural_only)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    print("PASS: native structure" + (" (export NOT checked)" if args.structural_only else ", upstream export, skills-ref and ZIP parity"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
