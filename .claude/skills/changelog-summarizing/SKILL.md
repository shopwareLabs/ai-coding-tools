---
name: changelog-summarizing
description: Write a summary post about repository changes since a given date for Discord and Slack. Analyzes commits on main, groups by plugin, and produces separate platform-formatted posts.
allowed-tools: Bash, Read, Grep, AskUserQuestion
---

# Changelog Summary Post

Generate summary posts about repository changes since a given date. Produces two separate outputs: one formatted for Discord (markdown) and one for Slack (mrkdwn).

## Requirements

- Working directory is this repository
- User provides a date (absolute or relative)

## Hard Constraints

- **Main branch only.** Only analyze committed history on the `main` branch. Ignore uncommitted files, staged changes, untracked files, and working tree state entirely. The skill operates as if in a clean checkout.
- **Repository URL:** `https://github.com/shopwareLabs/ai-coding-tools`. Use this for constructing plugin links.

## Phase 1: Parse Date

Extract the date from the user's input. Accept absolute dates ("2026-04-01") and relative dates ("last Monday", "two weeks ago").

If no date is provided, ask:

> What date should I summarize changes from? (e.g., "2026-04-01" or "last Monday")

If the date is in the future, inform the user and stop.

## Phase 2: Discover Commits

Run:

```bash
git log main --since="<date>" --format="%H %s" --no-merges
```

If no commits are found, inform the user and stop:

> No commits found on main since <date>.

## Phase 3: Analyze Each Commit

For every commit hash from Phase 2, run:

```bash
git show <hash>
```

For each commit, extract:
1. The full commit message (intent)
2. The diff (actual code changes)
3. The conventional commit scope from the subject line (if present)

Analyze both the message and the diff to understand what actually changed and why. The message states the intent; the diff confirms what happened. Use both to produce an accurate summary.

## Phase 4: Group and Cluster

**Group by scope:** Parse `type(scope): subject` from each commit's subject line. Group commits by their scope value. Commits without a scope go into a "General" group.

**Detect clusters:** Within each group, identify commits that contribute to the same feature or initiative. Signals include:
- Sequential commits with related subjects
- PR numbers appearing in multiple commits
- Commits that build on each other's changes (visible in diffs)

Clusters get synthesized into a single narrative paragraph instead of being listed separately.

## Phase 5: Synthesize

For each plugin group, write a short contextual paragraph. Follow these rules:

- Focus on user-facing changes: new features, bug fixes, changed behavior, new tools. Describe what changed and why it matters to someone using the plugin
- Internal changes (refactoring, extracting shared code, restructuring files, renaming internals) get skipped unless they change user-visible behavior
- If multiple commits in a group are part of the same feature, merge them into one narrative
- Contextualize changes in the broader project direction when a connection exists (e.g., "builds on the migration support from last week")
- The "General" section covers cross-cutting or unscoped changes

## Phase 6: Anti-Slop Validation

Read [Anti-AI-Slop Rules](mdc:references/writing-rules-anti-ai-slop.md) and apply every rule to the draft post. Specifically:

1. Search the entire draft for em dash (—) and en dash (–) characters. Remove every instance. This is the most common violation.
2. Check every word against the banned vocabulary list. Replace with the plain alternative or delete.
3. Check for banned sentence patterns, colon/semicolon overuse, hedging filler.
4. Verify sentence rhythm varies (mix short and long sentences, no metronomic 15-20 word uniformity).
5. Check for concreteness: no "improved X" when you can name the specific class, config key, or behavior.
6. If any violations found, rewrite the affected text and re-check.

## Phase 7: Format Output

Produce two separate outputs: one for Discord (markdown) and one for Slack (mrkdwn). Both carry the same content, but use each platform's native formatting for links, bold, and headers.

### Plugin Links

Each plugin section header links to the plugin's directory on GitHub at main. Construct URLs as:
`https://github.com/shopwareLabs/ai-coding-tools/tree/main/plugins/<plugin-name>`

The "General" section doesn't get a link.

### Emoji Section Headers

Each plugin group gets an emoji prefix for visual scanability. Use emojis consistent with the repository's README conventions:

- 🔌 dev-tooling
- 🧪 test-writing
- 🔍 chunkhound-integration
- 🚦 ci-failure-interpretation
- ✍️ contributor-writing
- 🐙 gh-tooling
- 🔧 General

For plugins not listed above, pick an emoji that fits the plugin's purpose.

### Discord Format (markdown)

Discord supports standard markdown. Use `**bold**` for emphasis, `[text](url)` for links.

```
**Summary: Changes since <date>**

**🔌 [dev-tooling](https://github.com/shopwareLabs/ai-coding-tools/tree/main/plugins/dev-tooling)**

<contextual paragraph>

**🧪 [test-writing](https://github.com/shopwareLabs/ai-coding-tools/tree/main/plugins/test-writing)**

...

**🔧 General**

...

<AI transparency footer>
```

### Slack Format (mrkdwn)

Slack uses mrkdwn: `*bold*` for bold. No markdown headers. Place plugin URLs as plain text on the line below the bold header (Slack auto-links them).

```
*Summary: Changes since <date>*

*🔌 dev-tooling*
https://github.com/shopwareLabs/ai-coding-tools/tree/main/plugins/dev-tooling

<contextual paragraph>

*🧪 test-writing*
https://github.com/shopwareLabs/ai-coding-tools/tree/main/plugins/test-writing

...

*🔧 General*

...

<AI transparency footer>
```

### AI Transparency Footer

End every post with a short, funny, self-aware one-liner acknowledging LLM authorship. Must be different each time. Same vibe as the README note ("Yes, an AI wrote this README. And everything else as well."). Keep it to one or two sentences. Don't force it if nothing good comes to mind; a simple quip is better than a bad joke.

### Tone

Casual and conversational. Like updating colleagues in Slack or a community in Discord. Use contractions ("don't", "isn't"). No marketing-speak, no enthusiasm ("exciting new feature"). Just describe what happened in a way that's quick to read.

Emojis appear in section headers only, not scattered through prose.

## Phase 8: Adaptive Length

The post length should match the volume and significance of changes. A quiet week with 3 small fixes gets a short post. Two weeks with 20+ commits across 4 plugins gets a longer, more detailed one. Don't compress meaningful content just to hit an arbitrary target.

**Slack:** No hard character limit. Write what the changes need.

**Discord:** 2000-character message limit. If the Discord version exceeds 2000 characters, split it into multiple messages at natural section boundaries (between plugin groups). Each message must be self-contained and under 2000 characters. Mark split points clearly:

```
Message 1: title + first N plugin groups + "(continued...)"
Message 2: remaining plugin groups + footer
```

Count characters for each Discord message and verify all are under 2000.

## Phase 9: Present

Present both versions in separate code blocks, clearly labeled. Show character counts for each Discord message.

```
## Discord

\`\`\`
<discord formatted post, or multiple blocks if split>
\`\`\`
> Message 1: <N> characters
> Message 2: <N> characters (if split)

## Slack

\`\`\`
<slack formatted post>
\`\`\`
```
