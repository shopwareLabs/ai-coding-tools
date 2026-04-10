# Version Bump Reasoning Reference

Detailed rules for determining MAJOR, MINOR, or PATCH version bumps. All plugins follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Public API Definition

A Claude Code plugin's "public API" — the interfaces consumers depend on:

| Surface | Examples |
|---------|----------|
| Plugin name and install path | How users install it |
| MCP server and tool names | How other plugins/skills reference tools |
| Skill invocation model | Direct call, `context: fork`, pure instruction set |
| Agent names and consumption patterns | How orchestrators spawn agents |
| Hook behavior contracts | What hooks enforce or inject |
| Config file names and schema | What users configure |

Internal implementation (phase logic, reference file layout, agent coordination internals) is **not** public API.

## MAJOR (X.0.0) — Breaking Changes

Bump major when consumers must change their behavior to continue working.

**Triggers:**

- Plugin renamed — `php-tooling` became `dev-tooling` (dev-tooling 2.0.0)
- Plugin extracted into standalone — gh-tooling split from dev-tooling (dev-tooling 3.0.0)
- Skill invocation model changed — skills dropped `context: fork`, callers must spawn explicitly (test-writing 3.0.0)
- Agent names/roles replaced — three agents replaced by two thin fork targets (test-writing 2.0.0)
- MCP tool architecture rewritten — static references replaced by MCP-served rules (test-writing 2.0.0)
- Multiple reference files removed — 7 reviewing references deleted, content moved to MCP (test-writing 2.0.0)
- Config files require migration

**Indicators:** MAJOR bumps always include a `### Migration` section or multiple `### Removed` entries. They always affect at least one of: plugin name, MCP tool surface, skill consumption model, or agent interface.

## MINOR (x.Y.0) — New Capabilities

Bump minor when the plugin gains user-facing capabilities that were not possible before.

**Triggers:**

- New skill — pr-description-writing (contributor-writing 1.1.0), setup skill (dev-tooling 3.9.0)
- New MCP tool — console_run/console_list (dev-tooling 1.4.0), phpunit_coverage_gaps (dev-tooling 3.2.0)
- New hook type — PreToolUse enforcement (dev-tooling 2.1.0), PostToolUse baseline check (dev-tooling 3.8.0)
- New environment type — Docker Compose (dev-tooling 3.6.0)
- New agent — test-adversary (test-writing 2.6.0)
- New command
- Significant new parameters on existing tools — suppress_errors + fallback + jq_filter + grep on all 19 tools (dev-tooling 2.5.0)
- New test rule when independently queryable via MCP — UNIT-009 (test-writing 2.5.0)
- Significant capability expansion — team review expanded to multiple files (test-writing 2.3.0)

## PATCH (x.y.Z) — Fixes and Refinements

Bump patch for bug fixes, behavioral corrections, refinements, and internal restructuring that adds no new user-facing capability.

**Triggers:**

- Bug fixes — missing lib/config.sh (dev-tooling 1.3.1), shell quoting errors (dev-tooling 3.1.1), missing reference copies (contributor-writing 1.6.1)
- Rule/detection refinements — E008 false positives (test-writing 1.2.7), W012/E019/E009 regressions (test-writing 1.2.5)
- Behavioral/workflow corrections — phase execution enforcement (test-writing 2.0.1), premature defense stances (test-writing 2.6.1)
- Internal refactoring — replaced explicit MCP tool lists with wildcards (test-writing 3.2.1)
- Description/documentation improvements — clarified parameter descriptions (dev-tooling 2.5.1), changed skill description wording (chunkhound 1.0.3)
- Validation/guard additions to existing features — anti-slop validation pass (contributor-writing 1.1.6), model pin (contributor-writing 1.4.4)
- Removing deprecated/legacy internals — removed resolve_legacy tool (test-writing 2.0.3)

## Edge Cases

### "Added" Does Not Always Mean MINOR

When an addition refines, guards, or validates an existing feature, it is PATCH — users do not gain a capability they lacked.

- Adding anti-slop validation to an existing writing skill → PATCH (the skill already produced output; this improves quality)
- Adding a filter mode to an existing MCP tool → PATCH (the tool already existed)
- Extracting a shared reference file from inline code → PATCH (no new capability)

### "Breaking" in Description Does Not Always Mean MAJOR

If the breaking change is internal (restructured agents, reorganized phases) and transparent to consumers (the orchestrator absorbs it), it stays MINOR or PATCH. Example: test-writing 1.2.0 described "Breaking: Split reviewer into two agents" but was MINOR because the orchestrator hid the change.

### Test Rules: Pre-MCP vs Post-MCP

Before test-writing 2.0.0, rules were internal to the reviewing skill — adding them was PATCH. After 2.0.0, rules became independently queryable via MCP, making them public API — adding them became MINOR. The key: is the component part of the public API surface?

### Removal of Capabilities

- Removing a deprecated component already superseded → PATCH (test-writing 2.0.3 removed resolve_legacy)
- Removing a functional component consumers depend on → MAJOR (dev-tooling 3.0.0 extracted gh-tooling)

### Batch Additions

Multiple small additions shipping as a cohesive feature constitute a meaningful new capability → MINOR even if each individual parameter seems incremental (dev-tooling 2.5.0).

### Setup Skills

Adding an interactive setup skill is always MINOR — it is a new user-facing capability even though it does not change the plugin's core functionality.
