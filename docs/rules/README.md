# User-Scoped Claude Code Rules

Rules files are markdown files stored in `~/.claude/rules/` (user-scoped) or `.claude/rules/` (project-scoped) that Claude Code auto-loads. They're really just a way to split a large `CLAUDE.md` into smaller, topical files — same loading mechanism, better organization.

Two loading modes, depending on frontmatter:

- **Unscoped rules** (no frontmatter) load **once at session start** and stay in context for the whole session. Behaves identically to `CLAUDE.md`.
- **Path-scoped rules** (with a `paths:` glob in frontmatter) **lazy-load** the first time Claude reads a file matching the glob. Useful for language- or tool-specific guidance that shouldn't occupy context when it's not relevant.

Unlike skills, rules are not invoked on demand — once loaded, they shape Claude's behavior unconditionally.

This directory collects the rules we've found useful when working on Shopware (and everything else) with Claude Code. Each file is self-contained: copy the ones you want into `~/.claude/rules/` and restart Claude Code.

## 📦 Installation

```bash
mkdir -p ~/.claude/rules
cp calibrated-honesty.md ~/.claude/rules/
# ...repeat for the rules you want
```

Rules take effect on the next session start. You can also scope rules per-project by placing them in `.claude/rules/` inside a repository.

## 🧩 Available Rules

General behavioral steering (apply to every session):

| Rule                                                                 | What it does                                                                                         |
|----------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| [calibrated-honesty.md](./calibrated-honesty.md)                     | Suppresses sycophancy AND reflexive contrarianism. Agree or disagree based on evidence, not vibes.   |
| [calibrated-honesty-in-coding.md](./calibrated-honesty-in-coding.md) | Coding-specific honesty rules: trust the code not the description, reproduce before diagnosing.     |
| [fail-hard-rules.md](./fail-hard-rules.md)                           | Hard failure is the default. Bans silent degradation, defensive fallbacks, and "sensible defaults".  |
| [research-rules.md](./research-rules.md)                             | Forces real web tools for research tasks. Bans silent fallback to training knowledge.                |

Tool-specific rules (apply only when the relevant tool is in use):

| Rule                                               | What it does                                                                                   |
|----------------------------------------------------|------------------------------------------------------------------------------------------------|
| [npm-registry-access.md](./npm-registry-access.md) | Routes npm package metadata lookups to `registry.npmjs.org` instead of the WAF-blocked web UI. |

## 💡 Why Rules And Not Skills?

Skills are invoked on demand when their description matches a task, then loaded and followed for that turn. Rules are auto-loaded (at session start or on first matching file read, depending on frontmatter) and then shape behavior unconditionally for the rest of the session — use them for things that must hold regardless of what Claude is doing, like honesty calibration or failure semantics.

Rough decision test:

- **"Claude should do X when working on Y"** → skill
- **"Claude should never do X"** → rule
- **"Claude should always do X"** → rule

> [!NOTE]
> These rules are opinionated. They reflect preferences built up over many Claude Code sessions on this marketplace. Read each file before installing — if you disagree with the reasoning, don't install it.
