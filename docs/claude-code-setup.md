# Recommended Claude Code Setup

Nothing in this file is required to use the plugins, but everything in it makes them more pleasant to work with. It's what the maintainers of this marketplace rely on day-to-day.

Paths below refer to the user-level config at `~/.claude/settings.json`. You can also drop these settings into a project-level `.claude/settings.json` if you prefer per-repo configuration.

---

## 1. 🌿 Environment Variables

These go under the `env` key in `settings.json`. Several are experimental or undocumented internal flags that aren't part of Claude Code's public API and may change without notice. The list reflects what works well with this marketplace today.

```json
{
  "env": {
    "DISABLE_AUTOUPDATER": "1",
    "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING": "1",
    "CLAUDE_CODE_DISABLE_FAST_MODE": "1",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_NEW_INIT": "1",
    "CLAUDE_CODE_NO_FLICKER": "1",
    "ENABLE_CLAUDEAI_MCP_SERVERS": "0",
    "ENABLE_TOOL_SEARCH": "1"
  }
}
```

| Variable                                  | Why it's useful                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `DISABLE_AUTOUPDATER=1`                   | Pins your Claude Code version. Avoids surprise breakage in the middle of a long session. Update on your own schedule with `claude update`.                                                                                                                                                                                                                                                                                                                                                                                                   |
| `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` | Disables Claude Code's automatic thinking-budget reductions. See [Reasoning Quality and Consistency](#2-reasoning-quality-and-consistency) for the full story.                                                                                                                                                                                                                                                                                                                                                                               |
| `CLAUDE_CODE_DISABLE_FAST_MODE=1`         | Disables `/fast` so [fast mode](https://docs.claude.com/en/docs/claude-code/fast-mode) can't be turned on by accident. Fast mode is the same Opus 4.6 with a different API configuration. It runs 2.5× faster at \$30 / \$150 MTok. Quality is identical, so you're paying for latency rather than reasoning depth. On Pro/Max/Team/Enterprise plans fast mode is billed to extra usage and isn't covered by your subscription quota, which means a stray `/fast` can produce surprise charges. Set this if you never want fast mode active. |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`  | Required if you want to use the `test-writing` plugin's team-consensus review mode. Enables [Agent Teams](https://code.claude.com/docs/en/agent-teams). Experimental, and may move or rename.                                                                                                                                                                                                                                                                                                                                                |
| `CLAUDE_CODE_NEW_INIT=1`                  | Opts into the newer init/startup flow.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `CLAUDE_CODE_NO_FLICKER=1`                | Switches Claude Code to an experimental renderer using the terminal's alternate screen buffer. Input pins to the bottom, scrollback is virtualized, and mouse and keyboard navigation work. See [New Terminal Mode](#3-new-terminal-mode-no_flicker) for the full story.                                                                                                                                                                                                                                                                     |
| `ENABLE_CLAUDEAI_MCP_SERVERS=0`           | Opts out of claude.ai-managed MCP servers so only your own `.mcp.json` and plugin-supplied MCP servers load. Recommended when you install several MCP-heavy plugins from this marketplace.                                                                                                                                                                                                                                                                                                                                                   |
| `ENABLE_TOOL_SEARCH=1`                    | Highly recommended for this marketplace. Enables deferred tool loading, so tool schemas fetch on demand instead of all at once at session start. The `dev-tooling` plugin alone exposes around 30 MCP tools. A typical setup with `gh-tooling`, `test-writing`, and `chunkhound-integration` pushes that well over 60. Tool search keeps the context window lean.                                                                                                                                                                            |

> [!WARNING]
> The `CLAUDE_CODE_*` variables prefixed with `EXPERIMENTAL` or describing internal behavior (`NEW_INIT`, `DISABLE_ADAPTIVE_THINKING`) aren't part of the public Claude Code API. Treat them as opt-in tweaks that may change between Claude Code releases. `DISABLE_FAST_MODE` is officially documented and stable.

---

## 2. 🧠 Reasoning Quality and Consistency

Have you ever asked Claude Code the same question twice and gotten one thorough, well-reasoned answer and one shallow, hand-wavy one? That's adaptive thinking. Claude Code dynamically reduces the model's thinking budget on many turns, most likely as a capacity-saving measure on Anthropic's side. When it kicks in, multi-step reasoning gets shallower than the model is capable of, and you see it as inconsistent quality from one prompt to the next.

Fast mode is a different thing entirely. It's a cost and latency lever that runs the same Opus 4.6 with a different API configuration. Quality is identical. You just pay more for speed. See the `DISABLE_FAST_MODE` row in [Environment Variables](#1-environment-variables) for details.

The plugins here lean on reasoning quality. Test generation, architectural research, PR analysis, release note drafting. All of them work better when the model isn't being throttled mid-turn.

### Mitigation

One env var opts out of the throttling.

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING": "1"
  }
}
```

`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` keeps the thinking budget consistent across turns instead of letting Claude Code dial it down.

A second, complementary lever lives in `settings.json` rather than `env`.

```json
{
  "effortLevel": "high"
}
```

`effortLevel` takes `"low"`, `"medium"`, or `"high"`, and nudges Claude Code's overall reasoning effort. `"high"` pairs naturally with the env var above when you want the most thorough behavior available. Together they're the closest you can get to telling Claude Code "stop trying to save effort, just do the work properly."

### The cost

These settings aren't free. You'll pay for the thinking budget you just unlocked with higher token usage per turn. On a Max plan that's rate-limit pressure rather than invoice pressure, but it's real. Turns get slower, sometimes dramatically so on reasoning-heavy prompts. A turn that usually finishes in 20 seconds can take 60 to 90 for a hard one. Long thinking blocks also consume context faster, so cache pressure goes up.

### When to use

Use this configuration for architectural decisions, tricky debugging, long implementation plans, code review, and test generation. Anywhere "wrong but fast" is worse than "right but slow". Skip it for trivial edits, copy-paste boilerplate, one-line fixes, mechanical refactors, and chat-style Q&A.

You can scope it per project rather than globally. Drop the env block in `.claude/settings.json` inside the repos where reasoning quality matters most, and leave your global config alone.

> [!WARNING]
> `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` is an undocumented internal flag. Anthropic could rename, remove, or change its semantics in any release. If you suddenly notice everything got slower *and* the env var stopped having any effect, check the Claude Code release notes.

---

## 3. 🖥️ New Terminal Mode (NO_FLICKER)

`CLAUDE_CODE_NO_FLICKER=1` is more than a rendering tweak. It switches Claude Code to an experimental new renderer that runs in the terminal's alternate screen buffer, the same mechanism `vim`, `htop`, and `less` use. Anthropic hasn't shipped it as the default because it makes real trade-offs against native terminal features, but most internal users prefer it once they try it.

```json
{
  "env": {
    "CLAUDE_CODE_NO_FLICKER": "1"
  }
}
```

### What you get

Input pins to the bottom, so the prompt no longer jumps around as tool output streams in. Streaming code blocks, ASCII diagrams, dense tables, and deeply nested lists render smoothly line by line without the screen flashing or reflowing.

Scrollback is virtualized. Only visible messages stay in the render tree, which keeps memory roughly constant no matter how long the conversation runs. Long sessions with heavy tool output stop degrading.

Mouse support works inside the terminal. Click to position the cursor, click to expand or collapse tool output blocks, click URLs, and scroll with the wheel. Keyboard navigation uses `PgUp`/`PgDn` and `Ctrl+Home`/`Ctrl+End` to jump around scrollback. `Ctrl+o` opens transcript mode, a `less`-style view with `/` search that replaces the terminal's native search.

### What you give up

The renderer is early and trades away some native terminal features.

- `Cmd+F` doesn't work. Search with `Ctrl+o` then `/` instead.
- Native terminal scrollback is gone, since scrolling is handled inside Claude Code.
- Native text selection is replaced by an in-app selection mode.
- URLs open on plain click instead of `Cmd`-click.
- tmux integration mode is incompatible with iTerm2's `tmux -CC`.

### Fine-tuning

A few related env vars let you keep the new renderer while restoring some native behavior.

```json
{
  "env": {
    "CLAUDE_CODE_NO_FLICKER": "1",
    "CLAUDE_CODE_DISABLE_MOUSE": "1",
    "CLAUDE_CODE_DISABLE_MOUSE_CLICKS": "1",
    "CLAUDE_CODE_SCROLL_SPEED": "3"
  }
}
```

`CLAUDE_CODE_DISABLE_MOUSE=1` keeps flicker-free rendering but drops mouse capture entirely. It's useful over SSH, or inside tmux where you want native text selection back. `CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1` drops click events while keeping the scroll wheel, a middle ground if you only care about wheel scrolling. `CLAUDE_CODE_SCROLL_SPEED=3` adjusts scroll wheel speed on a scale from 1 to 20, with the default being 1.

> [!WARNING]
> The renderer is experimental. Behavior, env var names, and trade-offs may change between Claude Code releases. If you hit a regression, unsetting `CLAUDE_CODE_NO_FLICKER` falls back to the default renderer immediately.

---

## 4. 🤝 Complementary Marketplaces

This marketplace focuses on Shopware development. A few plugins from other public marketplaces compose well with it.

### superpowers (Anthropic)

Process skills that govern *how* Claude approaches work. Brainstorming before implementation, TDD for non-trivial changes, systematic debugging, plan writing and execution, and code review workflows.

```bash
/plugin marketplace add anthropics/claude-code
/plugin install superpowers@claude-plugins-official
```

The `test-writing` and `contributor-writing` plugins in this marketplace pair naturally with `superpowers:brainstorming` (for figuring out *what* to test) and `superpowers:writing-plans` (for multi-step contribution work).

### ai-tools (IT-Bens)

A community marketplace with general-purpose guardrails and quality plugins.

```bash
/plugin marketplace add it-bens/ai-tools
/plugin install llm-author@itb-ai-tools
/plugin install native-tools-enforcer@itb-ai-tools
/plugin install redundant-read-blocker@itb-ai-tools
```

`llm-author` provides skills for authoring LLM-targeted content: `prompt-engineering` for prompts and system instructions, `content-editing` as a "minimal change" skill that pushes Claude to *correct* existing content rather than pile additions on top, and `rule-file-writing` for `~/.claude/rules/` behavioral steering files. It's useful when you contribute back to this marketplace.

`native-tools-enforcer` uses hooks to block Bash equivalents of native tools (`grep`, `cat`, `find`, and friends) and routes Claude to `Grep`, `Read`, `Glob` instead. It cuts a lot of wasted tool calls.

`redundant-read-blocker` uses hooks to prevent re-reading files that haven't changed. It tracks read ranges and decays context over time. It pairs especially well with this marketplace's larger PR-analysis and test-generation workflows where the same files get touched repeatedly.

Optional model-enforcer plugins from the same marketplace pin specific models for the built-in `Explore` and `Plan` subagents.

```bash
/plugin install explore-with-sonnet-enforcer@itb-ai-tools   # or explore-with-opus-enforcer
/plugin install plan-with-sonnet-enforcer@itb-ai-tools      # or plan-with-opus-enforcer
```

Pick one enforcer per subagent, sonnet *or* opus, never both. Sonnet is the sensible default. Opus is for when you genuinely need maximum reasoning depth and don't mind the cost.

---

## 5. 🎛️ `settings.json` Patterns

A few `settings.json` keys beyond env vars shape Claude Code's behavior. None of them are CLI flags. They live in the JSON config and persist across sessions.

### Permissions

Pre-approve common tool invocations so you don't have to click through prompts every time.

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": [
      "Bash(git log:*)",
      "Bash(git diff:*)",
      "Bash(composer test:unit:*)",
      "Bash(vendor/bin/phpstan:*)",
      "WebFetch(domain:developer.shopware.com)",
      "WebFetch(domain:docs.claude.com)"
    ],
    "ask": [
      "Bash(php:*)",
      "Bash(mysql:*)"
    ],
    "deny": [
      "Read(.env)"
    ]
  }
}
```

`allow` auto-approves patterns. Use narrow ones like `Bash(git log:*)` instead of broad catchalls like `Bash(*)`. `ask` always prompts even when a broader rule would otherwise allow the tool, and is a good fit for commands that touch state like `mysql` or `php`. `deny` is a hard block. Reach for it when a file should never be read, for example `.env`. `defaultMode` picks the starting permission mode. `"default"` prompts for everything, `"acceptEdits"` auto-approves edits, and `"bypassPermissions"` auto-approves everything (not recommended).

### Selective Plugin Enabling

If you install a marketplace but only want some of its plugins active.

```json
{
  "enabledPlugins": {
    "dev-tooling@shopware-ai-coding-tools": true,
    "gh-tooling@shopware-ai-coding-tools": true,
    "test-writing@shopware-ai-coding-tools": false
  }
}
```

It's gentler than uninstalling. You can flip a plugin off temporarily without losing config.

### Hooks

User-level hooks fire on lifecycle events. A few entry points are most useful for general users. `SessionStart` runs at session start for loading context, running health checks, or printing a banner. `UserPromptSubmit` lets you augment or log prompts. `Stop` and `Notification` are the hooks to wire up desktop notifications when Claude finishes or needs you. `PreToolUse` and `PostToolUse` are what most plugins in this marketplace use internally, but you can layer your own on top.

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "/usr/bin/osascript -e 'display notification \"Claude needs you\"'", "async": true }
        ]
      }
    ]
  }
}
```

### Status Line

Custom shell command rendered in the bottom bar.

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/scripts/status-line.sh"
  }
}
```

The script receives session context on stdin and prints a single line. It's useful for showing token usage, current branch, or current model.

### Local Marketplace Registration

If you're developing a plugin, or want to test changes to this marketplace before they're published.

```json
{
  "extraKnownMarketplaces": {
    "shopware-ai-coding-tools": {
      "source": {
        "source": "directory",
        "path": "/absolute/path/to/your/clone/of/claude-code-plugins"
      }
    }
  }
}
```

Claude Code then resolves `@shopware-ai-coding-tools` to your local checkout instead of fetching from GitHub. Restart Claude Code after editing.

---

## 6. 🚀 Putting It All Together

A minimal `~/.claude/settings.json` that covers the recommendations above.

```json
{
  "env": {
    "DISABLE_AUTOUPDATER": "1",
    "CLAUDE_CODE_DISABLE_FAST_MODE": "1",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "ENABLE_CLAUDEAI_MCP_SERVERS": "0",
    "ENABLE_TOOL_SEARCH": "1"
  },
  "permissions": {
    "defaultMode": "default",
    "allow": [
      "Bash(git log:*)",
      "Bash(git diff:*)",
      "WebFetch(domain:developer.shopware.com)"
    ]
  }
}
```

Then add marketplaces and install plugins.

```bash
/plugin marketplace add shopwareLabs/ai-coding-tools
/plugin marketplace add anthropics/claude-code
/plugin marketplace add it-bens/ai-tools

/plugin install dev-tooling@shopware-ai-coding-tools
/plugin install gh-tooling@shopware-ai-coding-tools
/plugin install superpowers@claude-plugins-official
/plugin install native-tools-enforcer@itb-ai-tools
/plugin install redundant-read-blocker@itb-ai-tools
```

Restart Claude Code after installing anything that ships an MCP server.
